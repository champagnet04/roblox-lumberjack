-- Per-player run state, owned by the server.
-- Values are stored as attributes on the Player so the client can read them for the HUD.

local Players = game:GetService("Players")

local PlayerState = {}

function PlayerState.getHaul(player: Player): number
	return player:GetAttribute("Haul") or 0
end

function PlayerState.addHaul(player: Player, amount: number)
	player:SetAttribute("Haul", PlayerState.getHaul(player) + amount)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Haul", 0)
end

function PlayerState.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlayerState
