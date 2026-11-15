-- NEON CORE: Vault Breaker — one-shot visual feedback.
-- Screen shake, flashes, floating text and particle bursts. Every player
-- action gets an answer on screen within a frame: mining pops ore text
-- and a burst, a hit shakes the arena, a vault change flashes the new
-- palette.
-- SPDX-License-Identifier: MIT

local TweenService = game:GetService("TweenService")

local EffectsController = {}

local arena = nil

function EffectsController.init(context)
	arena = context.arena
end

-- A short shake of the whole arena, scaled by how hard the hit was.
function EffectsController.screenShake(intensity)
	if arena == nil then
		return
	end
	local original = arena.Position
	local steps = 6
	for i = 1, steps do
		local offset = intensity * (1 - i / steps)
		arena.Position = UDim2.new(
			original.X.Scale,
			original.X.Offset + math.random(-offset, offset),
			original.Y.Scale,
			original.Y.Offset + math.random(-offset, offset)
		)
		task.wait(0.03)
	end
	arena.Position = original
end

-- A full-arena colour flash that fades out.
function EffectsController.flash(color)
	if arena == nil then
		return
	end
	local overlay = Instance.new("Frame")
	overlay.Name = "Flash"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = color
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 50
	overlay.Parent = arena
	local tween = TweenService:Create(
		overlay,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	tween.Completed:Connect(function()
		overlay:Destroy()
	end)
	tween:Play()
end

-- Text that rises and fades, for ore gains and zone messages.
function EffectsController.floatingText(text, position, color)
	if arena == nil then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "FloatText"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(position.x, position.y)
	label.Size = UDim2.fromOffset(140, 28)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = 20
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.4
	label.ZIndex = 60
	label.Parent = arena
	local tween = TweenService:Create(
		label,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(position.x, position.y - 44), TextTransparency = 1 }
	)
	tween.Completed:Connect(function()
		label:Destroy()
	end)
	tween:Play()
end

-- A burst of small shards flying out from a point and fading: the pop
-- when a crystal breaks or a dash kill lands.
function EffectsController.burst(position, color)
	if arena == nil then
		return
	end
	for i = 1, 6 do
		local angle = (i - 1) * (math.pi * 2 / 6) + math.random() * 0.5
		local distance = 26 + math.random(0, 18)
		local shard = Instance.new("Frame")
		shard.Name = "BurstShard"
		shard.AnchorPoint = Vector2.new(0.5, 0.5)
		shard.Position = UDim2.fromOffset(position.x, position.y)
		shard.Size = UDim2.fromOffset(8, 8)
		shard.BackgroundColor3 = color
		shard.BorderSizePixel = 0
		shard.Rotation = 45
		shard.ZIndex = 60
		shard.Parent = arena
		local tween = TweenService:Create(
			shard,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromOffset(
					position.x + math.cos(angle) * distance,
					position.y + math.sin(angle) * distance
				),
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(3, 3),
			}
		)
		tween.Completed:Connect(function()
			shard:Destroy()
		end)
		tween:Play()
	end
end

-- A quick scale pulse on a frame, for pickups and button presses.
function EffectsController.pulse(frame)
	if frame == nil then
		return
	end
	local original = frame.Size
	local grow = TweenService:Create(
		frame,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(original.X.Offset + 6, original.Y.Offset + 6) }
	)
	grow.Completed:Connect(function()
		local shrink = TweenService:Create(
			frame,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Size = original }
		)
		shrink:Play()
	end)
	grow:Play()
end

return EffectsController
