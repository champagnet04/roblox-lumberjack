-- Player input. Hold the mouse button (or a finger) on a tree to keep chopping it.
-- Hold Shift to sprint; on touch devices, hold the on-screen sprint button.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ChopAnimation = require(script.Parent:WaitForChild("ChopAnimation"))

local player = Players.LocalPlayer
local treesFolder = Workspace:WaitForChild("World"):WaitForChild("Trees")

local SPRINT_KEYS = {
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.RightShift] = true,
}

local heldInput: InputObject? = nil
local lastSwing = 0

-- Where the held mouse button or finger is, in the coordinates the camera ray expects.
local function pointerPosition(): Vector2?
	if not heldInput then
		return nil
	end
	if heldInput.UserInputType == Enum.UserInputType.MouseButton1 then
		return UserInputService:GetMouseLocation()
	end
	return Vector2.new(heldInput.Position.X, heldInput.Position.Y) + GuiService:GetGuiInset()
end

local function treeAt(screenPosition: Vector2): Model?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if not hit then
		return nil
	end

	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	if model and model.Parent == treesFolder then
		return model
	end
	return nil
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Same range rule as the server, so the swing only plays when it will count.
local function inRange(root: BasePart, tree: Model): boolean
	local trunk = tree.PrimaryPart
	if not trunk then
		return false
	end
	local offset = (trunk.Position - root.Position) * Vector3.new(1, 0, 1)
	return offset.Magnitude <= Config.Tree.ChopRange + trunk.Size.Y / 2
end

local function faceTree(root: BasePart, tree: Model)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local trunk = tree.PrimaryPart
	if not humanoid or not trunk or humanoid.MoveDirection.Magnitude > 0.1 then
		return
	end
	local target = Vector3.new(trunk.Position.X, root.Position.Y, trunk.Position.Z)
	if (target - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, target)
	end
end

local function startSwing(root: BasePart, tree: Model)
	faceTree(root, tree)
	ChopAnimation.swing()

	-- The hit counts when the axe lands, not when the swing starts.
	task.delay(ChopAnimation.IMPACT_DELAY, function()
		if tree.Parent ~= treesFolder then
			return
		end
		-- The final blow is followed by the fall, so it gets no shake.
		if (tree:GetAttribute("Health") or 0) > 1 then
			ChopAnimation.shakeTree(tree, root.Position)
		end
		Remotes.ChopRequest:FireServer(tree)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if SPRINT_KEYS[input.KeyCode] then
		Remotes.SetSprinting:FireServer(true)
		return
	end
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		heldInput = input
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if SPRINT_KEYS[input.KeyCode] then
		Remotes.SetSprinting:FireServer(false)
		return
	end
	if not heldInput then
		return
	end
	local mouseReleased = input.UserInputType == Enum.UserInputType.MouseButton1
		and heldInput.UserInputType == Enum.UserInputType.MouseButton1
	if mouseReleased or input == heldInput then
		heldInput = nil
	end
end)

RunService.Heartbeat:Connect(function()
	local position = pointerPosition()
	if not position then
		return
	end

	local now = os.clock()
	if now - lastSwing < Config.Tree.SwingCooldown then
		return
	end
	if (player:GetAttribute("Stamina") or 0) < Config.Stamina.SwingCost then
		return -- too tired to swing
	end

	local root = rootPart()
	local tree = treeAt(position)
	if root and tree and inRange(root, tree) then
		lastSwing = now
		startSwing(root, tree)
	end
end)

-- Touch devices: a hold-to-sprint button sits where Roblox's jump button normally is,
-- and jumping is switched off so the jump button disappears.
local isTouchDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

if isTouchDevice then
	local function disableJump(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		-- Roblox hides its jump button by itself when the character cannot jump.
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
	player.CharacterAdded:Connect(disableJump)
	if player.Character then
		task.spawn(disableJump, player.Character)
	end

	local IDLE_COLOR = Color3.fromRGB(20, 16, 12)
	local HELD_COLOR = Color3.fromRGB(255, 214, 120)

	local touchGui = Instance.new("ScreenGui")
	touchGui.Name = "TouchControls"
	touchGui.ResetOnSpawn = false

	-- Same sizes Roblox uses for its own jump button: smaller on phones, larger on tablets.
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(800, 400)
	local isPhone = math.min(viewport.X, viewport.Y) <= 500
	local size = if isPhone then 70 else 120

	local sprintButton = Instance.new("TextButton")
	sprintButton.Name = "Sprint"
	sprintButton.AnchorPoint = Vector2.new(1, 1)
	sprintButton.Position = if isPhone then UDim2.new(1, -25, 1, -20) else UDim2.new(1, -50, 1, -90)
	sprintButton.Size = UDim2.fromOffset(size, size)
	sprintButton.BackgroundColor3 = IDLE_COLOR
	sprintButton.BackgroundTransparency = 0.35
	sprintButton.BorderSizePixel = 0
	sprintButton.AutoButtonColor = false
	sprintButton.Font = Enum.Font.GothamBlack
	sprintButton.TextSize = if isPhone then 13 else 20
	sprintButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	sprintButton.Text = "SPRINT"
	sprintButton.Parent = touchGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = sprintButton

	touchGui.Parent = player:WaitForChild("PlayerGui")

	-- The finger currently holding the button. Tracked so that sliding off still ends the sprint.
	local sprintTouch: InputObject? = nil

	sprintButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and not sprintTouch then
			sprintTouch = input
			sprintButton.BackgroundColor3 = HELD_COLOR
			sprintButton.TextColor3 = IDLE_COLOR
			Remotes.SetSprinting:FireServer(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input == sprintTouch then
			sprintTouch = nil
			sprintButton.BackgroundColor3 = IDLE_COLOR
			sprintButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			Remotes.SetSprinting:FireServer(false)
		end
	end)
end
