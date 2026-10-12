-- Publishes each player's leaderboard numbers to Roblox's ordered data stores, one store
-- per board and per week (see RECORD_BOOK.md and Records).
--
-- It only writes. Reading the boards for the menu is a later step.
-- It never touches a player's saved progress: it is given a copy of the numbers.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Records = require(ReplicatedStorage.Shared.Records)

local RecordService = {}

-- What has already been written for each player this session, by store name, so the same
-- number is not sent twice.
local published: { [Player]: { [string]: number } } = {}

local function write(player: Player, storeName: string, value: number)
	local sent = published[player]
	if not sent or value <= 0 or sent[storeName] == value then
		return
	end
	local ok, problem = pcall(function()
		DataStoreService:GetOrderedDataStore(storeName):SetAsync(tostring(player.UserId), value)
	end)
	if ok then
		sent[storeName] = value
	else
		warn("[RecordService] Could not update", storeName, "for", player.Name, "-", problem)
	end
end

-- Sends on whichever of the player's leaderboard numbers have changed.
-- `data` is their saved numbers, as PlayerState.getSaved returns them. It may pause.
function RecordService.publish(player: Player, data: { [string]: number })
	if player.UserId <= 0 then
		return -- a Studio test player, not a real account
	end
	published[player] = published[player] or {}

	local week = Records.currentWeek()
	for _, board in Records.Boards do
		write(player, Records.boardStore(board.Id), data[board.AllTime] or 0)
		if data.Week == week then
			write(player, Records.boardStore(board.Id, week), data[board.Weekly] or 0)
		end
	end
end

function RecordService.forget(player: Player)
	published[player] = nil
end

return RecordService
