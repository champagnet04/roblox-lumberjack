-- Server entry point. Builds the world; later steps start the gameplay services here.

local LightingSetup = require(script.Parent.LightingSetup)
local PlayerSetup = require(script.Parent.PlayerSetup)
local WorldBuilder = require(script.Parent.WorldBuilder)

LightingSetup.apply()
WorldBuilder.build()
PlayerSetup.start()
