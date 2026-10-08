-- Generates the ground as Roblox terrain: gentle hills that flatten out to Y = 0 at camp.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local TerrainBuilder = {}

local CELL = 4 -- terrain voxels are 4 studs wide
local DEPTH = 24 -- how far the ground extends below Y = 0

local function smoothstep(from: number, to: number, value: number): number
	local t = math.clamp((value - from) / (to - from), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Ground height at any point. Everything placed in the world uses this to sit on the hills.
function TerrainBuilder.heightAt(x: number, z: number): number
	local world = Config.World
	local seed = world.Seed * 17.31
	local hills = math.noise(x / world.HillScale, z / world.HillScale, seed) * world.HillHeight
	local bumps = math.noise(x / 28, z / 28, seed + 50) * world.HillHeight * 0.25
	local distance = math.sqrt(x * x + z * z)
	local flatten = smoothstep(world.CampRadius, world.CampRadius + 60, distance)
	return (hills + bumps) * flatten
end

function TerrainBuilder.build()
	local world = Config.World
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(58, 92, 52))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(48, 78, 46))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(92, 72, 52))

	local half = world.GroundSize / 2
	local seed = world.Seed * 5.77
	for x = -half, half - CELL, CELL do
		for z = -half, half - CELL, CELL do
			local cx, cz = x + CELL / 2, z + CELL / 2
			local top = TerrainBuilder.heightAt(cx, cz)
			local distance = math.sqrt(cx * cx + cz * cz)

			local material = Enum.Material.Grass
			if distance < world.CampRadius + math.noise(cx / 9, cz / 9, seed) * 4 then
				material = Enum.Material.Ground
			elseif math.noise(cx / 40, cz / 40, seed + 20) > 0.2 then
				material = Enum.Material.LeafyGrass
			end

			terrain:FillBlock(
				CFrame.new(cx, (top - DEPTH) / 2, cz),
				Vector3.new(CELL, top + DEPTH, CELL),
				material
			)
		end
	end
end

return TerrainBuilder
