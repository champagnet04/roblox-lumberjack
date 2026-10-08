-- Per-player setup: an axe in the right hand, a lit torch in the left,
-- and a camera that stays under the canopy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerSetup = {}

local GRIP_TURN = CFrame.Angles(math.rad(-90), 0, 0) -- how Roblox orients things held in a hand

local function makeHeldPart(props: { [string]: any }, parent: Instance): Part
	local part = Instance.new("Part")
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function weldTo(handle: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
end

-- The axe is a Roblox tool, so the character holds its right arm out in front.
local function buildAxe(): Tool
	local axe = Instance.new("Tool")
	axe.Name = "Axe"
	axe.CanBeDropped = false
	axe.Grip = CFrame.new(0, -1, 0) -- hold it near the bottom of the shaft

	local handle = makeHeldPart({
		Name = "Handle",
		Size = Vector3.new(0.3, 3.2, 0.3),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(120, 84, 54),
	}, axe)

	local head = makeHeldPart({
		Name = "Head",
		Size = Vector3.new(0.25, 1, 1.1),
		CFrame = handle.CFrame * CFrame.new(0, 1.2, -0.5), -- blade faces forward
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(150, 154, 160),
	}, axe)
	weldTo(handle, head)

	return axe
end

local function buildTorch(): (Model, Part)
	local torch = Instance.new("Model")
	torch.Name = "Torch"

	local handle = makeHeldPart({
		Name = "Handle",
		Size = Vector3.new(0.35, 2.8, 0.35),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(84, 60, 42),
	}, torch)

	local head = makeHeldPart({
		Name = "Head",
		Size = Vector3.new(0.6, 0.7, 0.6),
		CFrame = handle.CFrame * CFrame.new(0, 1.5, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(40, 32, 28),
	}, torch)
	weldTo(handle, head)

	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Parent = head

	local light = Instance.new("PointLight")
	light.Color = Config.Lighting.WarmLight
	light.Brightness = Config.Lighting.TorchBrightness
	light.Range = Config.Lighting.TorchRange
	light.Shadows = true
	light.Parent = head

	torch.PrimaryPart = handle
	return torch, handle
end

-- Tools only go in the right hand, so the torch is welded to the left hand directly.
-- The client holds the left arm up (see ChopAnimation).
local function attachTorch(character: Model)
	local hand = character:WaitForChild("LeftHand", 5) or character:FindFirstChild("Left Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end

	local torch, handle = buildTorch()
	local grip = hand:FindFirstChild("LeftGripAttachment")

	local weld = Instance.new("Weld")
	weld.Name = "TorchGrip"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = if grip and grip:IsA("Attachment")
		then grip.CFrame
		else CFrame.new(0, -hand.Size.Y / 2, 0) * GRIP_TURN
	weld.C1 = CFrame.new(0, -0.7, 0) -- hold it below the middle of the handle
	weld.Parent = handle

	torch.Parent = character
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if not character:IsDescendantOf(Workspace) then
		character.AncestryChanged:Wait()
	end

	attachTorch(character)

	local axe = buildAxe()
	axe.Parent = player:WaitForChild("Backpack")
	humanoid:EquipTool(axe)
end

local function onPlayerAdded(player: Player)
	player.CameraMaxZoomDistance = Config.Player.CameraMaxZoom
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function PlayerSetup.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerSetup
