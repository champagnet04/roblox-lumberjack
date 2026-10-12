-- The menu shown when a player joins: Solo, Quick Race, Race with Friends.
-- It sits over a slow turn round the campfire. When a game starts it removes itself.
--
-- This script must not load Config: on a player's game that waits until a game is chosen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameMode = require(ReplicatedStorage.Shared.GameMode)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

if GameMode.waitForAny() ~= "Menu" then
	return -- this server is already running a game
end

local player = Players.LocalPlayer

local PANEL_COLOR = Color3.fromRGB(20, 16, 12)
local TITLE_COLOR = Color3.fromRGB(214, 190, 150)
local GOLD = Color3.fromRGB(255, 214, 120)
local WHITE = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(150, 150, 150)

-- Same rule as the in-game display: full size on a screen this large, shrinking below it.
local FULL_SIZE_SCREEN = Vector2.new(1280, 720)
local MIN_SCALE = 0.5

-- The camera circles the fire from this far out and this high up.
local ORBIT_RADIUS = 34
local ORBIT_HEIGHT = 13
local ORBIT_SECONDS = 90 -- one full turn
local LOOK_AT = Vector3.new(0, 5, 0)

local gui = Instance.new("ScreenGui")
gui.Name = "Menu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10

local scale = Instance.new("UIScale")
scale.Parent = gui

-- Darkens the view a little so the words stand out.
local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.45
shade.BorderSizePixel = 0
shade.Parent = gui

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

makeLabel({
	Name = "Title",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.13),
	Size = UDim2.fromOffset(900, 70),
	Font = Enum.Font.GothamBlack,
	TextSize = 64,
	TextColor3 = GOLD,
	Text = "ONE MORE TREE",
}, gui)

makeLabel({
	Name = "Subtitle",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.13, 74),
	Size = UDim2.fromOffset(900, 34),
	TextSize = 26,
	TextColor3 = TITLE_COLOR,
	Text = "FOREST ESCAPE",
}, gui)

local status = makeLabel({
	Name = "Status",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.42, 232),
	Size = UDim2.fromOffset(900, 30),
	TextSize = 20,
	TextColor3 = GOLD,
	Text = "",
}, gui)

type MenuButton = { Button: TextButton, Caption: TextLabel }

local function makeButton(order: number, text: string, caption: string, choice: string): MenuButton
	local button = Instance.new("TextButton")
	button.Name = choice
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0.42, (order - 1) * 74)
	button.Size = UDim2.fromOffset(360, 62)
	button.BackgroundColor3 = PANEL_COLOR
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button

	makeLabel({
		Name = "Text",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		Text = text,
	}, button)

	local captionLabel = makeLabel({
		Name = "Caption",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		TextColor3 = TITLE_COLOR,
		Text = caption,
	}, button)

	button.Activated:Connect(function()
		Remotes.ChooseMode:FireServer(choice)
	end)

	return { Button = button, Caption = captionLabel }
end

makeButton(1, "SOLO", "BUILD YOUR OWN CAMP", "Solo")
local quickRace = makeButton(2, "QUICK RACE", "", "QuickRace")
local friendsRace = makeButton(3, "RACE WITH FRIENDS", "", "FriendsRace")

local function dim(item: MenuButton, caption: string)
	item.Caption.Text = caption
	item.Caption.TextColor3 = MUTED
	local text = item.Button:FindFirstChild("Text")
	if text and text:IsA("TextLabel") then
		text.TextColor3 = MUTED
	end
end

-- Buttons that do nothing yet are greyed and say so.
local function refreshRaceButtons()
	if Workspace:GetAttribute("MenuRaceOpen") == true then
		quickRace.Caption.Text = "RACE THE OTHER LUMBERJACKS"
		quickRace.Caption.TextColor3 = TITLE_COLOR
		local text = quickRace.Button:FindFirstChild("Text")
		if text and text:IsA("TextLabel") then
			text.TextColor3 = WHITE
		end
	else
		dim(quickRace, "COMING SOON")
	end
	dim(friendsRace, "COMING SOON")
end
Workspace:GetAttributeChangedSignal("MenuRaceOpen"):Connect(refreshRaceButtons)
refreshRaceButtons()

Remotes.MenuStatus.OnClientEvent:Connect(function(text)
	status.Text = if typeof(text) == "string" then text else ""
end)

gui.Parent = player:WaitForChild("PlayerGui")

local function fitToScreen()
	local screen = gui.AbsoluteSize
	if screen.X > 0 and screen.Y > 0 then
		local fit = math.min(screen.X / FULL_SIZE_SCREEN.X, screen.Y / FULL_SIZE_SCREEN.Y)
		scale.Scale = math.clamp(fit, MIN_SCALE, 1)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)
fitToScreen()

-- A slow turn round the campfire behind the menu.
local startedAt = os.clock()
local orbit = RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local angle = (os.clock() - startedAt) / ORBIT_SECONDS * math.pi * 2
	local from =
		Vector3.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(angle) * ORBIT_RADIUS)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(from, LOOK_AT)
end)

-- A game has started in this server (this only happens in Studio): hand the camera back.
GameMode.waitForPlay()
orbit:Disconnect()
gui:Destroy()
local camera = Workspace.CurrentCamera
if camera then
	camera.CameraType = Enum.CameraType.Custom
end
