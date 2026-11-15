-- LUMEN CORE: Deep Delve — the three hazards.
-- Chaser Drones hunt the player, Falling Rocks drop from the cave roof,
-- Lava Blobs patrol the floor and lunge. Each zone fields its own mix at
-- its own speed, and the Core Guardian spawns extra chasers while the
-- Core Crystal is being mined. Movement and collision are simulated here
-- on the client; the server only applies the damage, with its own
-- invulnerability window, so a hit is always the server's call.
-- SPDX-License-Identifier: MIT

local EnemyController = {}

local context = nil
local enemies = {}
local nextId = 1
local spawnTimer = 0

local CHASER_SIZE = 24
local ROCK_SIZE = 22
local BLOB_SIZE = 30

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

-- The Core Guardian: extra chasers that swarm while the Core Crystal is
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

-- Keep the zone's mix topped up: chasers enter from the edges, rocks fall
-- on a timer, blobs spawn inside the arena.
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
end

local function rectsOverlap(a, b)
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function EnemyController.update(dt, playerRect, playerInvulnerable)
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
		end

		if enemies[i] == enemy then
			enemy.frame.Position = UDim2.fromOffset(
				math.floor(enemy.x + 0.5),
				math.floor(enemy.y + 0.5)
			)
			local size = enemy.type == "blob" and BLOB_SIZE
				or (enemy.type == "rock" and ROCK_SIZE or CHASER_SIZE)
			local enemyRect = { x = enemy.x, y = enemy.y, w = size, h = size }
			if not playerInvulnerable and rectsOverlap(playerRect, enemyRect) then
				context.remotes.action:FireServer("TakeHit", { enemyType = enemy.type })
			end
		end
	end
end

return EnemyController
