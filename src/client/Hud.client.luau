-- On-screen display. Reads the player's state attributes, which the server owns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PANEL_COLOR = Color3.fromRGB(20, 16, 12)
local TITLE_COLOR = Color3.fromRGB(214, 190, 150)
local GOLD = Color3.fromRGB(255, 214, 120)
local DANGER = Color3.fromRGB(255, 96, 80)
local WHITE = Color3.fromRGB(255, 255, 255)
local GUARDIAN_NAME = string.upper(Config.Guardian.DisplayName)

local function makeLabel(props: { [string]: any }, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = WHITE
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

local function roundCorners(target: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = target
end

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
	roundCorners(panel, UDim.new(0, 10))

	makeLabel({
		Name = "Title",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextColor3 = TITLE_COLOR,
		Text = titleText,
	}, panel)

	local value = makeLabel({
		Name = "Value",
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
	}, panel)

	local scale = Instance.new("UIScale")
	scale.Parent = value

	return value, scale
end

local haulValue, haulScale = makePanel("Haul", "CURRENT HAUL", 16)
local gameBankValue, gameBankScale = makePanel("GameBank", "GAME BANK", 96)

-- Smaller panel underneath for the permanent numbers.
local statsPanel = Instance.new("Frame")
statsPanel.Name = "Stats"
statsPanel.AnchorPoint = Vector2.new(1, 0)
statsPanel.Position = UDim2.new(1, -16, 0, 176)
statsPanel.Size = UDim2.fromOffset(210, 117)
statsPanel.BackgroundColor3 = PANEL_COLOR
statsPanel.BackgroundTransparency = 0.35
statsPanel.BorderSizePixel = 0
statsPanel.Parent = gui
roundCorners(statsPanel, UDim.new(0, 10))

local function makeStatRow(titleText: string, row: number): TextLabel
	local offsetY = 10 + (row - 1) * 25
	makeLabel({
		Position = UDim2.fromOffset(14, offsetY),
		Size = UDim2.new(1, -28, 0, 22),
		TextSize = 13,
		TextColor3 = TITLE_COLOR,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = titleText,
	}, statsPanel)
	return makeLabel({
		Position = UDim2.fromOffset(14, offsetY),
		Size = UDim2.new(1, -28, 0, 22),
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, statsPanel)
end

local overallValue = makeStatRow("TOTAL BANKED", 1)
local bestHaulValue = makeStatRow("BEST HAUL", 2)
local bestGameValue = makeStatRow("BEST GAME", 3)
local furthestValue = makeStatRow("FURTHEST TREE", 4)

-- Shown only when progress cannot be saved this session.
local saveNotice = makeLabel({
	Name = "SaveNotice",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 299),
	Size = UDim2.fromOffset(210, 18),
	TextSize = 12,
	TextColor3 = DANGER,
	TextStrokeTransparency = 0.5,
	Text = "PROGRESS IS NOT BEING SAVED",
	Visible = false,
}, gui)

-- Shown for as long as the guardian is hunting the player.
local chaseBanner = makeLabel({
	Name = "ChaseBanner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.08),
	Size = UDim2.fromOffset(800, 36),
	Font = Enum.Font.GothamBlack,
	TextSize = 26,
	TextColor3 = DANGER,
	TextStrokeTransparency = 0.4,
	Text = `{GUARDIAN_NAME} IS HUNTING YOU - GET BACK TO CAMP`,
	Visible = false,
}, gui)

TweenService:Create(
	chaseBanner,
	TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ TextTransparency = 0.45 }
):Play()

-- Short message near the top of the screen that fades out.
local toast = makeLabel({
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.16),
	Size = UDim2.fromOffset(800, 44),
	Font = Enum.Font.GothamBlack,
	TextSize = 32,
	TextColor3 = GOLD,
	TextStrokeTransparency = 1,
	TextTransparency = 1,
	Text = "",
}, gui)

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
roundCorners(staminaBar, UDim.new(1, 0))

local staminaFill = Instance.new("Frame")
staminaFill.Name = "Fill"
staminaFill.Size = UDim2.fromScale(1, 1)
staminaFill.BackgroundColor3 = STAMINA_COLOR
staminaFill.BorderSizePixel = 0
staminaFill.Parent = staminaBar
roundCorners(staminaFill, UDim.new(1, 0))

makeLabel({
	Name = "Title",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -4),
	Size = UDim2.fromOffset(320, 16),
	TextSize = 13,
	TextColor3 = TITLE_COLOR,
	TextStrokeTransparency = 0.5,
	Text = "STAMINA",
}, staminaBar)

gui.Parent = playerGui

-- Game-over screen: covers everything after the guardian catches the player.
local runOverGui = Instance.new("ScreenGui")
runOverGui.Name = "RunOver"
runOverGui.ResetOnSpawn = false
runOverGui.IgnoreGuiInset = true
runOverGui.DisplayOrder = 10
runOverGui.Enabled = false

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(8, 6, 6)
overlay.BackgroundTransparency = 0.15
overlay.BorderSizePixel = 0
overlay.Active = true -- swallow clicks so the player cannot chop through the screen
overlay.Parent = runOverGui

local summary = Instance.new("Frame")
summary.AnchorPoint = Vector2.new(0.5, 0.5)
summary.Position = UDim2.fromScale(0.5, 0.5)
summary.Size = UDim2.fromOffset(560, 560)
summary.BackgroundTransparency = 1
summary.Parent = overlay

local summaryLayout = Instance.new("UIListLayout")
summaryLayout.FillDirection = Enum.FillDirection.Vertical
summaryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
summaryLayout.VerticalAlignment = Enum.VerticalAlignment.Center
summaryLayout.SortOrder = Enum.SortOrder.LayoutOrder
summaryLayout.Padding = UDim.new(0, 8)
summaryLayout.Parent = summary

makeLabel({
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 70),
	Font = Enum.Font.GothamBlack,
	TextSize = 60,
	TextColor3 = DANGER,
	Text = "GAME OVER",
}, summary)

makeLabel({
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 26),
	TextSize = 20,
	TextColor3 = TITLE_COLOR,
	Text = `{Config.Guardian.DisplayName} caught you.`,
}, summary)

local function makeSummaryLine(order: number, textSize: number, color: Color3): TextLabel
	return makeLabel({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, textSize + 12),
		Font = Enum.Font.GothamBlack,
		TextSize = textSize,
		TextColor3 = color,
	}, summary)
end

local gameBankLabel = makeSummaryLine(3, 34, GOLD)
local newBestLabel = makeSummaryLine(4, 20, GOLD)
newBestLabel.Text = "NEW BEST GAME!"
local woodLostLabel = makeSummaryLine(5, 24, DANGER)
local bestGameLabel = makeSummaryLine(6, 20, WHITE)
local bestHaulLabel = makeSummaryLine(7, 20, WHITE)
local furthestLabel = makeSummaryLine(8, 20, WHITE)
local overallLabel = makeSummaryLine(9, 20, WHITE)

makeLabel({
	LayoutOrder = 10,
	Size = UDim2.new(1, 0, 0, 24),
	TextSize = 16,
	TextColor3 = TITLE_COLOR,
	Text = "Everything you banked this game is safe in your total.",
}, summary)

local tryAgain = Instance.new("TextButton")
tryAgain.LayoutOrder = 11
tryAgain.Size = UDim2.fromOffset(240, 56)
tryAgain.BackgroundColor3 = GOLD
tryAgain.BorderSizePixel = 0
tryAgain.Font = Enum.Font.GothamBlack
tryAgain.TextSize = 24
tryAgain.TextColor3 = PANEL_COLOR
tryAgain.Text = "NEW GAME"
tryAgain.Parent = summary
roundCorners(tryAgain, UDim.new(0, 12))

runOverGui.Parent = playerGui

tryAgain.Activated:Connect(function()
	runOverGui.Enabled = false
end)

local toastTween: Tween?

local function showToast(text: string, color: Color3?)
	if toastTween then
		toastTween:Cancel()
	end
	toast.Text = text
	toast.TextColor3 = color or GOLD
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

-- Escaping, banking and a new best haul can all happen at the same moment,
-- so they share one message.
local ARRIVAL_WINDOW = 1.5
local lastEscapeAt = -math.huge
local lastBankAt = -math.huge
local lastBestHaulAt = -math.huge
local lastFurthestAt = -math.huge
local lastBankAmount = 0

local function showArrivalToast()
	local now = os.clock()
	local parts = {}
	if now - lastEscapeAt < ARRIVAL_WINDOW then
		table.insert(parts, "YOU ESCAPED!")
	end
	if now - lastBestHaulAt < ARRIVAL_WINDOW then
		table.insert(parts, "NEW BEST HAUL!")
	end
	if now - lastFurthestAt < ARRIVAL_WINDOW then
		table.insert(parts, "NEW FURTHEST TREE!")
	end
	if now - lastBankAt < ARRIVAL_WINDOW then
		table.insert(parts, `+{lastBankAmount} WOOD BANKED`)
	end
	if #parts > 0 then
		showToast(table.concat(parts, "  "))
	end
end

local shownHaul = 0
local shownGameBank = 0
local shownBestHaul = 0
local shownFurthest = 0

local function refreshHaul()
	local haul = player:GetAttribute("Haul") or 0
	haulValue.Text = `{haul} WOOD`
	if haul > shownHaul then
		pop(haulScale)
	end
	shownHaul = haul
end

local function refreshGameBank()
	local gameBank = player:GetAttribute("GameBank") or 0
	gameBankValue.Text = `{gameBank} WOOD`
	if gameBank > shownGameBank then
		pop(gameBankScale)
		lastBankAt = os.clock()
		lastBankAmount = gameBank - shownGameBank
		showArrivalToast()
	end
	shownGameBank = gameBank
end

local function refreshStats()
	local bestHaul = player:GetAttribute("BestHaul") or 0
	overallValue.Text = tostring(player:GetAttribute("OverallBank") or 0)
	bestHaulValue.Text = tostring(bestHaul)
	bestGameValue.Text = tostring(player:GetAttribute("BestGame") or 0)
	if bestHaul > shownBestHaul then
		lastBestHaulAt = os.clock()
	end
	shownBestHaul = bestHaul

	local furthest = player:GetAttribute("FurthestTree") or 0
	furthestValue.Text = `{furthest} STUDS`
	if furthest > shownFurthest then
		lastFurthestAt = os.clock()
	end
	shownFurthest = furthest
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

local function refreshSaveStatus()
	saveNotice.Visible = player:GetAttribute("SaveStatus") == "Unavailable"
end

local wasChased = false

local function refreshChased()
	local chased = player:GetAttribute("Chased") == true
	chaseBanner.Visible = chased
	if chased and not wasChased then
		showToast(`{GUARDIAN_NAME} HAS AWOKEN`, DANGER)
	end
	wasChased = chased
end

Remotes.Escaped.OnClientEvent:Connect(function()
	lastEscapeAt = os.clock()
	showArrivalToast()
end)

Remotes.GameOver.OnClientEvent:Connect(function(result)
	gameBankLabel.Text = `THIS GAME: {result.GameBank} WOOD BANKED`
	newBestLabel.Visible = result.IsBestGame
	woodLostLabel.Text = `HAUL LOST: {result.WoodLost}`
	bestGameLabel.Text = `BEST GAME: {result.BestGame}`
	bestHaulLabel.Text = `BEST HAUL: {result.BestHaul}`
	furthestLabel.Text = `FURTHEST TREE: {result.FurthestTree} STUDS`
	overallLabel.Text = `TOTAL BANKED: {result.OverallBank}`
	runOverGui.Enabled = true
end)

player:GetAttributeChangedSignal("Stamina"):Connect(refreshStamina)
player:GetAttributeChangedSignal("Haul"):Connect(refreshHaul)
player:GetAttributeChangedSignal("GameBank"):Connect(refreshGameBank)
for _, name in { "OverallBank", "BestHaul", "BestGame", "FurthestTree" } do
	player:GetAttributeChangedSignal(name):Connect(refreshStats)
end
player:GetAttributeChangedSignal("Chased"):Connect(refreshChased)
refreshHaul()
refreshStats()
refreshGameBank()
refreshStamina()
refreshChased()
player:GetAttributeChangedSignal("SaveStatus"):Connect(refreshSaveStatus)
refreshSaveStatus()
