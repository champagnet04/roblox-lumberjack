-- The safe zone. Detects players inside the stone ring and banks their haul when they arrive.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)

local CampService = {}

local CHECK_INTERVAL = 0.2

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
