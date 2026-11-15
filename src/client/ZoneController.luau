-- LUMEN CORE: Deep Delve — zone presentation and the portal.
-- Re-skins the arena in each zone's palette, shows the zone banner, and
-- owns the portal: the glowing gate that opens once the zone's shard goal
-- is met. Walking into it carries the player to the next zone.
-- SPDX-License-Identifier: MIT

local TweenService = game:GetService("TweenService")

local ZoneController = {}

local context = nil
local background = nil
local banner = nil
local bannerTitle = nil
local bannerSubtitle = nil
local portal = nil

local PORTAL_SIZE = 44

function ZoneController.init(ctx, backgroundFrame)
	context = ctx
	background = backgroundFrame

	banner = Instance.new("Frame")
	banner.Name = "ZoneBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.42)
	banner.Size = UDim2.fromOffset(420, 96)
	banner.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	banner.BackgroundTransparency = 0.25
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.ZIndex = 40
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = banner
	bannerTitle = Instance.new("TextLabel")
	bannerTitle.Name = "BannerTitle"
	bannerTitle.Position = UDim2.fromScale(0, 0.12)
	bannerTitle.Size = UDim2.fromScale(1, 0.5)
	bannerTitle.BackgroundTransparency = 1
	bannerTitle.TextSize = 34
	bannerTitle.Font = Enum.Font.GothamBold
	bannerTitle.ZIndex = 41
	bannerTitle.Parent = banner
	bannerSubtitle = Instance.new("TextLabel")
	bannerSubtitle.Name = "BannerSubtitle"
	bannerSubtitle.Position = UDim2.fromScale(0, 0.58)
	bannerSubtitle.Size = UDim2.fromScale(1, 0.32)
	bannerSubtitle.BackgroundTransparency = 1
	bannerSubtitle.TextSize = 18
	bannerSubtitle.Font = Enum.Font.Gotham
	bannerSubtitle.ZIndex = 41
	bannerSubtitle.Parent = banner
	banner.Parent = context.arena
end

-- Paint the cave in the zone's palette and announce it.
function ZoneController.applyZone(zoneIndex)
	local zone = context.config.ZONES[zoneIndex]
	background.BackgroundColor3 = zone.background
	context.arena.BackgroundColor3 = zone.arena
	ZoneController.hidePortal()
	ZoneController.showBanner(zone.name, zone.subtitle, zone.accent)
end

function ZoneController.showBanner(title, subtitle, color)
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color
	bannerSubtitle.Text = subtitle
	bannerSubtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	banner.Visible = true
	banner.BackgroundTransparency = 0.25
	task.delay(2.2, function()
		local tween = TweenService:Create(
			banner,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		local titleTween = TweenService:Create(
			bannerTitle,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 1 }
		)
		local subTween = TweenService:Create(
			bannerSubtitle,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 1 }
		)
		tween:Play()
		titleTween:Play()
		subTween:Play()
		tween.Completed:Connect(function()
			banner.Visible = false
			bannerTitle.TextTransparency = 0
			bannerSubtitle.TextTransparency = 0
		end)
	end)
end

-- The portal: a glowing ring in the top-right of the arena, pulsing while
-- it waits for the player to walk in.
function ZoneController.showPortal()
	if portal ~= nil then
		return
	end
	local zone = context.config.ZONES[context.state.zoneIndex]
	portal = Instance.new("Frame")
	portal.Name = "Portal"
	portal.AnchorPoint = Vector2.new(0.5, 0.5)
	portal.Position = UDim2.fromOffset(context.config.ARENA_WIDTH - 50, 50)
	portal.Size = UDim2.fromOffset(PORTAL_SIZE, PORTAL_SIZE)
	portal.BackgroundColor3 = zone.accent
	portal.BackgroundTransparency = 0.3
	portal.BorderSizePixel = 0
	portal.ZIndex = 12
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = portal
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 3
	stroke.Transparency = 0.1
	stroke.Parent = portal
	local label = Instance.new("TextLabel")
	label.Name = "PortalLabel"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 1, 6)
	label.Size = UDim2.fromOffset(120, 20)
	label.BackgroundTransparency = 1
	label.Text = "PORTAL OPEN"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.ZIndex = 13
	label.Parent = portal
	portal.Parent = context.arena
	task.spawn(function()
		while portal ~= nil do
			local grow = TweenService:Create(
				portal,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Size = UDim2.fromOffset(PORTAL_SIZE + 8, PORTAL_SIZE + 8) }
			)
			grow:Play()
			task.wait(0.5)
			if portal == nil then
				return
			end
			local shrink = TweenService:Create(
				portal,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Size = UDim2.fromOffset(PORTAL_SIZE, PORTAL_SIZE) }
			)
			shrink:Play()
			task.wait(0.5)
		end
	end)
end

function ZoneController.hidePortal()
	if portal ~= nil then
		portal:Destroy()
		portal = nil
	end
end

function ZoneController.getPortalRect()
	if portal == nil then
		return nil
	end
	return {
		x = context.config.ARENA_WIDTH - 50 - PORTAL_SIZE / 2,
		y = 50 - PORTAL_SIZE / 2,
		w = PORTAL_SIZE,
		h = PORTAL_SIZE,
	}
end

return ZoneController
