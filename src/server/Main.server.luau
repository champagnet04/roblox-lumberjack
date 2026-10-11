-- Server entry point. Builds the world, then starts the gameplay services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CampBuildService = require(script.Parent.CampBuildService)
local CampService = require(script.Parent.CampService)
local GuardianService = require(script.Parent.GuardianService)
local LightingSetup = require(script.Parent.LightingSetup)
local MovementService = require(script.Parent.MovementService)
local PlayerSetup = require(script.Parent.PlayerSetup)
local PlayerState = require(script.Parent.PlayerState)
local SaveService = require(script.Parent.SaveService)
local TreeService = require(script.Parent.TreeService)
local WorldBuilder = require(script.Parent.WorldBuilder)

LightingSetup.apply()
WorldBuilder.build()
PlayerSetup.start()
PlayerState.start()
MovementService.start()
TreeService.start()
CampService.start()
if Config.Mode == "Race" then
	-- A race saves nothing and has one finished camp for everyone.
	CampBuildService.startShared(Config.Race.CampBuilds)
else
	SaveService.start()
	CampBuildService.start()
end
GuardianService.start()
