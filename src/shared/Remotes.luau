-- The message channels between server and client, defined once.
-- The server creates them; the client waits for them to replicate.

local RunService = game:GetService("RunService")

local NAMES = {
	"ChopRequest", -- client -> server: player swung at a tree
	"Swing", -- client -> server: a swing has started; server -> other clients: show that player's swing
	"SetSprinting", -- client -> server: sprint key pressed or released
	"Escaped", -- server -> client: player reached camp with the guardian behind them
	"Notice", -- server -> client: a short message to show on screen
	"GameOver", -- server -> client: player was caught, ending the game; carries the summary
	"ChooseMode", -- client -> server: a menu button was pressed ("Solo" or "QuickRace")
	"MenuStatus", -- server -> client: a line of text to show on the menu
	"LobbyAction", -- client -> server: the host of a friends race pressed "Start", "ToggleBots" or "ToggleOpen"
	"ReturnToMenu", -- client -> server: leave this game and go back to the menu
	"RaceResults", -- server -> everyone: a race round has ended; carries each racer's place and prize
}

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = script
else
	local folder = script:WaitForChild("Remotes")
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
