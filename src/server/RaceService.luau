-- Runs the rounds of a race (Config.Mode = "Race"). See MULTIPLAYER.md.
--
-- A server loops through these phases for as long as it is up:
--   Waiting    too few players to start
--   Lobby      a friends race waits here until its host presses Start
--   Gathering  a new race waits a while for more players to arrive (not in Studio)
--   Countdown  everyone is put back at camp and held there; the forest regrows; bots join
--              to fill the round (see BotService)
--   Running    the timed round; ends early when one racer is left standing
--   Results    places and prizes are shown, then the next countdown starts
--
-- The phase and its start and end times are published as attributes on Workspace
-- (RacePhase, RacePhaseStartedAt, RacePhaseEndsAt) for the other services and the client.
-- Times are on the shared server clock, Workspace:GetServerTimeNow().
--
-- A friends race (made with Race with Friends) has a host, who starts it and has two
-- switches, also published on Workspace: RaceBots (bots fill the empty places) and
-- RaceOpen (Quick Race may send other players here). RaceHost is the host's user id and
-- RaceInvite is what an invite to this race carries.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BotService = require(script.Parent.BotService)
local GuardianService = require(script.Parent.GuardianService)
local PlayerState = require(script.Parent.PlayerState)
local RaceDirectory = require(script.Parent.RaceDirectory)
local TreeService = require(script.Parent.TreeService)

local RaceService = {}

local TICK = 0.25
local LIST_EVERY = 3 -- seconds between updates to this server's entry in the list of open races

local friendsRace = false -- this race was made with Race with Friends and has a host
local startRequested = false -- the host has pressed Start

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

-- Everyone racing: the players and the bots. Both keep their score in a RaceScore attribute
-- and whether the guardian has caught them in a RaceOut attribute.
local function allRacers(): { Instance }
	local list: { Instance } = Players:GetPlayers()
	for _, bot in BotService.getBots() do
		table.insert(list, bot)
	end
	return list
end

local function isOut(racer: Instance): boolean
	return racer:GetAttribute("RaceOut") == true
end

local function scoreOf(racer: Instance): number
	return racer:GetAttribute("RaceScore") or 0
end

local function nameOf(racer: Instance): string
	return if racer:IsA("Player") then racer.DisplayName else racer.Name
end

-- How many racers are still standing, and how many of those are real players.
local function standingCount(): (number, number)
	local total, players = 0, 0
	for _, racer in allRacers() do
		if not isOut(racer) then
			total += 1
			if racer:IsA("Player") then
				players += 1
			end
		end
	end
	return total, players
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

-- Puts everyone back at camp with nothing carried and no score, each in their own
-- starting place round the fire. `places` counts players and bots together; the players
-- take the first ones.
local function resetRacers(places: number)
	for place, player in Players:GetPlayers() do
		PlayerState.startRound(player)
		task.spawn(function()
			player:LoadCharacter() -- waits until the new character is in the world
			local character = player.Character
			if character then
				local at = BotService.startingPlace(place, places)
				character:PivotTo(CFrame.lookAt(at, Vector3.new(at.X * 2, at.Y, at.Z * 2)))
			end
		end)
	end
end

-- Works out the places and pays the prizes. Only racers still standing are placed, by wood
-- banked; on a tie, whoever reached that score first is placed higher.
-- A prize needs at least some wood banked, so standing still at camp earns nothing.
-- Bots take places like anyone, but prizes are only paid to players.
local function scoreRound(): { Result }
	local cfg = Config.Race
	local racers = allRacers()
	table.sort(racers, function(a, b)
		local outA, outB = isOut(a), isOut(b)
		if outA ~= outB then
			return outB
		end
		local scoreA, scoreB = scoreOf(a), scoreOf(b)
		if scoreA ~= scoreB then
			return scoreA > scoreB
		end
		-- A tie goes to whoever reached that score first.
		local atA, atB = a:GetAttribute("RaceScoreAt") or 0, b:GetAttribute("RaceScoreAt") or 0
		if atA ~= atB then
			return atA < atB
		end
		return nameOf(a) < nameOf(b)
	end)

	local results: { Result } = {}
	local place = 0
	for _, racer in racers do
		local out = isOut(racer)
		local score = scoreOf(racer)
		local prize = 0
		if not out then
			place += 1
			if score > 0 and racer:IsA("Player") then
				prize = cfg.Prizes[place] or cfg.SurvivorPrize
				PlayerState.addPrize(racer, prize)
			end
		end
		table.insert(results, {
			Name = nameOf(racer),
			UserId = if racer:IsA("Player") then racer.UserId else 0,
			Score = score,
			Out = out,
			Place = if out then 0 else place,
			Prize = prize,
		})
	end
	return results
end

-- Seconds until the current phase ends.
local function phaseTimeLeft(): number
	local endsAt = Workspace:GetAttribute("RacePhaseEndsAt") or 0
	return math.max(endsAt - Workspace:GetServerTimeNow(), 0)
end

-- While a round has not started, the server is listed so Quick Race can send players
-- here. Returns a function to call every tick of the wait; `extra` is how long after the
-- current phase the round starts.
-- Whether Quick Race may send players here: always, except to a friends race whose host
-- has kept it private.
local function isOpen(): boolean
	return not friendsRace or Workspace:GetAttribute("RaceOpen") == true
end

local function keepListed(extra: number): () -> boolean
	local nextAt = 0
	return function()
		if os.clock() >= nextAt then
			nextAt = os.clock() + LIST_EVERY
			if isOpen() then
				task.spawn(RaceDirectory.announce, phaseTimeLeft() + extra)
			end
		end
		return false
	end
end

-- A new race waits a while for more players to arrive. Not in Studio: nobody can join there.
local function gather()
	local cfg = Config.Race
	if RunService:IsStudio() or cfg.GatherTime <= 0 or not isOpen() then
		return
	end
	setPhase("Gathering", cfg.GatherTime)
	local listed = keepListed(cfg.CountdownTime)
	waitFor(cfg.GatherTime, function()
		listed()
		return #Players:GetPlayers() >= Players.MaxPlayers -- full: no need to wait
	end)
end

local function run()
	local cfg = Config.Race
	local gathered = false
	while true do
		if #Players:GetPlayers() < cfg.MinPlayers then
			setPhase("Waiting")
			gathered = false
			repeat
				task.wait(TICK)
			until #Players:GetPlayers() >= cfg.MinPlayers
		end
		if not gathered then
			gathered = true
			if friendsRace then
				-- A friends race waits for its host, however long that takes.
				setPhase("Lobby")
				startRequested = false
				-- In Studio the players were at the menu and have no character yet.
				for _, player in Players:GetPlayers() do
					if not player.Character then
						task.spawn(function()
							player:LoadCharacter()
						end)
					end
				end
				repeat
					task.wait(TICK)
				until startRequested and #Players:GetPlayers() >= cfg.MinPlayers
			end
			gather()
		end

		GuardianService.reset()
		TreeService.regrowAll()
		local playerCount = #Players:GetPlayers()
		local fillTo = cfg.FillTo
		if friendsRace and Workspace:GetAttribute("RaceBots") ~= true then
			fillTo = 0 -- the host has switched bots off
		end
		local botCount = math.clamp(fillTo - playerCount, 0, #Config.Bots.Roster)
		resetRacers(playerCount + botCount)
		BotService.prepareRound(botCount, playerCount)
		setPhase("Countdown", cfg.CountdownTime)
		waitFor(cfg.CountdownTime, keepListed(0))

		local startedWith, playersAtStart = standingCount()
		if playersAtStart == 0 then
			continue -- everyone left during the countdown
		end
		GuardianService.reset() -- a fresh hidden number for the round
		setPhase("Running", cfg.RoundTime)
		task.spawn(RaceDirectory.close) -- nobody is sent into the middle of a round
		BotService.setRacing(true)
		waitFor(cfg.RoundTime, function()
			-- Over when one racer is left, or when no real player is: nobody waits for bots.
			local left, playersLeft = standingCount()
			return playersLeft == 0 or (left == 1 and startedWith >= 2)
		end)

		-- Change phase first, so nothing more can be chopped or banked while the round is scored.
		setPhase("Results", cfg.ResultsTime)
		BotService.setRacing(false)
		GuardianService.reset()
		Remotes.RaceResults:FireAllClients(scoreRound())
		waitFor(cfg.ResultsTime, keepListed(cfg.CountdownTime)) -- open again for the next round
	end
end

-- Sets this race up as a friends race hosted by the player with this user id.
local function hostFriendsRace(host: number)
	friendsRace = true
	Workspace:SetAttribute("RaceHost", host)
	Workspace:SetAttribute("RaceBots", true)
	Workspace:SetAttribute("RaceOpen", false)
	-- What an invite carries, so the menu can send an invited friend here. Empty in Studio.
	Workspace:SetAttribute(
		"RaceInvite",
		if game.PrivateServerId ~= ""
			then RaceDirectory.INVITE_PREFIX .. game.PrivateServerId
			else ""
	)

	Remotes.LobbyAction.OnServerEvent:Connect(function(player, action)
		if player.UserId ~= Workspace:GetAttribute("RaceHost") then
			return -- only the host has these controls
		end
		if action == "Start" then
			if Workspace:GetAttribute("RacePhase") == "Lobby" then
				startRequested = true
			end
		elseif action == "ToggleBots" then
			Workspace:SetAttribute("RaceBots", Workspace:GetAttribute("RaceBots") ~= true)
		elseif action == "ToggleOpen" then
			local open = Workspace:GetAttribute("RaceOpen") ~= true
			Workspace:SetAttribute("RaceOpen", open)
			if not open then
				task.spawn(RaceDirectory.close)
			end
		end
	end)

	-- If the host leaves, the player who has been here longest takes over.
	Players.PlayerRemoving:Connect(function(leaving)
		if leaving.UserId ~= Workspace:GetAttribute("RaceHost") then
			return
		end
		for _, other in Players:GetPlayers() do
			if other ~= leaving then
				Workspace:SetAttribute("RaceHost", other.UserId)
				Remotes.Notice:FireClient(other, "YOU ARE NOW THE HOST")
				return
			end
		end
	end)
end

-- `host` is given for a friends race: the user id of the player who made it.
function RaceService.start(host: number?)
	if host then
		hostFriendsRace(host)
	end

	-- Someone who joins partway through a round watches until the next one.
	local function onPlayerAdded(player: Player)
		PlayerState.setOut(player, Workspace:GetAttribute("RacePhase") == "Running")
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	setPhase("Waiting")
	task.spawn(run)
end

return RaceService
