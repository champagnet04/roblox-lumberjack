-- The bot lumberjacks that fill out a race (Config.Mode = "Race"). See MULTIPLAYER.md.
--
-- Each bot walks to a tree, steering round trunks in its way, chops it, and carries the wood
-- home to bank once it has enough. RaceService decides how many there are and when they race.
--
-- A bot is a character in Workspace.Bots, tagged "Bot". Its numbers are attributes on the
-- model with the same names a player's have (Haul, RaceScore, RaceOut), so the scoreboard
-- and results can treat players and bots alike.
--
-- The guardian treats bots like players: their felled trees add to its count, it hunts the
-- one that woke it, and that bot runs for camp. A caught bot is out for the round.
--
-- Each bot always plays the same way, careful, steady or greedy (Config.Bots.Styles).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BotModels = require(script.Parent.BotModels)
local GuardianService = require(script.Parent.GuardianService)
local MovementService = require(script.Parent.MovementService)
local PlayerSetup = require(script.Parent.PlayerSetup)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local TreeService = require(script.Parent.TreeService)

local BotService = {}

local TICK = 0.2
local FLAT = Vector3.new(1, 0, 1)
local IMPACT_DELAY = 0.18 -- matches the swing drawn by the client (ChopAnimation.IMPACT_DELAY)
local LOOKAHEAD = 12 -- how far ahead a bot looks for trunks in its way
local CLEARANCE = 2.5 -- how wide a berth it gives them
local STUCK_AFTER = 1.5 -- seconds without progress before it slips past whatever blocks it
local SPAWN_RING = 10 -- bots start a round this far from the fire

-- Roblox's own animations for the standard character.
local RUN_ANIMATION = "rbxassetid://507767714"
local IDLE_ANIMATION = "rbxassetid://507766666"
local HOLD_ANIMATION = "rbxassetid://507768375" -- arm out, holding a tool

type Style = typeof(Config.Bots.Styles.Steady)

type Bot = {
	Model: Model,
	Style: Style,
	Outward: Vector3, -- the direction from camp it sets out in, so bots spread round the forest
	Humanoid: Humanoid,
	Root: BasePart,
	Run: AnimationTrack?,
	State: string, -- "Idle", "ToTree", "Chopping", "Resting", "Home", "Fleeing" or "Out"
	Place: number, -- its place in the ring at camp, out of `places`
	FleeAt: number, -- when it stops staring at the guardian and runs
	Stamina: number, -- spent on swings and sprinting, by the same rules as a player
	LastEffortAt: number, -- stamina refills a short while after the last swing or sprint
	Tree: Model?,
	BankAt: number, -- heads home once it carries this much
	NextSwingAt: number,
	RestUntil: number,
	ProgressFrom: Vector3, -- where it was when progress was last checked
	ProgressAt: number,
}

local rng = Random.new()
local folder: Folder
local bots: { Bot } = {}
local racing = false
local places = 1 -- how many starting places there are this round, players and bots together

local function loadTrack(humanoid: Humanoid, animationId: string, looped: boolean): AnimationTrack?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok then
		return nil
	end
	track.Looped = looped
	return track
end

-- Where a racer stands at camp at the start of a round: one place each, spread round the
-- fire, for players and bots alike. The arc leaves a gap where the lean-to stands.
function BotService.startingPlace(place: number, outOf: number): Vector3
	local arc = math.rad(300)
	local angle = -arc / 2 + (place - 0.5) / math.max(outOf, 1) * arc
	local x, z = math.cos(angle) * SPAWN_RING, math.sin(angle) * SPAWN_RING
	return Vector3.new(x, TerrainBuilder.heightAt(x, z) + 4, z)
end

local function makeBot(look: BotModels.Look): Bot?
	local model = BotModels.build(look)
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end

	model:SetAttribute("Haul", 0)
	model:SetAttribute("RaceScore", 0)
	model:SetAttribute("RaceOut", false)
	model:SetAttribute("Chased", false)
	CollectionService:AddTag(model, "Bot")
	model.Parent = folder
	root:SetNetworkOwner(nil) -- the server moves it, not any player's game

	PlayerSetup.equip(model, Config.Bots.TorchShadows)

	local idle = loadTrack(humanoid, IDLE_ANIMATION, true)
	if idle then
		idle:Play()
	end
	local hold = loadTrack(humanoid, HOLD_ANIMATION, true)
	if hold then
		hold.Priority = Enum.AnimationPriority.Action
		hold:Play()
	end

	return {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Run = loadTrack(humanoid, RUN_ANIMATION, true),
		Style = (Config.Bots.Styles :: any)[look.Style] or Config.Bots.Styles.Steady,
		Outward = Vector3.xAxis,
		State = "Idle",
		Place = 1,
		FleeAt = 0,
		Stamina = Config.Stamina.Max,
		LastEffortAt = 0,
		Tree = nil,
		BankAt = 0,
		NextSwingAt = 0,
		RestUntil = 0,
		ProgressFrom = root.Position,
		ProgressAt = os.clock(),
	}
end

local function setRunning(bot: Bot, running: boolean)
	local run = bot.Run
	if not run then
		return
	end
	if running and not run.IsPlaying then
		run:Play(0.15)
	elseif not running and run.IsPlaying then
		run:Stop(0.15)
	end
end

local function stop(bot: Bot)
	bot.Humanoid:MoveTo(bot.Root.Position)
	setRunning(bot, false)
	bot.ProgressAt = os.clock()
	bot.ProgressFrom = bot.Root.Position
end

-- Walks towards a point, stepping aside from any trunk in the way. `ignore` is the tree the
-- bot is walking up to, which is not an obstacle.
local function walkToward(bot: Bot, target: Vector3, ignore: Instance?, sprint: boolean?)
	local position = bot.Root.Position
	local toTarget = (target - position) * FLAT
	if toTarget.Magnitude < 0.5 then
		stop(bot)
		return
	end
	local direction = toTarget.Unit

	local trunk = TreeService.trunkAhead(position, direction, LOOKAHEAD, CLEARANCE, ignore)
	if trunk then
		-- Lean away from the side the trunk is on.
		local right = direction:Cross(Vector3.yAxis)
		local side = if ((trunk - position) * FLAT):Dot(right) > 0 then -1 else 1
		direction = (direction + right * side * 1.3).Unit
	end

	local haul = bot.Model:GetAttribute("Haul") or 0
	-- Sprinting drains stamina; once it is gone the bot can only walk, and tired at that.
	local sprinting = sprint == true and bot.Stamina > 0
	if sprinting then
		bot.Stamina = math.max(bot.Stamina - Config.Stamina.SprintDrainPerSecond * TICK, 0)
		bot.LastEffortAt = os.clock()
	end
	bot.Humanoid.WalkSpeed = (
		if sprinting then Config.Player.SprintSpeed else Config.Player.WalkSpeed
	)
		* MovementService.carryMultiplier(haul)
		* MovementService.tiredMultiplier(bot.Stamina)
	bot.Humanoid:MoveTo(position + direction * 8)
	setRunning(bot, true)

	-- Caught on a rock, a log or another racer: slip past rather than stand there.
	local now = os.clock()
	if ((position - bot.ProgressFrom) * FLAT).Magnitude > 1.5 then
		bot.ProgressFrom = position
		bot.ProgressAt = now
	elseif now - bot.ProgressAt > STUCK_AFTER then
		bot.Model:PivotTo(bot.Model:GetPivot() + direction * 5 + Vector3.new(0, 1.5, 0))
		bot.ProgressFrom = bot.Root.Position
		bot.ProgressAt = now
	end
end

-- Trees other bots are heading for or chopping, so two do not pick the same one.
local function takenTrees(except: Bot): { [Instance]: boolean }
	local taken = {}
	for _, other in bots do
		if other ~= except and other.Tree then
			taken[other.Tree] = true
		end
	end
	return taken
end

local function between(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

local function chooseTree(bot: Bot)
	-- Look a little farther out than where it stands, until it is as deep as its style goes.
	local position = bot.Root.Position
	local flat = position * FLAT
	local near = position
	if flat.Magnitude < bot.Style.MaxDepth then
		local outward = if flat.Magnitude > SPAWN_RING + 4 then flat.Unit else bot.Outward
		near = position + outward * bot.Style.Push
	end
	bot.Tree = TreeService.findTree(near, takenTrees(bot))
	bot.State = if bot.Tree then "ToTree" else "Home" -- no trees left: take home what it has
end

local function rest(bot: Bot)
	stop(bot)
	bot.Tree = nil
	bot.RestUntil = os.clock() + between(bot.Style.Rest)
	bot.State = "Resting"
end

local function swing(bot: Bot, tree: Model)
	local base = TreeService.placeOf(tree)
	local position = bot.Root.Position
	local facing = Vector3.new(base.X, position.Y, base.Z)
	if (facing - position).Magnitude > 0.5 then
		bot.Root.CFrame = CFrame.lookAt(position, facing)
	end

	-- The swing is drawn by each player's game; the hit lands a moment later.
	Remotes.Swing:FireAllClients(bot.Model, tree)
	task.delay(IMPACT_DELAY, function()
		if not racing or bot.State ~= "Chopping" or bot.Tree ~= tree then
			return
		end
		local wood = TreeService.botHit(tree, bot.Root.Position)
		if wood > 0 then
			local haul = (bot.Model:GetAttribute("Haul") or 0) + wood
			bot.Model:SetAttribute("Haul", haul)
			GuardianService.onTreeFelled(bot.Model, (TreeService.placeOf(tree)))
			if bot.Model:GetAttribute("Chased") == true then
				return -- this tree woke the guardian; step() takes over
			end
			if haul >= bot.BankAt then
				bot.Tree = nil
				bot.State = "Home"
			else
				rest(bot)
			end
		end
	end)
end

local function bank(bot: Bot)
	local haul = bot.Model:GetAttribute("Haul") or 0
	bot.Model:SetAttribute("RaceScore", (bot.Model:GetAttribute("RaceScore") or 0) + haul)
	bot.Model:SetAttribute("Haul", 0)
	bot.BankAt = math.round(between(bot.Style.BankAt))
end

local function step(bot: Bot)
	local now = os.clock()
	local tree = bot.Tree
	local model = bot.Model

	if now - bot.LastEffortAt >= Config.Stamina.RegenDelay then
		bot.Stamina =
			math.min(bot.Stamina + Config.Stamina.RegenPerSecond * TICK, Config.Stamina.Max)
	end

	-- The guardian comes first, whatever the bot was doing.
	if model:GetAttribute("RaceOut") == true then
		if bot.State ~= "Out" then
			-- Caught: back to its place at camp for the rest of the round.
			bot.State = "Out"
			bot.Tree = nil
			model:PivotTo(CFrame.new(BotService.startingPlace(bot.Place, places)))
			stop(bot)
		end
		return
	end
	if model:GetAttribute("Chased") == true then
		if bot.State ~= "Fleeing" then
			-- It freezes for a moment at the sight of the guardian, then runs.
			bot.State = "Fleeing"
			bot.Tree = nil
			bot.FleeAt = now + between(bot.Style.Reaction)
			stop(bot)
		elseif now >= bot.FleeAt then
			walkToward(bot, Vector3.zero, nil, true)
		end
		return
	elseif bot.State == "Fleeing" then
		-- Made it into camp, and the guardian has gone: bank and carry on.
		bank(bot)
		rest(bot)
		return
	end

	if bot.State == "Resting" then
		if now >= bot.RestUntil then
			chooseTree(bot)
		end
	elseif bot.State == "ToTree" then
		if not tree or not TreeService.isStanding(tree) then
			chooseTree(bot) -- someone else felled it first
			return
		end
		local base, radius = TreeService.placeOf(tree)
		local distance = ((base - bot.Root.Position) * FLAT).Magnitude
		if distance <= Config.Tree.ChopRange + radius - 3 then
			stop(bot)
			bot.State = "Chopping"
			bot.NextSwingAt = now + 0.3
		else
			walkToward(bot, base, tree)
		end
	elseif bot.State == "Chopping" then
		if not tree or not TreeService.isStanding(tree) then
			chooseTree(bot)
		elseif
			now >= bot.NextSwingAt
			and bot.Stamina >= Config.Stamina.SwingCost + bot.Style.Reserve
		then
			bot.NextSwingAt = now + Config.Bots.SwingInterval
			bot.Stamina -= Config.Stamina.SwingCost
			bot.LastEffortAt = now
			swing(bot, tree)
		end
	elseif bot.State == "Home" then
		local distance = (bot.Root.Position * FLAT).Magnitude
		if distance <= Config.World.SafeZoneRadius - 4 then
			-- Home: bank what it carries, then set off again.
			bank(bot)
			rest(bot)
		else
			walkToward(bot, Vector3.zero, nil)
		end
	end
end

-- The bots racing this round, as their character models.
function BotService.getBots(): { Model }
	local models = {}
	for _, bot in bots do
		table.insert(models, bot.Model)
	end
	return models
end

-- Gets the bots ready for a new round: the right number of them, back at camp, with no
-- score. Players take the first `playerCount` starting places and the bots the rest.
-- It may pause while new bots are made.
function BotService.prepareRound(count: number, playerCount: number)
	racing = false
	count = math.clamp(count, 0, #Config.Bots.Roster)

	while #bots > count do
		local bot = table.remove(bots) :: Bot
		bot.Model:Destroy()
	end
	while #bots < count do
		local bot = makeBot(Config.Bots.Roster[#bots + 1])
		if not bot then
			break -- Roblox could not make one; race with the bots there are
		end
		table.insert(bots, bot)
	end

	places = playerCount + #bots
	for index, bot in bots do
		bot.Model:SetAttribute("Haul", 0)
		bot.Model:SetAttribute("RaceScore", 0)
		bot.Model:SetAttribute("RaceOut", false)
		bot.Model:SetAttribute("Chased", false)
		bot.Stamina = Config.Stamina.Max
		bot.State = "Idle"
		bot.Place = playerCount + index
		bot.Tree = nil
		bot.BankAt = math.round(between(bot.Style.BankAt))
		local at = BotService.startingPlace(bot.Place, places)
		bot.Outward = (at * FLAT).Unit
		bot.Model:PivotTo(CFrame.lookAt(at, Vector3.new(at.X * 2, at.Y, at.Z * 2))) -- facing outwards
		stop(bot)
	end
end

-- Sets the bots racing, or stops them where they stand.
function BotService.setRacing(on: boolean)
	racing = on
	for _, bot in bots do
		if on then
			-- Set off at slightly different moments so they do not move as one.
			bot.RestUntil = os.clock() + rng:NextNumber(0, 1.2)
			bot.State = "Resting"
		else
			bot.State = "Idle"
			bot.Tree = nil
			stop(bot)
		end
	end
end

function BotService.start()
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = Workspace

	task.spawn(function()
		while true do
			if racing then
				for _, bot in bots do
					if bot.Model.Parent and bot.Humanoid.Health > 0 then
						step(bot)
					end
				end
			end
			task.wait(TICK)
		end
	end)
end

return BotService
