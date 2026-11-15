-- NEON CORE: Vault Breaker — power-up drops.
-- Renders the drops the server deals when a crystal is mined, bobs them so
-- they read as pickups, and reports a pickup to the server by drop id. The
-- server is what pays out; this module only draws and measures. Four kinds:
-- Shield blocks one hit, Overdrive doubles mining damage, Time Cell adds
-- clock, Star grants brief invulnerability and speed.
-- SPDX-License-Identifier: MIT

local PowerupController = {}

local context = nil
local effects = nil
local powerups = {} -- id -> { data, frame }

local POWERUP_SIZE = 24

local KIND_STYLE = {
	shield = { color = Color3.fromRGB(144, 224, 239), glyph = "S", text = "SHIELD UP! Blocks one hit" },
	overdrive = { color = Color3.fromRGB(255, 159, 28), glyph = "O", text = "OVERDRIVE! 2x mining" },
	timecell = { color = Color3.fromRGB(128, 255, 0), glyph = "T", text = "TIME CELL! +20 seconds" },
	star = { color = Color3.fromRGB(255, 214, 10), glyph = "*", text = "STAR POWER! Invulnerable" },
}

local function powerupFrame(data)
	local style = KIND_STYLE[data.kind] or KIND_STYLE.shield
	local frame = Instance.new("Frame")
	frame.Name = "Powerup_" .. tostring(data.id)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset(data.x, data.y)
	frame.Size = UDim2.fromOffset(POWERUP_SIZE, POWERUP_SIZE)
	frame.BackgroundColor3 = style.color
	frame.BorderSizePixel = 0
	frame.Rotation = 45
	frame.ZIndex = 12
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0.1
	stroke.Parent = frame
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromOffset(POWERUP_SIZE, POWERUP_SIZE)
	glyph.BackgroundTransparency = 1
	glyph.Text = style.glyph
	glyph.TextColor3 = Color3.fromRGB(20, 20, 28)
	glyph.TextSize = 16
	glyph.Font = Enum.Font.GothamBold
	glyph.Rotation = -45
	glyph.ZIndex = 13
	glyph.Parent = frame
	frame.Parent = context.arena
	return frame
end

function PowerupController.init(ctx, effectsController)
	context = ctx
	effects = effectsController
end

function PowerupController.spawnPowerup(drop)
	if powerups[drop.id] ~= nil then
		return
	end
	powerups[drop.id] = {
		data = drop,
		frame = powerupFrame(drop),
		bornAt = os.clock(),
	}
end

function PowerupController.clear()
	for _, entry in pairs(powerups) do
		entry.frame:Destroy()
	end
	powerups = {}
end

local function rectsOverlap(a, b)
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

-- Each frame: bob the drops and pick up any the drone touches. The pickup
-- is reported once and the frame is cleared optimistically; the server
-- still validates the id before it pays out.
function PowerupController.update(_dt, playerRect)
	local now = os.clock()
	for id, entry in pairs(powerups) do
		local bob = math.sin((now - entry.bornAt) * 4) * 4
		entry.frame.Position = UDim2.fromOffset(entry.data.x, entry.data.y + bob)
		local dropRect = {
			x = entry.data.x - POWERUP_SIZE / 2,
			y = entry.data.y - POWERUP_SIZE / 2,
			w = POWERUP_SIZE,
			h = POWERUP_SIZE,
		}
		if rectsOverlap(playerRect, dropRect) then
			context.remotes.action:FireServer("CollectPowerup", { id = id })
			entry.frame:Destroy()
			powerups[id] = nil
		end
	end
end

-- The server confirmed the pickup: pop the kind's text where the drop
-- stood, and burst its colour across the arena.
function PowerupController.onCollected(payload)
	local style = KIND_STYLE[payload.kind]
	if style == nil then
		return
	end
	local state = context.state
	local center = { x = 320, y = 240 }
	effects.floatingText(style.text, center, style.color)
	effects.flash(style.color)
end

return PowerupController
