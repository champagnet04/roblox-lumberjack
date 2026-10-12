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
-- Not built yet: Race with Friends (MULTIPLAYER.md).

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CampModels = require(script.Parent.CampModels)
local RaceDirectory = require(script.Parent.RaceDirectory)

local MenuService = {}

local ROLE_NOTES = "ServerRoles"
local NOTE_LIFETIME = 600 -- seconds a note is kept; the new server reads it within a few
local MOVE_ATTEMPTS = 3
local FAILED = "COULD NOT GET THERE. PLEASE TRY AGAIN."

local busy: { [Player]: boolean } = {}

local function roleNotes(): MemoryStoreHashMap
	return MemoryStoreService:GetHashMap(ROLE_NOTES)
end

-- What this private server was made for: "Solo" or "Race". Only for the published game.
-- It may wait several seconds for the note, and then for the first player to arrive.
function MenuService.roleOfThisServer(): string
	for _ = 1, 5 do
		local ok, role = pcall(function()
			return roleNotes():GetAsync(game.PrivateServerId)
		end)
		if ok and (role == "Solo" or role == "Race") then
			return role
		end
		task.wait(1)
	end

	-- No note: fall back to what the first player was sent here with.
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local data = player:GetJoinData().TeleportData
	if typeof(data) == "table" and (data.Mode == "Solo" or data.Mode == "Race") then
		return data.Mode
	end
	warn("[MenuService] Could not tell what this server is for; running the solo game.")
	return "Solo"
end

local function tell(player: Player, text: string)
	if player.Parent then
		Remotes.MenuStatus:FireClient(player, text)
	end
end

-- Makes a private server for a game and leaves a note saying what it is for.
-- Returns the code needed to send players there.
local function makeServer(mode: string): string
	local accessCode, serverId = TeleportService:ReserveServer(game.PlaceId)
	roleNotes():SetAsync(serverId, mode, NOTE_LIFETIME)
	if mode == "Race" then
		RaceDirectory.register(serverId, accessCode)
	end
	return accessCode
end

-- Sends the player to their own camp ("Solo"), or to a race that is gathering players,
-- making a new one if there is none ("Race").
local function send(player: Player, mode: string)
	tell(player, if mode == "Race" then "FINDING A RACE..." else "HEADING TO YOUR CAMP...")
	local lastError
	for attempt = 1, MOVE_ATTEMPTS do
		local ok, result = pcall(function()
			local accessCode = if mode == "Race" then RaceDirectory.findOpen() else nil
			if not accessCode then
				accessCode = makeServer(mode)
			end

			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = accessCode
			options:SetTeleportData({ Mode = mode })
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if ok or not player.Parent then
			return
		end
		lastError = result
		task.wait(attempt)
	end
	warn("[MenuService] Could not send", player.Name, "to a", mode, "server:", lastError)
	tell(player, FAILED)
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
-- "Race") in this server, once, for everyone in it.
function MenuService.start(startHere: ((mode: string) -> ())?)
	local backdrop = buildBackdrop()
	local started = false

	Workspace:SetAttribute("MenuRaceOpen", true) -- Quick Race works; the menu shows it as open

	Remotes.ChooseMode.OnServerEvent:Connect(function(player, choice)
		if started or busy[player] then
			return
		end

		if startHere then
			if choice == "Solo" or choice == "QuickRace" then
				started = true
				backdrop:Destroy()
				for _, other in Players:GetPlayers() do
					other.ReplicationFocus = nil
				end
				startHere(if choice == "Solo" then "Solo" else "Race")
			end
			return
		end

		if choice == "Solo" or choice == "QuickRace" then
			busy[player] = true
			send(player, if choice == "Solo" then "Solo" else "Race")
			busy[player] = nil
		else
			tell(player, "RACING WITH FRIENDS IS COMING SOON")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)

	-- Nobody has a character at the menu, so tell Roblox to show each player the camp.
	local camp = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local function onPlayerAdded(player: Player)
		if camp and not started then
			player.ReplicationFocus = camp
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
