-- Generates the whole world from code: terrain, camp, pine forest and undergrowth.
-- Every model is assembled from basic parts. Camp is at the origin on flat ground at Y = 0.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Forest = require(ReplicatedStorage.Shared.Forest)
local TerrainBuilder = require(script.Parent.TerrainBuilder)

local WorldBuilder = {}

local BARK_COLORS = {
	Color3.fromRGB(84, 60, 42),
	Color3.fromRGB(72, 54, 40),
	Color3.fromRGB(96, 66, 46),
	Color3.fromRGB(66, 56, 48),
}
local LEAF_COLORS = {
	Color3.fromRGB(28, 62, 44),
	Color3.fromRGB(34, 72, 48),
	Color3.fromRGB(24, 54, 42),
	Color3.fromRGB(40, 80, 52),
}
local BUSH_COLORS = {
	Color3.fromRGB(48, 96, 52),
	Color3.fromRGB(60, 108, 56),
	Color3.fromRGB(42, 82, 58),
}
local STONE_COLOR = Color3.fromRGB(104, 106, 110)

type TreeSpec = {
	Height: number,
	Diameter: number,
	Clearance: number, -- bare trunk below the lowest needles
	FoliageWidth: number, -- width of the lowest tier
	Tiers: number,
	Detailed: boolean, -- roots; skipped on distant border trees
}

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

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

-- Scenery the player walks through and clicks through.
local function makeFoliage(props: { [string]: any }, parent: Instance): Part
	local part = makePart(props, parent)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
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

-- A cylinder running from one point to another (must not be exactly vertical).
local function cylinderBetween(from: Vector3, to: Vector3, diameter: number): (Vector3, CFrame)
	local size = Vector3.new((to - from).Magnitude, diameter, diameter)
	local cframe = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
	return size, cframe
end

local function onGround(x: number, z: number): Vector3
	return Vector3.new(x, TerrainBuilder.heightAt(x, z), z)
end

local function pointOnCircle(angle: number, radius: number, y: number): Vector3
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

-- Random point in a ring around camp, spread evenly over the ring's area.
local function randomInRing(rng: Random, minRadius: number, maxRadius: number): Vector3
	local radius = math.sqrt(rng:NextNumber(minRadius ^ 2, maxRadius ^ 2))
	local angle = rng:NextNumber(0, math.pi * 2)
	return onGround(math.cos(angle) * radius, math.sin(angle) * radius)
end

local function buildBoundary(parent: Instance)
	-- Invisible circular wall just past the last choppable trees.
	local radius = Config.World.ForestRadius + 6
	local segmentCount = 48
	local segmentLength = (2 * math.pi * radius) / segmentCount
	for i = 1, segmentCount do
		local angle = (i / segmentCount) * math.pi * 2
		local position = pointOnCircle(angle, radius, 30)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		makePart({
			Name = "Boundary",
			Size = Vector3.new(2, 120, segmentLength * 1.1),
			CFrame = CFrame.lookAt(position, position + tangent),
			Transparency = 1,
			CanQuery = false,
		}, parent)
	end
end

local function buildFirePit(parent: Instance)
	local pit = Instance.new("Model")
	pit.Name = "FirePit"

	local stoneCount = 14
	for i = 1, stoneCount do
		local angle = (i / stoneCount) * math.pi * 2
		makePart({
			Name = "Stone",
			Size = Vector3.new(2.2, 1.5, 1.8),
			CFrame = CFrame.new(pointOnCircle(angle, 5, 0.55)) * CFrame.Angles(0, -angle, 0),
			Material = Enum.Material.Slate,
			Color = STONE_COLOR,
		}, pit)
	end

	-- Logs leaning together over the flames.
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + 0.4
		local size, cframe =
			cylinderBetween(pointOnCircle(angle, 1.8, 0.3), pointOnCircle(angle, -0.3, 2.8), 0.8)
		makePart({
			Name = "Log",
			Shape = Enum.PartType.Cylinder,
			Size = size,
			CFrame = cframe,
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(70, 48, 32),
		}, pit)
	end

	local flame = makePart({
		Name = "Flame",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 1.6, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, pit)

	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 10
	fire.Parent = flame

	local light = Instance.new("PointLight")
	light.Color = Config.Lighting.WarmLight
	light.Brightness = Config.Lighting.CampfireBrightness
	light.Range = Config.Lighting.CampfireRange
	light.Shadows = true
	light.Parent = flame

	pit.Parent = parent
end

local function buildSafeZoneMarker(parent: Instance)
	local marker = Instance.new("Model")
	marker.Name = "SafeZoneMarker"
	local radius = Config.World.SafeZoneRadius

	local stoneCount = 44
	for i = 1, stoneCount do
		local angle = (i / stoneCount) * math.pi * 2
		makePart({
			Name = "Stone",
			Size = Vector3.new(1.3, 0.8, 1),
			CFrame = CFrame.new(pointOnCircle(angle, radius, 0.25)) * CFrame.Angles(0, -angle, 0),
			Material = Enum.Material.Slate,
			Color = STONE_COLOR,
			CanCollide = false,
		}, marker)
	end

	-- Lantern posts so camp can be seen glowing through the trees.
	local postCount = 6
	for i = 1, postCount do
		local angle = (i / postCount) * math.pi * 2 + math.pi / postCount
		local base = pointOnCircle(angle, radius, 0)
		local size, cframe = uprightCylinder(base, 7, 0.6)
		makePart({
			Name = "Post",
			Shape = Enum.PartType.Cylinder,
			Size = size,
			CFrame = cframe,
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(70, 48, 32),
		}, marker)

		local lantern = makePart({
			Name = "Lantern",
			Size = Vector3.new(0.7, 0.9, 0.7),
			Position = base + Vector3.new(0, 7.4, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 190, 110),
			CanCollide = false,
		}, marker)

		local light = Instance.new("PointLight")
		light.Color = Config.Lighting.WarmLight
		light.Brightness = Config.Lighting.LanternBrightness
		light.Range = Config.Lighting.LanternRange
		light.Parent = lantern
	end

	marker.Parent = parent
end

local function buildCamp(parent: Instance)
	local camp = Instance.new("Folder")
	camp.Name = "Camp"

	buildFirePit(camp)
	buildSafeZoneMarker(camp)

	-- Log benches beside the fire.
	for _, angle in { math.rad(120), math.rad(240) } do
		local centre = pointOnCircle(angle, 9, 0.8)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local size, cframe = cylinderBetween(centre - tangent * 4, centre + tangent * 4, 1.8)
		makePart({
			Name = "Bench",
			Shape = Enum.PartType.Cylinder,
			Size = size,
			CFrame = cframe,
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(96, 66, 46),
		}, camp)
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "CampSpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.Position = Vector3.new(11, 0.5, 0)
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.CanQuery = false
	spawnLocation.Neutral = true
	spawnLocation.Parent = camp

	camp.Parent = parent
end

-- Finds which top corner of a CornerWedgePart is the tall one by measuring a probe part.
local function findCornerWedgeApex(): (number, number)
	local probe = Instance.new("CornerWedgePart")
	probe.Anchored = true
	probe.Size = Vector3.new(8, 8, 8)
	probe.Position = Vector3.new(0, 1000, 0)
	probe.Parent = Workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { probe }

	local apexX, apexZ, highest = 1, -1, -math.huge
	for _, x in { 1, -1 } do
		for _, z in { 1, -1 } do
			local origin = probe.Position + Vector3.new(x * 3, 10, z * 3)
			local hit = Workspace:Raycast(origin, Vector3.new(0, -20, 0), params)
			if hit and hit.Position.Y > highest then
				apexX, apexZ, highest = x, z, hit.Position.Y
			end
		end
	end

	probe:Destroy()
	return apexX, apexZ
end

-- A pyramid is four corner wedges. For each quarter: where it sits, and how far to turn it
-- so its tall corner meets the others at the centre.
local pyramidQuarters: { { X: number, Z: number, Yaw: number } } = {}

local function preparePyramidQuarters()
	local apexX, apexZ = findCornerWedgeApex()
	local apex = Vector3.new(apexX, 0, apexZ)
	table.clear(pyramidQuarters)
	for _, x in { 1, -1 } do
		for _, z in { 1, -1 } do
			local towardCentre = Vector3.new(-x, 0, -z)
			for turn = 0, 3 do
				local yaw = turn * math.pi / 2
				if CFrame.Angles(0, yaw, 0):VectorToWorldSpace(apex):Dot(towardCentre) > 1.5 then
					table.insert(pyramidQuarters, { X = x, Z = z, Yaw = yaw })
					break
				end
			end
		end
	end
end

local function buildPyramid(
	baseCFrame: CFrame,
	width: number,
	height: number,
	color: Color3,
	parent: Instance
)
	for _, quarter in pyramidQuarters do
		local wedge = Instance.new("CornerWedgePart")
		wedge.Name = "Needles"
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.Material = Enum.Material.Grass
		wedge.Color = color
		wedge.Size = Vector3.new(width / 2, height, width / 2)
		wedge.CFrame = baseCFrame
			* CFrame.new(quarter.X * width / 4, height / 2, quarter.Z * width / 4)
			* CFrame.Angles(0, quarter.Yaw, 0)
		wedge.Parent = parent
	end
end

-- A pine: bare lower trunk, then stacked pyramids of needles narrowing to a point.
local function buildTree(rng: Random, base: Vector3, spec: TreeSpec, parent: Instance)
	local tree = Instance.new("Model")
	tree.Name = "Tree"

	local bark = pick(rng, BARK_COLORS)
	local height, diameter = spec.Height, spec.Diameter
	local sunk = base - Vector3.new(0, 2, 0) -- start below ground so hills never expose the bottom

	local trunkSize, trunkCFrame = uprightCylinder(sunk, height * 0.85 + 2, diameter)
	local trunk = makePart({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = trunkSize,
		CFrame = trunkCFrame,
		Material = Enum.Material.Wood,
		Color = bark,
	}, tree)

	-- Wider collar at the base.
	local collarSize, collarCFrame = uprightCylinder(sunk, diameter * 0.6 + 2, diameter * 1.35)
	makePart({
		Name = "Collar",
		Shape = Enum.PartType.Cylinder,
		Size = collarSize,
		CFrame = collarCFrame,
		Material = Enum.Material.Wood,
		Color = bark,
	}, tree)

	if spec.Detailed then
		local rootCount = 3
		local rootOffset = rng:NextNumber(0, math.pi * 2)
		for i = 1, rootCount do
			local angle = rootOffset + (i / rootCount) * math.pi * 2
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local size, cframe = cylinderBetween(
				base + direction * diameter * 0.3 + Vector3.new(0, diameter * 0.8, 0),
				base + direction * diameter * 1.7 - Vector3.new(0, 1.5, 0),
				diameter * 0.4
			)
			makePart({
				Name = "Root",
				Shape = Enum.PartType.Cylinder,
				Size = size,
				CFrame = cframe,
				Material = Enum.Material.Wood,
				Color = bark,
				CanCollide = false,
			}, tree)
		end
	end

	-- Each tier overlaps the one above and is turned 45 degrees from it.
	local tierStep = (height - spec.Clearance) / spec.Tiers
	local yaw = rng:NextNumber(0, math.pi / 2)
	for tier = 1, spec.Tiers do
		local towardTop = (tier - 1) / math.max(spec.Tiers - 1, 1) -- 0 = lowest tier, 1 = highest
		local tierBase = base + Vector3.new(0, spec.Clearance + (tier - 1) * tierStep, 0)
		buildPyramid(
			CFrame.new(tierBase) * CFrame.Angles(0, yaw + (tier - 1) * math.rad(45), 0),
			spec.FoliageWidth * (1 - 0.62 * towardTop),
			tierStep * 1.6,
			pick(rng, LEAF_COLORS),
			tree
		)
	end

	tree.PrimaryPart = trunk
	tree.Parent = parent
end

local function buildForest(rng: Random, parent: Instance)
	local world = Config.World
	local treeCfg = Config.Tree
	local placed: { Vector3 } = {}

	local function scatter(
		count: number,
		minRadius: number,
		maxRadius: number,
		build: (Vector3) -> ()
	)
		local done, attempts = 0, 0
		while done < count and attempts < count * 50 do
			attempts += 1
			local position = randomInRing(rng, minRadius, maxRadius)
			local clear = true
			for _, other in placed do
				if (other - position).Magnitude < world.TreeSpacing then
					clear = false
					break
				end
			end
			if clear then
				table.insert(placed, position)
				build(position)
				done += 1
			end
		end
	end

	local function between(min: number, max: number, alpha: number): number
		return min + (max - min) * alpha
	end

	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	scatter(world.TreeCount, world.TreeMinDistanceFromCamp, world.ForestRadius, function(position)
		-- 0 = smallest tree, 1 = largest. Trees grow bigger deeper in, because they are worth more.
		local weight = treeCfg.DepthSizeWeight
		local size = Forest.depthAt(position) * weight + rng:NextNumber() * (1 - weight)
		buildTree(rng, position, {
			Height = between(treeCfg.HeightMin, treeCfg.HeightMax, size),
			Diameter = between(treeCfg.TrunkDiameterMin, treeCfg.TrunkDiameterMax, size),
			Clearance = rng:NextNumber(treeCfg.ClearanceMin, treeCfg.ClearanceMax),
			FoliageWidth = between(treeCfg.FoliageWidthMin, treeCfg.FoliageWidthMax, size)
				* rng:NextNumber(0.9, 1.1),
			Tiers = treeCfg.Tiers,
			Detailed = true,
		}, trees)
	end)
	trees.Parent = parent

	local border = Instance.new("Folder")
	border.Name = "BorderTrees"
	scatter(
		world.BorderTreeCount,
		world.ForestRadius + 12,
		world.ForestRadius + 12 + world.BorderDepth,
		function(position)
			buildTree(rng, position, {
				Height = rng:NextNumber(treeCfg.BorderHeightMin, treeCfg.BorderHeightMax),
				Diameter = rng:NextNumber(
					treeCfg.BorderTrunkDiameterMin,
					treeCfg.BorderTrunkDiameterMax
				),
				Clearance = rng:NextNumber(treeCfg.ClearanceMax, treeCfg.ClearanceMax * 1.5),
				FoliageWidth = treeCfg.BorderFoliageWidth * rng:NextNumber(0.85, 1.15),
				Tiers = treeCfg.BorderTiers,
				Detailed = false,
			}, border)
		end
	)
	border.Parent = parent
end

local function buildUndergrowth(rng: Random, parent: Instance)
	local world = Config.World
	local undergrowth = Instance.new("Folder")
	undergrowth.Name = "Undergrowth"

	local innerRadius = world.CampRadius + 4
	local outerRadius = world.ForestRadius + world.BorderDepth

	for _ = 1, world.BushCount do
		local centre = randomInRing(rng, innerRadius, outerRadius)
		for _ = 1, rng:NextInteger(2, 3) do
			local width = rng:NextNumber(4, 7.5)
			local height = width * rng:NextNumber(0.5, 0.75)
			makeFoliage({
				Name = "Bush",
				Size = Vector3.new(width, height, width),
				Position = centre + Vector3.new(
					rng:NextNumber(-2.5, 2.5),
					height * 0.25,
					rng:NextNumber(-2.5, 2.5)
				),
				Color = pick(rng, BUSH_COLORS),
			}, undergrowth)
		end
	end

	for _ = 1, world.RockCount do
		local size = rng:NextNumber(2, 5.5)
		makePart({
			Name = "Rock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = randomInRing(rng, innerRadius, outerRadius) + Vector3.new(0, size * 0.1, 0),
			Material = Enum.Material.Slate,
			Color = STONE_COLOR,
		}, undergrowth)
	end

	for _ = 1, world.FallenLogCount do
		local diameter = rng:NextNumber(2, 3.5)
		local centre = randomInRing(rng, innerRadius + 10, world.ForestRadius)
		local angle = rng:NextNumber(0, math.pi * 2)
		local halfLength = rng:NextNumber(5, 9)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * halfLength
		local lift = Vector3.new(0, diameter * 0.35, 0)
		local size, cframe = cylinderBetween(
			onGround(centre.X - offset.X, centre.Z - offset.Z) + lift,
			onGround(centre.X + offset.X, centre.Z + offset.Z) + lift,
			diameter
		)
		makePart({
			Name = "FallenLog",
			Shape = Enum.PartType.Cylinder,
			Size = size,
			CFrame = cframe,
			Material = Enum.Material.Wood,
			Color = pick(rng, BARK_COLORS),
		}, undergrowth)
	end

	undergrowth.Parent = parent
end

function WorldBuilder.build()
	-- A fresh Studio place comes with its own baseplate and spawn; ours replace them.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = Workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	TerrainBuilder.build()
	preparePyramidQuarters()

	local rng = Random.new(Config.World.Seed)
	local world = Instance.new("Folder")
	world.Name = "World"

	buildBoundary(world)
	buildCamp(world)
	buildForest(rng, world)
	buildUndergrowth(rng, world)

	world.Parent = Workspace
end

return WorldBuilder
