-- NEON CORE: Vault Breaker — the game server.
-- The single authority for game state: ore, shards, lives, vault, timer,
-- combo, shield, power-up timers, the boss, upgrades, win and loss. The
-- client renders and reports; this script decides. Every client action
-- arrives on one RemoteEvent (GameAction) and every state change leaves on
-- one RemoteEvent (GameEvent), so the wire between client and server is
-- two channels and nothing else.
-- SPDX-License-Identifier: MIT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ZoneServer = require(script.Parent.ZoneServer)

math.randomseed(os.time())

-- The two channels. Created here at place start so the client can wait for
-- them before it builds anything.
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local gameAction = Instance.new("RemoteEvent")
gameAction.Name = "GameAction"
gameAction.Parent = remotesFolder

local gameEvent = Instance.new("RemoteEvent")
gameEvent.Name = "GameEvent"
gameEvent.Parent = remotesFolder

-- One run's state. Single-player game: one player, one state table, reset
-- whenever a player joins.
local state = nil
local player = nil

local function newState()
	return {
		phase = "lobby", -- lobby | playing | forge | ended
		ore = 0,
		shards = 0,
		shardsInZone = 0,
		lives = GameConfig.START_LIVES,
		maxLives = GameConfig.START_LIVES,
		zoneIndex = 1,
		timeLeft = GameConfig.GAME_TIME_SECONDS,
		upgrades = { pickaxe = 0, dash = 0, magnet = 0, hull = 0 },
		portalOpen = false,
		coreSpawned = false,
		coreMined = false,
		won = false,
		score = 0,
		combo = 0,
		bonusScore = 0,
		shield = false,
		bossHp = nil, -- nil until the Warden spawns
		bossDefeated = false,
	}
end

-- The crystal registry: id -> crystal. A crystal can only be mined once,
-- because mining deletes its row here before anything is awarded.
local crystals = {}
local nextCrystalId = 1

-- The power-up registry: id -> power-up. Same one-claim rule as crystals.
local powerups = {}
local nextPowerupId = 1

-- Power-up timers live outside the snapshot table because they are clock
-- values; the snapshot carries the seconds left instead.
local overdriveUntil = 0
local starUntil = 0

local function sendEvent(eventName, payload)
	if player ~= nil then
		gameEvent:FireClient(player, eventName, payload)
	end
end

-- The ore multiplier the current combo pays: x1 at combo 0-1, up to x2.
local function comboMultiplier()
	return 1 + GameConfig.COMBO_ORE_PER_STEP * math.max(state.combo - 1, 0)
end

-- A plain snapshot of the state, safe to send over a RemoteEvent.
local function snapshot()
	local now = os.clock()
	return {
		phase = state.phase,
		ore = state.ore,
		shards = state.shards,
		shardsInZone = state.shardsInZone,
		lives = state.lives,
		maxLives = state.maxLives,
		zoneIndex = state.zoneIndex,
		timeLeft = state.timeLeft,
		upgrades = {
			pickaxe = state.upgrades.pickaxe,
			dash = state.upgrades.dash,
			magnet = state.upgrades.magnet,
			hull = state.upgrades.hull,
		},
		portalOpen = state.portalOpen,
		coreSpawned = state.coreSpawned,
		won = state.won,
		score = state.score,
		combo = state.combo,
		multiplier = comboMultiplier(),
		bonusScore = state.bonusScore,
		shield = state.shield,
		overdrive = now < overdriveUntil,
		overdriveLeft = math.max(0, math.ceil(overdriveUntil - now)),
		star = now < starUntil,
		starLeft = math.max(0, math.ceil(starUntil - now)),
		bossHp = state.bossHp,
		bossDefeated = state.bossDefeated,
	}
end

local function broadcastState()
	sendEvent("StateChanged", snapshot())
end

local function computeScore()
	return state.ore
		+ state.shards * GameConfig.SCORE_PER_SHARD
		+ state.bonusScore
		+ state.timeLeft * GameConfig.SCORE_PER_SECOND_LEFT
		+ state.lives * GameConfig.SCORE_PER_LIFE_LEFT
end

local function raiseCombo()
	state.combo = math.min(state.combo + 1, GameConfig.COMBO_MAX)
end

local function spawnCrystalBatch(zoneIndex, count)
	local batch = ZoneServer.generateCrystalBatch(zoneIndex, nextCrystalId, count)
	nextCrystalId = nextCrystalId + #batch
	for _, crystal in ipairs(batch) do
		crystals[crystal.id] = crystal
	end
	sendEvent("SpawnCrystals", batch)
end

local function spawnCoreCrystal()
	local core = ZoneServer.generateCoreCrystal(nextCrystalId)
	nextCrystalId = nextCrystalId + 1
	crystals[core.id] = core
	state.coreSpawned = true
	sendEvent("CoreSpawned", core)
end

local function spawnBoss()
	local boss = ZoneServer.generateBoss()
	state.bossHp = boss.hp
	sendEvent("BossSpawned", boss)
end

-- Starts a vault: fresh crystals, a reset shard counter, and the Forge
-- between vaults (never before the first vault, always after clearing
-- one). ZoneStarted goes out BEFORE the crystals: the client's
-- ZoneStarted handler clears the arena, so a batch dealt before it would
-- be wiped on arrival and the vault would open empty.
local function startZone(zoneIndex, openForge)
	state.zoneIndex = zoneIndex
	state.shardsInZone = 0
	state.portalOpen = false
	state.bossHp = nil
	state.bossDefeated = false
	crystals = {}
	powerups = {}
	if openForge then
		state.phase = "forge"
		sendEvent("ZoneStarted", { zoneIndex = zoneIndex, openForge = true })
	else
		state.phase = "playing"
		sendEvent("ZoneStarted", { zoneIndex = zoneIndex, openForge = false })
	end
	spawnCrystalBatch(zoneIndex)
	if ZoneServer.isFinalZone(zoneIndex) then
		spawnCoreCrystal()
		spawnBoss()
	end
	broadcastState()
end

local function endGame(won)
	if state.phase == "ended" then
		return
	end
	state.phase = "ended"
	state.won = won
	state.score = computeScore()
	broadcastState()
	sendEvent("GameOver", { won = won, score = state.score })
end

local function startGame()
	state = newState()
	crystals = {}
	powerups = {}
	nextCrystalId = 1
	nextPowerupId = 1
	overdriveUntil = 0
	starUntil = 0
	startZone(1, false)
end

-- Power-up drop: a mined crystal sometimes leaves one behind. The kind is
-- a fair roll across the four kinds, and the drop spawns where the
-- crystal stood so the player can grab it on the way past.
local function maybeDropPowerup(x, y)
	if math.random() > GameConfig.POWERUP_DROP_CHANCE then
		return
	end
	local kinds = GameConfig.POWERUP_KINDS
	local kind = kinds[math.random(1, #kinds)]
	local id = nextPowerupId
	nextPowerupId = nextPowerupId + 1
	local drop = { id = id, kind = kind, x = x, y = y }
	powerups[id] = drop
	sendEvent("PowerupSpawned", drop)
end

-- Mining: the client reports a crystal id it finished mining. The id must
-- still be in the registry, which is what stops a double claim: the row is
-- deleted before the reward is paid.
local function onMineCrystal(crystalId)
	if state.phase ~= "playing" then
		return
	end
	local crystal = crystals[crystalId]
	if crystal == nil then
		return
	end
	crystals[crystalId] = nil
	raiseCombo()
	local oreGain = math.floor(crystal.ore * comboMultiplier() + 0.5)
	state.ore = state.ore + oreGain
	state.shards = state.shards + 1
	state.shardsInZone = state.shardsInZone + 1
	sendEvent("CrystalMined", {
		id = crystalId,
		ore = oreGain,
		combo = state.combo,
		multiplier = comboMultiplier(),
		isCore = crystal.isCore == true,
	})
	if crystal.isCore == true then
		state.coreMined = true
		broadcastState()
		endGame(true)
		return
	end
	maybeDropPowerup(crystal.x, crystal.y)
	if ZoneServer.isPortalOpen(state.zoneIndex, state.shardsInZone) and not state.portalOpen then
		state.portalOpen = true
		sendEvent("PortalOpened", { zoneIndex = state.zoneIndex })
	end
	broadcastState()
	-- Keep the vault stocked: one replacement crystal a few seconds later.
	local zoneAtMineTime = state.zoneIndex
	task.delay(GameConfig.CRYSTAL_RESPAWN_SECONDS, function()
		if state.phase ~= "playing" or state.zoneIndex ~= zoneAtMineTime then
			return
		end
		local count = 0
		for _ in pairs(crystals) do
			count = count + 1
		end
		if count < GameConfig.CRYSTALS_PER_ZONE then
			spawnCrystalBatch(zoneAtMineTime, 1)
		end
	end)
end

-- Dash combat: the client reports an enemy it dashed through. Ordinary
-- enemies pay score and raise the combo; the Warden takes damage, and
-- breaking it pays the boss bonus and ends its barrage.
local function onDashKill(enemyType)
	if state.phase ~= "playing" then
		return
	end
	if enemyType == "boss" then
		if state.bossHp == nil or state.bossDefeated then
			return
		end
		state.bossHp = state.bossHp - GameConfig.BOSS_DASH_DAMAGE
		if state.bossHp <= 0 then
			state.bossHp = 0
			state.bossDefeated = true
			state.bonusScore = state.bonusScore + GameConfig.BOSS_SCORE
			sendEvent("BossDefeated", { bonus = GameConfig.BOSS_SCORE })
		else
			sendEvent("BossDamaged", { hp = state.bossHp, maxHp = GameConfig.BOSS_HP })
		end
		broadcastState()
		return
	end
	raiseCombo()
	state.bonusScore = state.bonusScore + GameConfig.DASH_KILL_SCORE
	sendEvent("EnemyDestroyed", {
		enemyType = enemyType,
		bonus = GameConfig.DASH_KILL_SCORE,
		combo = state.combo,
	})
	broadcastState()
end

-- Power-up pickup: the id must still be in the registry, so a drop can
-- only be claimed once. Shield and the timers are server state; the time
-- cell pays into the clock at once.
local function onCollectPowerup(powerupId)
	if state.phase ~= "playing" then
		return
	end
	local drop = powerups[powerupId]
	if drop == nil then
		return
	end
	powerups[powerupId] = nil
	if drop.kind == "shield" then
		state.shield = true
	elseif drop.kind == "overdrive" then
		overdriveUntil = os.clock() + GameConfig.OVERDRIVE_SECONDS
	elseif drop.kind == "timecell" then
		state.timeLeft = state.timeLeft + GameConfig.TIME_BONUS_SECONDS
	elseif drop.kind == "star" then
		starUntil = os.clock() + GameConfig.STAR_SECONDS
	end
	sendEvent("PowerupCollected", { id = powerupId, kind = drop.kind })
	broadcastState()
end

-- Hits: the client reports contact with an enemy. The server enforces the
-- invulnerability window, so a single brush cannot drain several lives.
-- A shield absorbs one hit instead of a life, and a hit always resets the
-- combo.
local invulnerableUntil = 0

local function onTakeHit(_enemyType)
	if state.phase ~= "playing" then
		return
	end
	if os.clock() < starUntil then
		return
	end
	if os.clock() < invulnerableUntil then
		return
	end
	invulnerableUntil = os.clock() + GameConfig.INVULNERABLE_SECONDS
	state.combo = 0
	if state.shield then
		state.shield = false
		sendEvent("ShieldBlocked", {})
		broadcastState()
		return
	end
	state.lives = state.lives - 1
	sendEvent("PlayerHit", { lives = state.lives })
	broadcastState()
	if state.lives <= 0 then
		endGame(false)
	end
end

local function onEnterPortal()
	if state.phase ~= "playing" or not state.portalOpen then
		return
	end
	local nextZone = ZoneServer.getNextZone(state.zoneIndex)
	if nextZone == nil then
		return
	end
	startZone(nextZone, true)
end

local function onBuyUpgrade(upgradeId)
	if state.phase ~= "forge" then
		return
	end
	local upgrade = GameConfig.UPGRADES[upgradeId]
	if upgrade == nil then
		return
	end
	local level = state.upgrades[upgradeId]
	if level >= #upgrade.costs then
		return
	end
	local cost = upgrade.costs[level + 1]
	if state.ore < cost then
		return
	end
	state.ore = state.ore - cost
	state.upgrades[upgradeId] = level + 1
	if upgradeId == "hull" then
		state.maxLives = math.min(state.maxLives + 1, GameConfig.MAX_LIVES)
		state.lives = math.min(state.lives + 1, state.maxLives)
	end
	sendEvent("UpgradeBought", { upgradeId = upgradeId, level = level + 1 })
	broadcastState()
end

local function onResumeGame()
	if state.phase ~= "forge" then
		return
	end
	state.phase = "playing"
	broadcastState()
end

local function onRestartGame()
	startGame()
end

local actions = {
	StartGame = function()
		startGame()
	end,
	MineCrystal = function(payload)
		onMineCrystal(payload.id)
	end,
	DashKill = function(payload)
		onDashKill(payload.enemyType)
	end,
	CollectPowerup = function(payload)
		onCollectPowerup(payload.id)
	end,
	TakeHit = function(payload)
		onTakeHit(payload.enemyType)
	end,
	EnterPortal = function()
		onEnterPortal()
	end,
	BuyUpgrade = function(payload)
		onBuyUpgrade(payload.upgradeId)
	end,
	ResumeGame = function()
		onResumeGame()
	end,
	RestartGame = function()
		onRestartGame()
	end,
}

gameAction.OnServerEvent:Connect(function(sender, actionName, payload)
	if sender ~= player then
		return
	end
	local handler = actions[actionName]
	if handler ~= nil then
		handler(payload or {})
	end
end)

-- The game clock: one second per tick, only while playing. The Forge
-- pauses it, so upgrades never cost run time.
task.spawn(function()
	while true do
		task.wait(1)
		if state ~= nil and state.phase == "playing" then
			state.timeLeft = state.timeLeft - 1
			if state.timeLeft <= 0 then
				state.timeLeft = 0
				broadcastState()
				endGame(false)
			else
				broadcastState()
			end
		end
	end
end)

local function onPlayerAdded(newPlayer)
	player = newPlayer
	state = newState()
	invulnerableUntil = 0
	overdriveUntil = 0
	starUntil = 0
	broadcastState()
end

local function onPlayerRemoving(leavingPlayer)
	if leavingPlayer == player then
		player = nil
		state = nil
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, existingPlayer in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, existingPlayer)
end
