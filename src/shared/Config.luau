-- Every tuning number for the game lives here. Distances are in studs, times in seconds.

local Config = {}

Config.World = {
	Seed = 1, -- same seed = same forest layout every time
	GroundSize = 720,
	CampRadius = 26, -- dirt clearing; the ground is flat inside it
	SafeZoneRadius = 22, -- ring of stones and lanterns; inside it the player is safe
	ForestRadius = 280, -- edge of the playable forest
	HillHeight = 14, -- rough height difference between hilltops and dips
	HillScale = 90, -- larger = wider, gentler hills

	TreeCount = 420, -- choppable trees
	TreeMinDistanceFromCamp = 32,
	TreeSpacing = 11, -- minimum gap between two trees

	-- Giant scenery trees beyond the playable edge that hide the end of the world.
	BorderTreeCount = 200,
	BorderDepth = 45,

	BushCount = 380,
	RockCount = 130,
	FallenLogCount = 45,
}

Config.Lighting = {
	ClockTime = 0, -- midnight; the campfire and the torch are the main lights
	Brightness = 1.5, -- moonlight strength
	Ambient = Color3.fromRGB(52, 64, 84),
	OutdoorAmbient = Color3.fromRGB(70, 86, 110),
	ExposureCompensation = 0,
	FogDensity = 0.38,
	FogHaze = 2,
	FogColor = Color3.fromRGB(95, 120, 135),
	FogDecay = Color3.fromRGB(25, 40, 50),

	CampfireRange = 60, -- 60 is the engine maximum for a point light
	CampfireBrightness = 4,
	LanternRange = 18,
	LanternBrightness = 1.2,
	TorchRange = 40,
	TorchBrightness = 1.6,
	WarmLight = Color3.fromRGB(255, 170, 90),
}

Config.Player = {
	WalkSpeed = 16,
	SprintSpeed = 24,
	CameraMaxZoom = 24, -- keeps the camera under the canopy
	ChaseCameraZoom = 36, -- the camera pulls back this far while the guardian is hunting you
}

Config.Stamina = {
	Max = 100,
	SprintDrainPerSecond = 12,
	SwingCost = 4,
	RegenPerSecond = 6,
	RegenDelay = 1.5, -- pause after a swing or sprint before stamina starts refilling
	SprintMinToStart = 10, -- after running dry, stamina needed before sprinting again
	LowThreshold = 30, -- below this, speed starts dropping
	LowSpeedMultiplier = 0.75, -- speed multiplier at zero stamina
}

-- Speed multiplier by current haul, interpolated between these points.
Config.Carry = {
	{ Haul = 0, Speed = 1.00 },
	{ Haul = 50, Speed = 1.00 },
	{ Haul = 150, Speed = 0.95 },
	{ Haul = 300, Speed = 0.90 },
	{ Haul = 500, Speed = 0.82 },
	{ Haul = 700, Speed = 0.72 },
}

Config.Tree = {
	SwingsToFell = 5,
	SwingCooldown = 0.35, -- time between swings while the button is held
	WoodMin = 10, -- wood from a tree beside camp
	WoodMax = 20,
	DeepWoodMultiplier = 3, -- trees at the forest edge give this many times more
	RespawnTime = 180, -- slow enough that the trees near camp run out and you must go deeper
	DepthSizeWeight = 0.7, -- how much of a tree's size comes from depth (the rest is random)
	ChopRange = 10,
	-- Appearance: pines with a bare lower trunk and stacked tiers of needles
	HeightMin = 45,
	HeightMax = 80,
	TrunkDiameterMin = 2.5,
	TrunkDiameterMax = 5,
	ClearanceMin = 14, -- bare trunk below the lowest needles
	ClearanceMax = 22,
	FoliageWidthMin = 20, -- width of the lowest tier
	FoliageWidthMax = 30,
	Tiers = 4,
	BorderHeightMin = 90,
	BorderHeightMax = 125,
	BorderTrunkDiameterMin = 8,
	BorderTrunkDiameterMax = 12,
	BorderFoliageWidth = 46,
	BorderTiers = 3,
}

-- The creature that hunts the player. An original design; the name is a placeholder.
Config.Guardian = {
	DisplayName = "The Guardian",
	-- Each trip out of camp, a hidden number between these two is picked.
	-- The guardian wakes when the player has felled that many trees.
	-- For testing, set both to 1 to wake it on the first tree.
	WakeAfterTreesMin = 2,
	WakeAfterTreesMax = 10,
	RiseTime = 1.5, -- it rises out of the fallen tree's stump for this long
	WaitTime = 1, -- then stands still for this long before it starts chasing
	Speed = 21,
	CaptureRange = 4,
	-- It turns see-through when it comes this close to the line between camera and player.
	SeeThroughDistance = 6,
	SeeThroughAmount = 0.7, -- 0 = solid, 1 = invisible
}

return Config
