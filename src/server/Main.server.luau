-- Server entry point. Builds the world; later steps start the gameplay services here.

local WorldBuilder = require(script.Parent.WorldBuilder)

WorldBuilder.build()
