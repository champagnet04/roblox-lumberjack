-- Per-player setup: a lit torch in hand and a camera that stays under the canopy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerSetup = {}

local function buildTorch(): Tool
	local torch = Instance.new("Tool")
	torch.Name = "Torch"
	torch.CanBeDropped = false
	torch.Grip = CFrame.new(0, -0.7, 0) -- hold it below the middle of the handle

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 2.8, 0.35)
	handle.Material = Enum.Material.Wood
	handle.Color = Color3.fromRGB(84, 60, 42)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = torch

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(0.6, 0.7, 0.6)
	head.CFrame = handle.CFrame * CFrame.new(0, 1.5, 0)
	head.Material = Enum.Material.Slate
	head.Color = Color3.fromRGB(40, 32, 28)
	head.CanCollide = false
	head.Massless = true
	head.Parent = torch

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head

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

	return torch
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if not character:IsDescendantOf(Workspace) then
		character.AncestryChanged:Wait()
	end

	local torch = buildTorch()
	torch.Parent = player:WaitForChild("Backpack")
	humanoid:EquipTool(torch)
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
