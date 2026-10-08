-- Models for the camp builds and for the materials found in the forest.
-- Everything is assembled from basic parts. Camp is at the origin on flat ground at Y = 0.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CampModels = {}

local WOOD = Color3.fromRGB(96, 66, 46)
local DARK_WOOD = Color3.fromRGB(70, 48, 32)
local ROPE = Color3.fromRGB(176, 148, 104)
local CLOTH = Color3.fromRGB(196, 180, 150)
local MOSS = Color3.fromRGB(70, 120, 62)
local FLINT = Color3.fromRGB(120, 124, 134)
local GHOST = Color3.fromRGB(255, 214, 120)

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

-- A cylinder standing straight up from a point on the ground.
local function post(base: Vector3, height: number, diameter: number, parent: Instance): Part
	return makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
	}, parent)
end

local function onCircle(degrees: number, radius: number, y: number): Vector3
	local angle = math.rad(degrees)
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

local function tangentAt(degrees: number): Vector3
	local angle = math.rad(degrees)
	return Vector3.new(-math.sin(angle), 0, math.cos(angle))
end

-- The lean-to stands on the far side of the fire from the spawn point, open toward the fire.
-- Points are given in its own space: X along the ridge, Y up, -Z toward the fire.
local LEAN_TO = CFrame.lookAt(Vector3.new(-14, 0, 0), Vector3.zero)
local RIDGE_HEIGHT = 5.5
local RIDGE_HALF_LENGTH = 4.5
local RIDGE_Z = -1
local BACK_Z = 4.5

local function leanToPoint(x: number, y: number, z: number): Vector3
	return LEAN_TO:PointToWorldSpace(Vector3.new(x, y, z))
end

local builders: { [string]: (model: Model) -> () } = {}

-- Logs leaning together inside the stone ring, alight.
function builders.FirePit(model: Model)
	for i = 1, 4 do
		local degrees = i * 90 + 23
		pole(onCircle(degrees, 1.8, 0.3), onCircle(degrees, -0.3, 2.8), 0.8, model, DARK_WOOD).Name =
			"Log"
	end

	local flame = makePart({
		Name = "Flame",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 1.6, 0),
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

-- Two log benches beside the fire.
function builders.LogSeat(model: Model)
	for _, degrees in { 120, 240 } do
		local centre = onCircle(degrees, 9, 0.8)
		local tangent = tangentAt(degrees)
		pole(centre - tangent * 4, centre + tangent * 4, 1.8, model).Name = "Bench"
	end
end

-- A stack of cut logs: three, then two, then one.
function builders.Woodpile(model: Model)
	local degrees = 300
	local centre = onCircle(degrees, 14, 0)
	local along = tangentAt(degrees) * 2.5
	local across = onCircle(degrees, 1, 0)
	local diameter = 1.1
	for row, count in { 3, 2, 1 } do
		for i = 1, count do
			local offset = across * ((i - (count + 1) / 2) * diameter)
			local height = Vector3.new(0, diameter * (0.5 + (row - 1) * 0.86), 0)
			pole(
				centre + offset + height - along,
				centre + offset + height + along,
				diameter,
				model,
				DARK_WOOD
			).Name =
				"Log"
		end
	end
end

-- Two posts, a ridge pole and slanted poles running back to the ground.
function builders.LeanToFrame(model: Model)
	for _, side in { -1, 1 } do
		post(leanToPoint(side * RIDGE_HALF_LENGTH, 0, RIDGE_Z), RIDGE_HEIGHT, 0.6, model).Name =
			"Post"
	end
	pole(
		leanToPoint(-RIDGE_HALF_LENGTH - 0.5, RIDGE_HEIGHT, RIDGE_Z),
		leanToPoint(RIDGE_HALF_LENGTH + 0.5, RIDGE_HEIGHT, RIDGE_Z),
		0.5,
		model
	).Name =
		"Ridge"
	for i = 0, 4 do
		local x = -RIDGE_HALF_LENGTH + i * (RIDGE_HALF_LENGTH * 2 / 4)
		pole(leanToPoint(x, RIDGE_HEIGHT, RIDGE_Z), leanToPoint(x, 0.2, BACK_Z), 0.35, model).Name =
			"Rafter"
	end
end

-- A cloth sheet laid over the slanted poles.
function builders.LeanToCover(model: Model)
	local top = leanToPoint(0, RIDGE_HEIGHT, RIDGE_Z)
	local bottom = leanToPoint(0, 0.2, BACK_Z)
	makePart({
		Name = "Cover",
		Size = Vector3.new(RIDGE_HALF_LENGTH * 2 + 0.6, 0.2, (bottom - top).Magnitude + 0.4),
		-- Laid along the slope and lifted slightly so it rests on top of the poles.
		CFrame = CFrame.lookAt((top + bottom) / 2, bottom, LEAN_TO.UpVector - LEAN_TO.LookVector)
			* CFrame.new(0, 0.3, 0),
		Material = Enum.Material.Fabric,
		Color = CLOTH,
	}, model)
end

-- A bedroll and pillow under the lean-to.
function builders.Bedroll(model: Model)
	makePart({
		Name = "Bedroll",
		Size = Vector3.new(6, 0.4, 2.6),
		CFrame = LEAN_TO * CFrame.new(0, 0.2, 1.8),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(120, 60, 50),
	}, model)
	makePart({
		Name = "Pillow",
		Size = Vector3.new(1.3, 0.5, 2),
		CFrame = LEAN_TO * CFrame.new(-2.3, 0.6, 1.8),
		Material = Enum.Material.Fabric,
		Color = CLOTH,
	}, model)
	makePart({
		Name = "MossPadding",
		Size = Vector3.new(6.6, 0.15, 3.2),
		CFrame = LEAN_TO * CFrame.new(0, 0.05, 1.8),
		Material = Enum.Material.Grass,
		Color = MOSS,
		CanCollide = false,
	}, model)
end

-- Builds one camp structure, in place, by its Id from Config.Camp.Builds.
function CampModels.build(id: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = id
	local builder = builders[id]
	if builder then
		builder(model)
	else
		warn("[CampModels] No model for build", id)
	end
	model.Parent = parent
	return model
end

-- Adds a glowing edge and tint in the shape of the model, visible in the dark.
local function addGlow(model: Model, fillTransparency: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = GHOST
	highlight.FillTransparency = fillTransparency
	highlight.OutlineColor = GHOST
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
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
	addGlow(model, 0.75)
end

local materialBuilders: { [string]: (model: Model, at: Vector3) -> () } = {}

function materialBuilders.Sticks(model: Model, at: Vector3)
	for i = 1, 3 do
		local side = Vector3.new(0, 0, (i - 2) * 0.35)
		pole(
			at + side + Vector3.new(-1.4, 0.25, 0),
			at + side + Vector3.new(1.4, 0.25 + (i % 2) * 0.2, 0),
			0.25,
			model,
			DARK_WOOD
		)
	end
end

function materialBuilders.Flint(model: Model, at: Vector3)
	makePart({
		Size = Vector3.new(0.9, 0.6, 1.2),
		CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0.3, 0.6, 0.2),
		Material = Enum.Material.Slate,
		Color = FLINT,
	}, model)
end

function materialBuilders.Branch(model: Model, at: Vector3)
	pole(at + Vector3.new(-2, 0.3, 0), at + Vector3.new(2, 0.4, 0), 0.5, model, DARK_WOOD)
	pole(at + Vector3.new(0.4, 0.4, 0), at + Vector3.new(1.4, 1.1, 0.8), 0.25, model, DARK_WOOD)
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

	addGlow(model, 0.35)

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
