-- Player input. Clicking or tapping a tree asks the server for one axe swing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local treesFolder = Workspace:WaitForChild("World"):WaitForChild("Trees")

local function treeAt(screenPosition: Vector2 | Vector3): Model?
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

local function tryChop(screenPosition: Vector2 | Vector3)
	local tree = treeAt(screenPosition)
	if tree then
		Remotes.ChopRequest:FireServer(tree)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- GetMouseLocation counts the top bar, which is what ViewportPointToRay expects.
		tryChop(UserInputService:GetMouseLocation())
	end
end)

UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
	if not processedByUI then
		tryChop(position)
	end
end)
