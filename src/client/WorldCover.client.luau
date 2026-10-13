-- Darkens the screen while the server makes the forest again at a bigger size
-- (see WorldGrowth on the server), so the trees are not seen vanishing and reappearing.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FADE = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local gui = Instance.new("ScreenGui")
gui.Name = "WorldCover"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50 -- over the rest of the display

local cover = Instance.new("Frame")
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = Color3.fromRGB(6, 10, 12)
cover.BackgroundTransparency = 1
cover.BorderSizePixel = 0
cover.Visible = false
cover.Parent = gui

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.fromScale(0.5, 0.5)
label.Size = UDim2.fromScale(0.8, 0.2)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBlack
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(255, 214, 120)
label.TextTransparency = 1
label.Parent = cover

local limit = Instance.new("UITextSizeConstraint")
limit.MaxTextSize = 34
limit.Parent = label

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local function update()
	local covered = Workspace:GetAttribute("WorldCovered") == true
	if covered then
		label.Text = Workspace:GetAttribute("WorldCover") or ""
		cover.Visible = true
	end
	local goal = if covered then 0 else 1
	TweenService:Create(cover, FADE, { BackgroundTransparency = goal }):Play()
	local fade = TweenService:Create(label, FADE, { TextTransparency = goal })
	fade.Completed:Connect(function()
		if Workspace:GetAttribute("WorldCovered") ~= true then
			cover.Visible = false
		end
	end)
	fade:Play()
end

Workspace:GetAttributeChangedSignal("WorldCovered"):Connect(update)
if Workspace:GetAttribute("WorldCovered") == true then
	update()
end
