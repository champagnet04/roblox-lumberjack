-- What the Record Book and the leaderboards are made of (see RECORD_BOOK.md).
-- Shared by the server, which records and publishes the numbers, and the menu, which
-- shows them. This file must not load Config: the menu runs before a game is chosen.

local Records = {}

-- The leaderboards. Each ranks players by one saved number, and has a weekly twin.
--   AllTime  the saved number ranked on the all-time list
--   Weekly   the saved number ranked on this week's list
Records.Boards = {
	{ Id = "RaceWins", Title = "RACES WON", AllTime = "RaceWins", Weekly = "WeekRaceWins" },
	{
		Id = "RaceScore",
		Title = "BEST RACE SCORE",
		AllTime = "BestRaceScore",
		Weekly = "WeekBestRaceScore",
	},
	{ Id = "Haul", Title = "BEST HAUL", AllTime = "BestHaul", Weekly = "WeekBestHaul" },
	{ Id = "Camp", Title = "CAMP PROGRESS", AllTime = "BuildsDone", Weekly = "WeekBuilds" },
}

local WEEK = 7 * 24 * 60 * 60
local FIRST_MONDAY = 4 * 24 * 60 * 60 -- the clock's day zero was a Thursday; this is the Monday after

-- A number that goes up by one each Monday at midnight, world time (UTC), so a week
-- turns over at the same moment for every player and every server.
function Records.currentWeek(): number
	return math.floor((os.time() - FIRST_MONDAY) / WEEK)
end

-- The name a player's saved progress is kept under.
function Records.saveKey(userId: number): string
	return `user_{userId}`
end

-- The name of the Roblox leaderboard holding a board's all-time list, or one week's list.
function Records.boardStore(boardId: string, week: number?): string
	return if week then `Board_{boardId}_W{week}` else `Board_{boardId}_All`
end

return Records
