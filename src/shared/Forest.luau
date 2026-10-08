-- Shared forest maths.

local Config = require(script.Parent.Config)

local Forest = {}

-- How deep into the forest a point is: 0 at the trees nearest camp, 1 at the forest edge.
-- Camp is at the origin. Deeper trees are bigger and give more wood.
function Forest.depthAt(position: Vector3): number
	local world = Config.World
	local distance = (position * Vector3.new(1, 0, 1)).Magnitude
	local depth = (distance - world.TreeMinDistanceFromCamp)
		/ (world.ForestRadius - world.TreeMinDistanceFromCamp)
	return math.clamp(depth, 0, 1)
end

return Forest
