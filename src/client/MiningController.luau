-- LUMEN CORE: Deep Delve — crystals and mining.
-- Renders the crystal batches the server deals, tracks the pickaxe charge
-- on each crystal the drone touches, and reports a finished mine to the
-- server by crystal id. The server is what pays out; this module only
-- draws and measures. A crystal shrinks and flashes as it cracks, so the
-- player can read how close it is to breaking.
-- SPDX-License-Identifier: MIT

local MiningController = {}

local context = nil
local effects = nil
local crystals = {} -- id -> { data, frame, progress, claimSent }

local CRYSTAL_SIZE = 26
local CORE_SIZE = 64

local function crystalFrame(data, size, color, glowColor)
	local frame = Instance.new("Frame")
	frame.Name = "Crystal_" .. tostring(data.id)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset(data.x, data.y)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Rotation = 45
	frame.ZIndex = 10
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = glowColor
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = frame
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(0.35, 0.35)
	shine.Size = UDim2.fromOffset(math.floor(size * 0.3), math.floor(size * 0.3))
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.25
	shine.BorderSizePixel = 0
	shine.ZIndex = 11
	local shineCorner = Instance.new("UICorner")
	shineCorner.CornerRadius = UDim.new(0.5, 0)
	shineCorner.Parent = shine
	shine.Parent = frame
	frame.Parent = context.arena
	return frame
end

function MiningController.init(ctx, effectsController)
	context = ctx
	effects = effectsController
end

function MiningController.spawnCrystals(batch)
	local zone = context.config.ZONES[context.state.zoneIndex]
	for _, data in ipairs(batch) do
		if crystals[data.id] == nil then
			crystals[data.id] = {
				data = data,
				frame = crystalFrame(data, CRYSTAL_SIZE, zone.crystal, zone.crystalGlow),
				progress = 0,
				claimSent = false,
			}
		end
	end
end

-- The Core Crystal: much bigger, gold, pulsing in the middle of the
-- Sanctum. Mining it wins the run.
function MiningController.spawnCore(coreData)
	if crystals[coreData.id] ~= nil then
		return
	end
	local zone = context.config.ZONES[context.state.zoneIndex]
	local entry = {
		data = coreData,
		frame = crystalFrame(coreData, CORE_SIZE, zone.crystal, zone.crystalGlow),
		progress = 0,
		claimSent = false,
	}
	crystals[coreData.id] = entry
	task.spawn(function()
		while crystals[coreData.id] ~= nil do
			effects.pulse(entry.frame)
			task.wait(1.2)
		end
	end)
end

function MiningController.clear()
	for _, entry in pairs(crystals) do
		entry.frame:Destroy()
	end
	crystals = {}
end

local function rectsOverlap(a, b, extra)
	return a.x < b.x + b.w + extra
		and a.x + a.w + extra > b.x
		and a.y < b.y + b.h + extra
		and a.y + a.h + extra > b.y
end

-- Each frame: every crystal the drone touches (within magnet reach) takes
-- pickaxe damage. A crystal at full charge is claimed once.
function MiningController.update(dt, playerRect)
	local config = context.config
	local state = context.state
	local damage = config.PICKAXE_DAMAGE_PER_SECOND
		+ state.upgrades.pickaxe * config.PICKAXE_DAMAGE_PER_LEVEL
	local reach = config.MAGNET_RADIUS_PIXELS
		+ state.upgrades.magnet * config.MAGNET_RADIUS_PER_LEVEL

	for id, entry in pairs(crystals) do
		local size = entry.data.isCore == true and CORE_SIZE or CRYSTAL_SIZE
		local crystalRect = {
			x = entry.data.x - size / 2,
			y = entry.data.y - size / 2,
			w = size,
			h = size,
		}
		if rectsOverlap(playerRect, crystalRect, reach) then
			entry.progress = entry.progress + damage * dt
			-- Crack feedback: the crystal shrinks as it nears breaking.
			local remaining = 1 - math.clamp(entry.progress / entry.data.hp, 0, 1)
			local shrink = size * (0.7 + 0.3 * remaining)
			entry.frame.Size = UDim2.fromOffset(math.floor(shrink + 0.5), math.floor(shrink + 0.5))
			if entry.progress >= entry.data.hp and not entry.claimSent then
				entry.claimSent = true
				context.remotes.action:FireServer("MineCrystal", { id = id })
			end
		end
	end
end

-- The server confirmed the mine: pop the ore text and clear the frame.
function MiningController.onCrystalMined(payload)
	local entry = crystals[payload.id]
	if entry == nil then
		return
	end
	local center = { x = entry.data.x, y = entry.data.y }
	effects.floatingText(
		"+" .. tostring(payload.ore) .. " ore",
		center,
		Color3.fromRGB(255, 214, 10)
	)
	if payload.isCore == true then
		effects.flash(Color3.fromRGB(255, 214, 10))
	end
	entry.frame:Destroy()
	crystals[payload.id] = nil
end

return MiningController
