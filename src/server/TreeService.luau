-- Tree health, chop validation, felling and regrowth. The server decides every outcome.
-- By default a felled tree stays down until the game ends, then the whole forest regrows.
-- Each tree's remaining health is published as a `Health` attribute for the client to read.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Camp = require(ReplicatedStorage.Shared.Camp)
local Config = require(ReplicatedStorage.Shared.Config)
local Forest = require(ReplicatedStorage.Shared.Forest)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuardianService = require(script.Parent.GuardianService)
local MovementService = require(script.Parent.MovementService)
local PlayerState = require(script.Parent.PlayerState)

local TreeService = {}

local IS_RACE = Config.Mode == "Race"

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
local FLAT = Vector3.new(1, 0, 1)

local rng = Random.new()
local treesFolder: Instance
local states: { [Instance]: TreeState } = {}
local lastSwing: { [Player]: number } = {}
local lastSwingShown: { [Player]: number } = {}

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

local function regrow(tree: Model, state: TreeState)
	if not state.Felled or states[tree] ~= state then
		return -- standing already, or the forest has been made again since (see readForest)
	end
	tree:PivotTo(state.Upright)
	state.Health = Config.Tree.SwingsToFell
	tree:SetAttribute("Health", state.Health)
	state.Felled = false
	tree.Parent = treesFolder
end

local function fell(tree: Model, state: TreeState, direction: Vector3)
	state.Felled = true

	local steps = 14
	for step = 1, steps do
		tilt(tree, state, direction, math.rad(85) * (step / steps) ^ 2)
		task.wait(0.04)
	end
	if states[tree] ~= state then
		return -- the forest was made again while this tree was falling
	end
	tree.Parent = nil

	-- A respawn time of 0 means the tree stays down until the game ends.
	if Config.Tree.RespawnTime > 0 then
		task.delay(Config.Tree.RespawnTime, regrow, tree, state)
	end
end

-- Takes one swing off a tree's health. `offset` is the flat line from the chopper to the tree.
-- `damage` is how much health the swing takes; 1 unless the chopper has a better axe.
-- Returns the wood gained: 0 unless this hit felled the tree.
local function landHit(tree: Model, state: TreeState, offset: Vector3, damage: number): number
	state.Health -= damage
	if state.Health < 0.01 then
		state.Health = 0 -- a better axe takes fractions, which do not always add up exactly
	end
	tree:SetAttribute("Health", state.Health)
	if state.Health > 0 then
		return 0
	end

	-- Deeper trees are worth more.
	local cfg = Config.Tree
	local multiplier = 1 + (cfg.DeepWoodMultiplier - 1) * Forest.depthAt(state.Base)
	local wood = math.round(rng:NextInteger(cfg.WoodMin, cfg.WoodMax) * multiplier)

	-- The tree falls away from whoever felled it. (The shake on earlier hits is played by the client.)
	local direction = if offset.Magnitude > 0.01 then offset.Unit else Vector3.xAxis
	task.spawn(fell, tree, state, direction)
	return wood
end

local function onChopRequest(player: Player, tree: any)
	if typeof(tree) ~= "Instance" then
		return
	end
	local state = states[tree]
	if not state or state.Felled then
		return
	end
	if IS_RACE and not PlayerState.canRace(player) then
		return -- between rounds, or the guardian has caught them
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local offset = (state.Base - root.Position) * FLAT
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

	-- The better axe fells a tree in fewer swings. Not in a race, where everyone is equal.
	local damage = 1
	if not IS_RACE and Camp.hasPerk(PlayerState.getBuildsDone(player), "BetterAxe") then
		damage = Config.Tree.SwingsToFell / Config.Tree.BetterAxeSwings
	end
	local wood = landHit(tree, state, offset, damage)
	if wood > 0 then
		PlayerState.addHaul(player, wood)
		PlayerState.recordTreeDistance(player, (state.Base * FLAT).Magnitude)
		GuardianService.onTreeFelled(player, state.Base)
	end
end

-- The rest of this section is for the bots in a race, which are not players.

function TreeService.isStanding(tree: Instance): boolean
	local state = states[tree]
	return state ~= nil and not state.Felled
end

-- Where a tree stands and how thick its trunk is.
function TreeService.placeOf(tree: Instance): (Vector3, number)
	local state = states[tree]
	if not state then
		return Vector3.zero, 0
	end
	return state.Base, state.TrunkRadius
end

-- Picks a standing tree for a bot: one of the few nearest to `near`, at random, leaving
-- out any in `taken` (trees other bots are already heading for).
function TreeService.findTree(near: Vector3, taken: { [Instance]: boolean }): Model?
	local CHOICES = 4
	local nearest: { { Tree: Instance, Distance: number } } = {}
	for tree, state in states do
		if not state.Felled and not taken[tree] then
			local distance = ((state.Base - near) * FLAT).Magnitude
			if #nearest < CHOICES or distance < nearest[#nearest].Distance then
				table.insert(nearest, { Tree = tree, Distance = distance })
				table.sort(nearest, function(a, b)
					return a.Distance < b.Distance
				end)
				if #nearest > CHOICES then
					table.remove(nearest)
				end
			end
		end
	end
	if #nearest == 0 then
		return nil
	end
	return nearest[rng:NextInteger(1, #nearest)].Tree :: Model
end

-- The nearest standing trunk in the way of something at `from` heading in `direction`
-- (flat, unit length), within `lookahead` studs. Returns where it stands, or nil.
function TreeService.trunkAhead(
	from: Vector3,
	direction: Vector3,
	lookahead: number,
	clearance: number,
	ignore: Instance?
): Vector3?
	local best: Vector3? = nil
	local bestAhead = lookahead
	for tree, state in states do
		if not state.Felled and tree ~= ignore then
			local offset = (state.Base - from) * FLAT
			local ahead = offset:Dot(direction)
			if ahead > 0 and ahead < bestAhead then
				local aside = (offset - direction * ahead).Magnitude
				if aside < state.TrunkRadius + clearance then
					best = state.Base
					bestAhead = ahead
				end
			end
		end
	end
	return best
end

-- One axe hit from a bot standing at `from`. Returns the wood gained: 0 unless this hit
-- felled the tree. Does nothing if the tree is down or out of reach.
function TreeService.botHit(tree: Instance, from: Vector3): number
	local state = states[tree]
	if not state or state.Felled then
		return 0
	end
	local offset = (state.Base - from) * FLAT
	if offset.Magnitude > Config.Tree.ChopRange + state.TrunkRadius then
		return 0
	end
	return landHit(tree :: Model, state, offset, 1)
end

-- A swing is drawn by each player's own game, so other players would not see it. This passes
-- the start of a swing on to everyone else, to draw on their screens. It decides nothing.
local function onSwing(player: Player, tree: any)
	local now = os.clock()
	if now - (lastSwingShown[player] or 0) < Config.Tree.SwingCooldown * COOLDOWN_SLACK then
		return
	end
	lastSwingShown[player] = now

	local shownTree = if typeof(tree) == "Instance" and states[tree] then tree else nil
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.Swing:FireClient(other, player, shownTree)
		end
	end
end

-- Stands every felled tree back up. Used between race rounds.
function TreeService.regrowAll()
	for tree, state in states do
		regrow(tree :: Model, state)
	end
end

-- Reads the forest afresh. Used at the start, and again after the world has grown, when
-- every tree has been replaced by a new one.
function TreeService.readForest()
	-- A felled tree is kept out of the world until it regrows; the old ones are finished with.
	for tree, state in states do
		if state.Felled then
			tree:Destroy()
		end
	end
	table.clear(states)

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
end

-- Call after the world has been built.
function TreeService.start()
	treesFolder = Workspace:WaitForChild("World"):WaitForChild("Trees")
	TreeService.readForest()

	-- When a game ends, the whole forest grows back for the next one.
	PlayerState.GameEnded:Connect(TreeService.regrowAll)

	Remotes.ChopRequest.OnServerEvent:Connect(onChopRequest)
	Remotes.Swing.OnServerEvent:Connect(onSwing)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastSwingShown[player] = nil
	end)
end

return TreeService
