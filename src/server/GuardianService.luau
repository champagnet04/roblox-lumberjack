-- The forest's guardian: the creature that may wake when a tree is felled and hunts the
-- player who felled it. It is an original design (a bark-and-moss forest spirit).
-- It wakes after a hidden, random number of trees felled since it last woke,
-- rises from where the last tree stood, waits a moment, then gives chase.
-- It glides in a straight line and ignores obstacles.
--
-- Solo: each player has their own count and their own guardian.
-- Race: there is one count and one guardian for the whole forest. Every tree anyone fells
-- adds to the count, bots included, and the guardian hunts whoever felled the tree that woke it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local TerrainBuilder = require(script.Parent.TerrainBuilder)

local GuardianService = {}

local BARK = Color3.fromRGB(52, 40, 32)
local MOSS = Color3.fromRGB(46, 84, 50)
local GLOW = Color3.fromRGB(170, 255, 200)
local RISE_DEPTH = 13 -- it starts this far underground, which hides it completely
local FLAT = Vector3.new(1, 0, 1)

type Chase = {
	Model: Model,
	Position: Vector3, -- where it stands, ignoring height
	RisenAt: number, -- when it has finished rising
	StartsAt: number, -- when it stops waiting and begins to move
}

-- Counts trees felled since the guardian last woke, against a hidden number.
-- Going back to camp does not reset it.
type Trip = {
	Felled: number,
	WakesAt: number,
}

local IS_RACE = Config.Mode == "Race"
local SHARED = "Shared" -- the one count everybody adds to in a race

local rng = Random.new()
local chases: { [Instance]: Chase } = {}
local trips: { [Instance | string]: Trip } = {}

-- Whose count a player's felled trees add to.
local function countFor(racer: Instance): Instance | string
	return if IS_RACE then SHARED else racer
end

-- How far through its round a race is, from 0 at the start to 1 at the end. Always 0 in solo.
local function raceProgress(): number
	if not IS_RACE or Workspace:GetAttribute("RacePhase") ~= "Running" then
		return 0
	end
	local startedAt = Workspace:GetAttribute("RacePhaseStartedAt") or 0
	local endsAt = Workspace:GetAttribute("RacePhaseEndsAt") or 0
	if endsAt <= startedAt then
		return 0
	end
	return math.clamp((Workspace:GetServerTimeNow() - startedAt) / (endsAt - startedAt), 0, 1)
end

-- Starts a fresh count with a new hidden number. Happens each time the guardian wakes.
-- In a race the top of the range comes down as the round goes on, so it wakes more easily.
local function newTrip(owner: Instance | string)
	local cfg = Config.Guardian
	local max = cfg.WakeAfterTreesMax
	if IS_RACE then
		local atEnd = Config.Race.WakeAfterTreesMaxAtEnd
		max = math.round(max + (atEnd - max) * raceProgress())
	end
	trips[owner] = {
		Felled = 0,
		WakesAt = rng:NextInteger(cfg.WakeAfterTreesMin, math.max(max, cfg.WakeAfterTreesMin)),
	}
end

local function makePart(props: { [string]: any }, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.Wood
	part.Color = BARK
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- A cylinder running from one point to another (must not be exactly vertical).
local function limb(from: Vector3, to: Vector3, diameter: number, parent: Instance)
	makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new((to - from).Magnitude, diameter, diameter),
		CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0),
	}, parent)
end

-- Built standing at the origin, facing -Z, with its feet at Y = 0.
local function buildGuardian(): Model
	local model = Instance.new("Model")
	model.Name = "Guardian"

	-- Stump-like lower body.
	makePart({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4.5, 3.2, 3.2),
		CFrame = CFrame.new(0, 2.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
	}, model)

	local torso = makePart({
		Name = "Torso",
		Size = Vector3.new(4.6, 4, 3),
		CFrame = CFrame.new(0, 6, -0.3) * CFrame.Angles(math.rad(-14), 0, 0),
	}, model)

	local mantle = makePart({
		Name = "Moss",
		Size = Vector3.new(6.4, 2.6, 4.6),
		Position = Vector3.new(0, 8.1, -0.4),
		Material = Enum.Material.Grass,
		Color = MOSS,
	}, model)
	local mantleMesh = Instance.new("SpecialMesh")
	mantleMesh.MeshType = Enum.MeshType.Sphere
	mantleMesh.Parent = mantle

	makePart({
		Name = "Head",
		Size = Vector3.new(2.6, 2.4, 2.4),
		Position = Vector3.new(0, 9.7, -1),
	}, model)

	for _, side in { 1, -1 } do
		makePart({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.55,
			Position = Vector3.new(0.62 * side, 9.9, -2.2),
			Material = Enum.Material.Neon,
			Color = GLOW,
		}, model)

		-- Long arms reaching forward.
		limb(Vector3.new(2.7 * side, 7.6, -0.2), Vector3.new(3.7 * side, 3.4, -2.4), 1, model)

		-- Branching antlers.
		local antlerBase = Vector3.new(0.8 * side, 10.7, -0.8)
		local antlerTip = Vector3.new(2.7 * side, 13.4, -0.3)
		limb(antlerBase, antlerTip, 0.4, model)
		limb((antlerBase + antlerTip) / 2, Vector3.new(3.4 * side, 12.1, -0.9), 0.3, model)
	end

	-- A cold glow so it can be seen coming through the dark.
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Brightness = 1.6
	light.Range = 26
	light.Parent = torso

	model.WorldPivot = CFrame.new()
	return model
end

-- Who the guardian can hunt: a player, or in a race the character of a bot (see BotService).
-- A bot keeps the same attributes on its character that a player has on their Player.
local function rootOf(racer: Instance): BasePart?
	local character = if racer:IsA("Player") then racer.Character else racer
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isInCamp(racer: Instance): boolean
	local root = rootOf(racer)
	return root ~= nil and (root.Position * FLAT).Magnitude <= Config.World.SafeZoneRadius
end

local function place(chase: Chase, facing: Vector3, heightOffset: number)
	local position = chase.Position
	local ground = TerrainBuilder.heightAt(position.X, position.Z)
	local at = Vector3.new(position.X, ground + heightOffset, position.Z)
	local toward = (facing - at) * FLAT
	if toward.Magnitude > 0.05 then
		chase.Model:PivotTo(CFrame.lookAt(at, at + toward))
	else
		chase.Model:PivotTo(CFrame.new(at))
	end
end

local function endChase(racer: Instance)
	local chase = chases[racer]
	if not chase then
		return
	end
	chases[racer] = nil
	chase.Model:Destroy()
	if racer.Parent then
		racer:SetAttribute("Chased", false)
	end
end

local function capture(racer: Instance)
	if not racer:IsA("Player") then
		-- A caught bot loses what it carries and is out for the rest of the round.
		-- BotService sees RaceOut and walks it off.
		racer:SetAttribute("Haul", 0)
		racer:SetAttribute("RaceOut", true)
		endChase(racer)
		return
	end

	local player = racer
	if IS_RACE then
		-- A caught racer loses what they carry and is out for the rest of the round.
		PlayerState.loseHaul(player)
		PlayerState.setOut(player, true)
		endChase(player)
		Remotes.Notice:FireClient(player, "CAUGHT! YOU ARE OUT THIS ROUND")
	else
		-- Being caught ends the game.
		local summary = PlayerState.endGame(player)
		endChase(player)
		Remotes.GameOver:FireClient(player, summary)
	end
	-- Back to camp. LoadCharacter can pause, so it runs on its own thread.
	task.spawn(function()
		player:LoadCharacter()
	end)
end

local function stepChase(racer: Instance, chase: Chase, dt: number)
	local root = rootOf(racer)
	if not root then
		endChase(racer)
		return
	end

	if isInCamp(racer) then
		endChase(racer)
		if racer:IsA("Player") then
			Remotes.Escaped:FireClient(racer)
		end
		return
	end

	local cfg = Config.Guardian
	local now = os.clock()

	if now < chase.RisenAt then
		-- It rises out of the stump, watching its quarry.
		local remaining = (chase.RisenAt - now) / cfg.RiseTime
		place(chase, root.Position, -RISE_DEPTH * math.clamp(remaining, 0, 1))
		return
	elseif now < chase.StartsAt then
		-- Fully risen: it stands and stares before giving chase.
		place(chase, root.Position, 0)
		return
	end

	local toQuarry = (root.Position - chase.Position) * FLAT
	local distance = toQuarry.Magnitude
	if distance <= cfg.CaptureRange then
		capture(racer)
		return
	end

	-- In a race it gets faster as the round goes on.
	local speed = cfg.Speed
	if IS_RACE then
		speed += (Config.Race.GuardianSpeedAtEnd - speed) * raceProgress()
	end
	chase.Position += toQuarry.Unit * math.min(speed * dt, distance)
	place(chase, root.Position, math.sin(now * 4) * 0.35) -- slight bob as it glides
end

-- Called when a racer (a player, or a bot's character) fells a tree. Wakes the guardian if
-- this tree reaches the hidden number.
function GuardianService.onTreeFelled(racer: Instance, treePosition: Vector3)
	if chases[racer] or isInCamp(racer) then
		return
	end
	if IS_RACE and next(chases) then
		return -- the one guardian is already out hunting someone
	end

	local trip = trips[countFor(racer)]
	if not trip then
		return
	end
	trip.Felled += 1
	if trip.Felled < trip.WakesAt then
		return
	end

	local cfg = Config.Guardian
	local root = rootOf(racer)
	if not root then
		return
	end

	local chase: Chase = {
		Model = buildGuardian(),
		Position = treePosition * FLAT,
		RisenAt = os.clock() + cfg.RiseTime,
		StartsAt = os.clock() + cfg.RiseTime + cfg.WaitTime,
	}
	chases[racer] = chase
	place(chase, root.Position, -RISE_DEPTH)
	CollectionService:AddTag(chase.Model, "Guardian") -- lets the client find it for the chase camera
	chase.Model.Parent = Workspace
	racer:SetAttribute("Chased", true)

	-- He has woken, so the count starts again for next time.
	newTrip(countFor(racer))
end

-- Sends the guardian back to sleep and starts the count again. Used between race rounds.
function GuardianService.reset()
	for player in table.clone(chases) do
		endChase(player)
	end
	if IS_RACE then
		newTrip(SHARED)
	end
end

function GuardianService.start()
	local function onPlayerAdded(player: Player)
		player:SetAttribute("Chased", false)
		if not IS_RACE then
			newTrip(player)
		end
	end
	if IS_RACE then
		newTrip(SHARED)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		endChase(player)
		trips[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		for racer, chase in chases do
			stepChase(racer, chase, dt)
		end
	end)
end

return GuardianService
