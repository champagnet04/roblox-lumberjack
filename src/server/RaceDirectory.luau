-- How Quick Race finds a race to join, across servers. Published game only; in Studio
-- every function here does nothing.
--
-- A race server that can still take players keeps an entry in a shared list ("OpenRaces")
-- saying when its next round starts and how many players it has. The menu looks through
-- that list for a race with room and enough time left to get there, and only makes a new
-- race server when there is none. A race is only listed before a round starts, so nobody
-- is sent into the middle of one.
--
-- To send a player to a private server the menu needs that server's access code, which
-- only the server that created it is given. So the code is saved under the new server's id
-- for the race server itself to read and put in its entry.
--
-- If the shared list cannot be reached, nothing breaks: each player simply gets a new
-- race of their own, filled with bots.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local RaceDirectory = {}

-- An invite to a friends race carries this followed by the race server's id.
RaceDirectory.INVITE_PREFIX = "race:"

local OPEN_RACES = "OpenRaces"
local SERVER_CODES = "RaceServerCodes"
local CODE_LIFETIME = 6 * 60 * 60 -- a race server can list itself for this long after it is made
local LOOK_AT = 20 -- how many open races the menu looks through

local IN_STUDIO = RunService:IsStudio()
local ownCode: string? = nil

type Entry = {
	Code: string, -- the access code needed to send a player there
	StartsAt: number, -- when its next round starts, in os.time() seconds
	Count: number, -- players there now
}

local function openRaces(): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap(OPEN_RACES)
end

local function serverCodes(): MemoryStoreHashMap
	return MemoryStoreService:GetHashMap(SERVER_CODES)
end

local function list(serverId: string, entry: Entry)
	local lifetime = math.max(entry.StartsAt - os.time(), 1) + 5
	openRaces():SetAsync(serverId, entry, lifetime, entry.StartsAt)
end

-- Menu server: saves a new race server's access code under its id. The race server reads
-- it to list itself, and the menu reads it to send an invited friend to a friends race.
function RaceDirectory.saveCode(serverId: string, accessCode: string)
	if IN_STUDIO then
		return
	end
	pcall(function()
		serverCodes():SetAsync(serverId, accessCode, CODE_LIFETIME)
	end)
end

-- Menu server: the access code of the race server with this id, or nil if it is not known
-- (the race is over, or the id is wrong).
function RaceDirectory.codeFor(serverId: string): string?
	if IN_STUDIO then
		return nil
	end
	local ok, code = pcall(function()
		return serverCodes():GetAsync(serverId)
	end)
	return if ok and typeof(code) == "string" then code else nil
end

-- Menu server: records a Quick Race server it has just made, and lists it as open straight
-- away so that other players pressing Quick Race in the same moment join it rather than
-- making their own.
function RaceDirectory.register(serverId: string, accessCode: string)
	if IN_STUDIO then
		return
	end
	local cfg = Config.Race
	RaceDirectory.saveCode(serverId, accessCode)
	pcall(function()
		-- A guess at when it will start; the race server corrects it once it is running.
		list(serverId, {
			Code = accessCode,
			StartsAt = os.time() + cfg.GatherTime + cfg.CountdownTime + 10,
			Count = 1,
		})
	end)
end

-- Menu server: the access code of a race that has room and has not started, or nil.
function RaceDirectory.findOpen(): string?
	if IN_STUDIO then
		return nil
	end
	local ok, items = pcall(function()
		return openRaces():GetRangeAsync(Enum.SortDirection.Ascending, LOOK_AT)
	end)
	if not ok or typeof(items) ~= "table" then
		return nil
	end
	local now = os.time()
	for _, item in items do
		local entry = item.value
		if
			typeof(entry) == "table"
			and typeof(entry.Code) == "string"
			and (entry.Count or 0) < Players.MaxPlayers
			and (entry.StartsAt or 0) - now >= Config.Race.MinJoinTime
		then
			return entry.Code
		end
	end
	return nil
end

-- Race server: lists this server as open, with its next round starting in this many seconds.
function RaceDirectory.announce(startsIn: number)
	if IN_STUDIO or game.PrivateServerId == "" then
		return
	end
	pcall(function()
		if not ownCode then
			ownCode = serverCodes():GetAsync(game.PrivateServerId)
		end
		if ownCode then
			list(game.PrivateServerId, {
				Code = ownCode,
				StartsAt = os.time() + math.ceil(startsIn),
				Count = #Players:GetPlayers(),
			})
		end
	end)
end

-- Race server: takes this server off the list. Called when a round starts.
function RaceDirectory.close()
	if IN_STUDIO or game.PrivateServerId == "" then
		return
	end
	pcall(function()
		openRaces():RemoveAsync(game.PrivateServerId)
	end)
end

return RaceDirectory
