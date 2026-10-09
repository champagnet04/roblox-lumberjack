-- Models for the camp builds and for the materials found in the forest.
-- Camp is at the origin on flat ground at Y = 0.
--
-- The organic shapes (rocks, stump, log, forked stick, crooked stick, meat) are sculpted meshes
-- made by art/make_camp_kit.py. They are imported into the place by hand, once, and kept in
-- ServerStorage as a model named "CampKit". If that model is missing, each piece falls back to
-- a plain shape, so the game still works.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local CampModels = {}

local WOOD = Color3.fromRGB(96, 66, 46)
local DARK_WOOD = Color3.fromRGB(70, 48, 32)
local PALE_WOOD = Color3.fromRGB(190, 152, 104)
local STICK = Color3.fromRGB(122, 92, 60)
local CHARRED = Color3.fromRGB(42, 34, 30)
local STONE = Color3.fromRGB(112, 110, 106)
local ROPE = Color3.fromRGB(176, 148, 104)
local CLOTH = Color3.fromRGB(196, 180, 150)
local CLOTH_WORN = Color3.fromRGB(172, 154, 124)
local CLOTH_PATCH = Color3.fromRGB(126, 104, 82)
local BLANKET = Color3.fromRGB(120, 60, 50)
local MOSS = Color3.fromRGB(70, 120, 62)
local FLINT = Color3.fromRGB(120, 124, 134)
local MEAT = Color3.fromRGB(134, 70, 44)
local RUST = Color3.fromRGB(140, 84, 54)
local EMBER = Color3.fromRGB(255, 120, 40)
local GHOST = Color3.fromRGB(255, 214, 120)

local KIT_MODEL = "CampKit"

-- Each sculpted piece as art/make_camp_kit.py made it: its size in studs, and where the middle
-- of that box sits from the piece's own origin. The script prints these numbers when it runs;
-- if a shape is changed there, copy the new numbers here.
local KIT = {
	RockA = { Size = Vector3.new(2.00, 1.14, 1.56), Middle = Vector3.new(0.02, 0.61, -0.02) },
	RockB = { Size = Vector3.new(1.66, 0.90, 1.96), Middle = Vector3.new(-0.13, 0.49, -0.04) },
	RockC = { Size = Vector3.new(2.51, 0.79, 1.43), Middle = Vector3.new(0.09, 0.43, 0.04) },
	Stump = { Size = Vector3.new(2.98, 2.08, 2.84), Middle = Vector3.new(0.02, 1.06, -0.06) },
	Log = { Size = Vector3.new(6.00, 1.32, 1.36), Middle = Vector3.new(0.00, 0.02, 0.03) },
	ForkedStick = { Size = Vector3.new(1.68, 4.99, 0.61), Middle = Vector3.new(-0.03, 2.52, 0.03) },
	Crossbar = { Size = Vector3.new(9.69, 0.71, 0.50), Middle = Vector3.new(-0.03, 0.13, 0.01) },
	Meat = { Size = Vector3.new(2.39, 1.22, 1.24), Middle = Vector3.new(0.21, -0.14, 0.02) },
}
-- The crooked stick's own thickness, used when stretching it into a pole of another size.
local CROSSBAR_DIAMETER = 0.32

local kitTemplates: { [string]: MeshPart } = {}
local kitLoaded = false

local function kitTemplate(name: string): MeshPart?
	if not kitLoaded then
		kitLoaded = true
		local kit = ServerStorage:FindFirstChild(KIT_MODEL)
		if not kit then
			warn(
				`[CampModels] No "{KIT_MODEL}" model in ServerStorage, so the camp uses plain shapes.`,
				"Import art/models/camp_kit.obj in Studio to get the sculpted ones."
			)
		else
			for pieceName, info in KIT do
				local found = kit:FindFirstChild(pieceName, true)
				if found and found:IsA("MeshPart") then
					kitTemplates[pieceName] = found
					-- If the import turned the mesh on its side, its box will be the wrong shape.
					local ratio = found.Size / info.Size
					local largest = math.max(ratio.X, ratio.Y, ratio.Z)
					local smallest = math.min(ratio.X, ratio.Y, ratio.Z)
					if largest > smallest * 1.15 then
						warn(`[CampModels] "{pieceName}" in {KIT_MODEL} is not the expected shape.`)
					end
				else
					warn(
						`[CampModels] {KIT_MODEL} has no mesh named "{pieceName}"; using a plain shape.`
					)
				end
			end
			local found = 0
			for _ in kitTemplates do
				found += 1
			end
			print(`[CampModels] Sculpted camp kit: found {found} of 8 pieces.`)
		end
	end
	return kitTemplates[name]
end

local function makePart(props: { [string]: any }, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.Wood
	part.Color = WOOD
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- A copy of a sculpted piece with its own origin at `origin`, or nil if the kit is not imported.
local function kitPart(
	name: string,
	origin: CFrame,
	scale: Vector3,
	props: { [string]: any },
	parent: Instance
): MeshPart?
	local template = kitTemplate(name)
	if not template then
		return nil
	end
	local info = KIT[name]
	local part = template:Clone()
	part.Name = name
	part.Anchored = true
	part.Size = info.Size * scale
	part.CFrame = origin * CFrame.new(info.Middle * scale)
	part.Material = Enum.Material.Wood
	part.Color = WOOD
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- A cylinder running from one point to another (must not be exactly vertical).
local function pole(
	from: Vector3,
	to: Vector3,
	diameter: number,
	parent: Instance,
	color: Color3?
): Part
	return makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new((to - from).Magnitude, diameter, diameter),
		CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0),
		Color = color or WOOD,
	}, parent)
end

-- A thin round slice, flat side facing along the X axis of `at`.
local function slice(at: CFrame, diameter: number, color: Color3, parent: Instance): Part
	return makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, diameter, diameter),
		CFrame = at,
		Color = color,
	}, parent)
end

-- A crooked stick from one point to another, thicker at `from` (must not be exactly vertical).
local function crookedPole(
	from: Vector3,
	to: Vector3,
	diameter: number,
	parent: Instance,
	color: Color3?,
	twist: number?
): BasePart
	local length = (to - from).Magnitude
	local along = CFrame.lookAt((from + to) / 2, to)
		* CFrame.Angles(0, math.rad(90), 0)
		* CFrame.Angles(twist or 0, 0, 0)
	local thickness = diameter / CROSSBAR_DIAMETER
	local scale = Vector3.new(length / KIT.Crossbar.Size.X, thickness, thickness)
	return kitPart("Crossbar", along, scale, { Color = color or STICK }, parent)
		or pole(from, to, diameter, parent, color or STICK)
end

-- A boulder sitting on the ground at `origin`.
local function rock(name: string, origin: CFrame, scale: number, parent: Instance, color: Color3?)
	local props = { Material = Enum.Material.Slate, Color = color or STONE }
	if not kitPart(name, origin, Vector3.one * scale, props, parent) then
		local size = KIT[name].Size * scale
		makePart({
			Name = name,
			Size = size,
			CFrame = origin * CFrame.new(0, size.Y / 2, 0),
			Material = Enum.Material.Slate,
			Color = color or STONE,
		}, parent)
	end
end

-- An upright stump standing on the ground at `origin`, with a pale sawn top.
local function stump(origin: CFrame, scale: Vector3, parent: Instance)
	local height = KIT.Stump.Size.Y * scale.Y
	if not kitPart("Stump", origin, scale, { Color = DARK_WOOD }, parent) then
		makePart({
			Name = "Stump",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 2.1 * scale.X, 2.1 * scale.X),
			CFrame = origin * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = DARK_WOOD,
		}, parent)
	end
	slice(
		origin * CFrame.new(0, height, 0) * CFrame.Angles(0, 0, math.rad(90)),
		1.84 * scale.X,
		PALE_WOOD,
		parent
	).Name =
		"StumpTop"
end

-- A log lying along the X axis of `origin`, centred on it, with a sawn face at each end.
local function log(origin: CFrame, scale: number, bark: Color3, ends: Color3, parent: Instance)
	if not kitPart("Log", origin, Vector3.one * scale, { Color = bark }, parent) then
		makePart({
			Name = "Log",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 1.2, 1.2) * scale,
			CFrame = origin,
			Color = bark,
		}, parent)
	end
	for _, side in { -1, 1 } do
		slice(origin * CFrame.new(side * 3 * scale, 0, 0), 1.04 * scale, ends, parent).Name =
			"LogEnd"
	end
end

-- An upright stick ending in a fork, its foot at `origin`. The prongs spread along X.
local function forkedStick(origin: CFrame, scale: Vector3, parent: Instance, color: Color3?)
	local stickColor = color or STICK
	if kitPart("ForkedStick", origin, scale, { Color = stickColor }, parent) then
		return
	end
	local function point(x: number, y: number): Vector3
		return origin:PointToWorldSpace(Vector3.new(x * scale.X, y * scale.Y, 0))
	end
	local thickness = 0.5 * scale.X
	pole(point(0, 0), point(0.03, 3.7), thickness, parent, stickColor)
	pole(point(0, 3.6), point(-0.75, 4.9), thickness * 0.7, parent, stickColor)
	pole(point(0, 3.6), point(0.68, 4.75), thickness * 0.7, parent, stickColor)
end

-- A wrap of rope around a joint, its axis along the X axis of `at`.
local function lashing(at: CFrame, diameter: number, parent: Instance)
	makePart({
		Name = "Lashing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, diameter, diameter),
		CFrame = at,
		Material = Enum.Material.Fabric,
		Color = ROPE,
		CanCollide = false,
	}, parent)
end

local function onCircle(degrees: number, radius: number, y: number): Vector3
	local angle = math.rad(degrees)
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

local function turn(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end

-- The cooking frame straddles the fire: a forked stick this far out on each side.
local FORK_DISTANCE = 4.1
local FORK_BURIED = 0.35
local SPIT_HEIGHT = 3.62

-- The lean-to stands on the far side of the fire from the spawn point, open toward the fire.
-- Points are given in its own space: X along the ridge, Y up, -Z toward the fire.
local LEAN_TO = CFrame.lookAt(Vector3.new(-14, 0, 0), Vector3.zero)
local RIDGE_HEIGHT = 5.4
local RIDGE_HALF_LENGTH = 4.5
local RIDGE_Z = -1
-- The slanted poles rest on the ridge and run from just past it down to the ground at the back.
local RAFTER_TOP = Vector3.new(0, 6.46, -1.5)
local RAFTER_FOOT = Vector3.new(0, 0.2, 4.5)
local RAFTER_DIAMETER = 0.32

local function leanToPoint(x: number, y: number, z: number): Vector3
	return LEAN_TO:PointToWorldSpace(Vector3.new(x, y, z))
end

local builders: { [string]: (model: Model) -> () } = {}

-- A ring of rough rocks around a small stack of burning logs.
function builders.FirePit(model: Model)
	local rng = Random.new(7)
	local rocks = { "RockA", "RockB", "RockC" }
	local count = 11
	for i = 1, count do
		local degrees = 360 * i / count + rng:NextNumber(-5, 5)
		local origin = CFrame.new(onCircle(degrees, 2.6, -0.08)) * turn(rng:NextNumber(0, 360))
		rock(rocks[i % 3 + 1], origin, rng:NextNumber(0.6, 0.85), model)
	end

	for i = 1, 4 do
		local origin = turn(90 * i + 20)
			* CFrame.new(0.62, 0.95, 0)
			* CFrame.Angles(0, 0, math.rad(122))
		log(origin, 0.4, CHARRED, CHARRED, model)
	end

	makePart({
		Name = "Embers",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 2.6, 2.6),
		CFrame = CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = EMBER,
		CanCollide = false,
	}, model)

	local flame = makePart({
		Name = "Flame",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 1.4, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, model)

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
end

-- Three upright stumps in an arc on the spawn side of the fire.
function builders.StumpStools(model: Model)
	for _, stool in { { -38, 1.0, 20 }, { 0, 0.9, 140 }, { 38, 1.05, 260 } } do
		local degrees, size, facing = stool[1], stool[2], stool[3]
		local origin = CFrame.new(onCircle(degrees, 7, 0)) * turn(facing)
		stump(origin, Vector3.new(size, size * 0.85, size), model)
	end
end

-- A forked stick either side of the fire, a crooked stick resting in the forks, and meat on it.
function builders.CookingFrame(model: Model)
	for _, side in { -1, 1 } do
		local origin = CFrame.new(0, -FORK_BURIED, side * FORK_DISTANCE) * turn(8 * side)
		forkedStick(origin, Vector3.one, model)
	end

	local spit = CFrame.new(0, SPIT_HEIGHT, 0) * turn(90)
	if not kitPart("Crossbar", spit, Vector3.one, { Color = STICK }, model) then
		pole(
			Vector3.new(0, SPIT_HEIGHT, -4.8),
			Vector3.new(0, SPIT_HEIGHT, 4.8),
			0.32,
			model,
			STICK
		)
	end

	local meatProps = { Material = Enum.Material.Leather, Color = MEAT, CanCollide = false }
	if not kitPart("Meat", spit * CFrame.new(-0.2, 0, 0), Vector3.one, meatProps, model) then
		makePart({
			Name = "Meat",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.2, 1.2, 1.2),
			CFrame = spit * CFrame.new(0, -0.15, 0),
			Material = Enum.Material.Leather,
			Color = MEAT,
			CanCollide = false,
		}, model)
	end
end

-- Logs stacked three, two, one beside the lean-to, held by an upright stake at each side.
function builders.Woodpile(model: Model)
	local rng = Random.new(11)
	local base = Vector3.new(-13, 0, -9)
	local rows = { { -1.3, 0, 1.3 }, { -0.65, 0.65 }, { 0 } }
	for row, offsets in rows do
		for _, offset in offsets do
			local at = base
				+ Vector3.new(rng:NextNumber(-0.25, 0.25), 0.58 + (row - 1) * 1.02, offset)
			local origin = CFrame.new(at)
				* turn(if rng:NextNumber() < 0.5 then 180 else 0)
				* CFrame.Angles(rng:NextNumber(0, math.pi * 2), 0, 0)
			log(origin, 1, WOOD, PALE_WOOD, model)
		end
	end
	for _, side in { -1, 1 } do
		local foot = base + Vector3.new(0.4 * side, -0.3, side * 2.1)
		crookedPole(foot, foot + Vector3.new(0.15 * side, 4, 0.1 * side), 0.4, model).Name = "Stake"
	end
end

-- Two forked posts, a ridge pole resting in the forks, and slanted poles running back to the
-- ground. Every foot sits on or just into the dirt; nothing else goes below ground.
function builders.LeanToFrame(model: Model)
	-- The posts are forked sticks, taller than the ones at the fire, with the fork turned so
	-- the ridge pole drops into it.
	local postScale = Vector3.new(1.2, 1.42, 1.2)
	for _, side in { -1, 1 } do
		local origin = LEAN_TO
			* CFrame.new(side * RIDGE_HALF_LENGTH, -0.3, RIDGE_Z)
			* turn(90 + 6 * side)
		forkedStick(origin, postScale, model, WOOD)
		lashing(LEAN_TO * CFrame.new(side * RIDGE_HALF_LENGTH, RIDGE_HEIGHT, RIDGE_Z), 0.75, model)
	end

	crookedPole(
		leanToPoint(-RIDGE_HALF_LENGTH - 0.9, RIDGE_HEIGHT, RIDGE_Z),
		leanToPoint(RIDGE_HALF_LENGTH + 0.9, RIDGE_HEIGHT + 0.05, RIDGE_Z),
		0.42,
		model,
		WOOD
	).Name =
		"Ridge"

	local rng = Random.new(5)
	for i = 0, 4 do
		local x = -RIDGE_HALF_LENGTH + 0.4 + i * ((RIDGE_HALF_LENGTH * 2 - 0.8) / 4)
		crookedPole(
			leanToPoint(x + rng:NextNumber(-0.15, 0.15), RAFTER_FOOT.Y, RAFTER_FOOT.Z),
			leanToPoint(x, RAFTER_TOP.Y, RAFTER_TOP.Z),
			RAFTER_DIAMETER,
			model,
			STICK,
			rng:NextNumber(0, math.pi * 2)
		).Name =
			"Rafter"
	end
end

-- A worn cloth sheet laid over the slanted poles: sewn from strips, patched, and ragged along
-- its lower edge, which stops short of the ground.
function builders.LeanToCover(model: Model)
	local slope = (RAFTER_FOOT - RAFTER_TOP).Unit
	local slopeLength = (RAFTER_FOOT - RAFTER_TOP).Magnitude
	-- Lifted off the line of the poles so it rests on top of them.
	local lift = RAFTER_DIAMETER / 2 + 0.12

	-- A piece of cloth on the slope: `x` along the ridge, from `from` to `to` studs down it.
	local function sheet(name: string, x: number, width: number, from: number, to: number, props)
		local middle = RAFTER_TOP + slope * ((from + to) / 2) + Vector3.new(x, 0, 0)
		local part = makePart({
			Name = name,
			Size = Vector3.new(width, 0.12, to - from),
			CFrame = LEAN_TO
				* CFrame.lookAt(middle, middle + slope, Vector3.new(0, 1, 0))
				* CFrame.new(0, lift, 0),
			Material = Enum.Material.Fabric,
			Color = CLOTH,
		}, model)
		for key, value in props do
			(part :: any)[key] = value
		end
		return part
	end

	local rng = Random.new(3)
	local strips = 6
	local width = (RIDGE_HALF_LENGTH * 2 + 0.8) / strips
	for i = 1, strips do
		local x = (i - (strips + 1) / 2) * width
		local ragged = slopeLength - rng:NextNumber(0.7, 1.9)
		sheet("Cover", x, width + 0.04, 0.15, ragged, {
			Color = if i % 2 == 0 then CLOTH else CLOTH_WORN,
		})
	end

	-- Patches sewn over the worst of the holes.
	for _, patch in { { -2.6, 2.2 }, { 1.1, 4.6 }, { 3.2, 1.6 } } do
		sheet("Patch", patch[1], 1.1, patch[2], patch[2] + 0.9, {
			Color = CLOTH_PATCH,
			CanCollide = false,
		}).CFrame *= CFrame.new(
			0,
			0.03,
			0
		) * turn(rng:NextNumber(-12, 12))
	end
end

-- A sleeping mat on a bed of moss under the lean-to, with a rolled blanket for a pillow.
function builders.Bedroll(model: Model)
	local bed = LEAN_TO * CFrame.new(0, 0, 1.6)
	makePart({
		Name = "MossPadding",
		Size = Vector3.new(6.8, 0.15, 3.2),
		CFrame = bed * CFrame.new(0, 0.08, 0),
		Material = Enum.Material.Grass,
		Color = MOSS,
		CanCollide = false,
	}, model)
	makePart({
		Name = "Mat",
		Size = Vector3.new(6.2, 0.3, 2.5),
		CFrame = bed * CFrame.new(0, 0.3, 0),
		Material = Enum.Material.Fabric,
		Color = BLANKET,
	}, model)
	makePart({
		Name = "FoldedBlanket",
		Size = Vector3.new(2.2, 0.3, 2.3),
		CFrame = bed * CFrame.new(1.9, 0.6, 0) * turn(4),
		Material = Enum.Material.Fabric,
		Color = CLOTH_WORN,
	}, model)
	makePart({
		Name = "Pillow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 0.9, 0.9),
		CFrame = bed * CFrame.new(-2.5, 0.85, 0) * turn(90),
		Material = Enum.Material.Fabric,
		Color = CLOTH,
	}, model)
	for _, side in { -1, 1 } do
		lashing(bed * CFrame.new(-2.5, 0.85, side * 0.6) * turn(90), 0.96, model)
	end
end

-- Where each build stands, for measuring the ground under it.
local BUILD_SPOTS: { [string]: Vector3 } = {
	FirePit = Vector3.new(0, 0, 0),
	StumpStools = Vector3.new(7, 0, 0),
	CookingFrame = Vector3.new(0, 0, 0),
	Woodpile = Vector3.new(-13, 0, -9),
	LeanToFrame = Vector3.new(-14, 0, 0),
	LeanToCover = Vector3.new(-14, 0, 0),
	Bedroll = Vector3.new(-14, 0, 0),
}
local reportedGround: { [string]: boolean } = {}

-- The real height of the terrain's surface at a spot. Terrain is drawn a little above the
-- height it was filled to, so anything built at Y = 0 would be partly buried.
local function groundHeightAt(spot: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(spot + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else 0
end

-- Builds one camp structure, in place, by its Id from Config.Camp.Builds.
function CampModels.build(id: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = id
	local builder = builders[id]
	if builder then
		builder(model)
		-- The builders work from Y = 0; lift the result onto the real ground.
		local ground = groundHeightAt(BUILD_SPOTS[id] or Vector3.zero)
		if not reportedGround[id] then
			reportedGround[id] = true
			print(`[CampModels] Ground under {id} is at height {string.format("%.2f", ground)}.`)
		end
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.CFrame += Vector3.new(0, ground, 0)
			end
		end
	else
		warn("[CampModels] No model for build", id)
	end
	model.Parent = parent
	return model
end

-- Adds a glowing edge and tint in the shape of the model, visible in the dark.
local function addGlow(model: Model, fillTransparency: number, seeThroughObstacles: boolean)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = GHOST
	highlight.FillTransparency = fillTransparency
	highlight.OutlineColor = GHOST
	highlight.OutlineTransparency = 0
	highlight.DepthMode = if seeThroughObstacles
		then Enum.HighlightDepthMode.AlwaysOnTop
		else Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
end

-- Turns a built model into a glowing outline showing where the next build will stand.
function CampModels.makeGhost(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			if item.Transparency < 1 then
				item.Transparency = Config.Camp.GhostTransparency
			end
			item.Material = Enum.Material.Neon
			item.Color = GHOST
			item.CanCollide = false
			item.CanQuery = false
			item.CastShadow = false
		elseif item:IsA("Fire") or item:IsA("Light") then
			item:Destroy()
		end
	end
	-- Drawn through anything in the way, so the next build can always be found at camp.
	addGlow(model, 0.6, true)
end

local materialBuilders: { [string]: (model: Model, at: Vector3) -> () } = {}

-- A small bundle of crooked sticks.
function materialBuilders.Sticks(model: Model, at: Vector3)
	for i = 1, 3 do
		local side = Vector3.new(0, 0, (i - 2) * 0.35)
		crookedPole(
			at + side + Vector3.new(-1.4, 0.25, 0),
			at + side + Vector3.new(1.4, 0.25 + (i % 2) * 0.2, 0),
			0.25,
			model,
			DARK_WOOD,
			i * 2
		)
	end
end

-- A sharp grey stone.
function materialBuilders.Flint(model: Model, at: Vector3)
	rock("RockC", CFrame.new(at) * CFrame.Angles(0.3, 0.6, 0.2), 0.5, model, FLINT)
end

-- A bow saw: a rusted blade strung across a bent wooden frame.
function materialBuilders.Saw(model: Model, at: Vector3)
	makePart({
		Name = "Blade",
		Size = Vector3.new(2.6, 0.3, 0.06),
		Position = at + Vector3.new(0, 0.2, 0),
		Material = Enum.Material.CorrodedMetal,
		Color = RUST,
	}, model)
	for _, side in { -1, 1 } do
		pole(
			at + Vector3.new(side * 1.3, 0.1, 0),
			at + Vector3.new(side * 1.1, 1.1, 0),
			0.2,
			model,
			DARK_WOOD
		)
	end
	pole(at + Vector3.new(-1.15, 1.1, 0), at + Vector3.new(1.15, 1.1, 0), 0.2, model, DARK_WOOD)
end

-- A branch ending in a fork, like the ones that hold the spit over the fire.
function materialBuilders.ForkedBranch(model: Model, at: Vector3)
	local lying = CFrame.new(at + Vector3.new(-1.4, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(-80))
	forkedStick(lying, Vector3.one * 0.6, model, DARK_WOOD)
end

function materialBuilders.Rope(model: Model, at: Vector3)
	-- A coil: a flat disc of rope with a smaller one on top.
	for layer, diameter in { 1.8, 1.3 } do
		makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, diameter, diameter),
			CFrame = CFrame.new(at + Vector3.new(0, 0.15 + (layer - 1) * 0.3, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Fabric,
			Color = ROPE,
		}, model)
	end
end

-- A long straight-ish pole for the lean-to.
function materialBuilders.Pole(model: Model, at: Vector3)
	crookedPole(
		at + Vector3.new(-2.2, 0.3, 0),
		at + Vector3.new(2.2, 0.45, 0),
		0.3,
		model,
		DARK_WOOD
	)
end

function materialBuilders.Cloth(model: Model, at: Vector3)
	makePart({
		Size = Vector3.new(1.8, 0.35, 1.4),
		CFrame = CFrame.new(at + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0.4, 0),
		Material = Enum.Material.Fabric,
		Color = CLOTH,
	}, model)
end

function materialBuilders.Moss(model: Model, at: Vector3)
	for _, offset in
		{ Vector3.new(0, 0.3, 0), Vector3.new(0.7, 0.2, 0.4), Vector3.new(-0.5, 0.2, -0.5) }
	do
		makePart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			Position = at + offset,
			Material = Enum.Material.Grass,
			Color = MOSS,
		}, model)
	end
end

-- Builds a material floating above a point on the ground. The model itself is enlarged and
-- lit up in its own shape, so it can be recognised and found in the dark.
function CampModels.buildMaterial(materialType: string, at: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = materialType

	local builder = materialBuilders[materialType]
	if builder then
		builder(model, at)
	else
		warn("[CampModels] No model for material", materialType)
	end

	for _, item in model:GetChildren() do
		if item:IsA("BasePart") then
			item.CanCollide = false
			item.CanQuery = false
		end
	end

	-- Enlarge it, then lift it clear of the long grass, which would otherwise hide it.
	local floatAt = at + Vector3.new(0, Config.Camp.MaterialHoverHeight, 0)
	model.WorldPivot = CFrame.new(at)
	model:ScaleTo(Config.Camp.MaterialScale)
	model:PivotTo(CFrame.new(floatAt) * CFrame.Angles(math.rad(20), 0, math.rad(15)))

	addGlow(model, 0.35, false)

	-- An invisible lamp just above it, lighting the ground around.
	local lamp = makePart({
		Name = "Lamp",
		Size = Vector3.one,
		Position = floatAt,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, model)

	local light = Instance.new("PointLight")
	light.Color = GHOST
	light.Brightness = 2
	light.Range = Config.Camp.MaterialGlowRange
	light.Parent = lamp

	model.Parent = parent
	return model
end

return CampModels
