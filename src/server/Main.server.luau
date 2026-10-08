-- Server entry point. Builds the world, then starts the gameplay services.

local CampService = require(script.Parent.CampService)
local GuardianService = require(script.Parent.GuardianService)
local LightingSetup = require(script.Parent.LightingSetup)
local MovementService = require(script.Parent.MovementService)
local PlayerSetup = require(script.Parent.PlayerSetup)
local PlayerState = require(script.Parent.PlayerState)
local TreeService = require(script.Parent.TreeService)
local WorldBuilder = require(script.Parent.WorldBuilder)

LightingSetup.apply()
WorldBuilder.build()
PlayerSetup.start()
PlayerState.start()
MovementService.start()
TreeService.start()
CampService.start()
GuardianService.start()
