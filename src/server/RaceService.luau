-- Runs the rounds of a race (Config.Mode = "Race"). See MULTIPLAYER.md.
--
-- A server loops through these phases for as long as it is up:
--   Waiting    too few players to start
--   Countdown  everyone is put back at camp and held there; the forest regrows
--   Running    the timed round; ends early when one racer is left standing
--   Results    places and prizes are shown, then the next countdown starts
--
-- The phase and its start and end times are published as attributes on Workspace
-- (RacePhase, RacePhaseStartedAt, RacePhaseEndsAt) for the other services and the client.
-- Times are on the shared server clock, Workspace:GetServerTimeNow().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuardianService = require(script.Parent.GuardianService)
local PlayerState = require(script.Parent.PlayerState)
local TreeService = require(script.Parent.TreeService)

local RaceService = {}

local TICK = 0.25

export type Result = {
	Name: string,
	UserId: number,
	Score: number,
	Out: boolean, -- the guardian caught them this round
	Place: number, -- 1 for the winner; 0 for anyone who was caught
	Prize: number,
}

local function setPhase(phase: string, duration: number?)
	local now = Workspace:GetServerTimeNow()
	Workspace:SetAttribute("RacePhase", phase)
	Workspace:SetAttribute("RacePhaseStartedAt", now)
	Workspace:SetAttribute("RacePhaseEndsAt", if duration then now + duration else now)
end

local function standingCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if not PlayerState.isOut(player) then
			count += 1
		end
	end
	return count
end

-- Waits out a phase. Returns early if `finished` says the phase is over.
local function waitFor(duration: number, finished: (() -> boolean)?)
	local endsAt = os.clock() + duration
	while os.clock() < endsAt do
		if finished and finished() then
			return
		end
		task.wait(TICK)
	end
end

-- Puts everyone back at camp with nothing carried and no score.
local function resetRacers()
	for _, player in Players:GetPlayers() do
		PlayerState.startRound(player)
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

-- Works out the places and pays the prizes. Only racers still standing are placed, by wood
-- banked. A prize needs at least some wood banked, so standing still at camp earns nothing.
local function scoreRound(): { Result }
	local cfg = Config.Race
	local racers = Players:GetPlayers()
	table.sort(racers, function(a, b)
		local outA, outB = PlayerState.isOut(a), PlayerState.isOut(b)
		if outA ~= outB then
			return outB
		end
		local scoreA, scoreB = PlayerState.getRaceScore(a), PlayerState.getRaceScore(b)
		if scoreA ~= scoreB then
			return scoreA > scoreB
		end
		return a.Name < b.Name
	end)

	local results: { Result } = {}
	local place = 0
	for _, player in racers do
		local out = PlayerState.isOut(player)
		local score = PlayerState.getRaceScore(player)
		local prize = 0
		if not out then
			place += 1
			if score > 0 then
				prize = cfg.Prizes[place] or cfg.SurvivorPrize
				PlayerState.addPrize(player, prize)
			end
		end
		table.insert(results, {
			Name = player.DisplayName,
			UserId = player.UserId,
			Score = score,
			Out = out,
			Place = if out then 0 else place,
			Prize = prize,
		})
	end
	return results
end

local function run()
	local cfg = Config.Race
	while true do
		if #Players:GetPlayers() < cfg.MinPlayers then
			setPhase("Waiting")
			repeat
				task.wait(TICK)
			until #Players:GetPlayers() >= cfg.MinPlayers
		end

		GuardianService.reset()
		TreeService.regrowAll()
		resetRacers()
		setPhase("Countdown", cfg.CountdownTime)
		waitFor(cfg.CountdownTime)

		local startedWith = standingCount()
		if startedWith == 0 then
			continue -- everyone left during the countdown
		end
		GuardianService.reset() -- a fresh hidden number for the round
		setPhase("Running", cfg.RoundTime)
		waitFor(cfg.RoundTime, function()
			local left = standingCount()
			return left == 0 or (left == 1 and startedWith >= 2)
		end)

		-- Change phase first, so nothing more can be chopped or banked while the round is scored.
		setPhase("Results", cfg.ResultsTime)
		GuardianService.reset()
		Remotes.RaceResults:FireAllClients(scoreRound())
		waitFor(cfg.ResultsTime)
	end
end

function RaceService.start()
	-- Someone who joins partway through a round watches until the next one.
	local function onPlayerAdded(player: Player)
		PlayerState.setOut(player, Workspace:GetAttribute("RacePhase") == "Running")
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	setPhase("Waiting")
	task.spawn(run)
end

return RaceService
