-- Player input. Hold the mouse button (or a finger) on a tree to keep chopping it.

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
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		heldInput = input
	end
end)

UserInputService.InputEnded:Connect(function(input)
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

	local root = rootPart()
	local tree = treeAt(position)
	if root and tree and inRange(root, tree) then
		lastSwing = now
		startSwing(root, tree)
	end
end)
