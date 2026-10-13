-- Server entry point. Builds the world, works out what this server is for, then either
-- shows the menu or starts a game.
--
-- The gameplay services read the game mode when they are first loaded, so they are only
-- loaded once the mode is known (see startGame).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameMode = require(ReplicatedStorage.Shared.GameMode)
local LightingSetup = require(script.Parent.LightingSetup)
local MenuService = require(script.Parent.MenuService)
local WorldBuilder = require(script.Parent.WorldBuilder)

-- A server anyone can join is a menu server. So is every server in Studio, and a private
-- server someone has bought. Only a private server made by the menu runs a game from the start.
local isMenu = RunService:IsStudio() or game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0

-- At the menu nobody has a character. This must be set before the first player arrives.
Players.CharacterAutoLoads = not isMenu

-- `host` is given for a friends race: the user id of the player who made it.
local function startGame(mode: string, host: number?)
	Config.Mode = mode
	Players.CharacterAutoLoads = true

	local BotService = require(script.Parent.BotService)
	local CampBuildService = require(script.Parent.CampBuildService)
	local CampService = require(script.Parent.CampService)
	local GuardianService = require(script.Parent.GuardianService)
	local MovementService = require(script.Parent.MovementService)
	local PlayerSetup = require(script.Parent.PlayerSetup)
	local PlayerState = require(script.Parent.PlayerState)
	local RaceService = require(script.Parent.RaceService)
	local SaveService = require(script.Parent.SaveService)
	local TreeService = require(script.Parent.TreeService)

	PlayerSetup.start()
	PlayerState.start()
	SaveService.start() -- in a race too: prizes are paid into the saved camp fund
	MovementService.start()
	TreeService.start()
	CampService.start()
	if mode == "Race" then
		-- One finished camp for everyone, and rounds.
		CampBuildService.startShared(Config.Race.CampBuilds)
		GuardianService.start()
		BotService.start()
		RaceService.start(host)
	else
		CampBuildService.start()
		GuardianService.start()
		-- Loaded here, not above: a race has no use for it.
		local WorldGrowth = require(script.Parent.WorldGrowth)
		WorldGrowth.start()
	end
	MenuService.listenForReturn()

	-- Tell the players' games last, so everything is running when their displays start.
	GameMode.set(mode)

	-- Anyone who was waiting at the menu (Studio only) has no character yet. A race puts
	-- everyone at camp itself when its first countdown begins.
	if mode ~= "Race" then
		for _, player in Players:GetPlayers() do
			if not player.Character then
				task.spawn(function()
					player:LoadCharacter()
				end)
			end
		end
	end
end

LightingSetup.apply()
WorldBuilder.build()

if isMenu then
	GameMode.set("Menu")
	-- Only Studio starts a game in the menu's own server.
	MenuService.start(if RunService:IsStudio() then startGame else nil)
else
	startGame(MenuService.roleOfThisServer())
end
