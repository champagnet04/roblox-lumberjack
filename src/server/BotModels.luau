-- Builds the bot lumberjacks that fill out a race (see MULTIPLAYER.md).
-- Each is a standard Roblox-shaped character coloured to look like a flannel shirt and jeans,
-- with a beanie or a beard. BotService gives them the same axe and torch a player carries.

local Players = game:GetService("Players")

local BotModels = {}

local JEANS = Color3.fromRGB(48, 68, 108)
local SKIN = Color3.fromRGB(236, 190, 146)

export type Look = {
	Name: string,
	Style: string, -- how it plays; one of Config.Bots.Styles
	Flannel: Color3,
	Hat: string, -- "Beanie", "Beard" or "Both"
	Trim: Color3, -- colour of the beanie or beard
}

local function addToHead(head: BasePart, props: { [string]: any }, offset: CFrame)
	local part = Instance.new("Part")
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.Fabric
	for key, value in props do
		(part :: any)[key] = value
	end
	part.CFrame = head.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	part.Parent = head.Parent
end

-- Returns the finished character, or nil if Roblox could not make one.
-- It may pause briefly while Roblox assembles the character.
function BotModels.build(look: Look): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = SKIN
	description.TorsoColor = look.Flannel
	description.LeftArmColor = look.Flannel
	description.RightArmColor = look.Flannel
	description.LeftLegColor = JEANS
	description.RightLegColor = JEANS

	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(result) ~= "Instance" then
		warn("[BotModels] Could not make a bot character:", result)
		return nil
	end
	local model = result :: Model
	model.Name = look.Name

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	if not humanoid or not head or not head:IsA("BasePart") then
		warn("[BotModels] The bot character is missing its humanoid or head.")
		model:Destroy()
		return nil
	end
	humanoid.DisplayName = look.Name

	if look.Hat == "Beanie" or look.Hat == "Both" then
		addToHead(head, {
			Name = "Beanie",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (head.Size.Y * 1.12),
			Color = look.Trim,
		}, CFrame.new(0, head.Size.Y * 0.22, 0))
	end
	if look.Hat == "Beard" or look.Hat == "Both" then
		addToHead(head, {
			Name = "Beard",
			Size = Vector3.new(head.Size.X * 0.62, head.Size.Y * 0.42, 0.3),
			Color = if look.Hat == "Both" then Color3.fromRGB(96, 70, 48) else look.Trim,
		}, CFrame.new(0, -head.Size.Y * 0.32, -head.Size.Z * 0.5))
	end

	return model
end

return BotModels
