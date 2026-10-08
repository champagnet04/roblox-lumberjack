-- Every tuning number for the game lives here. Distances are in studs, times in seconds.

local Config = {}

Config.World = {
	Seed = 1, -- same seed = same tree layout every time
	GroundSize = 600,
	CampRadius = 40, -- dirt clearing
	SafeZoneRadius = 30, -- glowing ring; inside it the player is safe
	ForestRadius = 280, -- trees spawn no farther than this from camp
	TreeCount = 60,
	TreeMinDistanceFromCamp = 55,
	TreeSpacing = 14, -- minimum gap between two trees
}

Config.Player = {
	WalkSpeed = 16,
	SprintSpeed = 24,
}

Config.Stamina = {
	Max = 100,
	SprintDrainPerSecond = 12,
	SwingCost = 4,
	RegenPerSecond = 6,
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
	SwingCooldown = 0.6,
	WoodMin = 10,
	WoodMax = 20,
	RespawnTime = 60,
	ChopRange = 10,
	-- Appearance (each tree is scaled randomly between ScaleMin and ScaleMax)
	TrunkHeight = 14,
	TrunkDiameter = 3,
	CanopyDiameter = 13,
	ScaleMin = 0.8,
	ScaleMax = 1.3,
}

Config.Lorax = {
	DisplayName = "The Guardian", -- placeholder; "Lorax" is an internal code name only
	SafeTriggerRadius = 60, -- trees this close to camp never trigger it
	MaxTriggerChance = 0.25, -- chance per felled tree at the forest edge
	WarningTime = 2,
	Speed = 21,
	CaptureRange = 4,
}

return Config
