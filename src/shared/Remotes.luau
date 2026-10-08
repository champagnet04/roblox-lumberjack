-- The message channels between server and client, defined once.
-- The server creates them; the client waits for them to replicate.

local RunService = game:GetService("RunService")

local NAMES = {
	"ChopRequest", -- client -> server: player swung at a tree
	"SetSprinting", -- client -> server: sprint key pressed or released
	"LoraxWarning", -- server -> client: the creature is waking up
	"RunOver", -- server -> client: player was caught; carries the run summary
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
