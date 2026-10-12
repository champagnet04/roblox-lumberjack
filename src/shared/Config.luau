-- Every tuning number for the game lives here. Distances are in studs, times in seconds.

local RunService = game:GetService("RunService")

local GameMode = require(script.Parent.GameMode)

local Config = {}

-- Config.Mode is "Solo" or "Race": which game is being played. It is not set here. The
-- player chooses on the menu, and it is filled in when the game starts (see GameMode and
-- the end of this file). Code that reads it is only loaded after that.

Config.Race = {
	CampBuilds = 7, -- the shared camp shows this many finished builds (7 = the whole lean-to stage)

	MinPlayers = 1, -- a round starts once this many players are in the server
	FillTo = 8, -- bots join until a round has this many racers (0 = no bots)
	-- Quick Race: a new race waits this long for more players before its first countdown.
	-- It starts sooner if the server fills. Skipped in Studio, where nobody else can join.
	GatherTime = 30,
	MinJoinTime = 10, -- Quick Race only sends a player to a race that starts at least this far off
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
	-- Everyone's trees add to one count, so in a race the hidden number is made slightly
	-- larger: it is multiplied by this and rounded up (1.5 turns 1-10 into 2-15).
	-- The guardian is meant to appear often; keep this small. 1 = same as solo.
	WakeCountScale = 1.5,
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
	Enabled = true,
	BuildsDone = 26, -- start with this many camp builds already finished (7 = lean-to stage, 16 = tent camp, 26 = hut)
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
	BetterAxeSwings = 4, -- with the better axe from finishing the hut (solo only; races stay equal)
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
--   Replaces  builds that are taken down when this one goes up
--   Strips    pieces removed from an earlier build when this one goes up (build -> piece name)
Config.Camp = {
	-- A stage may also give a perk when it is finished (Perk, below).
	-- The builds come in stages. Finishing a stage makes banked wood worth one more to the
	-- camp fund: 2 times after the first stage, 3 times after the second, and so on.
	-- LastBuild is the number of the stage's last build in the list below.
	Stages = {
		{ Name = "Lean-to", LastBuild = 7 },
		{ Name = "Tent camp", LastBuild = 16 },
		{ Name = "Hut", LastBuild = 26, Perk = "BetterAxe" }, -- see Config.Tree.BetterAxeSwings
	},

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

		-- Stage 2: tent camp.
		{
			Id = "HangingPot",
			Name = "Hanging pot",
			Wood = 2200,
			Materials = {
				{ Type = "IronPot", Count = 1 },
				{ Type = "Chain", Count = 1 },
				{ Type = "Rope", Count = 1 },
			},
			Strips = { CookingFrame = "Meat" },
		},
		{
			Id = "LanternPost",
			Name = "Lantern post",
			Wood = 2600,
			Materials = {
				{ Type = "Pole", Count = 1 },
				{ Type = "Lantern", Count = 1 },
				{ Type = "Rope", Count = 1 },
			},
		},
		{
			Id = "TentPoles",
			Name = "Tent poles",
			Wood = 3000,
			Materials = { { Type = "Pole", Count = 3 }, { Type = "Rope", Count = 1 } },
			Replaces = { "LeanToFrame", "LeanToCover" },
		},
		{
			Id = "TentCanvas",
			Name = "Tent canvas",
			Wood = 3400,
			Materials = { { Type = "Canvas", Count = 3 }, { Type = "Rope", Count = 1 } },
		},
		{
			Id = "TentPegs",
			Name = "Pegs and guy ropes",
			Wood = 3800,
			Materials = { { Type = "TentPeg", Count = 2 }, { Type = "Rope", Count = 2 } },
		},
		{
			Id = "Cot",
			Name = "Cot",
			Wood = 4200,
			Materials = {
				{ Type = "Pole", Count = 2 },
				{ Type = "Canvas", Count = 1 },
				{ Type = "Rope", Count = 1 },
			},
			Replaces = { "Bedroll" },
		},
		{
			Id = "SupplyCrate",
			Name = "Supply crate",
			Wood = 4600,
			Materials = { { Type = "Plank", Count = 3 }, { Type = "Nails", Count = 1 } },
		},
		{
			Id = "DryingRack",
			Name = "Drying rack",
			Wood = 5000,
			Materials = {
				{ Type = "ForkedBranch", Count = 2 },
				{ Type = "Pole", Count = 1 },
				{ Type = "Rope", Count = 1 },
			},
		},
		{
			Id = "Clothesline",
			Name = "Clothesline",
			Wood = 5400,
			Materials = {
				{ Type = "Pole", Count = 2 },
				{ Type = "Rope", Count = 1 },
				{ Type = "Cloth", Count = 1 },
			},
		},

		-- Stage 3: the hut. It stands where the tent stood.
		{
			Id = "PicnicTable",
			Name = "Picnic table",
			Wood = 5900,
			Materials = { { Type = "Plank", Count = 3 }, { Type = "Nails", Count = 1 } },
		},
		{
			Id = "ChoppingBlock",
			Name = "Chopping block",
			Wood = 6500,
			Materials = {
				{ Type = "AxeHead", Count = 1 },
				{ Type = "Saw", Count = 1 },
				{ Type = "Rope", Count = 1 },
			},
		},
		{
			Id = "Sawhorse",
			Name = "Sawhorse and plank stack",
			Wood = 7100,
			Materials = {
				{ Type = "Pole", Count = 2 },
				{ Type = "Saw", Count = 1 },
				{ Type = "Nails", Count = 1 },
			},
		},
		{
			Id = "StoneFooting",
			Name = "Stone footing",
			Wood = 7700,
			Materials = { { Type = "FlatStone", Count = 4 } },
			Replaces = { "TentPoles", "TentCanvas", "TentPegs" },
		},
		{
			Id = "LogWalls",
			Name = "Log walls",
			Wood = 8300,
			Materials = { { Type = "Pole", Count = 2 }, { Type = "Moss", Count = 2 } },
		},
		{
			Id = "BarkRoof",
			Name = "Bark roof",
			Wood = 8900,
			Materials = { { Type = "BarkSheet", Count = 3 }, { Type = "Rope", Count = 1 } },
		},
		{
			Id = "Door",
			Name = "Door",
			Wood = 9500,
			Materials = {
				{ Type = "Plank", Count = 2 },
				{ Type = "Hinge", Count = 1 },
				{ Type = "Nails", Count = 1 },
			},
		},
		{
			Id = "Workbench",
			Name = "Workbench and tool rack",
			Wood = 10100,
			Materials = {
				{ Type = "Plank", Count = 2 },
				{ Type = "OldTools", Count = 1 },
				{ Type = "Nails", Count = 1 },
			},
		},
		{
			Id = "RainBarrel",
			Name = "Rain barrel",
			Wood = 10700,
			Materials = {
				{ Type = "Barrel", Count = 1 },
				{ Type = "Plank", Count = 2 },
				{ Type = "Rope", Count = 1 },
			},
		},
		{
			Id = "StonePath",
			Name = "Stone path",
			Wood = 11300,
			Materials = { { Type = "FlatStone", Count = 4 } },
		},
	},

	-- Every material type, in a fixed order (used for saving and the on-screen list).
	-- New kinds go on the end; the order of the earlier ones must not change.
	MaterialOrder = {
		"Sticks",
		"Flint",
		"Saw",
		"ForkedBranch",
		"Rope",
		"Pole",
		"Cloth",
		"Moss",
		"IronPot",
		"Chain",
		"Lantern",
		"Canvas",
		"TentPeg",
		"Plank",
		"Nails",
		"FlatStone",
		"AxeHead",
		"BarkSheet",
		"Hinge",
		"OldTools",
		"Barrel",
	},
	Materials = {
		Sticks = { Name = "sticks" },
		Flint = { Name = "flint" },
		Saw = { Name = "rusty saw" },
		ForkedBranch = { Name = "forked branch" },
		Rope = { Name = "rope" },
		Pole = { Name = "long pole" },
		Cloth = { Name = "cloth" },
		Moss = { Name = "moss" },
		IronPot = { Name = "iron pot" },
		Chain = { Name = "chain" },
		Lantern = { Name = "old lantern" },
		Canvas = { Name = "canvas" },
		TentPeg = { Name = "tent peg" },
		Plank = { Name = "plank" },
		Nails = { Name = "nails" },
		FlatStone = { Name = "flat stone" },
		AxeHead = { Name = "axe head" },
		BarkSheet = { Name = "bark sheet" },
		Hinge = { Name = "hinge" },
		OldTools = { Name = "old tools" },
		Barrel = { Name = "barrel" },
	},

	-- Where a material appears: between these two distances from camp for the first build
	-- of the first stage...
	MaterialMinDistance = 45,
	MaterialMaxDistance = 110,
	MaterialStagePush = 120, -- ...moving this much farther out by the last build of a stage...
	MaterialStageStart = 25, -- ...and each later stage starting this much farther out than the one before.
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
	SwingInterval = 0.45, -- seconds between a bot's swings

	-- Each bot always plays one of these ways. Careful bots stay near camp, bank small
	-- loads and are rarely caught. Greedy bots go deep for the big trees and carry a lot:
	-- they score the most when they live, and are caught the most.
	--   BankAt     heads home once it carries a number of wood picked between these two
	--   Rest       pauses for a time between these two after each tree
	--   Reaction   freezes for a time between these two when the guardian rises for it
	--   Reserve    stops chopping to catch its breath below this much stamina (out of 100),
	--              so it has some left to sprint with
	--   Push       looks for its next tree this far farther out than where it stands
	--   MaxDepth   ...until it is this far from camp, after which it works where it is
	Styles = {
		Careful = {
			BankAt = { 45, 80 },
			Rest = { 1.8, 3.2 },
			Reaction = { 0.3, 0.6 },
			Reserve = 55,
			Push = 0,
			MaxDepth = 110,
		},
		Steady = {
			BankAt = { 80, 130 },
			Rest = { 1.3, 2.6 },
			Reaction = { 0.4, 0.9 },
			Reserve = 40,
			Push = 25,
			MaxDepth = 170,
		},
		Greedy = {
			BankAt = { 130, 210 },
			Rest = { 0.8, 1.8 },
			Reaction = { 0.6, 1.1 },
			Reserve = 25,
			Push = 55,
			MaxDepth = 250,
		},
	},

	-- Style is one of the Styles above. Hat is "Beanie", "Beard" or "Both"; Trim is the colour
	-- of the beanie or beard.
	Roster = {
		{
			Name = "Big Hank",
			Style = "Greedy",
			Flannel = Color3.fromRGB(176, 40, 40),
			Hat = "Beard",
			Trim = Color3.fromRGB(70, 44, 28),
		},
		{
			Name = "Old Maple",
			Style = "Careful",
			Flannel = Color3.fromRGB(196, 110, 36),
			Hat = "Beard",
			Trim = Color3.fromRGB(214, 214, 210),
		},
		{
			Name = "Sawdust Sam",
			Style = "Steady",
			Flannel = Color3.fromRGB(206, 176, 70),
			Hat = "Beanie",
			Trim = Color3.fromRGB(60, 60, 70),
		},
		{
			Name = "Birch Betty",
			Style = "Careful",
			Flannel = Color3.fromRGB(60, 120, 170),
			Hat = "Beanie",
			Trim = Color3.fromRGB(230, 226, 214),
		},
		{
			Name = "Knotty Pete",
			Style = "Steady",
			Flannel = Color3.fromRGB(58, 122, 72),
			Hat = "Both",
			Trim = Color3.fromRGB(150, 40, 40),
		},
		{
			Name = "Granny Oak",
			Style = "Careful",
			Flannel = Color3.fromRGB(128, 84, 150),
			Hat = "Beanie",
			Trim = Color3.fromRGB(200, 200, 204),
		},
		{
			Name = "Whittlin' Joe",
			Style = "Steady",
			Flannel = Color3.fromRGB(40, 60, 110),
			Hat = "Beard",
			Trim = Color3.fromRGB(150, 96, 50),
		},
		{
			Name = "Splinter",
			Style = "Greedy",
			Flannel = Color3.fromRGB(70, 70, 76),
			Hat = "Beanie",
			Trim = Color3.fromRGB(210, 120, 40),
		},
		{
			Name = "Timber Tess",
			Style = "Greedy",
			Flannel = Color3.fromRGB(190, 70, 110),
			Hat = "Beanie",
			Trim = Color3.fromRGB(46, 84, 50),
		},
		{
			Name = "Mossy Mae",
			Style = "Steady",
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

-- A player's game learns the mode from the server. Loading this file there waits at the
-- menu until a game is chosen, so the display and controls only start once one is.
if RunService:IsClient() then
	Config.Mode = GameMode.waitForPlay()
end

return Config
