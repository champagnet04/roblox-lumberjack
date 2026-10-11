-- Every tuning number for the game lives here. Distances are in studs, times in seconds.

local Config = {}

-- Which game this server runs.
--   "Solo"  the single-player game: your own camp, saved between sessions.
--   "Race"  the multiplayer race (see MULTIPLAYER.md): one shared camp, one guardian for
--           everyone, and nothing saved. For now it is switched on here by hand, for
--           testing in Studio with several players. A menu will choose it later.
Config.Mode = "Race"

Config.Race = {
	CampBuilds = 7, -- the shared camp shows this many finished builds (7 = the whole lean-to stage)

	MinPlayers = 1, -- a round starts once this many players are in the server
	FillTo = 8, -- bots join until a round has this many racers (0 = no bots)
	CountdownTime = 10, -- everyone is held at camp this long before the round starts
	RoundTime = 360, -- length of a round; lower it to test the end of a round quickly
	ResultsTime = 12, -- the results stay up this long before the next countdown

	-- Wood paid into the camp fund, by place among the racers still standing at the end.
	-- A caught racer gets nothing, and so does anyone who banked no wood at all.
	Prizes = { 300, 200, 100 },
	SurvivorPrize = 50, -- for fourth place and below

	-- Rising danger: over the round the guardian's hidden wake number and its speed move
	-- from the usual values in Config.Guardian to these.
	WakeAfterTreesMaxAtEnd = 3,
	GuardianSpeedAtEnd = 24, -- a sprinting player's top speed
}

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

-- Test settings. They only ever apply inside Roblox Studio, never in the published game.
-- While Enabled is true, every Play starts from the state below and nothing is loaded or saved.
Config.Testing = {
	Enabled = false,
	BuildsDone = 7, -- start with this many camp builds already finished (0 to 7)
	Wood = 1000, -- start with this much wood in the overall bank
	GiveNextMaterials = true, -- start with every material the next build needs
}

Config.Save = {
	Enabled = true,
	-- Changing this name starts everyone from zero (the old data is kept under the old name).
	StoreName = "PlayerData_v1",
	AutosaveInterval = 60,
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
	-- Seconds before a felled tree regrows. 0 = it stays down until the game ends, so the
	-- trees near camp run out and you must go deeper.
	RespawnTime = 0,
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

-- Camp progression: builds are completed in this order. Each costs banked wood plus
-- materials found in the forest, one material per trip.
Config.Camp = {
	Builds = {
		{
			Id = "FirePit",
			Name = "Fire pit",
			Wood = 100,
			Materials = { { Type = "Sticks", Count = 1 }, { Type = "Flint", Count = 1 } },
		},
		{
			Id = "StumpStools",
			Name = "Stump stools",
			Wood = 200,
			Materials = { { Type = "Saw", Count = 1 } },
		},
		{
			Id = "CookingFrame",
			Name = "Cooking frame",
			Wood = 350,
			Materials = { { Type = "ForkedBranch", Count = 2 }, { Type = "Rope", Count = 1 } },
		},
		{
			Id = "Woodpile",
			Name = "Woodpile",
			Wood = 500,
			Materials = { { Type = "Rope", Count = 2 } },
		},
		{
			Id = "LeanToFrame",
			Name = "Lean-to frame",
			Wood = 700,
			Materials = { { Type = "Pole", Count = 2 }, { Type = "Rope", Count = 1 } },
		},
		{
			Id = "LeanToCover",
			Name = "Lean-to cover",
			Wood = 1000,
			Materials = { { Type = "Cloth", Count = 2 } },
		},
		{
			Id = "Bedroll",
			Name = "Bedroll",
			Wood = 1400,
			Materials = { { Type = "Cloth", Count = 1 }, { Type = "Moss", Count = 2 } },
		},
	},

	-- Every material type, in a fixed order (used for saving and the on-screen list).
	MaterialOrder = { "Sticks", "Flint", "Saw", "ForkedBranch", "Rope", "Pole", "Cloth", "Moss" },
	Materials = {
		Sticks = { Name = "sticks" },
		Flint = { Name = "flint" },
		Saw = { Name = "rusty saw" },
		ForkedBranch = { Name = "forked branch" },
		Rope = { Name = "rope" },
		Pole = { Name = "long pole" },
		Cloth = { Name = "cloth" },
		Moss = { Name = "moss" },
	},

	-- Where a material appears: this far from camp for the first build...
	MaterialMinDistance = 45,
	MaterialMaxDistance = 110,
	MaterialDistanceStepPerBuild = 20, -- ...and this much farther out for each build completed
	MaterialRespawnDelay = 3, -- seconds after banking or losing one before the next appears
	MaterialGlowRange = 22, -- how far its light reaches
	MaterialScale = 3, -- materials are drawn this many times larger than life so they can be seen
	MaterialHoverHeight = 3.5, -- they float this far above the ground, clear of the long grass
	PickupRange = 5,

	BuildRange = 14, -- how close to the outline you must stand to build
	PromptHeight = 5, -- the build prompt floats this far above the outline, so it does not cover it
	BuildHoldTime = 1, -- seconds the build prompt must be held
	GhostTransparency = 0.8, -- how faint the glowing outline of the next build is (1 = invisible)
}

-- The bot lumberjacks that fill out a race. See MULTIPLAYER.md.
Config.Bots = {
	TorchShadows = false, -- shadows from seven extra torches are costly to draw
	-- Bots walk, sprint and tire by the same numbers as a player (Config.Player and
	-- Config.Stamina). They sprint only when the guardian is after them.
	-- A bot freezes for a time between these two when the guardian rises for it.
	ReactionMin = 0.4,
	ReactionMax = 1,
	SwingInterval = 0.45, -- seconds between a bot's swings
	-- A bot heads home once it carries a number of wood picked between these two.
	BankAtMin = 50,
	BankAtMax = 110,
	-- It pauses for a time between these two after each tree, standing in for stamina.
	RestMin = 2,
	RestMax = 4.5,

	-- Hat is "Beanie", "Beard" or "Both"; Trim is the colour of the beanie or beard.
	Roster = {
		{
			Name = "Big Hank",
			Flannel = Color3.fromRGB(176, 40, 40),
			Hat = "Beard",
			Trim = Color3.fromRGB(70, 44, 28),
		},
		{
			Name = "Old Maple",
			Flannel = Color3.fromRGB(196, 110, 36),
			Hat = "Beard",
			Trim = Color3.fromRGB(214, 214, 210),
		},
		{
			Name = "Sawdust Sam",
			Flannel = Color3.fromRGB(206, 176, 70),
			Hat = "Beanie",
			Trim = Color3.fromRGB(60, 60, 70),
		},
		{
			Name = "Birch Betty",
			Flannel = Color3.fromRGB(60, 120, 170),
			Hat = "Beanie",
			Trim = Color3.fromRGB(230, 226, 214),
		},
		{
			Name = "Knotty Pete",
			Flannel = Color3.fromRGB(58, 122, 72),
			Hat = "Both",
			Trim = Color3.fromRGB(150, 40, 40),
		},
		{
			Name = "Granny Oak",
			Flannel = Color3.fromRGB(128, 84, 150),
			Hat = "Beanie",
			Trim = Color3.fromRGB(200, 200, 204),
		},
		{
			Name = "Whittlin' Joe",
			Flannel = Color3.fromRGB(40, 60, 110),
			Hat = "Beard",
			Trim = Color3.fromRGB(150, 96, 50),
		},
		{
			Name = "Splinter",
			Flannel = Color3.fromRGB(70, 70, 76),
			Hat = "Beanie",
			Trim = Color3.fromRGB(210, 120, 40),
		},
		{
			Name = "Timber Tess",
			Flannel = Color3.fromRGB(190, 70, 110),
			Hat = "Beanie",
			Trim = Color3.fromRGB(46, 84, 50),
		},
		{
			Name = "Mossy Mae",
			Flannel = Color3.fromRGB(96, 140, 60),
			Hat = "Beanie",
			Trim = Color3.fromRGB(110, 78, 52),
		},
	},
}

-- The creature that hunts the player. An original design; the name is a placeholder.
Config.Guardian = {
	DisplayName = "The Guardian",
	-- A hidden number between these two is picked, and the guardian wakes when the player has
	-- felled that many trees. Banking does not reset the count; a new number is picked only
	-- when he wakes. For testing, set both to 1 to wake it on every tree.
	WakeAfterTreesMin = 1,
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
