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
--   RaceScore   wood banked this round of a race (Config.Mode = "Race"); a score only, never saved
--   RaceOut     true once the guardian has caught the player this round
--   RaceScoreAt when RaceScore last went up (server clock); on a tie, the earlier wins
--
-- Race records, saved (see RECORD_BOOK.md):
--   RaceWins, BestRaceScore, RacesRun, RacePodiums (top-three finishes)
-- This week's numbers for the weekly leaderboards, saved with the week they belong to:
--   Week, WeekRaceWins, WeekBestRaceScore, WeekBestHaul, WeekBuilds
--
-- A game ends when the guardian captures the player.
-- OverallBank, the three records, BuildsDone and banked materials are saved between
-- sessions by SaveService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Camp = require(ReplicatedStorage.Shared.Camp)
local Config = require(ReplicatedStorage.Shared.Config)
local Records = require(ReplicatedStorage.Shared.Records)

local PlayerState = {}

local IS_RACE = Config.Mode == "Race"

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
	PlayerState.ensureWeek(player)
	player:SetAttribute("WeekBuilds", get(player, "WeekBuilds") + 1)
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
	if IS_RACE then
		-- In a race, banked wood is only a score, and only counts while the round is on.
		if haul == 0 or not PlayerState.canRace(player) then
			return 0
		end
		player:SetAttribute("RaceScore", get(player, "RaceScore") + haul)
		player:SetAttribute("RaceScoreAt", Workspace:GetServerTimeNow())
		player:SetAttribute("Haul", 0)
		return haul
	end
	if haul > 0 then
		if haul > get(player, "BestHaul") then
			player:SetAttribute("BestHaul", haul)
		end
		PlayerState.ensureWeek(player)
		if haul > get(player, "WeekBestHaul") then
			player:SetAttribute("WeekBestHaul", haul)
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
		-- The camp fund gets more for each piece of wood as stages are finished. The game
		-- bank and the records stay in plain wood, so players can be compared fairly.
		local worth = Camp.woodWorth(get(player, "BuildsDone"))
		player:SetAttribute("OverallBank", get(player, "OverallBank") + haul * worth)
		player:SetAttribute("GameBank", get(player, "GameBank") + haul)
		player:SetAttribute("Haul", 0)
	end
	return haul
end

function PlayerState.getRaceScore(player: Player): number
	return get(player, "RaceScore")
end

function PlayerState.isOut(player: Player): boolean
	return player:GetAttribute("RaceOut") == true
end

function PlayerState.setOut(player: Player, out: boolean)
	player:SetAttribute("RaceOut", out)
end

-- True while a race round is running and the guardian has not caught this player.
-- Only then can they chop or bank.
function PlayerState.canRace(player: Player): boolean
	return Workspace:GetAttribute("RacePhase") == "Running" and not PlayerState.isOut(player)
end

-- Clears a racer for the start of a round.
function PlayerState.startRound(player: Player)
	player:SetAttribute("Haul", 0)
	player:SetAttribute("RaceScore", 0)
	player:SetAttribute("RaceScoreAt", 0)
	player:SetAttribute("RaceOut", false)
	tripFurthest[player] = nil
end

-- Notes a finished race in the player's records. `place` is 1 for the winner and 0 if the
-- guardian caught them. A win or a top-three finish only counts with wood banked and at
-- least one other racer, so a race run alone cannot be used to pile up wins.
function PlayerState.recordRace(player: Player, place: number, score: number, racers: number)
	PlayerState.ensureWeek(player)
	player:SetAttribute("RacesRun", get(player, "RacesRun") + 1)
	if score > get(player, "BestRaceScore") then
		player:SetAttribute("BestRaceScore", score)
	end
	if score > get(player, "WeekBestRaceScore") then
		player:SetAttribute("WeekBestRaceScore", score)
	end
	if score <= 0 or racers < 2 then
		return
	end
	if place >= 1 and place <= 3 then
		player:SetAttribute("RacePodiums", get(player, "RacePodiums") + 1)
	end
	if place == 1 then
		player:SetAttribute("RaceWins", get(player, "RaceWins") + 1)
		player:SetAttribute("WeekRaceWins", get(player, "WeekRaceWins") + 1)
	end
end

-- What a race prize of `amount` is worth to this player: multiplied, like banked wood, by
-- how far their own camp has got.
function PlayerState.prizeWorth(player: Player, amount: number): number
	return amount * Camp.woodWorth(get(player, "BuildsDone"))
end

-- Pays a race prize into the camp fund.
function PlayerState.addPrize(player: Player, amount: number)
	player:SetAttribute("OverallBank", get(player, "OverallBank") + amount)
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

-- This week's numbers. They start again from zero each Monday (see Records.currentWeek).
local WEEKLY = { "WeekRaceWins", "WeekBestRaceScore", "WeekBestHaul", "WeekBuilds" }

-- The numbers that are kept between sessions.
local SAVED = {
	"OverallBank",
	"BestHaul",
	"BestGame",
	"FurthestTree",
	"BuildsDone",
	"RaceWins",
	"BestRaceScore",
	"RacesRun",
	"RacePodiums",
	"Week",
}
for _, name in WEEKLY do
	table.insert(SAVED, name)
end
for _, materialType in Config.Camp.MaterialOrder do
	table.insert(SAVED, `Mat_{materialType}`)
end

-- Numbers that count things up. The rest are records, where the higher value is kept.
local COUNTED = {
	OverallBank = true,
	RaceWins = true,
	RacesRun = true,
	RacePodiums = true,
	WeekRaceWins = true,
	WeekBuilds = true,
}

-- If a new week has begun since the player's weekly numbers were last touched, clears them.
function PlayerState.ensureWeek(player: Player)
	local week = Records.currentWeek()
	if get(player, "Week") ~= week then
		for _, name in WEEKLY do
			player:SetAttribute(name, 0)
		end
		player:SetAttribute("Week", week)
	end
end

function PlayerState.getSaved(player: Player): { [string]: number }
	local data = {}
	for _, name in SAVED do
		data[name] = get(player, name)
	end
	return data
end

-- Applies numbers loaded from a save. Anything earned before the load finished is kept:
-- counts are added on top, and records keep whichever value is higher.
-- Saved weekly numbers are only used if they belong to the week it is now.
function PlayerState.applySaved(player: Player, data: { [string]: any })
	PlayerState.ensureWeek(player)
	local sameWeek = data.Week == Records.currentWeek()

	for _, name in SAVED do
		local value = data[name]
		local usable = typeof(value) == "number"
			and name ~= "Week"
			and (sameWeek or not table.find(WEEKLY, name))
		if usable then
			if COUNTED[name] then
				player:SetAttribute(name, get(player, name) + value)
			else
				player:SetAttribute(name, math.max(get(player, name), value))
			end
		end
	end
end

-- True when the Studio-only test settings in Config.Testing are switched on.
function PlayerState.isTesting(): boolean
	return Config.Testing.Enabled and RunService:IsStudio()
end

-- Starts the player from the state described in Config.Testing.
local function applyTestState(player: Player)
	local testing = Config.Testing
	local buildsDone = math.clamp(testing.BuildsDone, 0, #Config.Camp.Builds)
	player:SetAttribute("BuildsDone", buildsDone)
	player:SetAttribute("OverallBank", testing.Wood)

	local nextBuild = Config.Camp.Builds[buildsDone + 1]
	if testing.GiveNextMaterials and nextBuild then
		for _, requirement in nextBuild.Materials do
			player:SetAttribute(`Mat_{requirement.Type}`, requirement.Count)
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
	for _, name in { "Haul", "GameBank", "RaceScore" } do
		player:SetAttribute(name, 0)
	end
	for _, name in SAVED do
		player:SetAttribute(name, 0)
	end
	player:SetAttribute("CarriedMaterial", "")
	player:SetAttribute("RaceOut", false)
	PlayerState.ensureWeek(player)
	if PlayerState.isTesting() and not IS_RACE then
		applyTestState(player)
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
