-- Per-player run state, owned by the server.
-- Values are stored as attributes on the Player so the client can read them for the HUD.
--   Haul   = wood carried on the current run; at risk until banked
--   Banked = wood safely brought back to camp (not saved between sessions in Version 0)

local Players = game:GetService("Players")

local PlayerState = {}

function PlayerState.getHaul(player: Player): number
	return player:GetAttribute("Haul") or 0
end

function PlayerState.getBanked(player: Player): number
	return player:GetAttribute("Banked") or 0
end

function PlayerState.addHaul(player: Player, amount: number)
	player:SetAttribute("Haul", PlayerState.getHaul(player) + amount)
end

-- Moves the whole haul into banked wood. Returns how much was banked.
function PlayerState.bankHaul(player: Player): number
	local haul = PlayerState.getHaul(player)
	if haul > 0 then
		player:SetAttribute("Banked", PlayerState.getBanked(player) + haul)
		player:SetAttribute("Haul", 0)
	end
	return haul
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Haul", 0)
	player:SetAttribute("Banked", 0)
end

function PlayerState.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlayerState
