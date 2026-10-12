-- Reads the leaderboards for the Record Book (see RECORD_BOOK.md). Menu servers only.
--
-- Roblox's leaderboards return the top entries in order, cannot say what place a given
-- player holds, and allow only a few such requests a minute. So a board is read down to
-- 1,000th place at most once every few minutes, and that list (a "snapshot") is shared
-- between servers. Everything the Record Book shows is worked out from the snapshot: the
-- top 10, a player's own place, and which of their friends are on the board.
--
-- It only reads. Players' numbers are put on the boards by RecordService.

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Records = require(ReplicatedStorage.Shared.Records)

local BoardService = {}

local SNAPSHOTS = "BoardSnapshots"
local SNAPSHOT_KEPT_FOR = 60 * 60 -- a shared snapshot is thrown away after this long unused
local REFRESH_AFTER = 5 * 60 -- a snapshot older than this is read again
local RECHECK_SHARED = 30 -- how often this server looks for a newer shared snapshot
local MAX_RANKED = 1000 -- places are exact down to here
local PAGE_SIZE = 100
local SHOWN = 10 -- rows on a page
local FRIENDS_READ = 200 -- how many of a player's friends are looked at
local FRIENDS_KEPT_FOR = 5 * 60

type Snapshot = {
	At: number, -- when it was read, in os.time() seconds
	Ids: { number }, -- user ids in order, best first
	Values: { number },
	Names: { string }, -- names of the first few, for the top 10
}

export type Row = { Rank: number, Name: string, Value: number, You: boolean }

export type Page = {
	Failed: boolean?, -- the board could not be read
	Rows: { Row },
	You: { Rank: number?, Value: number, Beyond: boolean }, -- Beyond: below the last exact place
	UpdatedAgo: number, -- seconds since the board was read
}

local snapshots: { [string]: { Snapshot: Snapshot, CheckedAt: number } } = {}
local refreshing: { [string]: boolean } = {}
local friendsKept: { [Player]: { At: number, Names: { [number]: string } } } = {}

local function shared(): MemoryStoreHashMap
	return MemoryStoreService:GetHashMap(SNAPSHOTS)
end

local function namesOf(ids: { number }): { string }
	local names = table.create(#ids, "PLAYER")
	if #ids == 0 then
		return names
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(ids)
	end)
	if ok and typeof(infos) == "table" then
		for _, info in infos do
			local index = table.find(ids, info.Id)
			if index then
				names[index] = info.DisplayName or info.Username or names[index]
			end
		end
	end
	return names
end

-- Waits until Roblox will accept another leaderboard read. False if it does not come soon.
local function waitForBudget(): boolean
	local deadline = os.clock() + 40
	while os.clock() < deadline do
		local budget = DataStoreService:GetRequestBudgetForRequestType(
			Enum.DataStoreRequestType.GetSortedAsync
		)
		if budget > 0 then
			return true
		end
		task.wait(2)
	end
	return false
end

-- Reads a board from Roblox, down to MAX_RANKED or as far as the allowance lets it.
local function readBoard(storeName: string): Snapshot?
	local ok, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName):GetSortedAsync(false, PAGE_SIZE)
	end)
	if not ok then
		warn("[BoardService] Could not read", storeName, "-", pages)
		return nil
	end

	local ids, values = {}, {}
	while true do
		for _, entry in pages:GetCurrentPage() do
			local id = tonumber(entry.key)
			if id then
				table.insert(ids, id)
				table.insert(values, entry.value)
			end
		end
		if pages.IsFinished or #ids >= MAX_RANKED or not waitForBudget() then
			break
		end
		if not pcall(pages.AdvanceToNextPageAsync, pages) then
			break
		end
	end

	local top = table.move(ids, 1, math.min(SHOWN, #ids), 1, {})
	return { At = os.time(), Ids = ids, Values = values, Names = namesOf(top) }
end

local function refresh(storeName: string)
	-- Another server may have just done it.
	local ok, existing = pcall(function()
		return shared():GetAsync(storeName)
	end)
	local snapshot: Snapshot? = nil
	if ok and typeof(existing) == "table" and os.time() - (existing.At or 0) <= REFRESH_AFTER then
		snapshot = existing
	else
		snapshot = readBoard(storeName)
		if snapshot then
			pcall(function()
				shared():SetAsync(storeName, snapshot, SNAPSHOT_KEPT_FOR)
			end)
		end
	end
	if snapshot then
		snapshots[storeName] = { Snapshot = snapshot, CheckedAt = os.clock() }
	end
	refreshing[storeName] = nil
end

-- The latest snapshot of a board. The first request for a board waits while it is read;
-- later ones are answered at once, with a fresh read started behind them when it is due.
local function snapshotOf(storeName: string): Snapshot?
	local kept = snapshots[storeName]
	if kept and os.clock() - kept.CheckedAt > RECHECK_SHARED then
		kept.CheckedAt = os.clock()
		local ok, newer = pcall(function()
			return shared():GetAsync(storeName)
		end)
		if ok and typeof(newer) == "table" and (newer.At or 0) > kept.Snapshot.At then
			kept.Snapshot = newer
		end
	end

	local stale = not kept or os.time() - kept.Snapshot.At > REFRESH_AFTER
	if stale and not refreshing[storeName] then
		refreshing[storeName] = true
		if kept then
			task.spawn(refresh, storeName)
		else
			refresh(storeName)
		end
	elseif not kept then
		-- Someone else's request is reading it; wait for that.
		local deadline = os.clock() + 20
		while refreshing[storeName] and os.clock() < deadline do
			task.wait(0.25)
		end
	end

	kept = snapshots[storeName]
	return if kept then kept.Snapshot else nil
end

local function boardById(boardId: string)
	for _, board in Records.Boards do
		if board.Id == boardId then
			return board
		end
	end
	return nil
end

-- A player's friends, as user id -> name. Only the first FRIENDS_READ are looked at.
local function friendsOf(player: Player): { [number]: string }
	local kept = friendsKept[player]
	if kept and os.clock() - kept.At <= FRIENDS_KEPT_FOR then
		return kept.Names
	end
	local names: { [number]: string } = {}
	pcall(function()
		local pages = Players:GetFriendsAsync(player.UserId)
		local read = 0
		while true do
			for _, friend in pages:GetCurrentPage() do
				names[friend.Id] = friend.DisplayName or friend.Username
				read += 1
			end
			if pages.IsFinished or read >= FRIENDS_READ then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	friendsKept[player] = { At = os.clock(), Names = names }
	return names
end

local FAILED: Page =
	{ Failed = true, Rows = {}, You = { Value = 0, Beyond = false }, UpdatedAgo = 0 }

-- One page of the Record Book. `period` is "All" or "Week"; `kind` is "Everyone" or
-- "Friends". `saved` is the player's own saved numbers if they could be read, so that their
-- own row shows their score as it is now, not as of the last time the board was read.
function BoardService.page(
	player: Player,
	boardId: string,
	period: string,
	kind: string,
	saved: { [string]: any }?
): Page
	local board = boardById(boardId)
	if not board then
		return FAILED
	end
	local week = Records.currentWeek()
	local weekly = period == "Week"
	local snapshot = snapshotOf(Records.boardStore(board.Id, if weekly then week else nil))
	if not snapshot then
		return FAILED
	end

	local place = table.find(snapshot.Ids, player.UserId)
	local ownValue = if place then snapshot.Values[place] else 0
	if saved and (not weekly or saved.Week == week) then
		local current = saved[if weekly then board.Weekly else board.AllTime]
		if typeof(current) == "number" then
			ownValue = math.max(ownValue, current)
		end
	end

	local rows: { Row } = {}
	local you = { Rank = place, Value = ownValue, Beyond = false }

	if kind == "Friends" then
		-- You, and those of your friends who are on the board, ranked among yourselves.
		local friends = friendsOf(player)
		local list = { { Name = player.DisplayName, Value = ownValue, You = true } }
		for index, id in snapshot.Ids do
			if friends[id] then
				table.insert(
					list,
					{ Name = friends[id], Value = snapshot.Values[index], You = false }
				)
			end
		end
		table.sort(list, function(a, b)
			if a.Value ~= b.Value then
				return a.Value > b.Value
			end
			return a.Name < b.Name
		end)
		you.Rank = nil
		for rank, entry in list do
			if entry.You then
				you.Rank = rank
			end
			if rank <= SHOWN then
				table.insert(
					rows,
					{ Rank = rank, Name = entry.Name, Value = entry.Value, You = entry.You }
				)
			end
		end
	else
		for rank = 1, math.min(SHOWN, #snapshot.Ids) do
			table.insert(rows, {
				Rank = rank,
				Name = snapshot.Names[rank] or "PLAYER",
				Value = snapshot.Values[rank],
				You = snapshot.Ids[rank] == player.UserId,
			})
		end
		-- Not on the list: either below the last exact place, or too new to be on it yet.
		you.Beyond = place == nil and #snapshot.Ids >= MAX_RANKED
	end

	return {
		Rows = rows,
		You = you,
		UpdatedAgo = math.max(os.time() - snapshot.At, 0),
	}
end

function BoardService.forget(player: Player)
	friendsKept[player] = nil
end

return BoardService
