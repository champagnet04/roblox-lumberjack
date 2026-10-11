-- Server entry point. Builds the world, then starts the gameplay services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BotService = require(script.Parent.BotService)
local CampBuildService = require(script.Parent.CampBuildService)
local CampService = require(script.Parent.CampService)
local GuardianService = require(script.Parent.GuardianService)
local LightingSetup = require(script.Parent.LightingSetup)
local MovementService = require(script.Parent.MovementService)
local PlayerSetup = require(script.Parent.PlayerSetup)
local PlayerState = require(script.Parent.PlayerState)
local RaceService = require(script.Parent.RaceService)
local SaveService = require(script.Parent.SaveService)
local TreeService = require(script.Parent.TreeService)
local WorldBuilder = require(script.Parent.WorldBuilder)

LightingSetup.apply()
WorldBuilder.build()
PlayerSetup.start()
PlayerState.start()
SaveService.start() -- in a race too: prizes are paid into the saved camp fund
MovementService.start()
TreeService.start()
CampService.start()
if Config.Mode == "Race" then
	-- One finished camp for everyone, and rounds.
	CampBuildService.startShared(Config.Race.CampBuilds)
	GuardianService.start()
	BotService.start()
	RaceService.start()
else
	CampBuildService.start()
	GuardianService.start()
end
