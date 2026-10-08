-- On-screen display. Reads the player's state attributes, which the server owns.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false

local panel = Instance.new("Frame")
panel.Name = "Haul"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, 16)
panel.Size = UDim2.fromOffset(210, 72)
panel.BackgroundColor3 = Color3.fromRGB(20, 16, 12)
panel.BackgroundTransparency = 0.35
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(0, 8)
title.Size = UDim2.new(1, 0, 0, 18)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(214, 190, 150)
title.Text = "CURRENT HAUL"
title.Parent = panel

local value = Instance.new("TextLabel")
value.Name = "Value"
value.Position = UDim2.fromOffset(0, 28)
value.Size = UDim2.new(1, 0, 0, 36)
value.BackgroundTransparency = 1
value.Font = Enum.Font.GothamBlack
value.TextSize = 28
value.TextColor3 = Color3.fromRGB(255, 255, 255)
value.Parent = panel

local scale = Instance.new("UIScale")
scale.Parent = value

gui.Parent = player:WaitForChild("PlayerGui")

local shownHaul = 0

local function refreshHaul()
	local haul = player:GetAttribute("Haul") or 0
	value.Text = `{haul} WOOD`

	-- Brief pop when the haul goes up.
	if haul > shownHaul then
		scale.Scale = 1.25
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end
	shownHaul = haul
end

player:GetAttributeChangedSignal("Haul"):Connect(refreshHaul)
refreshHaul()
