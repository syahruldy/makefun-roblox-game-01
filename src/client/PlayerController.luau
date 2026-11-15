-- NEON CORE: Vault Breaker — the player drone.
-- Reads the keyboard every frame (arrow keys or WASD to move, Space or
-- Shift to phase dash), clamps the drone inside the arena, and owns the
-- dash cooldown and the invulnerability blink. Movement is local and
-- immediate: the server never positions the drone, it only scores it.
-- Star power makes the drone faster and untouchable while it lasts.
-- SPDX-License-Identifier: MIT

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local PlayerController = {}

local context = nil
local drone = nil
local glow = nil

local x = 0
local y = 0
local lastDx = 0
local lastDy = -1
local dashingUntil = 0
local dashReadyAt = 0
local dashDx = 0
local dashDy = 0
local invulnerableUntil = 0

-- The drone: a bright rounded miner with a headlamp dot and a glow ring.
local function buildDrone()
	drone = Instance.new("Frame")
	drone.Name = "Drone"
	drone.Size = UDim2.fromOffset(28, 28)
	drone.BackgroundColor3 = Color3.fromRGB(255, 214, 10)
	drone.BorderSizePixel = 0
	drone.ZIndex = 20
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.35, 0)
	corner.Parent = drone
	glow = Instance.new("UIStroke")
	glow.Color = Color3.fromRGB(255, 240, 150)
	glow.Thickness = 2
	glow.Transparency = 0.3
	glow.Parent = drone
	local lamp = Instance.new("Frame")
	lamp.Name = "Headlamp"
	lamp.AnchorPoint = Vector2.new(0.5, 0.5)
	lamp.Position = UDim2.fromScale(0.5, 0.5)
	lamp.Size = UDim2.fromOffset(10, 10)
	lamp.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	lamp.BorderSizePixel = 0
	lamp.ZIndex = 21
	local lampCorner = Instance.new("UICorner")
	lampCorner.CornerRadius = UDim.new(0.5, 0)
	lampCorner.Parent = lamp
	lamp.Parent = drone
	drone.Parent = context.arena
end

function PlayerController.init(ctx)
	context = ctx
	buildDrone()
	PlayerController.reset()
end

function PlayerController.reset()
	local config = context.config
	x = (config.ARENA_WIDTH - config.PLAYER_SIZE) / 2
	y = (config.ARENA_HEIGHT - config.PLAYER_SIZE) / 2
	dashingUntil = 0
	dashReadyAt = 0
	invulnerableUntil = 0
	PlayerController.place()
end

function PlayerController.place()
	if drone ~= nil then
		drone.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	end
end

function PlayerController.getRect()
	local size = context.config.PLAYER_SIZE
	return { x = x, y = y, w = size, h = size }
end

function PlayerController.getCenter()
	local size = context.config.PLAYER_SIZE
	return { x = x + size / 2, y = y + size / 2 }
end

function PlayerController.isDashing()
	return os.clock() < dashingUntil
end

function PlayerController.isInvulnerable()
	return os.clock() < invulnerableUntil
		or PlayerController.isDashing()
		or context.state.star == true
end

function PlayerController.setInvulnerable(seconds)
	invulnerableUntil = os.clock() + seconds
end

-- Fraction of the dash cooldown that has recharged, 0 to 1.
function PlayerController.getDashCharge()
	local config = context.config
	local cooldown = config.DASH_COOLDOWN_SECONDS
		- context.state.upgrades.dash * config.DASH_COOLDOWN_PER_LEVEL
	local remaining = dashReadyAt - os.clock()
	if remaining <= 0 then
		return 1
	end
	return math.clamp(1 - remaining / cooldown, 0, 1)
end

local function readMoveInput()
	local dx = 0
	local dy = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Left) or UserInputService:IsKeyDown(Enum.KeyCode.A) then
		dx = dx - 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Right) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
		dx = dx + 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Up) or UserInputService:IsKeyDown(Enum.KeyCode.W) then
		dy = dy - 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Down) or UserInputService:IsKeyDown(Enum.KeyCode.S) then
		dy = dy + 1
	end
	return dx, dy
end

local function dashKeyDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- The phase dash: a burst of speed in the current move direction, with
-- brief invulnerability. The drone flashes white while dashing.
local function performPhaseDash(dx, dy)
	local config = context.config
	if os.clock() < dashReadyAt then
		return
	end
	if dx == 0 and dy == 0 then
		dx, dy = lastDx, lastDy
	end
	local length = math.sqrt(dx * dx + dy * dy)
	if length == 0 then
		return
	end
	dashDx = dx / length
	dashDy = dy / length
	dashingUntil = os.clock() + config.DASH_SECONDS
	local cooldown = config.DASH_COOLDOWN_SECONDS
		- context.state.upgrades.dash * config.DASH_COOLDOWN_PER_LEVEL
	dashReadyAt = os.clock() + cooldown
	if glow ~= nil then
		glow.Color = Color3.fromRGB(255, 255, 255)
		glow.Thickness = 3
		glow.Transparency = 0
		task.delay(config.DASH_SECONDS, function()
			glow.Color = Color3.fromRGB(255, 240, 150)
			glow.Thickness = 2
			glow.Transparency = 0.3
		end)
	end
end

function PlayerController.update(dt)
	local config = context.config
	local dx, dy = readMoveInput()
	if dx ~= 0 or dy ~= 0 then
		lastDx, lastDy = dx, dy
	end
	if dashKeyDown() then
		performPhaseDash(dx, dy)
	end

	local speed = config.PLAYER_SPEED
	if context.state.star then
		speed = speed * config.STAR_SPEED_MULTIPLIER
	end
	if PlayerController.isDashing() then
		x = x + dashDx * speed * config.DASH_MULTIPLIER * dt
		y = y + dashDy * speed * config.DASH_MULTIPLIER * dt
	elseif dx ~= 0 or dy ~= 0 then
		local length = math.sqrt(dx * dx + dy * dy)
		x = x + (dx / length) * speed * dt
		y = y + (dy / length) * speed * dt
	end

	local size = config.PLAYER_SIZE
	x = math.clamp(x, 0, config.ARENA_WIDTH - size)
	y = math.clamp(y, 0, config.ARENA_HEIGHT - size)
	PlayerController.place()

	-- Invulnerability blink: the drone fades in and out while it cannot
	-- be hit, so the player can read the safe window.
	if drone ~= nil then
		if PlayerController.isInvulnerable() and not PlayerController.isDashing() then
			local blink = math.floor(os.clock() * 10) % 2 == 0
			drone.BackgroundTransparency = blink and 0.5 or 0.1
		else
			drone.BackgroundTransparency = 0
		end
	end
end

return PlayerController
