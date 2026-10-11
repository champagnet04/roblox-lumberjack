-- Watching other racers once the guardian has caught you (Config.Mode = "Race").
-- While you are out and the round is still running, a bar at the bottom of the screen lets
-- you move the camera between the racers still standing, or back to yourself at camp.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

if Config.Mode ~= "Race" then
	return
end

local player = Players.LocalPlayer

local PANEL_COLOR = Color3.fromRGB(20, 16, 12)
local GOLD = Color3.fromRGB(255, 214, 120)
local WHITE = Color3.fromRGB(255, 255, 255)
local TICK = 0.2

local watching: Player? = nil
local ownView = false -- the player chose to look at themselves instead
local wasActive = false

-- The bar lives inside the main display so that it shrinks with it on small screens.
local hud = player:WaitForChild("PlayerGui"):WaitForChild("Hud")

local bar = Instance.new("Frame")
bar.Name = "Spectate"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -66)
bar.Size = UDim2.fromOffset(440, 44)
bar.BackgroundColor3 = PANEL_COLOR
bar.BackgroundTransparency = 0.35
bar.BorderSizePixel = 0
bar.Visible = false
bar.Parent = hud

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 10)
barCorner.Parent = bar

local function makeButton(name: string, text: string, offsetX: number, width: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = UDim2.fromOffset(offsetX, 6)
	button.Size = UDim2.fromOffset(width, 32)
	button.BackgroundColor3 = PANEL_COLOR
	button.BackgroundTransparency = 0.2
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 16
	button.TextColor3 = WHITE
	button.Text = text
	button.Parent = bar
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

local previousButton = makeButton("Previous", "<", 6, 40)
local nextButton = makeButton("Next", ">", 286, 40)
local ownViewButton = makeButton("OwnView", "MY VIEW", 334, 100)

local label = Instance.new("TextLabel")
label.Name = "Watching"
label.Position = UDim2.fromOffset(50, 6)
label.Size = UDim2.fromOffset(232, 32)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextSize = 15
label.TextColor3 = GOLD
label.TextTruncate = Enum.TextTruncate.AtEnd
label.Text = ""
label.Parent = bar

local function humanoidOf(target: Player): Humanoid?
	local character = target.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Racers who can be watched: everyone else who is still standing, in name order.
local function standing(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("RaceOut") ~= true and humanoidOf(other) then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function lookAt(target: Player)
	local camera = Workspace.CurrentCamera
	local humanoid = humanoidOf(target)
	if camera and humanoid and camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
end

-- Moves to the next or previous racer still standing.
local function cycle(direction: number)
	local list = standing()
	if #list == 0 then
		return
	end
	local index = table.find(list, watching) or (if direction > 0 then 0 else 1)
	watching = list[(index - 1 + direction) % #list + 1]
	ownView = false
end

local function update()
	local active = player:GetAttribute("RaceOut") == true
		and Workspace:GetAttribute("RacePhase") == "Running"

	if not active then
		if wasActive then
			-- The round is over (or a new one began): back to your own character.
			lookAt(player)
			watching = nil
			ownView = false
		end
		wasActive = false
		bar.Visible = false
		return
	end
	wasActive = true
	bar.Visible = true

	local list = standing()
	if not ownView and (not watching or not table.find(list, watching)) then
		watching = list[1] -- the one being watched was caught or left: move on
	end

	if ownView or not watching then
		lookAt(player)
		label.Text = if #list == 0 then "NO ONE LEFT TO WATCH" else "YOUR VIEW"
	else
		lookAt(watching)
		label.Text = `WATCHING: {string.upper(watching.DisplayName)}`
	end
end

previousButton.Activated:Connect(function()
	cycle(-1)
	update()
end)
nextButton.Activated:Connect(function()
	cycle(1)
	update()
end)
ownViewButton.Activated:Connect(function()
	ownView = true
	update()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not bar.Visible then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		cycle(-1)
		update()
	elseif input.KeyCode == Enum.KeyCode.E then
		cycle(1)
		update()
	end
end)

while true do
	update()
	task.wait(TICK)
end
