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
local IRON = Color3.fromRGB(48, 48, 54)
local STEW = Color3.fromRGB(112, 78, 44)
local LANTERN_GLOW = Color3.fromRGB(255, 190, 110)
local CRATE = Color3.fromRGB(150, 112, 72)
local FLANNEL = Color3.fromRGB(176, 40, 40)
local FLANNEL_DARK = Color3.fromRGB(104, 22, 26)
local SOCK = Color3.fromRGB(206, 204, 196)
local FISH = Color3.fromRGB(150, 160, 166)
local BARK = Color3.fromRGB(74, 54, 40)
local BARK_LIGHT = Color3.fromRGB(92, 68, 48)
local WATER = Color3.fromRGB(40, 62, 78)

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

-- `standing` says which other builds are there, by Id, for the few pieces that sit
-- differently depending on what is around them.
type Standing = { [string]: boolean }
-- `layout` is which size the clearing is (0 at the start; see Config.WorldGrowth).
local builders: { [string]: (model: Model, standing: Standing, layout: number) -> () } = {}

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

-- Stage 2: the tent camp. See CAMP_PROGRESSION.md.

-- The tent stands where the lean-to stood, its open end toward the fire.
-- Points are given in its own space: Z along the ridge (-Z is the front), Y up, X to the sides.
local TENT = LEAN_TO
local TENT_RIDGE_HEIGHT = 6.2
local TENT_HALF_LENGTH = 4
local TENT_HALF_WIDTH = 4.4

local function tentPoint(x: number, y: number, z: number): Vector3
	return TENT:PointToWorldSpace(Vector3.new(x, y, z))
end

-- A thin rope from one point to another (must not be exactly vertical).
local function rope(from: Vector3, to: Vector3, parent: Instance, diameter: number?): Part
	local part = pole(from, to, diameter or 0.09, parent, ROPE)
	part.Name = "Rope"
	part.Material = Enum.Material.Fabric
	part.CanCollide = false
	return part
end

-- A flat piece of cloth hanging in the plane of `at` (its X and Y), such as washing on a line.
local function hanging(
	name: string,
	at: CFrame,
	width: number,
	height: number,
	color: Color3,
	parent
)
	return makePart({
		Name = name,
		Size = Vector3.new(width, height, 0.12),
		CFrame = at,
		Material = Enum.Material.Fabric,
		Color = color,
		CanCollide = false,
	}, parent)
end

-- An iron pot hung by a chain from the spit, over the fire. (The meat is taken off the
-- cooking frame when this is built; see Strips in Config.)
function builders.HangingPot(model: Model)
	local centre = Vector3.new(0, SPIT_HEIGHT - 1.8, 0)

	pole(
		Vector3.new(0, SPIT_HEIGHT - 0.1, 0),
		centre + Vector3.new(0.02, 1.3, 0),
		0.14,
		model,
		IRON
	).Name =
		"PotChain"
	for _, side in { -1, 1 } do
		-- The bail: a rod from each side of the rim up to the chain.
		pole(
			centre + Vector3.new(0, 0.7, side * 0.8),
			centre + Vector3.new(0, 1.3, 0),
			0.1,
			model,
			IRON
		).Name =
			"PotHandle"
	end

	makePart({
		Name = "Pot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.9,
		Position = centre,
		Material = Enum.Material.Metal,
		Color = IRON,
	}, model)
	makePart({
		Name = "PotRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.22, 1.75, 1.75),
		CFrame = CFrame.new(centre + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = IRON,
	}, model)
	local stew = makePart({
		Name = "Stew",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, 1.5, 1.5),
		CFrame = CFrame.new(centre + Vector3.new(0, 0.82, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.SmoothPlastic,
		Color = STEW,
		CanCollide = false,
	}, model)

	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.EmissionDirection = Enum.NormalId.Right -- the stew's flat face looks up along its X
	steam.Rate = 5
	steam.Lifetime = NumberRange.new(1.6, 2.6)
	steam.Speed = NumberRange.new(1.2, 1.8)
	steam.SpreadAngle = Vector2.new(12, 12)
	steam.Size = NumberSequence.new(0.5, 1.6)
	steam.Transparency = NumberSequence.new(0.7, 1)
	steam.Color = ColorSequence.new(Color3.fromRGB(230, 230, 230))
	steam.Parent = stew
end

-- A post on the spawn side with a lantern hanging from an arm: a second light at camp.
function builders.LanternPost(model: Model)
	local base = Vector3.new(11, 0, 8)
	local top = base + Vector3.new(0.12, 7, 0)
	local armEnd = base + Vector3.new(-1.7, 6.9, -0.9) -- reaching in towards the fire
	crookedPole(base - Vector3.new(0, 0.4, 0), top, 0.5, model, WOOD).Name = "Post"
	crookedPole(top - Vector3.new(0, 0.5, 0), armEnd, 0.3, model, WOOD).Name = "Arm"
	crookedPole(base + Vector3.new(0.08, 5.1, 0), (top + armEnd) / 2, 0.22, model, WOOD).Name =
		"Brace"
	lashing(
		CFrame.new(top - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		0.7,
		model
	)

	local lantern = armEnd - Vector3.new(0, 1.35, 0)
	pole(armEnd, lantern + Vector3.new(0.02, 0.6, 0), 0.08, model, IRON).Name = "LanternChain"
	for _, cap in { 0.52, -0.52 } do
		makePart({
			Name = "LanternCap",
			Size = Vector3.new(0.86, 0.14, 0.86),
			Position = lantern + Vector3.new(0, cap, 0),
			Material = Enum.Material.Metal,
			Color = IRON,
			CanCollide = false,
		}, model)
	end
	local glass = makePart({
		Name = "LanternGlass",
		Size = Vector3.new(0.66, 0.9, 0.66),
		Position = lantern,
		Material = Enum.Material.Neon,
		Color = LANTERN_GLOW,
		CanCollide = false,
	}, model)

	local light = Instance.new("PointLight")
	light.Color = Config.Lighting.WarmLight
	light.Brightness = 1.6
	light.Range = 30
	light.Shadows = false
	light.Parent = glass
end

-- Two uprights and a ridge pole on the lean-to's spot. (The lean-to is taken down when
-- this is built; see Replaces in Config.)
function builders.TentPoles(model: Model)
	for _, z in { -TENT_HALF_LENGTH, TENT_HALF_LENGTH } do
		crookedPole(tentPoint(0.06, -0.3, z), tentPoint(0, TENT_RIDGE_HEIGHT, z), 0.42, model, WOOD).Name =
			"Upright"
		lashing(TENT * CFrame.new(0, TENT_RIDGE_HEIGHT, z) * turn(90), 0.75, model)
	end
	crookedPole(
		tentPoint(0, TENT_RIDGE_HEIGHT + 0.05, -TENT_HALF_LENGTH - 0.6),
		tentPoint(0, TENT_RIDGE_HEIGHT, TENT_HALF_LENGTH + 0.6),
		0.4,
		model,
		WOOD
	).Name =
		"Ridge"
end

-- Weathered canvas over the ridge, sloping to the ground on both sides, closed at the back
-- and open at the front. Sewn from strips, with a couple of patches.
function builders.TentCanvas(model: Model)
	local top = Vector3.new(0, TENT_RIDGE_HEIGHT + 0.25, 0)
	local strips = 3
	local stripLength = (TENT_HALF_LENGTH * 2 + 0.4) / strips

	for _, side in { -1, 1 } do
		local foot = Vector3.new(side * TENT_HALF_WIDTH, 0.12, 0)
		local slope = (foot - top).Unit
		local slopeLength = (foot - top).Magnitude
		local along = Vector3.new(0, 0, 1)
		-- A panel lying on the slope: its X runs down the slope, its Z along the ridge.
		local function panel(
			name: string,
			z: number,
			length: number,
			from: number,
			to: number,
			color
		)
			local middle = top + slope * ((from + to) / 2) + along * z
			local part = makePart({
				Name = name,
				Size = Vector3.new(to - from, 0.12, length),
				CFrame = TENT * CFrame.fromMatrix(middle, slope, along:Cross(slope), along),
				Material = Enum.Material.Fabric,
				Color = color,
			}, model)
			return part
		end

		for i = 1, strips do
			local z = (i - (strips + 1) / 2) * stripLength
			panel(
				"Canvas",
				z,
				stripLength + 0.04,
				0,
				slopeLength,
				if (i + side) % 2 == 0 then CLOTH else CLOTH_WORN
			)
		end
		local patch =
			panel("Patch", side * 1.4, 1.2, slopeLength * 0.45, slopeLength * 0.45 + 1, CLOTH_PATCH)
		patch.CFrame *= CFrame.new(0, side * 0.04, 0)
		patch.CanCollide = false

		-- Half of the back wall: a triangle from the middle out to this side.
		local wall = Instance.new("WedgePart")
		wall.Name = "BackWall"
		wall.Anchored = true
		wall.Size = Vector3.new(0.12, TENT_RIDGE_HEIGHT, TENT_HALF_WIDTH)
		wall.CFrame = TENT
			* CFrame.fromMatrix(
				Vector3.new(
					side * TENT_HALF_WIDTH / 2,
					TENT_RIDGE_HEIGHT / 2 + 0.1,
					TENT_HALF_LENGTH
				),
				Vector3.new(0, 0, side),
				Vector3.new(0, 1, 0),
				Vector3.new(-side, 0, 0)
			)
		wall.Material = Enum.Material.Fabric
		wall.Color = CLOTH_WORN
		wall.TopSurface = Enum.SurfaceType.Smooth
		wall.BottomSurface = Enum.SurfaceType.Smooth
		wall.Parent = model
	end
end

-- Wooden pegs along both sides and off each end of the ridge, with ropes pulling the tent taut.
function builders.TentPegs(model: Model)
	local function peg(x: number, z: number, leanX: number, leanZ: number): Vector3
		local foot = tentPoint(x, -0.25, z)
		local head = tentPoint(x + leanX, 0.75, z + leanZ)
		pole(foot, head, 0.2, model, PALE_WOOD).Name = "Peg"
		return tentPoint(x + leanX * 0.6, 0.45, z + leanZ * 0.6)
	end

	for _, side in { -1, 1 } do
		-- Along the sides: from a third of the way up the canvas out to a peg.
		for _, z in { -3, 0, 3 } do
			local tie = peg(side * (TENT_HALF_WIDTH + 1.5), z, side * 0.35, 0)
			rope(tentPoint(side * TENT_HALF_WIDTH * 0.72, 1.85, z), tie, model)
		end
		-- Off each end of the ridge, splayed to either side so the front stays open.
		for _, direction in { -1, 1 } do
			local z = direction * (TENT_HALF_LENGTH + 2.6)
			local tie = peg(side * 3, z, 0, direction * 0.35)
			rope(tentPoint(0, TENT_RIDGE_HEIGHT, direction * (TENT_HALF_LENGTH + 0.5)), tie, model)
		end
	end
end

-- A low canvas bed on a pole frame, inside the tent. (The bedroll goes when this is built.)
function builders.Cot(model: Model, standing: Standing)
	-- In the tent it sits to one side, leaving room to walk in. Once the hut's walls are up
	-- there is more room, and it goes against the side wall, clear of the doorway.
	local x = if standing.LogWalls then -2.9 else -1.5
	local height = 1.25
	local halfLength = 2.9
	local halfWidth = 1.1

	for _, side in { -1, 1 } do
		crookedPole(
			tentPoint(x + side * halfWidth, height, -halfLength - 0.3),
			tentPoint(x + side * halfWidth, height + 0.03, halfLength + 0.3),
			0.26,
			model,
			WOOD
		).Name =
			"CotRail"
	end
	-- Crossed legs at each end.
	for _, z in { -halfLength + 0.5, halfLength - 0.5 } do
		for _, side in { -1, 1 } do
			pole(
				tentPoint(x + side * halfWidth, height, z),
				tentPoint(x - side * halfWidth * 0.8, -0.1, z),
				0.2,
				model,
				WOOD
			).Name =
				"CotLeg"
		end
	end

	makePart({
		Name = "CotCanvas",
		Size = Vector3.new(halfWidth * 2, 0.14, halfLength * 2),
		CFrame = TENT * CFrame.new(x, height + 0.08, 0),
		Material = Enum.Material.Fabric,
		Color = CLOTH,
	}, model)
	makePart({
		Name = "Blanket",
		Size = Vector3.new(halfWidth * 2 + 0.2, 0.22, 3),
		CFrame = TENT * CFrame.new(x, height + 0.24, -1.2),
		Material = Enum.Material.Fabric,
		Color = BLANKET,
		CanCollide = false,
	}, model)
	makePart({
		Name = "Pillow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.8, 0.7, 0.7),
		CFrame = TENT * CFrame.new(x, height + 0.5, halfLength - 0.7),
		Material = Enum.Material.Fabric,
		Color = CLOTH_WORN,
		CanCollide = false,
	}, model)
end

-- A plank crate with corner battens, a lid left ajar and a rope handle at each end.
function builders.SupplyCrate(model: Model)
	local size = Vector3.new(3.2, 2.1, 2.3)
	local crate = CFrame.new(-15.5, 0, 8.3) * turn(8)

	makePart({
		Name = "Crate",
		Size = size,
		CFrame = crate * CFrame.new(0, size.Y / 2, 0),
		Material = Enum.Material.WoodPlanks,
		Color = CRATE,
	}, model)
	for _, sideX in { -1, 1 } do
		for _, sideZ in { -1, 1 } do
			makePart({
				Name = "Batten",
				Size = Vector3.new(0.32, size.Y + 0.06, 0.32),
				CFrame = crate
					* CFrame.new(sideX * (size.X / 2 - 0.1), size.Y / 2, sideZ * (size.Z / 2 - 0.1)),
				Color = DARK_WOOD,
			}, model)
		end
		-- A loop of rope on each end to carry it by.
		lashing(crate * CFrame.new(sideX * (size.X / 2 + 0.08), size.Y * 0.62, 0), 0.9, model)
	end
	makePart({
		Name = "Lid",
		Size = Vector3.new(size.X + 0.3, 0.2, size.Z + 0.3),
		CFrame = crate
			* CFrame.new(0.15, size.Y + 0.16, 0.1)
			* turn(7)
			* CFrame.Angles(0, 0, math.rad(4)),
		Material = Enum.Material.WoodPlanks,
		Color = CRATE,
	}, model)
end

-- Two forked sticks and a pole, with a row of fish hung up to dry.
function builders.DryingRack(model: Model)
	local centre = Vector3.new(8.5, 0, -12.5)
	local half = 3.3
	for _, side in { -1, 1 } do
		local origin = CFrame.new(centre + Vector3.new(side * half, -FORK_BURIED, 0))
			* turn(90 + 8 * side)
		forkedStick(origin, Vector3.one, model)
	end
	crookedPole(
		centre + Vector3.new(-half - 0.7, SPIT_HEIGHT, 0),
		centre + Vector3.new(half + 0.7, SPIT_HEIGHT + 0.04, 0),
		0.3,
		model,
		STICK
	).Name =
		"RackPole"

	for i = 1, 5 do
		local x = (i - 3) * 1.15
		local hung = centre + Vector3.new(x, SPIT_HEIGHT - 0.15, 0)
		local drop = 0.55 + (i % 2) * 0.18
		rope(hung, hung + Vector3.new(0.02, -drop, 0), model, 0.06)

		local body = makePart({
			Name = "Fish",
			Size = Vector3.new(0.5, 1.5, 0.22),
			CFrame = CFrame.new(hung + Vector3.new(0, -drop - 0.7, 0)) * turn(i * 37),
			Material = Enum.Material.SmoothPlastic,
			Color = FISH,
			CanCollide = false,
		}, model)
		local shape = Instance.new("SpecialMesh")
		shape.MeshType = Enum.MeshType.Sphere
		shape.Parent = body

		local tail = makePart({
			Name = "FishTail",
			Size = Vector3.new(0.5, 0.36, 0.1),
			CFrame = body.CFrame * CFrame.new(0, -0.85, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = FISH,
			CanCollide = false,
		}, model)
		local tailShape = Instance.new("SpecialMesh")
		tailShape.MeshType = Enum.MeshType.Sphere
		tailShape.Parent = tail
	end
end

-- A sagging rope between two poles, with a flannel shirt, a pair of socks and a blanket.
function builders.Clothesline(model: Model)
	local centre = Vector3.new(3.5, 0, 16)
	local half = 4.6
	local high, low = 5.8, 5.3

	for _, side in { -1, 1 } do
		local foot = centre + Vector3.new(side * half, -0.4, 0)
		crookedPole(foot, foot + Vector3.new(side * 0.2, high + 0.8, 0), 0.4, model, WOOD).Name =
			"LinePost"
	end
	local points = {
		centre + Vector3.new(-half + 0.05, high, 0),
		centre + Vector3.new(-half / 3, low, 0),
		centre + Vector3.new(half / 3, low, 0),
		centre + Vector3.new(half - 0.05, high, 0),
	}
	for i = 1, #points - 1 do
		rope(points[i], points[i + 1], model, 0.1)
	end

	-- Everything hangs just below the low part of the line.
	local function at(x: number, drop: number, lean: number): CFrame
		return CFrame.new(centre + Vector3.new(x, low - drop, 0))
			* CFrame.Angles(0, 0, math.rad(lean))
	end

	-- A red flannel shirt: body, two sleeves hanging out, and a couple of darker stripes.
	hanging("Shirt", at(-2.3, 1.05, 0), 1.9, 2.1, FLANNEL, model)
	for _, side in { -1, 1 } do
		hanging("Sleeve", at(-2.3 + side * 1.25, 0.75, side * 28), 0.7, 1.6, FLANNEL, model)
	end
	for _, stripe in { -0.45, 0.45 } do
		hanging(
			"Stripe",
			at(-2.3 + stripe, 1.05, 0) * CFrame.new(0, 0, 0.02),
			0.14,
			2.1,
			FLANNEL_DARK,
			model
		)
		hanging(
			"Stripe",
			at(-2.3, 1.05 + stripe, 0) * CFrame.new(0, 0, 0.02),
			1.9,
			0.14,
			FLANNEL_DARK,
			model
		)
	end

	hanging("Sock", at(-0.1, 0.6, 4), 0.42, 1.2, SOCK, model)
	hanging("Sock", at(0.5, 0.62, -5), 0.42, 1.2, SOCK, model)

	-- A blanket folded over the line: one face each side of it.
	for _, face in { -1, 1 } do
		hanging(
			"Blanket",
			at(2.5, 0.85, 0) * CFrame.new(0, 0, face * 0.1),
			2.6,
			1.7,
			BLANKET,
			model
		)
	end
end

-- Stage 3: the hut. See CAMP_PROGRESSION.md.

-- The hut stands where the tent stood, its door toward the fire. The tent and the hut share
-- one space, so the cot ends up inside. X runs across the front, -Z is the front.
local HUT = TENT
local HUT_HALF_WIDTH = 5
local HUT_HALF_DEPTH = 4
local HUT_FLOOR = 0.3 -- top of the stone floor
local LOG_DIAMETER = 1.15
local LOG_COURSES = 6
local COURSE_STEP = 1.05
local DOOR_HALF_WIDTH = 1.45
local WALL_TOP = HUT_FLOOR + 0.6 + LOG_COURSES * COURSE_STEP
local ROOF_PEAK = WALL_TOP + 3

-- How far the hut moves back from the fire when the clearing grows (see GROWN_SHIFT).
local HUT_MOVED_BACK = 8

local function hutPoint(x: number, y: number, z: number): Vector3
	return HUT:PointToWorldSpace(Vector3.new(x, y, z))
end

-- A round log from one point to another (must not be exactly vertical), with a sawn face
-- at each end.
local function beam(from: Vector3, to: Vector3, diameter: number, parent: Instance, bark: Color3?)
	local length = (to - from).Magnitude
	local along = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
	local thickness = diameter / KIT.Log.Size.Y
	local scale = Vector3.new(length / KIT.Log.Size.X, thickness, thickness)
	local part = kitPart("Log", along, scale, { Color = bark or WOOD }, parent)
		or pole(from, to, diameter, parent, bark or WOOD)
	part.Name = "WallLog"
	for _, side in { -1, 1 } do
		slice(along * CFrame.new(side * length / 2, 0, 0), diameter * 0.8, PALE_WOOD, parent).Name =
			"LogEnd"
	end
end

-- A flat board with its middle at `at`.
local function board(name: string, at: CFrame, size: Vector3, color: Color3, parent: Instance): Part
	return makePart({
		Name = name,
		Size = size,
		CFrame = at,
		Material = Enum.Material.WoodPlanks,
		Color = color,
	}, parent)
end

-- A plank table with a bench down each side, between the fire and the clothesline.
function builders.PicnicTable(model: Model)
	local table_ = CFrame.new(1.5, 0, 9.5)
	board("TableTop", table_ * CFrame.new(0, 2.9, 0), Vector3.new(6.4, 0.3, 2.6), CRATE, model)
	for _, side in { -1, 1 } do
		board(
			"Bench",
			table_ * CFrame.new(0, 1.7, side * 2.25),
			Vector3.new(6.4, 0.25, 1),
			CRATE,
			model
		)
	end
	-- A pair of splayed legs at each end, joined by a rail that also carries the benches.
	for _, endSide in { -1, 1 } do
		local x = endSide * 2.4
		for _, side in { -1, 1 } do
			pole(
				table_:PointToWorldSpace(Vector3.new(x, 2.8, side * 0.7)),
				table_:PointToWorldSpace(Vector3.new(x, -0.1, side * 2.3)),
				0.34,
				model,
				DARK_WOOD
			).Name =
				"TableLeg"
		end
		pole(
			table_:PointToWorldSpace(Vector3.new(x, 1.55, -2.7)),
			table_:PointToWorldSpace(Vector3.new(x, 1.56, 2.7)),
			0.3,
			model,
			DARK_WOOD
		).Name =
			"TableRail"
	end
end

-- A wide stump with an axe stuck in it and split logs lying round it, by the woodpile.
function builders.ChoppingBlock(model: Model)
	local block = CFrame.new(-6.5, 0, -11.5)
	stump(block, Vector3.new(1.25, 0.7, 1.25), model)
	local top = KIT.Stump.Size.Y * 0.7

	-- The axe: its head buried in the block, the handle leaning out.
	local headAt = block:PointToWorldSpace(Vector3.new(0.2, top + 0.25, 0))
	local handleEnd = block:PointToWorldSpace(Vector3.new(-1.5, top + 2.5, 0.4))
	pole(headAt, handleEnd, 0.22, model, PALE_WOOD).Name = "AxeHandle"
	makePart({
		Name = "AxeHead",
		Size = Vector3.new(0.9, 0.7, 0.22),
		CFrame = CFrame.lookAt(headAt, handleEnd) * CFrame.new(0, -0.1, 0.1),
		Material = Enum.Material.Metal,
		Color = FLINT,
	}, model)

	-- Two short split logs, laid together on one side.
	for _, place in { { 2.3, 0.5, 12 }, { 2.5, -0.5, 24 } } do
		local origin = block * CFrame.new(place[1], 0.24, place[2]) * turn(place[3])
		log(origin, 0.32, WOOD, PALE_WOOD, model)
	end
end

-- A sawhorse with a log across it, and a stack of sawn planks a few steps away.
function builders.Sawhorse(model: Model)
	local horse = CFrame.new(3.8, 0, -16.6) * turn(6)
	local height = 2.5
	for _, endSide in { -1, 1 } do
		for _, side in { -1, 1 } do
			pole(
				horse:PointToWorldSpace(Vector3.new(endSide * 1.5, height + 0.5, -side * 0.35)),
				horse:PointToWorldSpace(Vector3.new(endSide * 1.5, -0.1, side * 1.3)),
				0.3,
				model,
				WOOD
			).Name =
				"SawhorseLeg"
		end
	end
	pole(
		horse:PointToWorldSpace(Vector3.new(-2.1, height, 0)),
		horse:PointToWorldSpace(Vector3.new(2.1, height + 0.01, 0)),
		0.36,
		model,
		WOOD
	).Name =
		"SawhorseBeam"

	log(horse * CFrame.new(0.3, height + 0.75, 0), 0.75, WOOD, PALE_WOOD, model)
	-- Planks stacked on two bearers, none quite square to the next.
	local stack = CFrame.new(-2.4, 0, -16.8) * turn(4)
	for _, x in { -1.6, 1.6 } do
		board("Bearer", stack * CFrame.new(x, 0.2, 0), Vector3.new(0.4, 0.4, 2.2), DARK_WOOD, model)
	end
	local rng = Random.new(21)
	for i = 1, 5 do
		local at = stack
			* CFrame.new(
				rng:NextNumber(-0.2, 0.2),
				0.4 + i * 0.2 - 0.1,
				rng:NextNumber(-0.25, 0.25)
			)
			* turn(rng:NextNumber(-4, 4))
		board("Plank", at, Vector3.new(5.2, 0.18, 0.8), PALE_WOOD, model)
	end
end

-- A floor of packed stone edged with rough rocks, where the tent stood. (The tent is taken
-- down when this is built; see Replaces in Config.)
function builders.StoneFooting(model: Model)
	makePart({
		Name = "Floor",
		Size = Vector3.new(HUT_HALF_WIDTH * 2 + 0.6, HUT_FLOOR + 0.3, HUT_HALF_DEPTH * 2 + 0.6),
		CFrame = HUT * CFrame.new(0, HUT_FLOOR / 2 - 0.15, 0),
		Material = Enum.Material.Slate,
		Color = STONE:Lerp(Color3.new(0, 0, 0), 0.25),
	}, model)

	local rng = Random.new(13)
	local rocks = { "RockA", "RockB", "RockC" }
	local count = 0
	local function edge(fromX: number, fromZ: number, toX: number, toZ: number)
		local length = math.max(math.abs(toX - fromX), math.abs(toZ - fromZ))
		local steps = math.floor(length / 1.5)
		for i = 0, steps - 1 do
			local t = (i + 0.5) / steps
			local x, z = fromX + (toX - fromX) * t, fromZ + (toZ - fromZ) * t
			count += 1
			-- Leave the doorway clear: nothing to step over on the way in.
			if z < 0 and math.abs(z) > HUT_HALF_DEPTH and math.abs(x) < DOOR_HALF_WIDTH + 0.8 then
				continue
			end
			rock(
				rocks[count % 3 + 1],
				HUT * CFrame.new(x, -0.1, z) * turn(rng:NextNumber(0, 360)),
				rng:NextNumber(0.62, 0.8),
				model
			)
		end
	end
	local w, d = HUT_HALF_WIDTH + 0.4, HUT_HALF_DEPTH + 0.4
	edge(-w, -d, w, -d)
	edge(w, -d, w, d)
	edge(w, d, -w, d)
	edge(-w, d, -w, -d)
end

-- Logs stacked six high on the footing, crossing at the corners, with a doorway in the
-- front wall.
function builders.LogWalls(model: Model)
	local w, d = HUT_HALF_WIDTH, HUT_HALF_DEPTH
	local over = 0.7 -- how far each log runs past the corner
	for course = 0, LOG_COURSES - 1 do
		local y = HUT_FLOOR + 0.6 + course * COURSE_STEP
		-- Side walls on the course, front and back half a log higher, so they lock together.
		for _, side in { -1, 1 } do
			beam(
				hutPoint(side * w, y, -d - over),
				hutPoint(side * w, y + 0.01, d + over),
				LOG_DIAMETER,
				model
			)
		end
		local crossY = y + COURSE_STEP / 2
		beam(
			hutPoint(-w - over, crossY, d),
			hutPoint(w + over, crossY + 0.01, d),
			LOG_DIAMETER,
			model
		)
		if course == LOG_COURSES - 1 then
			-- The lintel: one log right across, over the doorway.
			beam(
				hutPoint(-w - over, crossY, -d),
				hutPoint(w + over, crossY + 0.01, -d),
				LOG_DIAMETER,
				model
			)
		else
			for _, side in { -1, 1 } do
				beam(
					hutPoint(side * (w + over), crossY, -d),
					hutPoint(side * DOOR_HALF_WIDTH, crossY + 0.01, -d),
					LOG_DIAMETER,
					model
				)
			end
		end
	end
	-- An upright each side of the doorway, to tidy the cut ends.
	for _, side in { -1, 1 } do
		board(
			"DoorPost",
			HUT * CFrame.new(side * (DOOR_HALF_WIDTH + 0.05), (HUT_FLOOR + WALL_TOP) / 2, -d),
			Vector3.new(0.35, WALL_TOP - HUT_FLOOR, LOG_DIAMETER + 0.1),
			DARK_WOOD,
			model
		)
	end
end

-- Two slopes of overlapping bark sheets meeting at a ridge that runs front to back, with a
-- boarded triangle closing each end.
function builders.BarkRoof(model: Model)
	local top = Vector3.new(0, ROOF_PEAK, 0)
	local eaveX = HUT_HALF_WIDTH + 1.3
	local halfLength = HUT_HALF_DEPTH + 1.4
	local sheets = 4
	local sheetLength = halfLength * 2 / sheets
	local along = Vector3.new(0, 0, 1)
	local rng = Random.new(17)

	for _, side in { -1, 1 } do
		local foot = Vector3.new(side * eaveX, WALL_TOP - 0.9, 0)
		local slope = (foot - top).Unit
		local slopeLength = (foot - top).Magnitude
		local out = along:Cross(slope) * side -- pointing up and away from the roof
		for i = 1, sheets do
			local z = (i - (sheets + 1) / 2) * sheetLength
			local run = slopeLength + rng:NextNumber(-0.1, 0.5)
			local middle = top + slope * (run / 2) + along * z + out * ((i % 2) * 0.12)
			makePart({
				Name = "BarkSheet",
				Size = Vector3.new(run, 0.28, sheetLength + 0.25),
				CFrame = HUT * CFrame.fromMatrix(middle, slope, along:Cross(slope), along),
				Color = if (i + side) % 2 == 0 then BARK else BARK_LIGHT,
			}, model)
		end

		-- Half of each end's triangle, from the middle out to this side.
		for _, z in { -HUT_HALF_DEPTH, HUT_HALF_DEPTH } do
			local gable = Instance.new("WedgePart")
			gable.Name = "Gable"
			gable.Anchored = true
			gable.Size = Vector3.new(0.4, ROOF_PEAK - WALL_TOP + 0.3, HUT_HALF_WIDTH + 0.3)
			gable.CFrame = HUT
				* CFrame.fromMatrix(
					Vector3.new(
						side * (HUT_HALF_WIDTH + 0.3) / 2,
						(ROOF_PEAK + WALL_TOP) / 2 - 0.25,
						z
					),
					Vector3.new(0, 0, side),
					Vector3.new(0, 1, 0),
					Vector3.new(-side, 0, 0)
				)
			gable.Material = Enum.Material.WoodPlanks
			gable.Color = WOOD
			gable.TopSurface = Enum.SurfaceType.Smooth
			gable.BottomSurface = Enum.SurfaceType.Smooth
			gable.Parent = model
		end
	end

	crookedPole(
		hutPoint(0, ROOF_PEAK + 0.1, -halfLength - 0.3),
		hutPoint(0, ROOF_PEAK + 0.14, halfLength + 0.3),
		0.45,
		model,
		DARK_WOOD
	).Name =
		"RoofRidge"
end

-- A plank door on two iron hinges, standing open.
function builders.Door(model: Model)
	local height = WALL_TOP - HUT_FLOOR - 1.2
	local width = DOOR_HALF_WIDTH * 2 - 0.2
	-- Hinged on one side of the doorway and swung out towards the fire.
	local hinge = HUT
		* CFrame.new(DOOR_HALF_WIDTH - 0.1, HUT_FLOOR + height / 2 + 0.1, -HUT_HALF_DEPTH - 0.7)
		* turn(72)
	local door = hinge * CFrame.new(width / 2, 0, 0)

	board("Door", door, Vector3.new(width, height, 0.22), CRATE, model)
	for _, y in { -height * 0.3, height * 0.3 } do
		board(
			"DoorBrace",
			door * CFrame.new(0, y, 0.14),
			Vector3.new(width - 0.1, 0.4, 0.1),
			DARK_WOOD,
			model
		).CanCollide =
			false
		makePart({
			Name = "Hinge",
			Size = Vector3.new(0.8, 0.22, 0.34),
			CFrame = hinge * CFrame.new(0.3, y, 0),
			Material = Enum.Material.Metal,
			Color = IRON,
			CanCollide = false,
		}, model)
	end
	makePart({
		Name = "DoorHandle",
		Size = Vector3.new(0.2, 0.7, 0.3),
		CFrame = door * CFrame.new(width / 2 - 0.35, 0, 0.2),
		Material = Enum.Material.Metal,
		Color = IRON,
		CanCollide = false,
	}, model)
end

-- A work bench against the inside of the hut's side wall, with tools hung on a board above.
function builders.Workbench(model: Model)
	local inner = HUT_HALF_WIDTH - LOG_DIAMETER / 2 -- the inside face of the side wall
	local bench = HUT * CFrame.new(inner - 1.0, HUT_FLOOR, 0)
	local length = 5

	board("BenchTop", bench * CFrame.new(0, 2.8, 0), Vector3.new(1.8, 0.28, length), CRATE, model)
	board(
		"BenchShelf",
		bench * CFrame.new(0, 1, 0),
		Vector3.new(1.5, 0.18, length - 0.5),
		CRATE,
		model
	)
	for _, x in { -0.7, 0.7 } do
		for _, z in { -length / 2 + 0.3, length / 2 - 0.3 } do
			board(
				"BenchLeg",
				bench * CFrame.new(x, 1.4, z),
				Vector3.new(0.3, 2.8, 0.3),
				DARK_WOOD,
				model
			)
		end
	end
	-- Work in progress on the bench.
	board(
		"Offcut",
		bench * CFrame.new(-0.1, 3.03, 1.1) * turn(12),
		Vector3.new(0.7, 0.18, 2.2),
		PALE_WOOD,
		model
	)
	board(
		"Plane",
		bench * CFrame.new(0.2, 3.1, -1.2) * turn(-20),
		Vector3.new(0.45, 0.35, 1.1),
		DARK_WOOD,
		model
	)

	-- The tool board, flat against the wall, and what hangs on it.
	local rack = HUT * CFrame.new(inner - 0.12, HUT_FLOOR + 4.6, 0)
	board("ToolBoard", rack, Vector3.new(0.16, 1.9, length - 0.4), DARK_WOOD, model)
	local function tool(z: number, handleLength: number, headSize: Vector3, headColor: Color3)
		-- Hung head up: a handle, and a head across the top of it.
		makePart({
			Name = "ToolHandle",
			Size = Vector3.new(0.16, handleLength, 0.16),
			CFrame = rack * CFrame.new(-0.16, 0.3 - handleLength / 2, z),
			Color = PALE_WOOD,
			CanCollide = false,
		}, model)
		makePart({
			Name = "ToolHead",
			Size = headSize,
			CFrame = rack * CFrame.new(-0.16, 0.4, z),
			Material = Enum.Material.Metal,
			Color = headColor,
			CanCollide = false,
		}, model)
	end
	tool(-1.6, 1.3, Vector3.new(0.3, 0.34, 0.8), IRON) -- hammer
	tool(-0.5, 1.5, Vector3.new(0.14, 0.6, 0.9), FLINT) -- hatchet
	tool(0.6, 1.0, Vector3.new(0.14, 0.3, 0.3), IRON) -- chisel
	makePart({
		Name = "HandSaw",
		Size = Vector3.new(0.06, 0.7, 1.5),
		CFrame = rack * CFrame.new(-0.14, -0.1, 1.6) * CFrame.Angles(math.rad(8), 0, 0),
		Material = Enum.Material.Metal,
		Color = RUST,
		CanCollide = false,
	}, model)
end

-- A barrel at the hut's front corner, hooped with iron and full of rainwater.
function builders.RainBarrel(model: Model)
	local at = HUT * CFrame.new(HUT_HALF_WIDTH + 1.9, 0, -HUT_HALF_DEPTH - 0.4)
	local height, diameter = 3.1, 2.5
	local upright = CFrame.Angles(0, 0, math.rad(90))
	makePart({
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = at * CFrame.new(0, height / 2, 0) * upright,
		Material = Enum.Material.WoodPlanks,
		Color = CRATE,
	}, model)
	for _, y in { 0.55, height / 2, height - 0.55 } do
		makePart({
			Name = "Hoop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, diameter + 0.12, diameter + 0.12),
			CFrame = at * CFrame.new(0, y, 0) * upright,
			Material = Enum.Material.Metal,
			Color = IRON,
			CanCollide = false,
		}, model)
	end
	makePart({
		Name = "Water",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, diameter - 0.3, diameter - 0.3),
		CFrame = at * CFrame.new(0, height + 0.02, 0) * upright,
		Material = Enum.Material.Glass,
		Color = WATER,
		CanCollide = false,
	}, model)
end

-- Flat stones set in the dirt from the fire to the hut's door.
function builders.StonePath(model: Model, _standing: Standing, layout: number)
	local rng = Random.new(29)
	-- The hut's own Z axis runs through the fire, so the path is a line of Z values: from
	-- just clear of the fire's ring of rocks to just outside the door.
	local start = HUT:PointToObjectSpace(Vector3.new(-3.9, 0, 0)).Z
	local to = -HUT_HALF_DEPTH - 1.4
	local steps = 6
	if layout > 0 then
		-- The hut has moved back from the fire (see GROWN_SHIFT), so the path is longer.
		-- It is laid out from the hut and then moved with it.
		start -= HUT_MOVED_BACK
		steps = 11
	end
	for i = 0, steps - 1 do
		local z = start + (to - start) * (i / (steps - 1))
		local diameter = rng:NextNumber(1.7, 2.3)
		makePart({
			Name = "PathStone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, diameter, diameter * rng:NextNumber(0.75, 0.95)),
			CFrame = HUT * CFrame.new(rng:NextNumber(-0.45, 0.45), 0, z) * turn(
				rng:NextNumber(0, 360)
			) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Slate,
			Color = STONE,
			CanCollide = false,
		}, model)
	end
end

-- Stage 4: the cabin. See CAMP_PROGRESSION.md.

-- The cabin stands on the ground the clearing gained (see Config.WorldGrowth), behind the
-- fire and to one side of the hut, facing the fire. Points are given in its own space:
-- X across the front, Y up, -Z toward the fire. The chimney is on the +X side.
local CABIN_CENTRE = Vector3.new(-8.55, 0, 23.49)
local CABIN = CFrame.lookAt(CABIN_CENTRE, Vector3.zero)
local CABIN_HALF_WIDTH = 7.5
local CABIN_HALF_DEPTH = 5.5
local CABIN_FLOOR = 0.8 -- top of the stone foundation, and of the porch
local CABIN_LOG = 1.2 -- how thick a wall log is
local CABIN_COURSES = 7
local CABIN_STEP = 1.1 -- from one log up to the next
local CABIN_WALL_TOP = CABIN_FLOOR + 0.6 + CABIN_COURSES * CABIN_STEP
local CABIN_PEAK = CABIN_WALL_TOP + 4.2
local CABIN_EAVE = CABIN_HALF_DEPTH + 1.3 -- how far out the roof's lower edge is
local CABIN_EAVE_HEIGHT = CABIN_WALL_TOP - 0.75
local CABIN_ROOF_HALF_LENGTH = CABIN_HALF_WIDTH + 1.5
local CABIN_DOOR_HALF = 1.6
local CABIN_DOOR_TOP = CABIN_FLOOR + 6.1
local PORCH_DEPTH = 4
local PORCH_FRONT = -CABIN_HALF_DEPTH - 0.55 - PORCH_DEPTH -- the porch's front edge
local PORCH_POST_Z = PORCH_FRONT + 0.35

local DARK_LOG = Color3.fromRGB(58, 42, 32)
local CHINKING = Color3.fromRGB(206, 196, 172)
-- Old dark shingles with moss grown into them. Kept dark: firelight brightens them a lot.
local SHINGLES = {
	Color3.fromRGB(40, 50, 40),
	Color3.fromRGB(48, 56, 42),
	Color3.fromRGB(36, 42, 38),
}
local CHIMNEY_STONE = Color3.fromRGB(74, 72, 70)
local CHIMNEY_STONE_DARK = Color3.fromRGB(56, 54, 54)
local SHUTTER_RED = Color3.fromRGB(164, 42, 38)
local WINDOW_GLOW = Color3.fromRGB(255, 208, 140)
local CLAY = Color3.fromRGB(168, 98, 70)
local SOIL = Color3.fromRGB(54, 40, 32)
local QUILT = {
	Color3.fromRGB(164, 42, 38),
	Color3.fromRGB(224, 210, 178),
	Color3.fromRGB(58, 84, 128),
	Color3.fromRGB(206, 160, 62),
	Color3.fromRGB(70, 110, 72),
}
local PETALS = {
	Color3.fromRGB(240, 204, 70),
	Color3.fromRGB(236, 232, 224),
	Color3.fromRGB(150, 104, 190),
	Color3.fromRGB(226, 120, 150),
}

-- The windows: where the middle of each opening is, and which way it faces.
local CABIN_WINDOW_SIZE = 2.2
local FRONT_WINDOW_X = 4.7
local FRONT_WINDOW_Y = CABIN_FLOOR + 3.9
local SIDE_WINDOW_Y = CABIN_FLOOR + 4.45
local CABIN_WINDOWS = {
	CABIN * CFrame.new(-FRONT_WINDOW_X, FRONT_WINDOW_Y, -CABIN_HALF_DEPTH),
	CABIN * CFrame.new(FRONT_WINDOW_X, FRONT_WINDOW_Y, -CABIN_HALF_DEPTH),
	CABIN * CFrame.new(-CABIN_HALF_WIDTH, SIDE_WINDOW_Y, 0) * turn(90),
}

local function cabinPoint(x: number, y: number, z: number): Vector3
	return CABIN:PointToWorldSpace(Vector3.new(x, y, z))
end

-- A box in the cabin's own space.
local function cabinBox(
	name: string,
	middle: Vector3,
	size: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
): Part
	return makePart({
		Name = name,
		Size = size,
		CFrame = CABIN * CFrame.new(middle),
		Material = material or Enum.Material.WoodPlanks,
		Color = color,
	}, parent)
end

-- A round post standing on `foot` (a point in the world).
local function post(
	name: string,
	foot: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	parent: Instance
): Part
	return makePart({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(foot + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
	}, parent)
end

-- A dark wall log between two points, with a sawn face only on the ends that show.
local function cabinLog(
	from: Vector3,
	to: Vector3,
	parent: Instance,
	capFrom: boolean,
	capTo: boolean
)
	local length = (to - from).Magnitude
	local along = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
	local thickness = CABIN_LOG / KIT.Log.Size.Y
	local scale = Vector3.new(length / KIT.Log.Size.X, thickness, thickness)
	local part = kitPart("Log", along, scale, { Color = DARK_LOG }, parent)
		or pole(from, to, CABIN_LOG, parent, DARK_LOG)
	part.Name = "WallLog"
	for side, capped in { [-1] = capFrom, [1] = capTo } do
		if capped then
			slice(along * CFrame.new(side * length / 2, 0, 0), CABIN_LOG * 0.8, PALE_WOOD, parent).Name =
				"LogEnd"
		end
	end
end

-- A gap in a wall: From and To along the wall, Low and High in height.
type Opening = { From: number, To: number, Low: number, High: number }

-- One wall of the cabin: logs stacked up, cut short at any doorway or window, with pale
-- chinking between them. `alongX` walls run across the cabin at Z = `at`; the others run
-- front to back at X = `at`. `lift` raises the whole stack (the front and back walls sit
-- half a log higher than the sides, so the corners lock together).
local function cabinWall(
	model: Model,
	alongX: boolean,
	at: number,
	half: number,
	lift: number,
	openings: { Opening }
)
	local over = 0.8 -- how far each log runs past the corner
	local function point(t: number, y: number): Vector3
		return if alongX then cabinPoint(t, y, at) else cabinPoint(at, y, t)
	end

	for course = 0, CABIN_COURSES - 1 do
		local y = CABIN_FLOOR + 0.6 + lift + course * CABIN_STEP
		local start = -half - over
		local runs: { { number } } = {}
		for _, opening in openings do
			if y > opening.Low and y < opening.High then
				table.insert(runs, { start, opening.From })
				start = opening.To
			end
		end
		table.insert(runs, { start, half + over })

		for _, run in runs do
			local from, to = run[1], run[2]
			cabinLog(point(from, y), point(to, y), model, from == -half - over, to == half + over)

			local chinkFrom, chinkTo = math.max(from, -half), math.min(to, half)
			local length = chinkTo - chinkFrom
			local middle = (chinkFrom + chinkTo) / 2
			local chink = cabinBox(
				"Chinking",
				if alongX then Vector3.new(middle, y, at) else Vector3.new(at, y, middle),
				if alongX
					then Vector3.new(length, CABIN_STEP, 0.5)
					else Vector3.new(0.5, CABIN_STEP, length),
				CHINKING,
				model,
				Enum.Material.Sand
			)
			chink.CanCollide = false
		end
	end
end

-- Rows of mossy shingles down one slope of a roof, on a solid deck. `top` and `foot` are
-- the slope's upper and lower edges at the middle of the roof, in the cabin's own space;
-- the roof runs `halfLength` to each side of them.
local function shingleSlope(
	model: Model,
	top: Vector3,
	foot: Vector3,
	halfLength: number,
	rows: number,
	seed: number
)
	local rng = Random.new(seed)
	local along = Vector3.xAxis
	local slope = (foot - top).Unit
	local slopeLength = (foot - top).Magnitude
	local across = along:Cross(slope)
	local out = if across.Y < 0 then -across else across -- up and away from the roof

	makePart({
		Name = "RoofDeck",
		Size = Vector3.new(slopeLength, 0.25, halfLength * 2),
		CFrame = CABIN * CFrame.fromMatrix((top + foot) / 2, slope, across, along),
		Material = Enum.Material.WoodPlanks,
		Color = DARK_WOOD,
	}, model)

	local rowLength = slopeLength / rows
	local pieces = 4
	for row = 0, rows - 1 do
		-- Where one shingle ends and the next begins, a little different in every row.
		local edges = { -halfLength - 0.15 }
		for i = 1, pieces - 1 do
			table.insert(
				edges,
				-halfLength + (halfLength * 2) * (i / pieces) + rng:NextNumber(-0.9, 0.9)
			)
		end
		table.insert(edges, halfLength + 0.15)

		for i = 1, pieces do
			local length = edges[i + 1] - edges[i]
			local middle = top
				+ slope * ((row + 0.5) * rowLength + 0.1)
				+ along * ((edges[i] + edges[i + 1]) / 2)
				+ out * (0.2 + ((row + i) % 2) * 0.07)
			makePart({
				Name = "Shingles",
				Size = Vector3.new(rowLength * 1.12, 0.2, length),
				CFrame = CABIN * CFrame.fromMatrix(middle, slope, across, along),
				Material = Enum.Material.Slate,
				Color = SHINGLES[rng:NextInteger(1, #SHINGLES)],
				CanCollide = false,
			}, model)
		end
	end
end

-- A slab of grey stone the whole size of the cabin, edged with boulders, and a doorstep.
function builders.CabinFoundation(model: Model)
	local w, d = CABIN_HALF_WIDTH + 0.6, CABIN_HALF_DEPTH + 0.6
	cabinBox(
		"Floor",
		Vector3.new(0, CABIN_FLOOR / 2 - 0.15, 0),
		Vector3.new(w * 2, CABIN_FLOOR + 0.3, d * 2),
		STONE:Lerp(Color3.new(0, 0, 0), 0.25),
		model,
		Enum.Material.Slate
	)
	-- Half the floor's height, so there is an easy way up before the porch is built.
	cabinBox(
		"Doorstep",
		Vector3.new(0, CABIN_FLOOR / 4, -d - 0.8),
		Vector3.new(CABIN_DOOR_HALF * 2 + 1.4, CABIN_FLOOR / 2, 1.6),
		STONE,
		model,
		Enum.Material.Slate
	)

	-- Boulders along the sides and the back. The front is left clear for the porch.
	local rng = Random.new(31)
	local rocks = { "RockA", "RockB", "RockC" }
	local count = 0
	local function edge(fromX: number, fromZ: number, toX: number, toZ: number)
		local length = math.max(math.abs(toX - fromX), math.abs(toZ - fromZ))
		local steps = math.floor(length / 1.8)
		for i = 0, steps - 1 do
			local t = (i + 0.5) / steps
			count += 1
			rock(
				rocks[count % 3 + 1],
				CABIN
					* CFrame.new(fromX + (toX - fromX) * t, -0.1, fromZ + (toZ - fromZ) * t)
					* turn(rng:NextNumber(0, 360)),
				rng:NextNumber(0.8, 1.05),
				model
			)
		end
	end
	edge(w, -d, w, d)
	edge(w, d, -w, d)
	edge(-w, d, -w, -d)
end

-- Dark logs seven high with pale chinking, crossing at the corners. A doorway and two
-- windows in the front wall, and a window in the side wall facing the hut.
function builders.CabinWalls(model: Model)
	local w, d = CABIN_HALF_WIDTH, CABIN_HALF_DEPTH
	local window = CABIN_WINDOW_SIZE / 2
	local frontWindows = { Low = FRONT_WINDOW_Y - window, High = FRONT_WINDOW_Y + window }

	cabinWall(model, true, -d, w, CABIN_STEP / 2, {
		{
			From = -FRONT_WINDOW_X - window,
			To = -FRONT_WINDOW_X + window,
			Low = frontWindows.Low,
			High = frontWindows.High,
		},
		{ From = -CABIN_DOOR_HALF, To = CABIN_DOOR_HALF, Low = 0, High = CABIN_DOOR_TOP },
		{
			From = FRONT_WINDOW_X - window,
			To = FRONT_WINDOW_X + window,
			Low = frontWindows.Low,
			High = frontWindows.High,
		},
	})
	cabinWall(model, true, d, w, CABIN_STEP / 2, {})
	cabinWall(model, false, -w, d, 0, {
		{
			From = -window,
			To = window,
			Low = SIDE_WINDOW_Y - window,
			High = SIDE_WINDOW_Y + window,
		},
	})
	cabinWall(model, false, w, d, 0, {})

	-- The room itself, as an unseen box. The player's game watches for it and, while the
	-- player stands inside it, looks down on the room from a top corner (see CabinCamera).
	local roomHeight = CABIN_WALL_TOP - CABIN_FLOOR
	local room = cabinBox(
		"CabinRoom",
		Vector3.new(0, CABIN_FLOOR + roomHeight / 2, 0),
		Vector3.new(w * 2 - CABIN_LOG, roomHeight, d * 2 - CABIN_LOG),
		DARK_WOOD,
		model
	)
	room.Transparency = 1
	room.CanCollide = false
	room.CanQuery = false
	room.CanTouch = false
	room.CastShadow = false
	room:SetAttribute("LiveOnly", true)

	-- A button each side of the doorway, to step through it.
	for _, way in
		{
			{ Name = "GoInside", Text = "Go inside", From = -d - 1.7, To = -d + 2.6 },
			{ Name = "GoOutside", Text = "Go outside", From = -d + 1.7, To = -d - 2.6 },
		}
	do
		local anchor = cabinBox(
			way.Name,
			Vector3.new(0, CABIN_FLOOR + 3.4, way.From),
			Vector3.one,
			DARK_WOOD,
			model
		)
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor:SetAttribute("LiveOnly", true)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = way.Text
		prompt.ObjectText = "Cabin"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 5
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character and root and root:IsA("BasePart") then
				-- Keep them where they stood from side to side, as far as the doorway allows.
				local across = CABIN:PointToObjectSpace(root.Position).X
				local place = cabinPoint(
					math.clamp(across, -CABIN_DOOR_HALF + 0.8, CABIN_DOOR_HALF - 0.8),
					0,
					way.To
				)
				local height = anchor.Position.Y - 0.2 -- standing on the floor
				local facing = cabinPoint(0, 0, way.To) - cabinPoint(0, 0, way.From)
				local at = Vector3.new(place.X, height, place.Z)
				root.AssemblyLinearVelocity = Vector3.zero
				character:PivotTo(CFrame.lookAt(at, at + facing))
			end
		end)
		prompt.Parent = anchor
	end

	-- An upright each side of the doorway, to tidy the cut ends.
	for _, side in { -1, 1 } do
		cabinBox(
			"DoorPost",
			Vector3.new(side * (CABIN_DOOR_HALF + 0.05), (CABIN_FLOOR + CABIN_DOOR_TOP) / 2, -d),
			Vector3.new(0.35, CABIN_DOOR_TOP - CABIN_FLOOR, CABIN_LOG + 0.1),
			DARK_WOOD,
			model
		)
	end
end

-- The roof's skeleton: a ridge log, rafters down each side, two beams across the room,
-- and a boarded triangle closing each end wall.
function builders.CabinRoofBeams(model: Model)
	local w = CABIN_HALF_WIDTH
	local ridgeY = CABIN_PEAK - 0.45

	beam(
		cabinPoint(-CABIN_ROOF_HALF_LENGTH + 0.2, ridgeY, 0),
		cabinPoint(CABIN_ROOF_HALF_LENGTH - 0.2, ridgeY, 0),
		0.8,
		model,
		DARK_LOG
	)
	for _, x in { -w - 0.9, -w / 2, 0, w / 2, w + 0.9 } do
		for _, side in { -1, 1 } do
			pole(
				cabinPoint(x, ridgeY + 0.1, side * 0.2),
				cabinPoint(x, CABIN_EAVE_HEIGHT - 0.3, side * (CABIN_EAVE - 0.2)),
				0.45,
				model,
				DARK_LOG
			).Name =
				"Rafter"
		end
	end
	for _, x in { -w / 3, w / 3 } do
		beam(
			cabinPoint(x, CABIN_WALL_TOP + 0.1, -CABIN_HALF_DEPTH - 0.4),
			cabinPoint(x, CABIN_WALL_TOP + 0.1, CABIN_HALF_DEPTH + 0.4),
			0.7,
			model,
			DARK_LOG
		)
	end

	-- Each end's triangle is two halves, from the middle out to the front and to the back.
	-- It follows the roof's slope, a little below it.
	local base = CABIN_WALL_TOP - 0.6
	local height = CABIN_PEAK - 0.3 - base
	local rise = (CABIN_PEAK - CABIN_EAVE_HEIGHT) / CABIN_EAVE -- how steep the roof is
	local reach = height / rise
	for _, x in { -w, w } do
		for _, side in { -1, 1 } do
			local gable = Instance.new("WedgePart")
			gable.Name = "Gable"
			gable.Anchored = true
			gable.Size = Vector3.new(0.5, height, reach)
			gable.CFrame = CABIN
				* CFrame.fromMatrix(
					Vector3.new(x, base + height / 2, side * reach / 2),
					Vector3.new(-side, 0, 0),
					Vector3.new(0, 1, 0),
					Vector3.new(0, 0, -side)
				)
			gable.Material = Enum.Material.WoodPlanks
			gable.Color = DARK_WOOD
			gable.TopSurface = Enum.SurfaceType.Smooth
			gable.BottomSurface = Enum.SurfaceType.Smooth
			gable.Parent = model
		end
	end
end

-- Mossy green shingles down both slopes, and a cap along the ridge.
function builders.CabinRoof(model: Model)
	local top = Vector3.new(0, CABIN_PEAK, 0)
	for index, side in { -1, 1 } do
		shingleSlope(
			model,
			top,
			Vector3.new(0, CABIN_EAVE_HEIGHT, side * CABIN_EAVE),
			CABIN_ROOF_HALF_LENGTH,
			7,
			40 + index
		)
	end
	cabinBox(
		"RidgeCap",
		Vector3.new(0, CABIN_PEAK + 0.22, 0),
		Vector3.new(CABIN_ROOF_HALF_LENGTH * 2 + 0.5, 0.4, 0.9),
		SHINGLES[3]:Lerp(Color3.new(0, 0, 0), 0.2),
		model,
		Enum.Material.Slate
	)
end

-- A plank door standing open into the room, and glass in the three windows.
function builders.CabinDoorWindows(model: Model)
	local height = CABIN_DOOR_TOP - CABIN_FLOOR - 0.25
	local width = CABIN_DOOR_HALF * 2 - 0.3
	-- Hinged on one side of the doorway and swung back into the room.
	local hinge = CABIN
		* CFrame.new(
			CABIN_DOOR_HALF - 0.15,
			CABIN_FLOOR + height / 2 + 0.05,
			-CABIN_HALF_DEPTH + 0.5
		)
		* turn(-80)
	local door = hinge * CFrame.new(width / 2, 0, 0)

	board("Door", door, Vector3.new(width, height, 0.24), CRATE, model).CanCollide = false
	for _, y in { -height * 0.3, height * 0.3 } do
		board(
			"DoorBrace",
			door * CFrame.new(0, y, 0.15),
			Vector3.new(width - 0.1, 0.4, 0.1),
			DARK_WOOD,
			model
		).CanCollide =
			false
		makePart({
			Name = "Hinge",
			Size = Vector3.new(0.8, 0.22, 0.36),
			CFrame = hinge * CFrame.new(0.3, y, 0),
			Material = Enum.Material.Metal,
			Color = IRON,
			CanCollide = false,
		}, model)
	end
	makePart({
		Name = "DoorHandle",
		Size = Vector3.new(0.2, 0.7, 0.5),
		CFrame = door * CFrame.new(width / 2 - 0.35, 0, 0),
		Material = Enum.Material.Metal,
		Color = IRON,
		CanCollide = false,
	}, model)
	cabinBox(
		"DoorLintel",
		Vector3.new(0, CABIN_DOOR_TOP + 0.1, -CABIN_HALF_DEPTH),
		Vector3.new(CABIN_DOOR_HALF * 2 + 0.8, 0.35, CABIN_LOG + 0.2),
		DARK_WOOD,
		model
	)

	local half = CABIN_WINDOW_SIZE / 2
	for _, window in CABIN_WINDOWS do
		-- The frame: a board along each edge of the opening.
		for _, side in { -1, 1 } do
			board(
				"WindowFrame",
				window * CFrame.new(side * half, 0, 0),
				Vector3.new(0.3, CABIN_WINDOW_SIZE + 0.3, CABIN_LOG + 0.2),
				PALE_WOOD,
				model
			)
			board(
				"WindowFrame",
				window * CFrame.new(0, side * half, 0),
				Vector3.new(CABIN_WINDOW_SIZE + 0.3, 0.3, CABIN_LOG + 0.2),
				PALE_WOOD,
				model
			)
		end
		-- Four panes: one sheet of glass with a cross of thin bars over it.
		makePart({
			Name = "Glass",
			Size = Vector3.new(CABIN_WINDOW_SIZE, CABIN_WINDOW_SIZE, 0.12),
			CFrame = window,
			Material = Enum.Material.Glass,
			Color = WINDOW_GLOW,
			Transparency = 0.45,
		}, model)
		board("WindowBar", window, Vector3.new(0.14, CABIN_WINDOW_SIZE, 0.24), PALE_WOOD, model)
		board("WindowBar", window, Vector3.new(CABIN_WINDOW_SIZE, 0.14, 0.24), PALE_WOOD, model)
	end
end

-- A grey stone chimney up the outside of the end wall, and a fireplace inside with a fire
-- burning in it.
function builders.CabinChimney(model: Model)
	local w = CABIN_HALF_WIDTH
	local stone = Enum.Material.Cobblestone
	local grey, dark = CHIMNEY_STONE, CHIMNEY_STONE_DARK

	-- Outside: a wide base, a shoulder, and the stack rising past the ridge.
	local outer = w + 0.5
	cabinBox(
		"ChimneyBase",
		Vector3.new(outer + 1.2, 3.4, 0),
		Vector3.new(2.4, 6.8, 4.4),
		grey,
		model,
		stone
	)
	cabinBox(
		"ChimneyShoulder",
		Vector3.new(outer + 1.1, 7.6, 0),
		Vector3.new(2.2, 1.6, 3.5),
		dark,
		model,
		stone
	)
	local stackTop = CABIN_PEAK + 2.4
	cabinBox(
		"ChimneyStack",
		Vector3.new(outer + 1.0, (8.4 + stackTop) / 2, 0),
		Vector3.new(2.0, stackTop - 8.4, 2.6),
		grey,
		model,
		stone
	)
	cabinBox(
		"ChimneyCap",
		Vector3.new(outer + 1.0, stackTop + 0.2, 0),
		Vector3.new(2.5, 0.4, 3.1),
		dark,
		model,
		stone
	)
	local flue = cabinBox(
		"Flue",
		Vector3.new(outer + 1.0, stackTop + 0.45, 0),
		Vector3.new(1.3, 0.12, 1.9),
		CHARRED,
		model,
		Enum.Material.Slate
	)
	flue.CanCollide = false

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Rate = 3
	smoke.Lifetime = NumberRange.new(5, 7)
	smoke.Speed = NumberRange.new(1.5, 2.5)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-20, 20)
	smoke.Color = ColorSequence.new(Color3.fromRGB(150, 150, 156))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 4.5),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Parent = flue

	local rng = Random.new(37)
	for i, z in { -2.6, 0, 2.6 } do
		rock(
			({ "RockA", "RockB", "RockC" })[i],
			CABIN * CFrame.new(outer + 2.7, -0.1, z) * turn(rng:NextNumber(0, 360)),
			rng:NextNumber(0.7, 0.95),
			model
		)
	end

	-- Inside: stone against the wall, an opening for the fire, and a mantel shelf over it.
	local inner = w - CABIN_LOG / 2 -- the inside face of the end wall
	local floor = CABIN_FLOOR
	cabinBox(
		"Hearth",
		Vector3.new(inner - 1.5, floor + 0.12, 0),
		Vector3.new(3, 0.25, 5),
		dark,
		model,
		stone
	)
	cabinBox(
		"FireBack",
		Vector3.new(inner - 0.25, floor + 2.9, 0),
		Vector3.new(0.5, 5.8, 4.6),
		dark,
		model,
		stone
	)
	for _, side in { -1, 1 } do
		cabinBox(
			"FireSide",
			Vector3.new(inner - 1.0, floor + 1.85, side * 1.85),
			Vector3.new(1.5, 3.7, 0.9),
			grey,
			model,
			stone
		)
	end
	cabinBox(
		"FireArch",
		Vector3.new(inner - 1.0, floor + 4.2, 0),
		Vector3.new(1.5, 1, 4.6),
		grey,
		model,
		stone
	)
	cabinBox(
		"Mantel",
		Vector3.new(inner - 1.1, floor + 4.85, 0),
		Vector3.new(1.9, 0.3, 5.2),
		DARK_WOOD,
		model
	)
	local breastTop = CABIN_WALL_TOP + 1.6
	cabinBox(
		"ChimneyBreast",
		Vector3.new(inner - 0.6, (floor + 5 + breastTop) / 2, 0),
		Vector3.new(1.2, breastTop - floor - 5, 3.4),
		grey,
		model,
		stone
	)

	for i = 1, 3 do
		local origin = CABIN
			* CFrame.new(inner - 1.0, floor + 0.55, 0)
			* turn(60 * i + 15)
			* CFrame.new(0.3, 0, 0)
			* CFrame.Angles(0, 0, math.rad(12))
		log(origin, 0.34, CHARRED, CHARRED, model)
	end
	local flame = makePart({
		Name = "Flame",
		Size = Vector3.one,
		CFrame = CABIN * CFrame.new(inner - 1.0, floor + 0.7, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, model)

	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 5
	fire.Parent = flame

	local light = Instance.new("PointLight")
	light.Color = Config.Lighting.WarmLight
	light.Brightness = 1.8
	light.Range = 22
	light.Shadows = true
	light.Parent = flame
end

-- A plank porch right across the front, with a rail, its own shingled roof on four posts,
-- and a step up from the ground.
function builders.CabinPorch(model: Model)
	local w = CABIN_HALF_WIDTH
	local back = -CABIN_HALF_DEPTH - 0.55 -- where the porch meets the cabin
	local boards = 5
	local boardDepth = PORCH_DEPTH / boards
	for i = 1, boards do
		cabinBox(
			"PorchBoard",
			Vector3.new(0, CABIN_FLOOR - 0.15, back - (i - 0.5) * boardDepth),
			Vector3.new(w * 2 + 0.6, 0.3, boardDepth - 0.04),
			if i % 2 == 0 then CRATE else CRATE:Lerp(DARK_WOOD, 0.25),
			model
		)
	end
	cabinBox(
		"PorchSkirt",
		Vector3.new(0, (CABIN_FLOOR - 0.3) / 2, PORCH_FRONT + 0.15),
		Vector3.new(w * 2 + 0.6, CABIN_FLOOR - 0.3, 0.3),
		DARK_WOOD,
		model
	)
	for _, side in { -1, 1 } do
		cabinBox(
			"PorchSkirt",
			Vector3.new(side * (w + 0.15), (CABIN_FLOOR - 0.3) / 2, back - PORCH_DEPTH / 2),
			Vector3.new(0.3, CABIN_FLOOR - 0.3, PORCH_DEPTH),
			DARK_WOOD,
			model
		)
	end
	cabinBox(
		"PorchStep",
		Vector3.new(0, CABIN_FLOOR / 4, PORCH_FRONT - 0.75),
		Vector3.new(5, CABIN_FLOOR / 2, 1.5),
		CRATE,
		model
	)

	-- Four posts along the front, leaving the middle open for the step.
	local postHeight = 6.2
	local postX = { -w + 0.2, -2.7, 2.7, w - 0.2 }
	for _, x in postX do
		post(
			"PorchPost",
			cabinPoint(x, CABIN_FLOOR, PORCH_POST_Z),
			postHeight,
			0.55,
			DARK_LOG,
			model
		)
	end
	beam(
		cabinPoint(-w - 0.6, CABIN_FLOOR + postHeight + 0.25, PORCH_POST_Z),
		cabinPoint(w + 0.6, CABIN_FLOOR + postHeight + 0.25, PORCH_POST_Z),
		0.6,
		model,
		DARK_LOG
	)

	-- Rails between the outer posts, and down each end of the porch.
	for _, height in { 1.3, 2.6 } do
		local y = CABIN_FLOOR + height
		for _, side in { -1, 1 } do
			pole(
				cabinPoint(side * (w - 0.2), y, PORCH_POST_Z),
				cabinPoint(side * 2.7, y, PORCH_POST_Z),
				0.28,
				model,
				WOOD
			).Name =
				"PorchRail"
			pole(
				cabinPoint(side * (w - 0.2), y, PORCH_POST_Z),
				cabinPoint(side * (w - 0.2), y, back),
				0.28,
				model,
				WOOD
			).Name =
				"PorchRail"
		end
	end

	-- The porch roof runs on down from under the cabin's own.
	shingleSlope(
		model,
		Vector3.new(0, CABIN_EAVE_HEIGHT - 0.1, -CABIN_HALF_DEPTH - 0.6),
		Vector3.new(0, CABIN_FLOOR + postHeight + 0.45, PORCH_FRONT - 0.7),
		CABIN_ROOF_HALF_LENGTH - 0.4,
		3,
		47
	)
end

-- A rocking chair on the porch, and a lantern hung beside the door.
function builders.PorchChair(model: Model)
	local chair = CABIN
		* CFrame.new(-4.6, CABIN_FLOOR, -CABIN_HALF_DEPTH - 2.4)
		* turn(12)
		* CFrame.Angles(math.rad(6), 0, 0) -- rocked back a little
	local function piece(name: string, at: CFrame, size: Vector3, color: Color3)
		board(name, chair * at, size, color, model).CanCollide = false
	end

	for _, x in { -0.95, 0.95 } do
		-- A rocker: a long runner with each end turned up.
		piece("Rocker", CFrame.new(x, 0.12, 0), Vector3.new(0.22, 0.2, 2.6), DARK_WOOD)
		for _, side in { -1, 1 } do
			piece(
				"Rocker",
				CFrame.new(x, 0.26, side * 1.45) * CFrame.Angles(math.rad(side * 22), 0, 0),
				Vector3.new(0.22, 0.2, 0.8),
				DARK_WOOD
			)
		end
		piece("ChairLeg", CFrame.new(x, 0.95, -0.8), Vector3.new(0.2, 1.7, 0.2), WOOD)
		piece("ChairLeg", CFrame.new(x, 2.3, 0.85), Vector3.new(0.2, 4.4, 0.2), WOOD)
		piece("ChairArm", CFrame.new(x, 2.55, 0), Vector3.new(0.3, 0.16, 2), WOOD)
	end
	piece("ChairSeat", CFrame.new(0, 1.6, 0), Vector3.new(2, 0.18, 1.9), CRATE)
	for i = -2, 2 do
		piece("ChairSlat", CFrame.new(i * 0.38, 3.2, 0.85), Vector3.new(0.26, 2.4, 0.12), CRATE)
	end
	piece("ChairTop", CFrame.new(0, 4.45, 0.85), Vector3.new(2.1, 0.3, 0.18), WOOD)
	piece("Cushion", CFrame.new(0, 1.78, 0), Vector3.new(1.7, 0.2, 1.6), BLANKET)

	-- The lantern, on an iron bracket out from the wall.
	local bracket = cabinPoint(2.15, CABIN_FLOOR + 5.6, -CABIN_HALF_DEPTH - 0.5)
	local lantern = cabinPoint(2.15, CABIN_FLOOR + 4.6, -CABIN_HALF_DEPTH - 1.5)
	pole(bracket, cabinPoint(2.15, CABIN_FLOOR + 5.7, -CABIN_HALF_DEPTH - 1.5), 0.12, model, IRON).Name =
		"LanternBracket"
	for _, cap in { 0.52, -0.52 } do
		makePart({
			Name = "LanternCap",
			Size = Vector3.new(0.8, 0.14, 0.8),
			CFrame = CABIN.Rotation + (lantern + Vector3.new(0, cap, 0)),
			Material = Enum.Material.Metal,
			Color = IRON,
			CanCollide = false,
		}, model)
	end
	makePart({
		Name = "LanternHook",
		Size = Vector3.new(0.08, 0.5, 0.08),
		CFrame = CFrame.new(lantern + Vector3.new(0, 0.82, 0)),
		Material = Enum.Material.Metal,
		Color = IRON,
		CanCollide = false,
	}, model)
	local glass = makePart({
		Name = "LanternGlass",
		Size = Vector3.new(0.6, 0.9, 0.6),
		CFrame = CABIN.Rotation + lantern,
		Material = Enum.Material.Neon,
		Color = LANTERN_GLOW,
		CanCollide = false,
	}, model)

	local light = Instance.new("PointLight")
	light.Color = Config.Lighting.WarmLight
	light.Brightness = 1.4
	light.Range = 24
	light.Shadows = false
	light.Parent = glass
end

-- A wooden bed in the back corner, with a pillow and a patchwork quilt.
function builders.CabinBed(model: Model)
	local inner = CABIN_HALF_WIDTH - CABIN_LOG / 2
	local length, width = 6.2, 3.2
	-- Head against the side wall, one long side against the back wall.
	local bed = CABIN
		* CFrame.new(
			-inner + 0.2 + length / 2,
			CABIN_FLOOR,
			CABIN_HALF_DEPTH - CABIN_LOG / 2 - 0.15 - width / 2
		)

	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local tall = if x < 0 then 3.4 else 2.2 -- the head end stands taller
			board(
				"BedPost",
				bed * CFrame.new(x * (length / 2 - 0.2), tall / 2, z * (width / 2 - 0.2)),
				Vector3.new(0.4, tall, 0.4),
				DARK_WOOD,
				model
			)
		end
	end
	board(
		"BedFrame",
		bed * CFrame.new(0, 1.15, 0),
		Vector3.new(length - 0.4, 0.5, width),
		WOOD,
		model
	)
	board(
		"Headboard",
		bed * CFrame.new(-length / 2 + 0.2, 2.5, 0),
		Vector3.new(0.25, 1.5, width - 0.6),
		WOOD,
		model
	)
	board(
		"Footboard",
		bed * CFrame.new(length / 2 - 0.2, 1.75, 0),
		Vector3.new(0.25, 0.7, width - 0.6),
		WOOD,
		model
	)
	makePart({
		Name = "Mattress",
		Size = Vector3.new(length - 0.8, 0.5, width - 0.3),
		CFrame = bed * CFrame.new(0, 1.65, 0),
		Material = Enum.Material.Fabric,
		Color = CLOTH,
	}, model)
	makePart({
		Name = "Pillow",
		Size = Vector3.new(1.1, 0.4, width - 1),
		CFrame = bed * CFrame.new(-length / 2 + 1.15, 2.05, 0) * CFrame.Angles(0, 0, math.rad(-8)),
		Material = Enum.Material.Fabric,
		Color = SOCK,
		CanCollide = false,
	}, model)

	-- The quilt: squares of different cloth, covering the bed from below the pillow down,
	-- and hanging over the side that faces the room.
	local rng = Random.new(53)
	local columns, rows = 5, 3
	local quiltFrom, quiltTo = -length / 2 + 1.9, length / 2 - 0.45
	local squareX = (quiltTo - quiltFrom) / columns
	local squareZ = (width - 0.2) / rows
	for column = 1, columns do
		local x = quiltFrom + (column - 0.5) * squareX
		local color = QUILT[rng:NextInteger(1, #QUILT)]
		for row = 1, rows do
			local nextColor = QUILT[(column * 2 + row * 3) % #QUILT + 1]
			makePart({
				Name = "QuiltSquare",
				Size = Vector3.new(squareX, 0.14, squareZ),
				CFrame = bed * CFrame.new(x, 1.97, -width / 2 + 0.1 + (row - 0.5) * squareZ),
				Material = Enum.Material.Fabric,
				Color = nextColor,
				CanCollide = false,
			}, model)
		end
		makePart({
			Name = "QuiltEdge",
			Size = Vector3.new(squareX, 0.9, 0.12),
			CFrame = bed * CFrame.new(x, 1.55, -width / 2 + 0.05),
			Material = Enum.Material.Fabric,
			Color = color,
			CanCollide = false,
		}, model)
	end
end

-- A table and two stools in the middle of the room, and shelves of jars on the back wall.
function builders.CabinTable(model: Model)
	local floor = CABIN_FLOOR
	local tableAt = CABIN * CFrame.new(0.9, floor, -0.1) * turn(4)
	board("TableTop", tableAt * CFrame.new(0, 2.7, 0), Vector3.new(3.8, 0.26, 2.6), CRATE, model)
	for _, x in { -1.6, 1.6 } do
		for _, z in { -1, 1 } do
			board(
				"TableLeg",
				tableAt * CFrame.new(x, 1.3, z),
				Vector3.new(0.3, 2.6, 0.3),
				DARK_WOOD,
				model
			)
		end
	end
	for _, at in { CFrame.new(-2.8, 0, 0.1), CFrame.new(0.8, 0, 2.2) } do
		local stool = tableAt * at
		board("StoolSeat", stool * CFrame.new(0, 1.7, 0), Vector3.new(1.4, 0.22, 1.4), WOOD, model)
		for _, x in { -0.5, 0.5 } do
			for _, z in { -0.5, 0.5 } do
				board(
					"StoolLeg",
					stool * CFrame.new(x, 0.8, z),
					Vector3.new(0.2, 1.6, 0.2),
					DARK_WOOD,
					model
				).CanCollide =
					false
			end
		end
	end
	-- Supper laid out: a bowl, a mug and a candle.
	local upright = CFrame.Angles(0, 0, math.rad(90))
	makePart({
		Name = "Bowl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 0.9, 0.9),
		CFrame = tableAt * CFrame.new(-0.8, 2.98, -0.3) * upright,
		Color = PALE_WOOD,
		CanCollide = false,
	}, model)
	makePart({
		Name = "Mug",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 0.4, 0.4),
		CFrame = tableAt * CFrame.new(0.1, 3.08, 0.5) * upright,
		Material = Enum.Material.Metal,
		Color = IRON,
		CanCollide = false,
	}, model)
	makePart({
		Name = "Candle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 0.22, 0.22),
		CFrame = tableAt * CFrame.new(1.1, 3.18, -0.2) * upright,
		Material = Enum.Material.SmoothPlastic,
		Color = SOCK,
		CanCollide = false,
	}, model)
	local wick = makePart({
		Name = "CandleFlame",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.24,
		CFrame = tableAt * CFrame.new(1.1, 3.65, -0.2),
		Material = Enum.Material.Neon,
		Color = LANTERN_GLOW,
		CanCollide = false,
	}, model)
	local light = Instance.new("PointLight")
	light.Color = Config.Lighting.WarmLight
	light.Brightness = 0.8
	light.Range = 12
	light.Shadows = false
	light.Parent = wick

	-- Two shelves on the back wall, between the bed and the fireplace.
	local wall = CABIN_HALF_DEPTH - CABIN_LOG / 2
	local shelfX, shelfLength = 2.6, 4.2
	local jarColors = { CLAY, MOSS, EMBER:Lerp(RUST, 0.6), FLANNEL_DARK, STEW }
	local rng = Random.new(59)
	for shelf, height in { 3.6, 5.3 } do
		local y = floor + height
		board(
			"Shelf",
			CABIN * CFrame.new(shelfX, y, wall - 0.5),
			Vector3.new(shelfLength, 0.2, 1),
			WOOD,
			model
		).CanCollide =
			false
		for _, side in { -1, 1 } do
			board(
				"ShelfBracket",
				CABIN * CFrame.new(shelfX + side * (shelfLength / 2 - 0.4), y - 0.35, wall - 0.3),
				Vector3.new(0.2, 0.5, 0.6),
				DARK_WOOD,
				model
			).CanCollide =
				false
		end
		for i = 1, 5 do
			local x = shelfX - shelfLength / 2 + 0.5 + (i - 1) * 0.8 + rng:NextNumber(-0.1, 0.1)
			local tall = rng:NextNumber(0.6, 0.95)
			local jar = CABIN * CFrame.new(x, y + 0.1 + tall / 2, wall - 0.55)
			makePart({
				Name = "Jar",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(tall, 0.55, 0.55),
				CFrame = jar * upright,
				Material = Enum.Material.Glass,
				Color = jarColors[(i + shelf) % #jarColors + 1],
				Transparency = 0.25,
				CanCollide = false,
			}, model)
			makePart({
				Name = "JarLid",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.12, 0.6, 0.6),
				CFrame = jar * CFrame.new(0, tall / 2 + 0.06, 0) * upright,
				Material = Enum.Material.Metal,
				Color = RUST,
				CanCollide = false,
			}, model)
		end
	end
end

-- Red shutters each side of every window, and a box of wildflowers under it.
function builders.CabinShutters(model: Model)
	local half = CABIN_WINDOW_SIZE / 2
	local rng = Random.new(61)
	for _, window in CABIN_WINDOWS do
		-- The window's own -Z faces out of the cabin.
		local out = -(CABIN_LOG / 2 + 0.12)
		for _, side in { -1, 1 } do
			local shutter = window * CFrame.new(side * (half + 0.75), 0, out)
			board(
				"Shutter",
				shutter,
				Vector3.new(1.1, CABIN_WINDOW_SIZE + 0.4, 0.16),
				SHUTTER_RED,
				model
			).CanCollide =
				false
			for _, y in { -0.75, 0.75 } do
				board(
					"ShutterLedge",
					shutter * CFrame.new(0, y, -0.1),
					Vector3.new(1.1, 0.22, 0.08),
					FLANNEL_DARK,
					model
				).CanCollide =
					false
			end
		end

		local box = window * CFrame.new(0, -half - 0.65, out - 0.3)
		board("FlowerBox", box, Vector3.new(CABIN_WINDOW_SIZE + 0.8, 0.6, 0.8), DARK_WOOD, model).CanCollide =
			false
		makePart({
			Name = "Soil",
			Size = Vector3.new(CABIN_WINDOW_SIZE + 0.5, 0.1, 0.55),
			CFrame = box * CFrame.new(0, 0.3, 0),
			Material = Enum.Material.Slate,
			Color = SOIL,
			CanCollide = false,
		}, model)
		for i = 1, 6 do
			local x = -half - 0.1 + (i - 0.5) * (CABIN_WINDOW_SIZE + 0.2) / 6
			local foot = box:PointToWorldSpace(Vector3.new(x, 0.3, rng:NextNumber(-0.12, 0.12)))
			local tall = rng:NextNumber(0.5, 0.95)
			local head = foot + Vector3.new(rng:NextNumber(-0.1, 0.1), tall, 0.04)
			pole(foot, head, 0.08, model, MOSS).CanCollide = false
			makePart({
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * rng:NextNumber(0.3, 0.42),
				Position = head,
				Material = Enum.Material.SmoothPlastic,
				Color = PETALS[(i + rng:NextInteger(0, 1)) % #PETALS + 1],
				CanCollide = false,
			}, model)
		end
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
	HangingPot = Vector3.new(0, 0, 0),
	LanternPost = Vector3.new(11, 0, 8),
	TentPoles = Vector3.new(-14, 0, 0),
	TentCanvas = Vector3.new(-14, 0, 0),
	TentPegs = Vector3.new(-14, 0, 0),
	Cot = Vector3.new(-14, 0, 0),
	SupplyCrate = Vector3.new(-15.5, 0, 8.3),
	DryingRack = Vector3.new(8.5, 0, -12.5),
	Clothesline = Vector3.new(3.5, 0, 16),
	PicnicTable = Vector3.new(1.5, 0, 9.5),
	ChoppingBlock = Vector3.new(-6.5, 0, -11.5),
	Sawhorse = Vector3.new(3.8, 0, -16.6),
	StoneFooting = Vector3.new(-14, 0, 0),
	LogWalls = Vector3.new(-14, 0, 0),
	BarkRoof = Vector3.new(-14, 0, 0),
	Door = Vector3.new(-14, 0, 0),
	Workbench = Vector3.new(-14, 0, 0),
	RainBarrel = Vector3.new(-14, 0, 0),
	StonePath = Vector3.new(-7, 0, 0),
	CabinFoundation = CABIN_CENTRE,
	CabinWalls = CABIN_CENTRE,
	CabinRoofBeams = CABIN_CENTRE,
	CabinRoof = CABIN_CENTRE,
	CabinDoorWindows = CABIN_CENTRE,
	CabinChimney = CABIN_CENTRE,
	CabinPorch = CABIN_CENTRE,
	PorchChair = CABIN_CENTRE,
	CabinBed = CABIN_CENTRE,
	CabinTable = CABIN_CENTRE,
	CabinShutters = CABIN_CENTRE,
}
local reportedGround: { [string]: boolean } = {}

-- Once the clearing has grown, the camp is laid out again in three areas with open ground
-- between them, and each of these builds stands this far from its first spot:
--   * the fire circle keeps only the fire, the pot and the stools;
--   * the hut moves back from the fire, with everything in and against it;
--   * the work yard is beside the hut: woodpile, chopping block, planks, sawhorse, rack;
--   * the home area is by the cabin: picnic table, clothesline, lantern post.
local HUT_SHIFT = Vector3.new(-HUT_MOVED_BACK, 0, 0)
local GROWN_SHIFT: { [string]: Vector3 } = {
	StoneFooting = HUT_SHIFT,
	LogWalls = HUT_SHIFT,
	BarkRoof = HUT_SHIFT,
	Door = HUT_SHIFT,
	Workbench = HUT_SHIFT,
	RainBarrel = HUT_SHIFT,
	StonePath = HUT_SHIFT,
	Cot = HUT_SHIFT,
	SupplyCrate = HUT_SHIFT,

	Woodpile = Vector3.new(-7, 0, -3), -- to (-20, -12)
	ChoppingBlock = Vector3.new(-6.5, 0, -5.5), -- to (-13, -17)
	Sawhorse = Vector3.new(-8.8, 0, -7.4), -- sawhorse to (-5, -24), planks to (-11.2, -24.2)
	DryingRack = Vector3.new(-5.5, 0, -9.5), -- to (3, -22)

	PicnicTable = Vector3.new(7.5, 0, 7.5), -- to (9, 17)
	Clothesline = Vector3.new(8.5, 0, 10), -- to (12, 26)
	LanternPost = Vector3.new(3, 0, 4), -- to (14, 12)
}

-- The real height of the terrain's surface at a spot. Terrain is drawn a little above the
-- height it was filled to, so anything built at Y = 0 would be partly buried.
local function groundHeightAt(spot: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(spot + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else 0
end

-- True once the terrain at camp can be measured. For a moment after the world is made the
-- measurement finds nothing, and anything built then is placed too low and partly buried.
function CampModels.groundIsReady(): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	return Workspace:Raycast(Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params) ~= nil
end

-- Builds one camp structure, in place, by its Id from Config.Camp.Builds.
-- `standing` is the set of builds standing in the camp (by Id); leave it out for none.
-- `layout` is which size the clearing is (0, or left out, for the starting size).
function CampModels.build(
	id: string,
	parent: Instance,
	standing: { [string]: boolean }?,
	layout: number?
): Model
	local model = Instance.new("Model")
	model.Name = id
	local builder = builders[id]
	if builder then
		builder(model, standing or {}, layout or 0)
		-- The builders work from each piece's first spot and from Y = 0; move the result
		-- to where it stands now, and lift it onto the real ground.
		local shift = if (layout or 0) > 0 then GROWN_SHIFT[id] or Vector3.zero else Vector3.zero
		local ground = groundHeightAt((BUILD_SPOTS[id] or Vector3.zero) + shift)
		if not reportedGround[id] then
			reportedGround[id] = true
			print(`[CampModels] Ground under {id} is at height {string.format("%.2f", ground)}.`)
		end
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.CFrame += shift + Vector3.new(0, ground, 0)
			end
		end
	else
		warn("[CampModels] No model for build", id)
	end
	model.Parent = parent
	return model
end

-- Where the build prompt for a build should hang, for the builds that need telling. The
-- prompt otherwise hangs over the build's first piece, which on a roof is out of reach.
-- Every piece of the cabin is built from the ground in front of its door.
function CampModels.promptSpot(id: string): Vector3?
	if BUILD_SPOTS[id] == CABIN_CENTRE then
		local spot = cabinPoint(0, 0, PORCH_FRONT - 2.5)
		return spot + Vector3.new(0, groundHeightAt(spot), 0)
	end
	return nil
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
		if item:IsA("BasePart") and not item:GetAttribute("LiveOnly") then
			if item.Transparency < 1 then
				item.Transparency = Config.Camp.GhostTransparency
			end
			item.Material = Enum.Material.Neon
			item.Color = GHOST
			item.CanCollide = false
			item.CanQuery = false
			item.CastShadow = false
		elseif
			item:IsA("Fire")
			or item:IsA("Light")
			or item:IsA("ParticleEmitter")
			or item:GetAttribute("LiveOnly") -- a working piece, such as a button
		then
			item:Destroy()
		end
	end
	-- Drawn through anything in the way, so the next build can always be found at camp.
	addGlow(model, Config.Camp.GhostTransparency, true)
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
-- The tent camp's materials.

-- A small iron cooking pot.
function materialBuilders.IronPot(model: Model, at: Vector3)
	makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.1,
		Position = at + Vector3.new(0, 0.55, 0),
		Material = Enum.Material.Metal,
		Color = IRON,
	}, model)
	makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.16, 1.05, 1.05),
		CFrame = CFrame.new(at + Vector3.new(0, 0.98, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = IRON,
	}, model)
end

-- A short length of chain: links end to end, each turned against the last.
function materialBuilders.Chain(model: Model, at: Vector3)
	for i = 1, 5 do
		local from = at + Vector3.new((i - 3.5) * 0.42, 0.3 + (i % 2) * 0.14, 0)
		local to = from + Vector3.new(0.46, ((i + 1) % 2 - i % 2) * 0.14, 0)
		local link = pole(from, to, 0.22, model, IRON)
		link.Material = Enum.Material.Metal
	end
end

-- A battered lantern, still faintly lit.
function materialBuilders.Lantern(model: Model, at: Vector3)
	for _, cap in { 0.12, 1.02 } do
		makePart({
			Size = Vector3.new(0.7, 0.14, 0.7),
			Position = at + Vector3.new(0, cap, 0),
			Material = Enum.Material.Metal,
			Color = IRON,
		}, model)
	end
	makePart({
		Size = Vector3.new(0.52, 0.76, 0.52),
		Position = at + Vector3.new(0, 0.57, 0),
		Material = Enum.Material.Neon,
		Color = LANTERN_GLOW,
	}, model)
end

-- A folded sheet of canvas tied with rope.
function materialBuilders.Canvas(model: Model, at: Vector3)
	for i = 1, 3 do
		makePart({
			Size = Vector3.new(1.7 - i * 0.06, 0.16, 1.15),
			Position = at + Vector3.new(0, 0.1 + (i - 1) * 0.17, 0),
			Material = Enum.Material.Fabric,
			Color = if i % 2 == 0 then CLOTH_WORN else CLOTH,
		}, model)
	end
	lashing(CFrame.new(at + Vector3.new(0, 0.28, 0)) * turn(90), 0.72, model)
end

-- A pair of wooden tent pegs.
function materialBuilders.TentPeg(model: Model, at: Vector3)
	for _, side in { -1, 1 } do
		pole(
			at + Vector3.new(-0.6, 0.15, side * 0.2),
			at + Vector3.new(0.6, 0.3 + side * 0.08, side * 0.28),
			0.2,
			model,
			PALE_WOOD
		)
	end
end

-- Two sawn planks, one across the other.
function materialBuilders.Plank(model: Model, at: Vector3)
	for i, angle in { 0, 22 } do
		makePart({
			Size = Vector3.new(2.5, 0.14, 0.5),
			CFrame = CFrame.new(at + Vector3.new(0, 0.08 + (i - 1) * 0.15, 0)) * turn(angle),
			Material = Enum.Material.WoodPlanks,
			Color = PALE_WOOD,
		}, model)
	end
end

-- A small box of nails, a few standing proud.
function materialBuilders.Nails(model: Model, at: Vector3)
	makePart({
		Size = Vector3.new(0.9, 0.42, 0.7),
		Position = at + Vector3.new(0, 0.21, 0),
		Material = Enum.Material.WoodPlanks,
		Color = CRATE,
	}, model)
	for i = 1, 4 do
		local foot = at + Vector3.new((i - 2.5) * 0.18, 0.4, (i % 2 - 0.5) * 0.2)
		local nail = pole(foot, foot + Vector3.new(0.04, 0.42, 0.02), 0.07, model, RUST)
		nail.Material = Enum.Material.Metal
	end
end

-- The hut's materials.

-- Two flat stones, one on the other.
function materialBuilders.FlatStone(model: Model, at: Vector3)
	for i, size in { 1.5, 1.1 } do
		makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.26, size, size * 0.85),
			CFrame = CFrame.new(at + Vector3.new((i - 1) * 0.15, 0.13 + (i - 1) * 0.27, 0)) * turn(
				i * 40
			) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Slate,
			Color = STONE,
		}, model)
	end
end

-- An axe head with no handle: a wedge of steel with a hole for the haft.
function materialBuilders.AxeHead(model: Model, at: Vector3)
	makePart({
		Size = Vector3.new(1.3, 0.9, 0.28),
		CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(12)),
		Material = Enum.Material.Metal,
		Color = FLINT,
	}, model)
	makePart({
		Size = Vector3.new(0.4, 0.95, 0.4),
		CFrame = CFrame.new(at + Vector3.new(-0.55, 0.42, 0)) * CFrame.Angles(0, 0, math.rad(12)),
		Material = Enum.Material.Metal,
		Color = IRON,
	}, model)
end

-- A curl of bark peeled from a tree.
function materialBuilders.BarkSheet(model: Model, at: Vector3)
	for _, side in { -1, 1 } do
		makePart({
			Size = Vector3.new(2.2, 0.14, 0.8),
			CFrame = CFrame.new(at + Vector3.new(0, 0.32, side * 0.34))
				* CFrame.Angles(math.rad(side * 28), 0, 0),
			Color = if side == 1 then BARK else BARK_LIGHT,
		}, model)
	end
end

-- An iron door hinge: two leaves and the pin between them.
function materialBuilders.Hinge(model: Model, at: Vector3)
	for _, side in { -1, 1 } do
		makePart({
			Size = Vector3.new(0.7, 0.1, 0.9),
			CFrame = CFrame.new(at + Vector3.new(side * 0.4, 0.2, 0))
				* CFrame.Angles(0, 0, math.rad(side * -14)),
			Material = Enum.Material.Metal,
			Color = IRON,
		}, model)
	end
	local pin =
		pole(at + Vector3.new(0, 0.28, -0.5), at + Vector3.new(0.01, 0.28, 0.5), 0.2, model, RUST)
	pin.Material = Enum.Material.Metal
end

-- A hammer and a chisel, crossed.
function materialBuilders.OldTools(model: Model, at: Vector3)
	pole(
		at + Vector3.new(-0.9, 0.18, -0.3),
		at + Vector3.new(0.7, 0.2, 0.3),
		0.18,
		model,
		PALE_WOOD
	)
	makePart({
		Size = Vector3.new(0.34, 0.36, 0.9),
		CFrame = CFrame.new(at + Vector3.new(0.75, 0.22, 0.32)) * turn(-20),
		Material = Enum.Material.Metal,
		Color = IRON,
	}, model)
	pole(
		at + Vector3.new(-0.7, 0.3, 0.45),
		at + Vector3.new(0.1, 0.32, -0.25),
		0.2,
		model,
		DARK_WOOD
	)
	local blade = pole(
		at + Vector3.new(0.1, 0.32, -0.25),
		at + Vector3.new(0.75, 0.33, -0.8),
		0.12,
		model,
		FLINT
	)
	blade.Material = Enum.Material.Metal
end

-- A small barrel.
function materialBuilders.Barrel(model: Model, at: Vector3)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.3, 1.05, 1.05),
		CFrame = CFrame.new(at + Vector3.new(0, 0.65, 0)) * upright,
		Material = Enum.Material.WoodPlanks,
		Color = CRATE,
	}, model)
	for _, y in { 0.3, 1.0 } do
		makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 1.12, 1.12),
			CFrame = CFrame.new(at + Vector3.new(0, y, 0)) * upright,
			Material = Enum.Material.Metal,
			Color = IRON,
		}, model)
	end
end

-- The cabin's materials.

-- Three mossy shingles, overlapping.
function materialBuilders.Shingle(model: Model, at: Vector3)
	for i = 1, 3 do
		makePart({
			Size = Vector3.new(0.9, 0.1, 1.3),
			CFrame = CFrame.new(at + Vector3.new((i - 2) * 0.55, 0.08 + i * 0.07, 0)) * turn(
				(i - 2) * 9
			) * CFrame.Angles(0, 0, math.rad(6)),
			Material = Enum.Material.Slate,
			Color = SHINGLES[i],
		}, model)
	end
end

-- A pane of glass in a thin wooden frame, standing on edge.
function materialBuilders.GlassPane(model: Model, at: Vector3)
	local pane = CFrame.new(at + Vector3.new(0, 0.8, 0))
	makePart({
		Size = Vector3.new(1.2, 1.4, 0.06),
		CFrame = pane,
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(176, 214, 226),
		Transparency = 0.35,
	}, model)
	for _, side in { -1, 1 } do
		makePart({
			Size = Vector3.new(0.12, 1.6, 0.14),
			CFrame = pane * CFrame.new(side * 0.66, 0, 0),
			Color = PALE_WOOD,
		}, model)
		makePart({
			Size = Vector3.new(1.44, 0.12, 0.14),
			CFrame = pane * CFrame.new(0, side * 0.74, 0),
			Color = PALE_WOOD,
		}, model)
	end
end

-- A lump of wet clay.
function materialBuilders.Clay(model: Model, at: Vector3)
	for _, lump in
		{
			{ Vector3.new(0, 0.4, 0), 0.95 },
			{ Vector3.new(0.5, 0.3, 0.2), 0.65 },
			{ Vector3.new(-0.35, 0.28, -0.3), 0.6 },
		}
	do
		makePart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * lump[2],
			Position = at + lump[1],
			Material = Enum.Material.Sand,
			Color = CLAY,
		}, model)
	end
end

-- A folded patchwork quilt.
function materialBuilders.Quilt(model: Model, at: Vector3)
	for i = 1, 3 do
		for j = 1, 2 do
			makePart({
				Size = Vector3.new(0.7, 0.2, 1.1),
				Position = at + Vector3.new((j - 1.5) * 0.7, 0.1 + (i - 1) * 0.2, 0),
				Material = Enum.Material.Fabric,
				Color = QUILT[(i * 2 + j) % #QUILT + 1],
			}, model)
		end
	end
end

-- Two glass jars with tin lids.
function materialBuilders.Jars(model: Model, at: Vector3)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	for i, tall in { 0.9, 0.65 } do
		local foot = at + Vector3.new((i - 1.5) * 0.75, 0, (i - 1.5) * 0.2)
		makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(tall, 0.6, 0.6),
			CFrame = CFrame.new(foot + Vector3.new(0, tall / 2, 0)) * upright,
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(176, 214, 226),
			Transparency = 0.3,
		}, model)
		makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 0.66, 0.66),
			CFrame = CFrame.new(foot + Vector3.new(0, tall + 0.06, 0)) * upright,
			Material = Enum.Material.Metal,
			Color = RUST,
		}, model)
	end
end

-- A small bunch of wildflowers.
function materialBuilders.Wildflowers(model: Model, at: Vector3)
	for i = 1, 4 do
		local lean = Vector3.new((i - 2.5) * 0.28, 1.1 + (i % 2) * 0.25, (i % 2 - 0.5) * 0.3)
		pole(at, at + lean, 0.07, model, MOSS)
		makePart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.36,
			Position = at + lean,
			Material = Enum.Material.SmoothPlastic,
			Color = PETALS[i],
		}, model)
	end
end

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
