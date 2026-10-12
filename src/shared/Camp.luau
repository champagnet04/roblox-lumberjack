-- Questions about the camp's stages, answered from Config.Camp (see CAMP_PROGRESSION.md).
-- A stage is a run of builds; finishing one makes wood worth more when it is banked.

local Config = require(script.Parent.Config)

local Camp = {}

-- Which stage a build belongs to, by the build's number in Config.Camp.Builds.
-- Returns the stage's number, its first and last builds, and its name.
-- A build past the last stage counts as part of the last one.
function Camp.stageOf(buildIndex: number): (number, number, number, string)
	local stages = Config.Camp.Stages
	local first = 1
	for index, stage in stages do
		if buildIndex <= stage.LastBuild or index == #stages then
			return index, first, stage.LastBuild, stage.Name
		end
		first = stage.LastBuild + 1
	end
	return 1, 1, #Config.Camp.Builds, ""
end

-- How many stages are finished with this many builds done.
function Camp.stagesFinished(buildsDone: number): number
	local finished = 0
	for _, stage in Config.Camp.Stages do
		if buildsDone >= stage.LastBuild then
			finished += 1
		end
	end
	return finished
end

-- What each piece of banked wood is worth to the camp fund: 1 at the start, and one more
-- for every stage finished.
function Camp.woodWorth(buildsDone: number): number
	return 1 + Camp.stagesFinished(buildsDone)
end

return Camp
