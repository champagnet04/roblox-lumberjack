-- The menu shown when a player joins: Solo, Quick Race, Race with Friends, Record Book.
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

-- The buttons and the line under them, in one frame so the Record Book can hide them.
local choices = Instance.new("Frame")
choices.Name = "Choices"
choices.Size = UDim2.fromScale(1, 1)
choices.BackgroundTransparency = 1
choices.Parent = gui

local FIRST_BUTTON_AT = 0.36 -- how far down the screen the first button sits
local BUTTON_STEP = 72

local status = makeLabel({
	Name = "Status",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, FIRST_BUTTON_AT, 4 * BUTTON_STEP + 6),
	Size = UDim2.fromOffset(900, 30),
	TextSize = 20,
	TextColor3 = GOLD,
	Text = "",
}, choices)

type MenuButton = { Button: TextButton, Caption: TextLabel }

-- `choice` is sent to the server when the button is pressed, unless `onPressed` is given,
-- in which case that runs instead.
local function makeButton(
	order: number,
	text: string,
	caption: string,
	choice: string,
	onPressed: (() -> ())?
): MenuButton
	local button = Instance.new("TextButton")
	button.Name = choice
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, FIRST_BUTTON_AT, (order - 1) * BUTTON_STEP)
	button.Size = UDim2.fromOffset(360, 62)
	button.BackgroundColor3 = PANEL_COLOR
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = choices

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
		if onPressed then
			onPressed()
		else
			Remotes.ChooseMode:FireServer(choice)
		end
	end)

	return { Button = button, Caption = captionLabel }
end

makeButton(1, "SOLO", "BUILD YOUR OWN CAMP", "Solo")
local quickRace = makeButton(2, "QUICK RACE", "", "QuickRace")
makeButton(3, "RACE WITH FRIENDS", "A PRIVATE RACE YOU HOST", "FriendsRace")

-- The Record Book (see RECORD_BOOK.md): a panel over the menu with three pages.
-- Only My Records is built so far; the two leaderboard pages say so.
local book = Instance.new("Frame")
book.Name = "RecordBook"
book.AnchorPoint = Vector2.new(0.5, 0)
book.Position = UDim2.fromScale(0.5, 0.31)
book.Size = UDim2.fromOffset(780, 400)
book.BackgroundColor3 = PANEL_COLOR
book.BackgroundTransparency = 0.08
book.BorderSizePixel = 0
book.Visible = false
book.Parent = gui

local bookCorner = Instance.new("UICorner")
bookCorner.CornerRadius = UDim.new(0, 14)
bookCorner.Parent = book

makeLabel({
	Name = "Title",
	Position = UDim2.fromOffset(0, 12),
	Size = UDim2.new(1, 0, 0, 32),
	Font = Enum.Font.GothamBlack,
	TextSize = 28,
	TextColor3 = GOLD,
	Text = "RECORD BOOK",
}, book)

local function makeBookButton(text: string, position: UDim2, width: number): TextButton
	local button = Instance.new("TextButton")
	button.Position = position
	button.Size = UDim2.fromOffset(width, 34)
	button.BackgroundColor3 = Color3.fromRGB(44, 36, 28)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 15
	button.TextColor3 = WHITE
	button.Text = text
	button.Parent = book
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

local PAGES = { "MY RECORDS", "FRIENDS", "EVERYONE" }
local pageButtons: { TextButton } = {}
for index, name in PAGES do
	pageButtons[index] = makeBookButton(name, UDim2.fromOffset(24 + (index - 1) * 248, 56), 236)
end
local backButton = makeBookButton("BACK", UDim2.new(0.5, -80, 1, -46), 160)

-- My Records: solo records on the left, race records on the right.
local minePage = Instance.new("Frame")
minePage.Name = "MyRecords"
minePage.Position = UDim2.fromOffset(24, 104)
minePage.Size = UDim2.new(1, -48, 1, -160)
minePage.BackgroundTransparency = 1
minePage.Parent = book

local soonPage = makeLabel({
	Name = "ComingSoon",
	Position = UDim2.fromOffset(24, 104),
	Size = UDim2.new(1, -48, 1, -160),
	TextSize = 20,
	TextColor3 = TITLE_COLOR,
	Text = "LEADERBOARDS ARE COMING SOON",
	Visible = false,
}, book)

local ROW_HEIGHT = 34

local function makeColumn(title: string, column: number): Frame
	local frame = Instance.new("Frame")
	frame.Position = UDim2.new((column - 1) * 0.5, if column == 1 then 0 else 12, 0, 0)
	frame.Size = UDim2.new(0.5, -12, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = minePage
	makeLabel({
		Size = UDim2.new(1, 0, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextColor3 = TITLE_COLOR,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	}, frame)
	return frame
end

-- One line of a column: a name on the left and its value on the right. Returns the value.
local function makeRecord(column: Frame, row: number, title: string): TextLabel
	local offsetY = 32 + (row - 1) * ROW_HEIGHT
	makeLabel({
		Position = UDim2.fromOffset(0, offsetY),
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	}, column)
	return makeLabel({
		Position = UDim2.fromOffset(0, offsetY),
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "...",
	}, column)
end

local soloColumn = makeColumn("SOLO", 1)
local raceColumn = makeColumn("RACES", 2)

-- Each value, with the saved number it shows and what follows the number.
local recordRows = {
	{ Label = makeRecord(soloColumn, 1, "BEST HAUL"), Saved = "BestHaul", Unit = " WOOD" },
	{ Label = makeRecord(soloColumn, 2, "BEST GAME"), Saved = "BestGame", Unit = " WOOD" },
	{ Label = makeRecord(soloColumn, 3, "FURTHEST TREE"), Saved = "FurthestTree", Unit = " STUDS" },
	{ Label = makeRecord(raceColumn, 1, "RACES WON"), Saved = "RaceWins", Unit = "" },
	{
		Label = makeRecord(raceColumn, 2, "BEST RACE SCORE"),
		Saved = "BestRaceScore",
		Unit = " WOOD",
	},
	{ Label = makeRecord(raceColumn, 3, "RACES RUN"), Saved = "RacesRun", Unit = "" },
	{ Label = makeRecord(raceColumn, 4, "TOP-THREE FINISHES"), Saved = "RacePodiums", Unit = "" },
}
local campLabel = makeRecord(soloColumn, 4, "CAMP")

local bookNote = makeLabel({
	Name = "Note",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -54),
	Size = UDim2.new(1, -48, 0, 20),
	TextSize = 14,
	TextColor3 = MUTED,
	Text = "",
}, book)

local function showPage(index: number)
	for buttonIndex, button in pageButtons do
		button.TextColor3 = if buttonIndex == index then GOLD else WHITE
	end
	minePage.Visible = index == 1
	soonPage.Visible = index ~= 1
	bookNote.Visible = index == 1
end
for index, button in pageButtons do
	button.Activated:Connect(function()
		showPage(index)
	end)
end

local function setBookOpen(open: boolean)
	book.Visible = open
	choices.Visible = not open
	if open then
		showPage(1)
		for _, row in recordRows do
			row.Label.Text = "..."
		end
		campLabel.Text = "..."
		bookNote.Text = ""
		Remotes.RequestRecords:FireServer()
	end
end
backButton.Activated:Connect(function()
	setBookOpen(false)
end)

Remotes.Records.OnClientEvent:Connect(function(records)
	local saved = if typeof(records) == "table" then records.Saved else nil
	if typeof(saved) ~= "table" then
		for _, row in recordRows do
			row.Label.Text = "-"
		end
		campLabel.Text = "-"
		bookNote.Text = "YOUR RECORDS COULD NOT BE LOADED. PLEASE TRY AGAIN LATER."
		return
	end
	for _, row in recordRows do
		row.Label.Text = `{saved[row.Saved] or 0}{row.Unit}`
	end
	campLabel.Text = `{saved.BuildsDone or 0} OF {records.TotalBuilds or 0} BUILDS`
	bookNote.Text = "RACE RECORDS COUNT FROM THE DAY THE RECORD BOOK OPENED."
end)

makeButton(4, "RECORD BOOK", "YOUR RECORDS AND LEADERBOARDS", "RecordBook", function()
	setBookOpen(true)
end)

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
