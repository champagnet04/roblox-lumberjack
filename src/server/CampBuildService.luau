-- Camp progression. The camp grows one build at a time, in the order of Config.Camp.Builds.
-- Each build costs banked wood plus materials that must be found in the forest.
--
-- Rules:
--   * Only materials for the player's next build appear, one at a time.
--   * A player carries one material per trip. PlayerState banks it at camp (only alongside
--     wood) and drops it if the guardian catches them.
--   * The next build is shown at camp as a faint outline. Walking up to it and holding the
--     prompt builds it, if the wood and materials are there.
--
-- There is one camp in the world, so this assumes one player per server for now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CampModels = require(script.Parent.CampModels)
local PlayerState = require(script.Parent.PlayerState)
local TerrainBuilder = require(script.Parent.TerrainBuilder)

local CampBuildService = {}

local TICK = 0.25
local FLAT = Vector3.new(1, 0, 1)

type Build = typeof(Config.Camp.Builds[1])

type MaterialItem = {
	Type: string,
	Model: Model,
	Position: Vector3,
}

local rng = Random.new()
local buildsFolder: Folder
local materialsFolder: Folder
local treesFolder: Instance

local items: { [Player]: MaterialItem } = {}
local nextSpawnAt: { [Player]: number } = {}

local function nextBuild(player: Player): Build?
	return Config.Camp.Builds[PlayerState.getBuildsDone(player) + 1]
end

-- The first material the next build still needs, or nil if it needs none.
local function neededMaterial(player: Player): string?
	local build = nextBuild(player)
	if not build then
		return nil
	end
	for _, requirement in build.Materials do
		if PlayerState.getMaterial(player, requirement.Type) < requirement.Count then
			return requirement.Type
		end
	end
	return nil
end

local function describeCost(build: Build): string
	local parts = { `{build.Wood} wood` }
	for _, requirement in build.Materials do
		table.insert(parts, `{requirement.Count} {Config.Camp.Materials[requirement.Type].Name}`)
	end
	return table.concat(parts, ", ")
end

local function tryBuild(player: Player)
	local build = nextBuild(player)
	if not build then
		return
	end

	local missing = {}
	local woodShort = build.Wood - PlayerState.getOverallBank(player)
	if woodShort > 0 then
		table.insert(missing, `{woodShort} MORE WOOD`)
	end
	for _, requirement in build.Materials do
		local short = requirement.Count - PlayerState.getMaterial(player, requirement.Type)
		if short > 0 then
			table.insert(
				missing,
				`{short} {string.upper(Config.Camp.Materials[requirement.Type].Name)}`
			)
		end
	end

	if #missing > 0 then
		Remotes.Notice:FireClient(player, `NEED {table.concat(missing, ", ")}`)
		return
	end

	PlayerState.completeBuild(player, build)
	Remotes.Notice:FireClient(player, `{string.upper(build.Name)} BUILT!`)
end

-- Rebuilds the camp to match the player's progress: finished builds solid, the next one faint.
local function syncCamp(player: Player)
	buildsFolder:ClearAllChildren()

	local done = PlayerState.getBuildsDone(player)
	for index, build in Config.Camp.Builds do
		if index <= done then
			CampModels.build(build.Id, buildsFolder)
		elseif index == done + 1 then
			local ghost = CampModels.build(build.Id, buildsFolder)
			CampModels.makeGhost(ghost)

			local firstPart = ghost:FindFirstChildWhichIsA("BasePart")
			if firstPart then
				-- The prompt and label hang in the air above the outline. Attached to the
				-- outline itself, the prompt's box sat on top of it and hid it from view.
				local anchor = Instance.new("Part")
				anchor.Name = "PromptAnchor"
				anchor.Anchored = true
				anchor.Size = Vector3.one
				anchor.Transparency = 1
				anchor.CanCollide = false
				anchor.CanQuery = false
				anchor.CanTouch = false
				anchor.Position = firstPart.Position + Vector3.new(0, Config.Camp.PromptHeight, 0)
				anchor.Parent = ghost

				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Build"
				prompt.ObjectText = `{build.Name} ({describeCost(build)})`
				prompt.HoldDuration = Config.Camp.BuildHoldTime
				prompt.MaxActivationDistance = Config.Camp.BuildRange
				prompt.RequiresLineOfSight = false
				prompt.Triggered:Connect(tryBuild)
				prompt.Parent = anchor

				-- A floating label, readable from anywhere in camp, marking where to build.
				local label = Instance.new("BillboardGui")
				label.Name = "NextBuildLabel"
				label.Size = UDim2.fromOffset(220, 46)
				label.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
				label.AlwaysOnTop = true
				label.MaxDistance = 120
				label.Parent = anchor

				local text = Instance.new("TextLabel")
				text.Size = UDim2.fromScale(1, 1)
				text.BackgroundTransparency = 1
				text.Font = Enum.Font.GothamBlack
				text.TextSize = 18
				text.TextColor3 = Color3.fromRGB(255, 214, 120)
				text.TextStrokeTransparency = 0.3
				text.Text = `BUILD HERE\n{string.upper(build.Name)}`
				text.Parent = label
			end
		end
	end
end

local function removeItem(player: Player)
	local item = items[player]
	if item then
		item.Model:Destroy()
		items[player] = nil
	end
end

-- A spot in the forest for a material: nearer camp for early builds, deeper for later ones,
-- and never inside a tree trunk.
local function pickMaterialPosition(player: Player): Vector3
	local cfg = Config.Camp
	local step = PlayerState.getBuildsDone(player) * cfg.MaterialDistanceStepPerBuild
	local limit = Config.World.ForestRadius - 10
	local minRadius = math.min(cfg.MaterialMinDistance + step, limit - 40)
	local maxRadius = math.min(cfg.MaterialMaxDistance + step, limit)

	local position = Vector3.zero
	for _ = 1, 20 do
		local radius = math.sqrt(rng:NextNumber(minRadius ^ 2, maxRadius ^ 2))
		local angle = rng:NextNumber(0, math.pi * 2)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		position = Vector3.new(x, TerrainBuilder.heightAt(x, z), z)

		local clear = true
		for _, tree in treesFolder:GetChildren() do
			if tree:IsA("Model") and tree.PrimaryPart then
				if ((tree.PrimaryPart.Position - position) * FLAT).Magnitude < 6 then
					clear = false
					break
				end
			end
		end
		if clear then
			break
		end
	end
	return position
end

local function step(player: Player)
	local carried = PlayerState.getCarried(player)
	local needed = neededMaterial(player)
	local item = items[player]

	-- Remove an item that is no longer wanted.
	if item and (carried ~= "" or item.Type ~= needed) then
		removeItem(player)
		item = nil
	end

	if carried ~= "" then
		-- Nothing new appears until this one is banked or lost.
		nextSpawnAt[player] = os.clock() + Config.Camp.MaterialRespawnDelay
		return
	end

	if item then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local distance = ((root.Position - item.Position) * FLAT).Magnitude
			if distance <= Config.Camp.PickupRange then
				PlayerState.setCarried(player, item.Type)
				removeItem(player)
			end
		end
	elseif needed and os.clock() >= (nextSpawnAt[player] or 0) then
		local position = pickMaterialPosition(player)
		items[player] = {
			Type = needed,
			Position = position,
			Model = CampModels.buildMaterial(needed, position, materialsFolder),
		}
	end
end

local function onPlayerAdded(player: Player)
	player:GetAttributeChangedSignal("BuildsDone"):Connect(function()
		syncCamp(player)
	end)
	syncCamp(player)
end

-- Call after the world has been built.
function CampBuildService.start()
	local world = Workspace:WaitForChild("World")
	treesFolder = world:WaitForChild("Trees")

	buildsFolder = Instance.new("Folder")
	buildsFolder.Name = "Builds"
	buildsFolder.Parent = world:WaitForChild("Camp")

	materialsFolder = Instance.new("Folder")
	materialsFolder.Name = "Materials"
	materialsFolder.Parent = world

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		removeItem(player)
		nextSpawnAt[player] = nil
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				step(player)
			end
			task.wait(TICK)
		end
	end)
end

return CampBuildService
