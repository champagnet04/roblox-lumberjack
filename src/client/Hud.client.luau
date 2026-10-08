-- On-screen display. Reads the player's state attributes, which the server owns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local PANEL_COLOR = Color3.fromRGB(20, 16, 12)
local TITLE_COLOR = Color3.fromRGB(214, 190, 150)

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false

-- A titled number in the top-right corner. Returns the number's label and its scale for the pop.
local function makePanel(name: string, titleText: string, offsetY: number): (TextLabel, UIScale)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -16, 0, offsetY)
	panel.Size = UDim2.fromOffset(210, 72)
	panel.BackgroundColor3 = PANEL_COLOR
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
	title.TextColor3 = TITLE_COLOR
	title.Text = titleText
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

	return value, scale
end

local haulValue, haulScale = makePanel("Haul", "CURRENT HAUL", 16)
local bankedValue, bankedScale = makePanel("Banked", "BANKED WOOD", 96)

-- Short message near the top of the screen that fades out.
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.16)
toast.Size = UDim2.fromOffset(500, 44)
toast.BackgroundTransparency = 1
toast.Font = Enum.Font.GothamBlack
toast.TextSize = 32
toast.TextColor3 = Color3.fromRGB(255, 214, 120)
toast.TextStrokeTransparency = 1
toast.TextTransparency = 1
toast.Text = ""
toast.Parent = gui

-- Stamina bar at the bottom of the screen.
local STAMINA_COLOR = Color3.fromRGB(120, 200, 110)
local STAMINA_LOW_COLOR = Color3.fromRGB(220, 110, 70)

local staminaBar = Instance.new("Frame")
staminaBar.Name = "Stamina"
staminaBar.AnchorPoint = Vector2.new(0.5, 1)
staminaBar.Position = UDim2.new(0.5, 0, 1, -28)
staminaBar.Size = UDim2.fromOffset(320, 16)
staminaBar.BackgroundColor3 = PANEL_COLOR
staminaBar.BackgroundTransparency = 0.35
staminaBar.BorderSizePixel = 0
staminaBar.Parent = gui

local staminaCorner = Instance.new("UICorner")
staminaCorner.CornerRadius = UDim.new(1, 0)
staminaCorner.Parent = staminaBar

local staminaFill = Instance.new("Frame")
staminaFill.Name = "Fill"
staminaFill.Size = UDim2.fromScale(1, 1)
staminaFill.BackgroundColor3 = STAMINA_COLOR
staminaFill.BorderSizePixel = 0
staminaFill.Parent = staminaBar

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = staminaFill

local staminaTitle = Instance.new("TextLabel")
staminaTitle.Name = "Title"
staminaTitle.AnchorPoint = Vector2.new(0.5, 1)
staminaTitle.Position = UDim2.new(0.5, 0, 0, -4)
staminaTitle.Size = UDim2.fromOffset(320, 16)
staminaTitle.BackgroundTransparency = 1
staminaTitle.Font = Enum.Font.GothamBold
staminaTitle.TextSize = 13
staminaTitle.TextColor3 = TITLE_COLOR
staminaTitle.TextStrokeTransparency = 0.5
staminaTitle.Text = "STAMINA"
staminaTitle.Parent = staminaBar

gui.Parent = player:WaitForChild("PlayerGui")

local toastTween: Tween?

local function showToast(text: string)
	if toastTween then
		toastTween:Cancel()
	end
	toast.Text = text
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.4
	local tween = TweenService:Create(
		toast,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.5),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	toastTween = tween
	tween:Play()
end

local function pop(scale: UIScale)
	scale.Scale = 1.25
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
end

local shownHaul = 0
local shownBanked = 0

local function refreshHaul()
	local haul = player:GetAttribute("Haul") or 0
	haulValue.Text = `{haul} WOOD`
	if haul > shownHaul then
		pop(haulScale)
	end
	shownHaul = haul
end

local function refreshBanked()
	local banked = player:GetAttribute("Banked") or 0
	bankedValue.Text = `{banked} WOOD`
	if banked > shownBanked then
		pop(bankedScale)
		showToast(`+{banked - shownBanked} WOOD BANKED`)
	end
	shownBanked = banked
end

local function refreshStamina()
	local stamina = player:GetAttribute("Stamina") or Config.Stamina.Max
	local low = stamina < Config.Stamina.LowThreshold
	staminaFill.BackgroundColor3 = if low then STAMINA_LOW_COLOR else STAMINA_COLOR
	-- The server sends a new value ten times a second; glide between them.
	TweenService:Create(
		staminaFill,
		TweenInfo.new(0.1, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(math.clamp(stamina / Config.Stamina.Max, 0, 1), 1) }
	):Play()
end

player:GetAttributeChangedSignal("Stamina"):Connect(refreshStamina)
player:GetAttributeChangedSignal("Haul"):Connect(refreshHaul)
player:GetAttributeChangedSignal("Banked"):Connect(refreshBanked)
refreshHaul()
refreshBanked()
refreshStamina()
