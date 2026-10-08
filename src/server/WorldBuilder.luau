-- Generates the whole world from code: ground, camp, safe-zone ring and trees.
-- Everything is placeholder parts. The ground's top surface is at Y = 0 and camp is at the origin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

local function makePart(props: { [string]: any }, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Cylinders lie along their X axis, so stand them upright with a 90 degree roll.
local function uprightCylinder(
	basePosition: Vector3,
	height: number,
	diameter: number
): (Vector3, CFrame)
	local size = Vector3.new(height, diameter, diameter)
	local cframe = CFrame.new(basePosition + Vector3.new(0, height / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	return size, cframe
end

local function buildGround(parent: Instance)
	local size = Config.World.GroundSize
	makePart({
		Name = "Ground",
		Size = Vector3.new(size, 4, size),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(76, 110, 62),
	}, parent)

	-- Invisible walls so the player cannot walk off the edge.
	local wallHeight = 60
	local half = size / 2
	for _, wall in
		{
			{
				Position = Vector3.new(half, wallHeight / 2, 0),
				Size = Vector3.new(2, wallHeight, size),
			},
			{
				Position = Vector3.new(-half, wallHeight / 2, 0),
				Size = Vector3.new(2, wallHeight, size),
			},
			{
				Position = Vector3.new(0, wallHeight / 2, half),
				Size = Vector3.new(size, wallHeight, 2),
			},
			{
				Position = Vector3.new(0, wallHeight / 2, -half),
				Size = Vector3.new(size, wallHeight, 2),
			},
		}
	do
		makePart({
			Name = "Boundary",
			Size = wall.Size,
			Position = wall.Position,
			Transparency = 1,
		}, parent)
	end
end

local function buildFirePit(parent: Instance)
	local pit = Instance.new("Model")
	pit.Name = "FirePit"

	local stoneCount = 10
	for i = 1, stoneCount do
		local angle = (i / stoneCount) * math.pi * 2
		makePart({
			Name = "Stone",
			Size = Vector3.new(1.4, 1, 1.2),
			CFrame = CFrame.new(math.cos(angle) * 3, 0.6, math.sin(angle) * 3)
				* CFrame.Angles(0, -angle, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(110, 110, 115),
		}, pit)
	end

	for _, yaw in { 35, 125 } do
		makePart({
			Name = "Log",
			Size = Vector3.new(4, 0.8, 0.8),
			CFrame = CFrame.new(0, 0.7, 0) * CFrame.Angles(0, math.rad(yaw), 0),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(92, 64, 40),
		}, pit)
	end

	local flame = makePart({
		Name = "Flame",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 1.2, 0),
		Transparency = 1,
		CanCollide = false,
	}, pit)

	local fire = Instance.new("Fire")
	fire.Size = 7
	fire.Heat = 12
	fire.Parent = flame

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Brightness = 2
	light.Range = 28
	light.Parent = flame

	pit.Parent = parent
end

local function buildSafeZoneRing(parent: Instance)
	local ring = Instance.new("Model")
	ring.Name = "SafeZoneRing"

	local radius = Config.World.SafeZoneRadius
	local segmentCount = 64
	local segmentLength = (2 * math.pi * radius) / segmentCount
	for i = 1, segmentCount do
		local angle = (i / segmentCount) * math.pi * 2
		local position = Vector3.new(math.cos(angle) * radius, 0.3, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		makePart({
			Name = "Segment",
			Size = Vector3.new(0.6, 0.2, segmentLength),
			CFrame = CFrame.lookAt(position, position + tangent),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 200, 90),
			CanCollide = false,
		}, ring)
	end

	ring.Parent = parent
end

local function buildCamp(parent: Instance)
	local camp = Instance.new("Folder")
	camp.Name = "Camp"

	local diameter = Config.World.CampRadius * 2
	local size, cframe = uprightCylinder(Vector3.zero, 0.2, diameter)
	makePart({
		Name = "Clearing",
		Shape = Enum.PartType.Cylinder,
		Size = size,
		CFrame = cframe,
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(104, 82, 58),
	}, camp)

	buildFirePit(camp)
	buildSafeZoneRing(camp)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CampSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(10, 0.5, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Parent = camp

	camp.Parent = parent
end

local function buildTree(rng: Random, position: Vector3, parent: Instance)
	local tree = Instance.new("Model")
	tree.Name = "Tree"

	local scale = rng:NextNumber(Config.Tree.ScaleMin, Config.Tree.ScaleMax)
	local trunkHeight = Config.Tree.TrunkHeight * scale
	local canopyDiameter = Config.Tree.CanopyDiameter * scale

	local size, cframe = uprightCylinder(position, trunkHeight, Config.Tree.TrunkDiameter * scale)
	local trunk = makePart({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = size,
		CFrame = cframe,
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(96, 68, 44),
	}, tree)

	makePart({
		Name = "Canopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * canopyDiameter,
		Position = position + Vector3.new(0, trunkHeight + canopyDiameter * 0.3, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(46, 92, 48),
		CanCollide = false,
	}, tree)

	tree.PrimaryPart = trunk
	tree.Parent = parent
end

local function buildTrees(parent: Instance)
	local trees = Instance.new("Folder")
	trees.Name = "Trees"

	local world = Config.World
	local rng = Random.new(world.Seed)
	local minSq = world.TreeMinDistanceFromCamp ^ 2
	local maxSq = world.ForestRadius ^ 2
	local placed: { Vector3 } = {}

	local attempts = 0
	while #placed < world.TreeCount and attempts < world.TreeCount * 50 do
		attempts += 1
		-- Square-root sampling spreads trees evenly over the area instead of bunching them near camp.
		local radius = math.sqrt(rng:NextNumber(minSq, maxSq))
		local angle = rng:NextNumber(0, math.pi * 2)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		local clear = true
		for _, other in placed do
			if (other - position).Magnitude < world.TreeSpacing then
				clear = false
				break
			end
		end

		if clear then
			table.insert(placed, position)
			buildTree(rng, position, trees)
		end
	end

	trees.Parent = parent
end

function WorldBuilder.build()
	-- A fresh Studio place comes with its own baseplate and spawn; ours replace them.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = Workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	local world = Instance.new("Folder")
	world.Name = "World"

	buildGround(world)
	buildCamp(world)
	buildTrees(world)

	world.Parent = Workspace
end

return WorldBuilder
