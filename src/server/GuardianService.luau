-- The forest's guardian: the creature that may wake when a tree is felled and hunts the
-- player who felled it. It is an original design (a bark-and-moss forest spirit).
-- It wakes after a hidden, random number of trees felled on each trip out of camp,
-- rises from where the last tree stood, waits a moment, then gives chase.
-- One guardian per player. It glides in a straight line and ignores obstacles.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CampService = require(script.Parent.CampService)
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

-- Counts trees felled since the player last left camp, against a hidden number.
type Trip = {
	Felled: number,
	WakesAt: number,
}

local rng = Random.new()
local chases: { [Player]: Chase } = {}
local trips: { [Player]: Trip } = {}

-- Starts a fresh count with a new hidden number. Happens whenever the player is back in camp.
local function newTrip(player: Player)
	local cfg = Config.Guardian
	trips[player] = {
		Felled = 0,
		WakesAt = rng:NextInteger(cfg.WakeAfterTreesMin, cfg.WakeAfterTreesMax),
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

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
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

local function endChase(player: Player)
	local chase = chases[player]
	if not chase then
		return
	end
	chases[player] = nil
	chase.Model:Destroy()
	if player.Parent then
		player:SetAttribute("Chased", false)
	end
end

local function capture(player: Player)
	-- Being caught ends the game.
	local summary = PlayerState.endGame(player)
	endChase(player)
	Remotes.GameOver:FireClient(player, summary)
	-- Back to camp. LoadCharacter can pause, so it runs on its own thread.
	task.spawn(function()
		player:LoadCharacter()
	end)
end

local function stepChase(player: Player, chase: Chase, dt: number)
	local root = rootOf(player)
	if not root then
		endChase(player)
		return
	end

	if CampService.isInCamp(player) then
		endChase(player)
		Remotes.Escaped:FireClient(player)
		return
	end

	local cfg = Config.Guardian
	local now = os.clock()

	if now < chase.RisenAt then
		-- It rises out of the stump, watching the player.
		local remaining = (chase.RisenAt - now) / cfg.RiseTime
		place(chase, root.Position, -RISE_DEPTH * math.clamp(remaining, 0, 1))
		return
	elseif now < chase.StartsAt then
		-- Fully risen: it stands and stares before giving chase.
		place(chase, root.Position, 0)
		return
	end

	local toPlayer = (root.Position - chase.Position) * FLAT
	local distance = toPlayer.Magnitude
	if distance <= cfg.CaptureRange then
		capture(player)
		return
	end

	chase.Position += toPlayer.Unit * math.min(cfg.Speed * dt, distance)
	place(chase, root.Position, math.sin(now * 4) * 0.35) -- slight bob as it glides
end

-- Called when a player fells a tree. Wakes the guardian if this is the trip's unlucky tree.
function GuardianService.onTreeFelled(player: Player, treePosition: Vector3)
	if chases[player] or CampService.isInCamp(player) then
		return
	end

	local trip = trips[player]
	if not trip then
		return
	end
	trip.Felled += 1
	if trip.Felled < trip.WakesAt then
		return
	end

	local cfg = Config.Guardian
	local root = rootOf(player)
	if not root then
		return
	end

	local chase: Chase = {
		Model = buildGuardian(),
		Position = treePosition * FLAT,
		RisenAt = os.clock() + cfg.RiseTime,
		StartsAt = os.clock() + cfg.RiseTime + cfg.WaitTime,
	}
	chases[player] = chase
	place(chase, root.Position, -RISE_DEPTH)
	CollectionService:AddTag(chase.Model, "Guardian") -- lets the client find it for the chase camera
	chase.Model.Parent = Workspace
	player:SetAttribute("Chased", true)
end

function GuardianService.start()
	local function onPlayerAdded(player: Player)
		player:SetAttribute("Chased", false)
		newTrip(player)
		-- CampService keeps InCamp up to date; arriving home resets the count.
		player:GetAttributeChangedSignal("InCamp"):Connect(function()
			if player:GetAttribute("InCamp") then
				newTrip(player)
			end
		end)
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
		for player, chase in chases do
			stepChase(player, chase, dt)
		end
	end)
end

return GuardianService
