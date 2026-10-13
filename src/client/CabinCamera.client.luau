-- The view inside the cabin. Under a roof the usual camera has nowhere to go, so while the
-- player stands in the cabin's room the camera sits in a top corner and looks down across
-- the whole room, turning a little to follow them. Outside, the usual camera comes back.
--
-- The room is an unseen box named "CabinRoom" that the server puts in the cabin's walls.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Where the camera sits and looks, as shares of the room's size from its middle:
-- X across the front (the fireplace is at +X), Y up, -Z toward the door.
local CAMERA_AT = Vector3.new(-0.46, 0.42, -0.44) -- top front corner, on the bed's side
local LOOK_AT = Vector3.new(0.05, -0.3, 0.1)
local FOLLOW = 0.3 -- how far the view turns toward the player (0 = fixed, 1 = straight at them)
local FIELD_OF_VIEW = 95 -- wide, to take in the whole room
local NORMAL_FIELD_OF_VIEW = 70
local BLEND_TIME = 0.45 -- seconds to glide between the two views
local FIND_EVERY = 1 -- seconds between looks for the room, while there is none

local room: BasePart? = nil
local nextFindAt = 0
local inside = false
local blend = 0 -- 0 = the usual camera, 1 = the room's camera
local enteredFrom: CFrame? = nil -- where the camera was on walking in

local function findRoom(): BasePart?
	if room and room.Parent then
		return room
	end
	room = nil
	local now = os.clock()
	if now < nextFindAt then
		return nil
	end
	nextFindAt = now + FIND_EVERY

	local world = Workspace:FindFirstChild("World")
	local camp = world and world:FindFirstChild("Camp")
	local builds = camp and camp:FindFirstChild("Builds")
	local walls = builds and builds:FindFirstChild("CabinWalls")
	local found = walls and walls:FindFirstChild("CabinRoom")
	if found and found:IsA("BasePart") then
		room = found
	end
	return room
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function isInside(box: BasePart, position: Vector3): boolean
	local at = box.CFrame:PointToObjectSpace(position)
	local half = box.Size / 2
	-- A little slack once inside, so standing in the doorway does not flick between views.
	local slack = if inside then 0.6 else -0.4
	return math.abs(at.X) < half.X + slack
		and math.abs(at.Z) < half.Z + slack
		and at.Y > -half.Y - 2
		and at.Y < half.Y + 4
end

local function roomView(box: BasePart, position: Vector3): CFrame
	local eye = box.CFrame:PointToWorldSpace(CAMERA_AT * box.Size)
	local middle = box.CFrame:PointToWorldSpace(LOOK_AT * box.Size)
	return CFrame.lookAt(eye, middle:Lerp(position, FOLLOW))
end

RunService:BindToRenderStep("CabinCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local box = findRoom()
	local position = rootPosition()
	local nowInside = box ~= nil and position ~= nil and isInside(box, position)

	if nowInside and not inside then
		enteredFrom = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
	elseif inside and not nowInside then
		camera.CameraType = Enum.CameraType.Custom
	end
	inside = nowInside

	local goal = if inside then 1 else 0
	if blend == goal then
		return
	end
	local step = dt / BLEND_TIME
	blend = if goal > blend then math.min(blend + step, 1) else math.max(blend - step, 0)
	local eased = blend * blend * (3 - 2 * blend)
	camera.FieldOfView = NORMAL_FIELD_OF_VIEW + (FIELD_OF_VIEW - NORMAL_FIELD_OF_VIEW) * eased
end)

-- The room's view is set after the usual camera has moved, so it wins while inside.
RunService:BindToRenderStep("CabinCameraPlace", Enum.RenderPriority.Camera.Value + 2, function()
	local camera = Workspace.CurrentCamera
	local box = room
	local position = rootPosition()
	if not camera or not inside or not box or not box.Parent or not position then
		return
	end
	local view = roomView(box, position)
	local eased = blend * blend * (3 - 2 * blend)
	camera.CFrame = if enteredFrom and blend < 1 then enteredFrom:Lerp(view, eased) else view
end)
