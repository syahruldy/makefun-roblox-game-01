-- LUMEN CORE: Deep Delve — the client.
-- Builds the screen, wires the controllers, mirrors the server's state and
-- runs the frame loop. The server owns every number; this script owns
-- every pixel. Input is read with IsKeyDown each frame (never InputBegan
-- with gameProcessedEvent, which Roblox's default camera scripts swallow).
-- SPDX-License-Identifier: MIT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local PlayerController = require(script.Parent.PlayerController)
local MiningController = require(script.Parent.MiningController)
local EnemyController = require(script.Parent.EnemyController)
local ZoneController = require(script.Parent.ZoneController)
local HudController = require(script.Parent.HudController)
local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The two channels the server created at place start.
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gameAction = remotes:WaitForChild("GameAction")
local gameEvent = remotes:WaitForChild("GameEvent")

-- The mirrored server state. Starts as the lobby and is replaced wholesale
-- on every StateChanged, so the client can never drift from the server.
local state = {
	phase = "lobby",
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
	won = false,
	score = 0,
}

-- The screen: a full-screen GUI, a coloured background and the centred
-- 640 x 480 arena the whole game plays in.
local gui = Instance.new("ScreenGui")
gui.Name = "GameGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = GameConfig.ZONES[1].background
background.BorderSizePixel = 0
background.Parent = gui

local arena = Instance.new("Frame")
arena.Name = "Arena"
arena.AnchorPoint = Vector2.new(0.5, 0.5)
arena.Position = UDim2.fromScale(0.5, 0.53)
arena.Size = UDim2.fromOffset(GameConfig.ARENA_WIDTH, GameConfig.ARENA_HEIGHT)
arena.BackgroundColor3 = GameConfig.ZONES[1].arena
arena.BorderColor3 = Color3.fromRGB(20, 20, 28)
arena.BorderSizePixel = 3
arena.ClipsDescendants = true
arena.Parent = gui

local context = {
	gui = gui,
	arena = arena,
	state = state,
	config = GameConfig,
	remotes = { action = gameAction, event = gameEvent },
}

EffectsController.init(context)
PlayerController.init(context)
MiningController.init(context, EffectsController)
EnemyController.init(context)
ZoneController.init(context, background)
HudController.init(context, EffectsController)
HudController.showStart()

local function rectsOverlap(a, b)
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

local function applyState(newState)
	for key, value in pairs(newState) do
		state[key] = value
	end
	HudController.updateHud()
end

local events = {
	StateChanged = function(payload)
		applyState(payload)
	end,
	SpawnCrystals = function(payload)
		MiningController.spawnCrystals(payload)
	end,
	CrystalMined = function(payload)
		MiningController.onCrystalMined(payload)
	end,
	PlayerHit = function(_payload)
		PlayerController.setInvulnerable(GameConfig.INVULNERABLE_SECONDS)
		EffectsController.screenShake(8)
		EffectsController.flash(Color3.fromRGB(255, 0, 0))
	end,
	PortalOpened = function(_payload)
		ZoneController.showPortal()
		ZoneController.showBanner(
			"PORTAL OPEN",
			"Walk into the portal for the next zone",
			Color3.fromRGB(144, 224, 239)
		)
	end,
	ZoneStarted = function(payload)
		MiningController.clear()
		EnemyController.clear()
		ZoneController.applyZone(payload.zoneIndex)
		PlayerController.reset()
		if payload.openForge then
			HudController.showForge()
		end
	end,
	CoreSpawned = function(payload)
		MiningController.spawnCore(payload)
		EnemyController.spawnGuardianBarrage(GameConfig.CORE_GUARDIAN_CHASERS)
		ZoneController.showBanner(
			"THE CORE GUARDIAN WAKES",
			"Mine the Core Crystal — and watch your back",
			Color3.fromRGB(255, 214, 10)
		)
	end,
	UpgradeBought = function(_payload)
		-- The state refresh that follows redraws the Forge.
	end,
	GameOver = function(payload)
		HudController.showEnd(payload.won, payload.score)
		if payload.won then
			EffectsController.flash(Color3.fromRGB(255, 214, 10))
		end
	end,
}

gameEvent.OnClientEvent:Connect(function(eventName, payload)
	local handler = events[eventName]
	if handler ~= nil then
		handler(payload or {})
	end
end)

-- The frame loop: only the playing phase moves anything. The Forge, the
-- start screen and the end screen freeze the arena.
RunService.RenderStepped:Connect(function(dt)
	if state.phase == "playing" then
		PlayerController.update(dt)
		local playerRect = PlayerController.getRect()
		MiningController.update(dt, playerRect)
		EnemyController.update(dt, playerRect, PlayerController.isInvulnerable())
		HudController.updateDashBar(PlayerController.getDashCharge())
		local portalRect = ZoneController.getPortalRect()
		if portalRect ~= nil and rectsOverlap(playerRect, portalRect) then
			gameAction:FireServer("EnterPortal", {})
		end
	end
end)

-- The start screen hides once the first zone starts playing.
gameEvent.OnClientEvent:Connect(function(eventName, payload)
	if eventName == "ZoneStarted" and payload.zoneIndex == 1 and not payload.openForge then
		HudController.hideStart()
		HudController.showHud()
	end
end)
