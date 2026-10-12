-- Which game a server is running. The player chooses with the menu's buttons.
--
--   "Menu"  nothing is being played yet; players are looking at the menu
--   "Solo"  the single-player game: your own camp, saved between sessions
--   "Race"  the multiplayer race (see MULTIPLAYER.md)
--
-- The server decides and publishes it as a `GameMode` attribute on Workspace.
-- In the published game each server has one mode for its whole life, and choosing on the
-- menu moves the player to a server of the right kind. In Studio players cannot be moved
-- between servers, so there the menu's choice starts that game in the same server.

local Workspace = game:GetService("Workspace")

local GameMode = {}

local ATTRIBUTE = "GameMode"

-- nil until the server has decided.
function GameMode.get(): string?
	return Workspace:GetAttribute(ATTRIBUTE)
end

-- Server only.
function GameMode.set(mode: string)
	Workspace:SetAttribute(ATTRIBUTE, mode)
end

-- Waits until the server has decided, then returns the mode.
function GameMode.waitForAny(): string
	while GameMode.get() == nil do
		Workspace:GetAttributeChangedSignal(ATTRIBUTE):Wait()
	end
	return GameMode.get() :: string
end

-- Waits until a game is actually being played, then returns "Solo" or "Race".
function GameMode.waitForPlay(): string
	while true do
		local mode = GameMode.get()
		if mode == "Solo" or mode == "Race" then
			return mode
		end
		Workspace:GetAttributeChangedSignal(ATTRIBUTE):Wait()
	end
end

return GameMode
