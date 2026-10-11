-- The safe zone. Detects players inside the stone ring and banks their haul when they arrive.
-- In a race it also keeps racers the guardian has caught inside the ring until the next round.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)

local CampService = {}

local CHECK_INTERVAL = 0.2
local HOLD_MARGIN = 3 -- a held racer is put back this far inside the ring's edge

-- Puts a caught racer who has wandered out of the ring back just inside it.
local function holdInCamp(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local flat = root.Position * Vector3.new(1, 0, 1)
	if flat.Magnitude <= Config.World.SafeZoneRadius then
		return
	end
	local inside = flat.Unit * (Config.World.SafeZoneRadius - HOLD_MARGIN)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = root.CFrame.Rotation + Vector3.new(inside.X, root.Position.Y, inside.Z)
end

-- Camp is centred on the origin, so distance from camp is distance from (0, 0) on the ground.
function CampService.isInCamp(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local flat = root.Position * Vector3.new(1, 0, 1)
	return flat.Magnitude <= Config.World.SafeZoneRadius
end

function CampService.start()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				if PlayerState.isOut(player) then
					holdInCamp(player)
				end
				local inCamp = CampService.isInCamp(player)
				local justArrived = inCamp and not player:GetAttribute("InCamp")
				player:SetAttribute("InCamp", inCamp)
				if inCamp then
					local banked = PlayerState.bankHaul(player)
					-- A material only banks alongside wood; say so, or it looks like a bug.
					if banked == 0 and justArrived and PlayerState.getCarried(player) ~= "" then
						Remotes.Notice:FireClient(player, "BRING WOOD TO BANK YOUR MATERIAL")
					end
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return CampService
