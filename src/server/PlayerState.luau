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
--   BuildsDone  how many camp builds are finished
--   Mat_<Type>  banked materials of each type, waiting to be used in a build
--   CarriedMaterial  the one material being carried this trip ("" for none); at risk like the haul
--
-- A game ends when the guardian captures the player.
-- OverallBank, the three records, BuildsDone and banked materials are saved between
-- sessions by SaveService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerState = {}

-- Fires with the player when their game ends (the guardian caught them).
local gameEnded = Instance.new("BindableEvent")
PlayerState.GameEnded = gameEnded.Event

export type GameSummary = {
	WoodLost: number, -- the haul being carried when caught
	MaterialLost: string, -- the material being carried when caught ("" for none)
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

function PlayerState.getOverallBank(player: Player): number
	return get(player, "OverallBank")
end

function PlayerState.getBuildsDone(player: Player): number
	return get(player, "BuildsDone")
end

function PlayerState.getMaterial(player: Player, materialType: string): number
	return get(player, `Mat_{materialType}`)
end

function PlayerState.getCarried(player: Player): string
	return player:GetAttribute("CarriedMaterial") or ""
end

function PlayerState.setCarried(player: Player, materialType: string)
	player:SetAttribute("CarriedMaterial", materialType)
end

-- Pays for a camp build from the overall bank and banked materials, and marks it done.
-- The caller checks that the player can afford it.
function PlayerState.completeBuild(
	player: Player,
	build: {
		Wood: number,
		Materials: { { Type: string, Count: number } },
	}
)
	player:SetAttribute("OverallBank", get(player, "OverallBank") - build.Wood)
	for _, requirement in build.Materials do
		local name = `Mat_{requirement.Type}`
		player:SetAttribute(name, math.max(get(player, name) - requirement.Count, 0))
	end
	player:SetAttribute("BuildsDone", get(player, "BuildsDone") + 1)
end

function PlayerState.addHaul(player: Player, amount: number)
	player:SetAttribute("Haul", get(player, "Haul") + amount)
end

-- Notes how far from camp a felled tree stood.
function PlayerState.recordTreeDistance(player: Player, distance: number)
	tripFurthest[player] = math.max(tripFurthest[player] or 0, distance)
end

-- Moves the whole haul into the game bank and the overall bank. Returns how much was banked.
-- A carried material is banked with it; without wood, nothing banks.
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
		local carried = PlayerState.getCarried(player)
		if carried ~= "" then
			local name = `Mat_{carried}`
			player:SetAttribute(name, get(player, name) + 1)
			player:SetAttribute("CarriedMaterial", "")
		end
		player:SetAttribute("OverallBank", get(player, "OverallBank") + haul)
		player:SetAttribute("GameBank", get(player, "GameBank") + haul)
		player:SetAttribute("Haul", 0)
	end
	return haul
end

-- Throws away the whole haul and any carried material. Returns how much wood was lost.
function PlayerState.loseHaul(player: Player): number
	local haul = get(player, "Haul")
	player:SetAttribute("Haul", 0)
	player:SetAttribute("CarriedMaterial", "")
	tripFurthest[player] = nil -- a trip that did not make it home sets no distance record
	return haul
end

-- Ends the current game: the haul is lost, the game bank is scored and reset.
-- The overall bank is untouched, because banked wood was already added to it.
function PlayerState.endGame(player: Player): GameSummary
	local materialLost = PlayerState.getCarried(player)
	local lost = PlayerState.loseHaul(player)
	local gameBank = get(player, "GameBank")
	local isBest = gameBank > get(player, "BestGame")
	if isBest then
		player:SetAttribute("BestGame", gameBank)
	end
	player:SetAttribute("GameBank", 0)
	gameEnded:Fire(player)

	return {
		WoodLost = lost,
		MaterialLost = materialLost,
		GameBank = gameBank,
		BestGame = get(player, "BestGame"),
		IsBestGame = isBest,
		BestHaul = get(player, "BestHaul"),
		FurthestTree = get(player, "FurthestTree"),
		OverallBank = get(player, "OverallBank"),
	}
end

-- The numbers that are kept between sessions.
local SAVED = { "OverallBank", "BestHaul", "BestGame", "FurthestTree", "BuildsDone" }
for _, materialType in Config.Camp.MaterialOrder do
	table.insert(SAVED, `Mat_{materialType}`)
end

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
	for _, name in { "Haul", "GameBank" } do
		player:SetAttribute(name, 0)
	end
	for _, name in SAVED do
		player:SetAttribute(name, 0)
	end
	player:SetAttribute("CarriedMaterial", "")
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
