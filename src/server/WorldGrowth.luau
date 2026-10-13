-- Grows the clearing and the forest as the solo camp grows (see Config.WorldGrowth).
--
-- The world is first built at its starting size, before anyone's progress is known. When
-- a player's builds call for a bigger one, the ground and forest are made again behind a
-- dark screen: on arriving with a saved camp, and at the moment a stage's last build is
-- finished. A race never grows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Camp = require(ReplicatedStorage.Shared.Camp)
local CampBuildService = require(script.Parent.CampBuildService)
local GuardianService = require(script.Parent.GuardianService)
local PlayerState = require(script.Parent.PlayerState)
local TreeService = require(script.Parent.TreeService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local WorldGrowth = {}

local FADE_TIME = 0.7 -- the screen takes this long to go dark before the world changes
local SETTLE_TIME = 1.5 -- and stays dark this long after, while the new forest arrives
local GROWN_MESSAGE = "THE FOREST DRAWS BACK.\nTHE CLEARING GROWS."
local SPAWN_POINT = Vector3.new(11, 4, 0)

local growing = false
local lastBuilds: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- `message` is shown on the dark screen; leave it empty for none.
local function grow(step: number, message: string)
	growing = true
	-- The players' games darken the screen while this is set (see WorldCover).
	Workspace:SetAttribute("WorldCover", message)
	Workspace:SetAttribute("WorldCovered", true)

	-- The ground is taken away and put back, so everyone is held where they stand.
	local held: { BasePart } = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and not root.Anchored then
			root.Anchored = true
			table.insert(held, root)
		end
	end
	task.wait(FADE_TIME)

	GuardianService.reset()
	WorldBuilder.resize(step)
	TreeService.readForest()
	CampBuildService.worldChanged()
	task.wait(SETTLE_TIME)

	for _, root in held do
		if root.Parent then
			root.Anchored = false
		end
	end
	-- Anyone whose character appeared partway through may have dropped through the gap.
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and root.Position.Y < -3 then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(SPAWN_POINT)
		end
	end

	Workspace:SetAttribute("WorldCovered", false)
	growing = false
end

local function check(player: Player)
	local builds = PlayerState.getBuildsDone(player)
	local earned = builds == (lastBuilds[player] or 0) + 1 -- built just now, not loaded
	lastBuilds[player] = builds

	local step = Camp.worldStep(builds)
	if growing or step == WorldBuilder.step() then
		return
	end
	grow(step, if earned and step > WorldBuilder.step() then GROWN_MESSAGE else "")

	-- Progress can arrive while the world is being made; look once more.
	if player.Parent then
		check(player)
	end
end

-- Call after the other services have started. Solo only.
function WorldGrowth.start()
	local function onPlayerAdded(player: Player)
		player:GetAttributeChangedSignal("BuildsDone"):Connect(function()
			check(player)
		end)
		check(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastBuilds[player] = nil
	end)
end

return WorldGrowth
