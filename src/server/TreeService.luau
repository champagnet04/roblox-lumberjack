-- Tree health, chop validation, felling and regrowth. The server decides every outcome.
-- Each tree's remaining health is published as a `Health` attribute for the client to read.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MovementService = require(script.Parent.MovementService)
local PlayerState = require(script.Parent.PlayerState)

local TreeService = {}

type TreeState = {
	Health: number,
	Felled: boolean,
	Upright: CFrame, -- the tree's pivot when standing
	Base: Vector3, -- point on the ground the tree tips around
	TrunkRadius: number,
}

-- The client paces its own swings; the server accepts them slightly early so that
-- network delay never throws away a swing the player saw land.
local COOLDOWN_SLACK = 0.8

local rng = Random.new()
local treesFolder: Instance
local states: { [Instance]: TreeState } = {}
local lastSwing: { [Player]: number } = {}

-- Tips the whole tree around its base, toward the given direction.
local function tilt(tree: Model, state: TreeState, direction: Vector3, angle: number)
	local axis = Vector3.new(0, 1, 0):Cross(direction)
	tree:PivotTo(
		CFrame.new(state.Base)
			* CFrame.fromAxisAngle(axis, angle)
			* CFrame.new(-state.Base)
			* state.Upright
	)
end

local function fell(tree: Model, state: TreeState, direction: Vector3)
	state.Felled = true

	local steps = 14
	for step = 1, steps do
		tilt(tree, state, direction, math.rad(85) * (step / steps) ^ 2)
		task.wait(0.04)
	end
	tree.Parent = nil

	task.delay(Config.Tree.RespawnTime, function()
		tree:PivotTo(state.Upright)
		state.Health = Config.Tree.SwingsToFell
		tree:SetAttribute("Health", state.Health)
		state.Felled = false
		tree.Parent = treesFolder
	end)
end

local function onChopRequest(player: Player, tree: any)
	if typeof(tree) ~= "Instance" then
		return
	end
	local state = states[tree]
	if not state or state.Felled then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local offset = (state.Base - root.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude > Config.Tree.ChopRange + state.TrunkRadius then
		return
	end

	local now = os.clock()
	if now - (lastSwing[player] or 0) < Config.Tree.SwingCooldown * COOLDOWN_SLACK then
		return
	end
	if not MovementService.spendStamina(player, Config.Stamina.SwingCost) then
		return
	end
	lastSwing[player] = now

	-- The tree falls away from whoever felled it. (The shake on earlier hits is played by the client.)
	local direction = if offset.Magnitude > 0.01 then offset.Unit else Vector3.xAxis

	state.Health -= 1
	tree:SetAttribute("Health", state.Health)
	if state.Health <= 0 then
		PlayerState.addHaul(player, rng:NextInteger(Config.Tree.WoodMin, Config.Tree.WoodMax))
		task.spawn(fell, tree, state, direction)
	end
end

-- Call after the world has been built.
function TreeService.start()
	treesFolder = Workspace:WaitForChild("World"):WaitForChild("Trees")

	for _, tree in treesFolder:GetChildren() do
		if tree:IsA("Model") and tree.PrimaryPart then
			local trunk = tree.PrimaryPart
			tree:SetAttribute("Health", Config.Tree.SwingsToFell)
			-- The trunk is a cylinder lying along its own X axis, so Size.X is its height.
			states[tree] = {
				Health = Config.Tree.SwingsToFell,
				Felled = false,
				Upright = tree:GetPivot(),
				Base = trunk.Position - Vector3.new(0, trunk.Size.X / 2 - 2, 0),
				TrunkRadius = trunk.Size.Y / 2,
			}
		end
	end

	Remotes.ChopRequest.OnServerEvent:Connect(onChopRequest)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return TreeService
