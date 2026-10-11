-- The bot lumberjacks that fill out a race (Config.Mode = "Race"). See MULTIPLAYER.md.
--
-- Each bot walks to a tree, steering round trunks in its way, chops it, and carries the wood
-- home to bank once it has enough. RaceService decides how many there are and when they race.
--
-- A bot is a character in Workspace.Bots, tagged "Bot". Its numbers are attributes on the
-- model with the same names a player's have (Haul, RaceScore, RaceOut), so the scoreboard
-- and results can treat players and bots alike.
--
-- Not yet: the guardian ignores bots, and they all play the same way.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BotModels = require(script.Parent.BotModels)
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

type Bot = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Run: AnimationTrack?,
	State: string, -- "Idle", "ToTree", "Chopping", "Resting" or "Home"
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

local function spawnPoint(index: number, count: number): Vector3
	local angle = (index / math.max(count, 1)) * math.pi * 2
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
		State = "Idle",
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
local function walkToward(bot: Bot, target: Vector3, ignore: Instance?)
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
	bot.Humanoid.WalkSpeed = Config.Bots.WalkSpeed * MovementService.carryMultiplier(haul)
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

local function chooseTree(bot: Bot)
	bot.Tree = TreeService.findTree(bot.Root.Position, takenTrees(bot))
	bot.State = if bot.Tree then "ToTree" else "Home" -- no trees left: take home what it has
end

local function rest(bot: Bot)
	local cfg = Config.Bots
	stop(bot)
	bot.Tree = nil
	bot.RestUntil = os.clock() + rng:NextNumber(cfg.RestMin, cfg.RestMax)
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
			if haul >= bot.BankAt then
				bot.Tree = nil
				bot.State = "Home"
			else
				rest(bot)
			end
		end
	end)
end

local function step(bot: Bot)
	local now = os.clock()
	local tree = bot.Tree

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
		elseif now >= bot.NextSwingAt then
			bot.NextSwingAt = now + Config.Bots.SwingInterval
			swing(bot, tree)
		end
	elseif bot.State == "Home" then
		local distance = (bot.Root.Position * FLAT).Magnitude
		if distance <= Config.World.SafeZoneRadius - 4 then
			-- Home: bank what it carries, then set off again.
			local haul = bot.Model:GetAttribute("Haul") or 0
			bot.Model:SetAttribute("RaceScore", (bot.Model:GetAttribute("RaceScore") or 0) + haul)
			bot.Model:SetAttribute("Haul", 0)
			bot.BankAt = rng:NextInteger(Config.Bots.BankAtMin, Config.Bots.BankAtMax)
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
-- score. Call during the countdown. It may pause while new bots are made.
function BotService.prepareRound(count: number)
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

	for index, bot in bots do
		bot.Model:SetAttribute("Haul", 0)
		bot.Model:SetAttribute("RaceScore", 0)
		bot.Model:SetAttribute("RaceOut", false)
		bot.State = "Idle"
		bot.Tree = nil
		bot.BankAt = rng:NextInteger(Config.Bots.BankAtMin, Config.Bots.BankAtMax)
		local at = spawnPoint(index, #bots)
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
