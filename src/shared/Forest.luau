-- Shared forest maths.

local Config = require(script.Parent.Config)

local Forest = {}

-- How deep into the forest a point is: 0 at the trees nearest camp, 1 at the edge of the
-- starting forest. Once the forest has grown (Config.WorldGrowth) its far trees are deeper
-- than 1. Camp is at the origin. Deeper trees are bigger and give more wood.
function Forest.depthAt(position: Vector3): number
	local world = Config.World
	local distance = (position * Vector3.new(1, 0, 1)).Magnitude
	return math.max((distance - world.TreeMinDistanceFromCamp) / world.DepthSpan, 0)
end

return Forest
