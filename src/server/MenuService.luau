-- The menu players see when they join, and the moves between the menu and a game.
--
-- In the published game, a server anyone can join is a menu server. Choosing Solo makes a
-- private server for that player and sends them to it. The new server has to know what it
-- is for, so the menu server leaves a note under the new server's id, which the new server
-- reads when it starts (see roleOfThisServer).
--
-- In Studio players cannot be moved between servers, so the choice is handed back to
-- Main, which starts that game in the same server.
--
-- Quick Race works the same way, except that it first looks for a race that is still
-- gathering players (see RaceDirectory) and only makes a new server if there is none.
--
-- Race with Friends makes a private race server with the player as its host. Friends are
-- invited from inside it; an invited friend arrives at a menu server first, carrying the
-- race server's id, and is sent straight on (see followInvite).

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Records = require(ReplicatedStorage.Shared.Records)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CampModels = require(script.Parent.CampModels)
local RaceDirectory = require(script.Parent.RaceDirectory)

local MenuService = {}

local ROLE_NOTES = "ServerRoles"
local NOTE_LIFETIME = 600 -- seconds a note is kept; the new server reads it within a few
local MOVE_ATTEMPTS = 3
local FAILED = "COULD NOT GET THERE. PLEASE TRY AGAIN."

local busy: { [Player]: boolean } = {}

-- Records already read for the Record Book, kept briefly so reopening it costs nothing.
local RECORDS_KEPT_FOR = 30
local recordsRead: { [Player]: { At: number, Saved: { [string]: any }? } } = {}

local function roleNotes(): MemoryStoreHashMap
	return MemoryStoreService:GetHashMap(ROLE_NOTES)
end

-- What this private server was made for: "Solo" or "Race". Only for the published game.
-- It may wait several seconds for the note, and then for the first player to arrive.
-- Returns the mode, and for a friends race the user id of the player who made it.
function MenuService.roleOfThisServer(): (string, number?)
	for _ = 1, 5 do
		local ok, note = pcall(function()
			return roleNotes():GetAsync(game.PrivateServerId)
		end)
		if ok and typeof(note) == "table" and (note.Mode == "Solo" or note.Mode == "Race") then
			return note.Mode, if typeof(note.Host) == "number" then note.Host else nil
		end
		task.wait(1)
	end

	-- No note: fall back to what the first player was sent here with.
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local data = player:GetJoinData().TeleportData
	if typeof(data) == "table" and (data.Mode == "Solo" or data.Mode == "Race") then
		return data.Mode, if typeof(data.Host) == "number" then data.Host else nil
	end
	warn("[MenuService] Could not tell what this server is for; running the solo game.")
	return "Solo", nil
end

local function tell(player: Player, text: string)
	if player.Parent then
		Remotes.MenuStatus:FireClient(player, text)
	end
end

-- Makes a private server for a game and leaves a note saying what it is for.
-- `host` is given for a friends race: the user id of the player making it.
-- Returns the code needed to send players there.
local function makeServer(mode: string, host: number?): string
	local accessCode, serverId = TeleportService:ReserveServer(game.PlaceId)
	roleNotes():SetAsync(serverId, { Mode = mode, Host = host }, NOTE_LIFETIME)
	if mode == "Race" and host then
		RaceDirectory.saveCode(serverId, accessCode) -- private: reachable by invite only
	elseif mode == "Race" then
		RaceDirectory.register(serverId, accessCode)
	end
	return accessCode
end

local function teleport(player: Player, accessCode: string, data: { [string]: any })
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData(data)
	TeleportService:TeleportAsync(game.PlaceId, { player }, options)
end

-- Sends the player to a game, trying a few times. `kind` is "Solo" (their own camp),
-- "QuickRace" (a race that is gathering players, or a new one) or "FriendsRace" (a new
-- private race that they host).
local function send(player: Player, kind: string)
	tell(
		player,
		if kind == "Solo"
			then "HEADING TO YOUR CAMP..."
			elseif kind == "QuickRace" then "FINDING A RACE..."
			else "SETTING UP YOUR RACE..."
	)
	local mode = if kind == "Solo" then "Solo" else "Race"
	local host = if kind == "FriendsRace" then player.UserId else nil
	local lastError
	for attempt = 1, MOVE_ATTEMPTS do
		local ok, result = pcall(function()
			local accessCode = if kind == "QuickRace" then RaceDirectory.findOpen() else nil
			if not accessCode then
				accessCode = makeServer(mode, host)
			end
			teleport(player, accessCode, { Mode = mode, Host = host })
		end)
		if ok or not player.Parent then
			return
		end
		lastError = result
		task.wait(attempt)
	end
	warn("[MenuService] Could not send", player.Name, "to a", kind, "server:", lastError)
	tell(player, FAILED)
end

-- A friend who accepted an invite arrives at the menu carrying the id of the race they
-- were invited to. Send them straight on to it.
local function followInvite(player: Player)
	local launch = player:GetJoinData().LaunchData
	if typeof(launch) ~= "string" then
		return
	end
	local serverId = string.match(launch, "^" .. RaceDirectory.INVITE_PREFIX .. "(.+)$")
	if not serverId then
		return
	end

	busy[player] = true
	tell(player, "JOINING YOUR FRIEND'S RACE...")
	local accessCode = RaceDirectory.codeFor(serverId)
	local ok = accessCode ~= nil
		and pcall(teleport, player, accessCode :: string, { Mode = "Race" })
	if not ok then
		tell(player, "COULD NOT FIND THAT RACE. IT MAY HAVE ENDED.")
	end
	busy[player] = nil
end

-- Sends a player their saved records for the Record Book. This only reads their saved
-- progress; nothing at the menu ever writes it.
local function sendRecords(player: Player)
	local kept = recordsRead[player]
	if not kept or os.clock() - kept.At > RECORDS_KEPT_FOR then
		local ok, saved = pcall(function()
			local store = DataStoreService:GetDataStore(Config.Save.StoreName)
			return store:GetAsync(Records.saveKey(player.UserId))
		end)
		if not player.Parent then
			return
		end
		kept = {
			At = os.clock(),
			-- nil means it could not be read; an empty table means nothing is saved yet.
			Saved = if not ok then nil elseif typeof(saved) == "table" then saved else {},
		}
		recordsRead[player] = kept
	end
	Remotes.Records:FireClient(player, {
		Saved = kept.Saved,
		TotalBuilds = #Config.Camp.Builds,
	})
end

-- The camp shown behind the menu: the finished lean-to stage.
local function buildBackdrop(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "MenuCamp"
	folder.Parent = Workspace:WaitForChild("World"):WaitForChild("Camp")
	task.spawn(function()
		local deadline = os.clock() + 10
		while not CampModels.groundIsReady() and os.clock() < deadline do
			task.wait(0.1)
		end
		for index, build in Config.Camp.Builds do
			if index <= Config.Race.CampBuilds and folder.Parent then
				CampModels.build(build.Id, folder)
			end
		end
	end)
	return folder
end

-- Runs the menu. `startHere` is given in Studio only: it starts the chosen game ("Solo" or
-- "Race") in this server, once, for everyone in it. For a friends race it is also given
-- the user id of the player who chose it, who becomes the host.
function MenuService.start(startHere: ((mode: string, host: number?) -> ())?)
	local backdrop = buildBackdrop()
	local started = false

	Workspace:SetAttribute("MenuRaceOpen", true) -- Quick Race works; the menu shows it as open

	Remotes.ChooseMode.OnServerEvent:Connect(function(player, choice)
		if started or busy[player] then
			return
		end

		if startHere then
			if choice == "Solo" or choice == "QuickRace" or choice == "FriendsRace" then
				started = true
				backdrop:Destroy()
				for _, other in Players:GetPlayers() do
					other.ReplicationFocus = nil
				end
				startHere(
					if choice == "Solo" then "Solo" else "Race",
					if choice == "FriendsRace" then player.UserId else nil
				)
			end
			return
		end

		if choice == "Solo" or choice == "QuickRace" or choice == "FriendsRace" then
			busy[player] = true
			send(player, choice)
			busy[player] = nil
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		recordsRead[player] = nil
	end)

	Remotes.RequestRecords.OnServerEvent:Connect(sendRecords)

	-- Nobody has a character at the menu, so tell Roblox to show each player the camp.
	local camp = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local function onPlayerAdded(player: Player)
		if camp and not started then
			player.ReplicationFocus = camp
		end
		if not startHere then
			task.spawn(followInvite, player)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- If Roblox reports that a move failed after it began, say so and free the buttons.
	TeleportService.TeleportInitFailed:Connect(function(player)
		busy[player] = nil
		tell(player, FAILED)
	end)
end

-- Lets players in a game go back to the menu. Call once when a game starts.
function MenuService.listenForReturn()
	Remotes.ReturnToMenu.OnServerEvent:Connect(function(player)
		if busy[player] then
			return
		end
		if RunService:IsStudio() then
			Remotes.Notice:FireClient(player, "IN STUDIO: STOP, THEN PRESS PLAY, TO SEE THE MENU")
			return
		end
		busy[player] = true
		local ok, result = pcall(function()
			-- With no private server named, this goes to a server anyone can join: a menu server.
			TeleportService:TeleportAsync(game.PlaceId, { player })
		end)
		if not ok then
			warn("[MenuService] Could not send", player.Name, "to the menu:", result)
			Remotes.Notice:FireClient(player, "COULD NOT REACH THE MENU. TRY AGAIN.")
		end
		busy[player] = nil
	end)
end

return MenuService
