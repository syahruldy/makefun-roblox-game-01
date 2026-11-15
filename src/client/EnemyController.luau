-- NEON CORE: Vault Breaker — the five hazards.
-- Chaser Drones hunt the player, Falling Shards drop from the vault roof,
-- Lava Blobs patrol the floor and lunge, Sentry Turrets hold a corner and
-- fire aimed shots, and the Vault Warden chases slowly while firing radial
-- bullet bursts. Each vault fields its own mix at its own speed, and the
-- Core Guardian spawns extra chasers while the Vault Core is being mined.
-- Movement and collision are simulated here on the client; the server
-- only applies the damage, with its own invulnerability window, so a hit
-- is always the server's call. Dash combat is the mirror image: a dashing
-- drone destroys what it touches, and the Warden is the only enemy a dash
-- merely wounds.
-- SPDX-License-Identifier: MIT

local EnemyController = {}

local context = nil
local enemies = {}
local bullets = {}
local nextId = 1
local spawnTimer = 0
local boss = nil
local bossHitAt = 0

local CHASER_SIZE = 24
local ROCK_SIZE = 22
local BLOB_SIZE = 30
local TURRET_SIZE = 30

local function makeFrame(name, size, color, shape)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = 15
	if shape == "round" then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	elseif shape == "diamond" then
		frame.Rotation = 45
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = frame
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.6
	stroke.Parent = frame
	frame.Parent = context.arena
	return frame
end

function EnemyController.init(ctx)
	context = ctx
end

function EnemyController.clear()
	for _, enemy in ipairs(enemies) do
		enemy.frame:Destroy()
	end
	enemies = {}
	for _, bullet in ipairs(bullets) do
		bullet.frame:Destroy()
	end
	bullets = {}
	if boss ~= nil then
		boss.frame:Destroy()
		boss = nil
	end
end

local function spawnChaser(x, y)
	local enemy = {
		id = nextId,
		type = "chaser",
		frame = makeFrame("Chaser_" .. tostring(nextId), CHASER_SIZE, Color3.fromRGB(255, 77, 77), "diamond"),
		x = x,
		y = y,
		wobble = math.random() * math.pi * 2,
	}
	nextId = nextId + 1
	table.insert(enemies, enemy)
end

local function spawnRock()
	local config = context.config
	local enemy = {
		id = nextId,
		type = "rock",
		frame = makeFrame("Rock_" .. tostring(nextId), ROCK_SIZE, Color3.fromRGB(140, 140, 150), "round"),
		x = math.random(20, config.ARENA_WIDTH - 20),
		y = -ROCK_SIZE,
		speed = 140 + math.random(0, 80),
	}
	nextId = nextId + 1
	table.insert(enemies, enemy)
end

local function spawnBlob()
	local config = context.config
	local enemy = {
		id = nextId,
		type = "blob",
		frame = makeFrame("Blob_" .. tostring(nextId), BLOB_SIZE, Color3.fromRGB(255, 120, 40), "round"),
		x = math.random(40, config.ARENA_WIDTH - 40),
		y = math.random(60, config.ARENA_HEIGHT - 60),
		vx = (math.random(0, 1) == 0 and -1 or 1) * 60,
		vy = (math.random(0, 1) == 0 and -1 or 1) * 40,
		lungeAt = os.clock() + math.random(3, 6),
	}
	nextId = nextId + 1
	table.insert(enemies, enemy)
end

-- A Sentry Turret anchors near a corner and never moves; it fires one
-- aimed shot at the player every few seconds.
local function spawnTurret()
	local config = context.config
	local corners = {
		{ x = 50, y = 60 },
		{ x = config.ARENA_WIDTH - 80, y = 60 },
		{ x = 50, y = config.ARENA_HEIGHT - 90 },
		{ x = config.ARENA_WIDTH - 80, y = config.ARENA_HEIGHT - 90 },
	}
	local spot = corners[math.random(1, #corners)]
	local enemy = {
		id = nextId,
		type = "turret",
		frame = makeFrame("Turret_" .. tostring(nextId), TURRET_SIZE, Color3.fromRGB(170, 80, 255), "round"),
		x = spot.x + math.random(-16, 16),
		y = spot.y + math.random(-16, 16),
		nextShotAt = os.clock() + math.random(1, 2),
	}
	nextId = nextId + 1
	table.insert(enemies, enemy)
end

local function spawnBullet(x, y, vx, vy, color)
	local config = context.config
	local size = config.TURRET_BULLET_SIZE
	local frame = Instance.new("Frame")
	frame.Name = "Bullet"
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = 14
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = frame
	frame.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	frame.Parent = context.arena
	table.insert(bullets, { frame = frame, x = x, y = y, vx = vx, vy = vy, size = size })
end

-- The Vault Warden: a big crowned guardian that chases slowly and fires
-- radial bursts. Its hit points live on the server; this module only
-- draws it, moves it and fires its bullets.
function EnemyController.spawnBoss(payload)
	if boss ~= nil then
		return
	end
	local config = context.config
	local size = config.BOSS_SIZE
	local frame = Instance.new("Frame")
	frame.Name = "Warden"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset(payload.x, payload.y)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = Color3.fromRGB(200, 30, 60)
	frame.BorderSizePixel = 0
	frame.ZIndex = 16
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 214, 10)
	stroke.Thickness = 3
	stroke.Transparency = 0.1
	stroke.Parent = frame
	local crown = Instance.new("Frame")
	crown.Name = "Crown"
	crown.AnchorPoint = Vector2.new(0.5, 0.5)
	crown.Position = UDim2.fromScale(0.5, 0.5)
	crown.Size = UDim2.fromOffset(20, 20)
	crown.BackgroundColor3 = Color3.fromRGB(255, 214, 10)
	crown.BorderSizePixel = 0
	crown.Rotation = 45
	crown.ZIndex = 17
	crown.Parent = frame
	frame.Parent = context.arena
	boss = {
		frame = frame,
		x = payload.x,
		y = payload.y,
		size = size,
		nextBurstAt = os.clock() + 2,
	}
end

function EnemyController.removeBoss()
	if boss ~= nil then
		boss.frame:Destroy()
		boss = nil
	end
end

function EnemyController.hasBoss()
	return boss ~= nil
end

-- The Core Guardian: extra chasers that swarm while the Vault Core is
-- under the pickaxe.
function EnemyController.spawnGuardianBarrage(count)
	local config = context.config
	for _ = 1, count do
		local edge = math.random(1, 4)
		local x, y = 0, 0
		if edge == 1 then
			x, y = math.random(0, config.ARENA_WIDTH), 0
		elseif edge == 2 then
			x, y = math.random(0, config.ARENA_WIDTH), config.ARENA_HEIGHT
		elseif edge == 3 then
			x, y = 0, math.random(0, config.ARENA_HEIGHT)
		else
			x, y = config.ARENA_WIDTH, math.random(0, config.ARENA_HEIGHT)
		end
		spawnChaser(x, y)
	end
end

local function countByType(enemyType)
	local count = 0
	for _, enemy in ipairs(enemies) do
		if enemy.type == enemyType then
			count = count + 1
		end
	end
	return count
end

-- Keep the vault's mix topped up: chasers enter from the edges, rocks
-- fall on a timer, blobs spawn inside the arena, turrets anchor in
-- corners.
local function maintainPopulation(dt, zone)
	spawnTimer = spawnTimer + dt
	if spawnTimer < 1.2 then
		return
	end
	spawnTimer = 0
	local config = context.config
	if countByType("chaser") < zone.chasers then
		local edge = math.random(1, 4)
		if edge == 1 then
			spawnChaser(math.random(0, config.ARENA_WIDTH), 0)
		elseif edge == 2 then
			spawnChaser(math.random(0, config.ARENA_WIDTH), config.ARENA_HEIGHT)
		elseif edge == 3 then
			spawnChaser(0, math.random(0, config.ARENA_HEIGHT))
		else
			spawnChaser(config.ARENA_WIDTH, math.random(0, config.ARENA_HEIGHT))
		end
	end
	if countByType("rock") < zone.rocks then
		spawnRock()
	end
	if countByType("blob") < zone.blobs then
		spawnBlob()
	end
	if countByType("turret") < (zone.turrets or 0) then
		spawnTurret()
	end
end

local function rectsOverlap(a, b)
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function EnemyController.update(dt, playerRect, playerInvulnerable, playerDashing)
	local config = context.config
	local zone = config.ZONES[context.state.zoneIndex]
	maintainPopulation(dt, zone)

	local playerCenter = {
		x = playerRect.x + playerRect.w / 2,
		y = playerRect.y + playerRect.h / 2,
	}
	local now = os.clock()

	for i = #enemies, 1, -1 do
		local enemy = enemies[i]
		if enemy.type == "chaser" then
			-- Hunts the player with a sine wobble so its path is readable.
			local dx = playerCenter.x - enemy.x
			local dy = playerCenter.y - enemy.y
			local length = math.sqrt(dx * dx + dy * dy)
			if length > 1 then
				enemy.x = enemy.x + (dx / length) * zone.enemySpeed * dt
				enemy.y = enemy.y + (dy / length) * zone.enemySpeed * dt
			end
			enemy.wobble = enemy.wobble + dt * 3
			local wobbleOffset = math.sin(enemy.wobble) * 12 * dt
			enemy.x = enemy.x + wobbleOffset
		elseif enemy.type == "rock" then
			-- Falls straight down; gone once it leaves the floor.
			enemy.y = enemy.y + enemy.speed * dt
			if enemy.y > config.ARENA_HEIGHT + ROCK_SIZE then
				enemy.frame:Destroy()
				table.remove(enemies, i)
			end
		elseif enemy.type == "blob" then
			-- Patrols and bounces; lunges at the player every few seconds.
			if now >= enemy.lungeAt then
				local dx = playerCenter.x - enemy.x
				local dy = playerCenter.y - enemy.y
				local length = math.sqrt(dx * dx + dy * dy)
				if length > 1 then
					enemy.vx = (dx / length) * 170
					enemy.vy = (dy / length) * 170
				end
				enemy.lungeAt = now + math.random(3, 6)
			end
			enemy.x = enemy.x + enemy.vx * dt
			enemy.y = enemy.y + enemy.vy * dt
			if enemy.x < 0 or enemy.x > config.ARENA_WIDTH - BLOB_SIZE then
				enemy.vx = -enemy.vx
				enemy.x = math.clamp(enemy.x, 0, config.ARENA_WIDTH - BLOB_SIZE)
			end
			if enemy.y < 0 or enemy.y > config.ARENA_HEIGHT - BLOB_SIZE then
				enemy.vy = -enemy.vy
				enemy.y = math.clamp(enemy.y, 0, config.ARENA_HEIGHT - BLOB_SIZE)
			end
		elseif enemy.type == "turret" then
			-- Anchored: one aimed shot at the player on its timer.
			if now >= enemy.nextShotAt then
				enemy.nextShotAt = now + config.TURRET_SHOT_SECONDS
				local cx = enemy.x + TURRET_SIZE / 2
				local cy = enemy.y + TURRET_SIZE / 2
				local dx = playerCenter.x - cx
				local dy = playerCenter.y - cy
				local length = math.sqrt(dx * dx + dy * dy)
				if length > 1 then
					spawnBullet(
						cx,
						cy,
						(dx / length) * config.TURRET_BULLET_SPEED,
						(dy / length) * config.TURRET_BULLET_SPEED,
						Color3.fromRGB(200, 120, 255)
					)
				end
			end
		end

		if enemies[i] == enemy then
			enemy.frame.Position = UDim2.fromOffset(
				math.floor(enemy.x + 0.5),
				math.floor(enemy.y + 0.5)
			)
			local size = enemy.type == "blob" and BLOB_SIZE
				or (enemy.type == "rock" and ROCK_SIZE
					or (enemy.type == "turret" and TURRET_SIZE or CHASER_SIZE))
			local enemyRect = { x = enemy.x, y = enemy.y, w = size, h = size }
			if playerDashing and rectsOverlap(playerRect, enemyRect) then
				-- Dash combat: the dash destroys what it touches.
				context.remotes.action:FireServer("DashKill", { enemyType = enemy.type })
				enemy.frame:Destroy()
				table.remove(enemies, i)
			elseif not playerInvulnerable and rectsOverlap(playerRect, enemyRect) then
				context.remotes.action:FireServer("TakeHit", { enemyType = enemy.type })
			end
		end
	end

	-- The Warden: slow chase plus a radial burst on its timer. A dash
	-- through it wounds it (one hit per dash, enforced by a short
	-- cooldown); anything else that touches the player hurts the player.
	if boss ~= nil then
		local dx = playerCenter.x - boss.x
		local dy = playerCenter.y - boss.y
		local length = math.sqrt(dx * dx + dy * dy)
		if length > 1 then
			boss.x = boss.x + (dx / length) * config.BOSS_SPEED * dt
			boss.y = boss.y + (dy / length) * config.BOSS_SPEED * dt
		end
		boss.x = math.clamp(boss.x, boss.size / 2, config.ARENA_WIDTH - boss.size / 2)
		boss.y = math.clamp(boss.y, boss.size / 2, config.ARENA_HEIGHT - boss.size / 2)
		boss.frame.Position = UDim2.fromOffset(
			math.floor(boss.x + 0.5),
			math.floor(boss.y + 0.5)
		)
		if now >= boss.nextBurstAt then
			boss.nextBurstAt = now + config.BOSS_BURST_SECONDS
			for k = 1, config.BOSS_BURST_COUNT do
				local angle = (k - 1) * (math.pi * 2 / config.BOSS_BURST_COUNT)
				spawnBullet(
					boss.x,
					boss.y,
					math.cos(angle) * config.BOSS_BULLET_SPEED,
					math.sin(angle) * config.BOSS_BULLET_SPEED,
					Color3.fromRGB(255, 60, 90)
				)
			end
		end
		local bossRect = {
			x = boss.x - boss.size / 2,
			y = boss.y - boss.size / 2,
			w = boss.size,
			h = boss.size,
		}
		if playerDashing and rectsOverlap(playerRect, bossRect) and now - bossHitAt > 0.5 then
			bossHitAt = now
			context.remotes.action:FireServer("DashKill", { enemyType = "boss" })
		elseif not playerInvulnerable and rectsOverlap(playerRect, bossRect) then
			context.remotes.action:FireServer("TakeHit", { enemyType = "boss" })
		end
	end

	-- Bullets fly straight and vanish past the arena edge.
	for i = #bullets, 1, -1 do
		local bullet = bullets[i]
		bullet.x = bullet.x + bullet.vx * dt
		bullet.y = bullet.y + bullet.vy * dt
		if bullet.x < -bullet.size
			or bullet.x > config.ARENA_WIDTH + bullet.size
			or bullet.y < -bullet.size
			or bullet.y > config.ARENA_HEIGHT + bullet.size
		then
			bullet.frame:Destroy()
			table.remove(bullets, i)
		else
			bullet.frame.Position = UDim2.fromOffset(
				math.floor(bullet.x + 0.5),
				math.floor(bullet.y + 0.5)
			)
			local bulletRect = { x = bullet.x, y = bullet.y, w = bullet.size, h = bullet.size }
			if not playerInvulnerable and rectsOverlap(playerRect, bulletRect) then
				context.remotes.action:FireServer("TakeHit", { enemyType = "bullet" })
				bullet.frame:Destroy()
				table.remove(bullets, i)
			end
		end
	end
end

return EnemyController
