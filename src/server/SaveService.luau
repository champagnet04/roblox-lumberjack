-- Saves each player's permanent numbers (overall bank and high scores) between sessions,
-- using Roblox data stores. The current haul and game bank are never saved.
--
-- Safety rule: if a player's data could not be loaded, it is never saved for that session,
-- so a failed load cannot overwrite real progress with zeros.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerState = require(script.Parent.PlayerState)

local SaveService = {}

local ATTEMPTS = 3

local store: DataStore? = nil
local loaded: { [Player]: boolean } = {}
local lastSaved: { [Player]: { [string]: number } } = {}
local warnedUnavailable = false

local function keyFor(player: Player): string
	return `user_{player.UserId}`
end

-- Runs a data store call, retrying a couple of times because they can fail briefly.
local function attempt(call: () -> any): (boolean, any)
	local lastError
	for try = 1, ATTEMPTS do
		local ok, result = pcall(call)
		if ok then
			return true, result
		end
		lastError = result
		if try < ATTEMPTS then
			task.wait(try)
		end
	end
	return false, lastError
end

local function warnUnavailable(reason: any)
	if warnedUnavailable then
		return
	end
	warnedUnavailable = true
	warn(
		"[SaveService] Progress will NOT be saved this session.",
		"In Studio this usually means the place is not published, or",
		"Game Settings > Security > 'Enable Studio Access to API Services' is off.",
		"Reason:",
		reason
	)
end

local function sameData(a: { [string]: number }, b: { [string]: number }?): boolean
	if not b then
		return false
	end
	for name, value in a do
		if b[name] ~= value then
			return false
		end
	end
	return true
end

local function load(player: Player)
	player:SetAttribute("SaveStatus", "Loading")

	local dataStore = store
	if not dataStore then
		player:SetAttribute("SaveStatus", "Unavailable")
		return
	end

	local ok, result = attempt(function()
		return dataStore:GetAsync(keyFor(player))
	end)
	if not player.Parent then
		return -- left while loading
	end
	if not ok then
		warnUnavailable(result)
		player:SetAttribute("SaveStatus", "Unavailable")
		return
	end

	if typeof(result) == "table" then
		PlayerState.applySaved(player, result)
	end
	loaded[player] = true
	lastSaved[player] = PlayerState.getSaved(player)
	player:SetAttribute("SaveStatus", "Ready")
end

local function save(player: Player)
	local dataStore = store
	if not dataStore or not loaded[player] then
		return
	end

	local data = PlayerState.getSaved(player)
	if sameData(data, lastSaved[player]) then
		return -- nothing new to save
	end

	local ok, result = attempt(function()
		dataStore:SetAsync(keyFor(player), data, { player.UserId })
		return nil
	end)
	if ok then
		lastSaved[player] = data
	else
		warn("[SaveService] Could not save for", player.Name, "-", result)
	end
end

function SaveService.start()
	if not Config.Save.Enabled then
		return
	end

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Save.StoreName)
	end)
	if ok then
		store = result
	else
		warnUnavailable(result)
	end

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
		lastSaved[player] = nil
	end)

	-- Regular saves, so a crash loses little.
	task.spawn(function()
		while true do
			task.wait(Config.Save.AutosaveInterval)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)

	-- When the server shuts down, save everyone before it closes.
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return SaveService
