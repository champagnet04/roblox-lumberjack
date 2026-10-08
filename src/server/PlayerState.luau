-- Per-player wood and scores, owned by the server.
-- Values are stored as attributes on the Player so the client can read them for the HUD.
--
--   Haul        wood carried right now; at risk until banked
--   GameBank    wood banked so far in the current game; back to 0 when the game ends
--   OverallBank everything ever banked; never lost; spent on camp upgrades (later)
--   BestHaul    the most wood banked in a single trip
--   BestGame    the highest GameBank a game has finished with
--   FurthestTree the greatest distance from camp (in studs) of a tree felled on a trip that
--               made it home
--
-- A game ends when the guardian captures the player.
-- OverallBank and the three records are saved between sessions by SaveService.

local Players = game:GetService("Players")

local PlayerState = {}

export type GameSummary = {
	WoodLost: number, -- the haul being carried when caught
	GameBank: number, -- what this game banked in total
	BestGame: number,
	IsBestGame: boolean, -- this game set a new best
	BestHaul: number,
	FurthestTree: number,
	OverallBank: number,
}

-- Distance of the furthest tree felled on the current trip. It only becomes a record
-- once the player gets back to camp.
local tripFurthest: { [Player]: number } = {}

local function get(player: Player, name: string): number
	return player:GetAttribute(name) or 0
end

function PlayerState.getHaul(player: Player): number
	return get(player, "Haul")
end

function PlayerState.addHaul(player: Player, amount: number)
	player:SetAttribute("Haul", get(player, "Haul") + amount)
end

-- Notes how far from camp a felled tree stood.
function PlayerState.recordTreeDistance(player: Player, distance: number)
	tripFurthest[player] = math.max(tripFurthest[player] or 0, distance)
end

-- Moves the whole haul into the game bank and the overall bank. Returns how much was banked.
function PlayerState.bankHaul(player: Player): number
	local haul = get(player, "Haul")
	if haul > 0 then
		if haul > get(player, "BestHaul") then
			player:SetAttribute("BestHaul", haul)
		end
		local furthest = math.round(tripFurthest[player] or 0)
		if furthest > get(player, "FurthestTree") then
			player:SetAttribute("FurthestTree", furthest)
		end
		tripFurthest[player] = nil
		player:SetAttribute("OverallBank", get(player, "OverallBank") + haul)
		player:SetAttribute("GameBank", get(player, "GameBank") + haul)
		player:SetAttribute("Haul", 0)
	end
	return haul
end

-- Throws away the whole haul. Returns how much was lost.
function PlayerState.loseHaul(player: Player): number
	local haul = get(player, "Haul")
	player:SetAttribute("Haul", 0)
	tripFurthest[player] = nil -- a trip that did not make it home sets no distance record
	return haul
end

-- Ends the current game: the haul is lost, the game bank is scored and reset.
-- The overall bank is untouched, because banked wood was already added to it.
function PlayerState.endGame(player: Player): GameSummary
	local lost = PlayerState.loseHaul(player)
	local gameBank = get(player, "GameBank")
	local isBest = gameBank > get(player, "BestGame")
	if isBest then
		player:SetAttribute("BestGame", gameBank)
	end
	player:SetAttribute("GameBank", 0)

	return {
		WoodLost = lost,
		GameBank = gameBank,
		BestGame = get(player, "BestGame"),
		IsBestGame = isBest,
		BestHaul = get(player, "BestHaul"),
		FurthestTree = get(player, "FurthestTree"),
		OverallBank = get(player, "OverallBank"),
	}
end

-- The numbers that are kept between sessions.
local SAVED = { "OverallBank", "BestHaul", "BestGame", "FurthestTree" }

function PlayerState.getSaved(player: Player): { [string]: number }
	local data = {}
	for _, name in SAVED do
		data[name] = get(player, name)
	end
	return data
end

-- Applies numbers loaded from a save. Anything earned before the load finished is kept:
-- banked wood is added on top, and records keep whichever value is higher.
function PlayerState.applySaved(player: Player, data: { [string]: any })
	for _, name in SAVED do
		local value = data[name]
		if typeof(value) == "number" then
			if name == "OverallBank" then
				player:SetAttribute(name, get(player, name) + value)
			else
				player:SetAttribute(name, math.max(get(player, name), value))
			end
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	-- Dying any other way (falling, resetting) also loses the haul,
	-- so resetting is not a free trip home. The game itself carries on.
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		PlayerState.loseHaul(player)
	end)
end

local function onPlayerAdded(player: Player)
	for _, name in { "Haul", "GameBank", "OverallBank", "BestHaul", "BestGame", "FurthestTree" } do
		player:SetAttribute(name, 0)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function PlayerState.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		tripFurthest[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlayerState
