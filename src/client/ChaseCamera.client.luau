-- Gives a clearer view during a chase:
--   1. pulls the camera back so the guardian behind the player is in frame, and
--   2. makes the guardian see-through whenever it stands between the camera and the player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local FREE_MIN_ZOOM = 0.5 -- Roblox's normal closest zoom
local SETTLE_TIME = 0.5 -- after a chase, hold the camera at its earlier distance this long

local wasChased = false
local settleUntil = 0
local zoomBeforeChase = Config.Player.CameraMaxZoom -- where the player had the camera before the chase
local checkZoomAt: number? = nil

-- Roblox has no "set zoom" call, so the camera is moved by narrowing the allowed zoom range.
-- Setting the minimum and maximum to the same value pins the camera at that distance.
local function setZoomRange(min: number, max: number)
	if player.CameraMinZoomDistance == min and player.CameraMaxZoomDistance == max then
		return
	end
	-- Change them in the order that never leaves the minimum above the maximum.
	if max >= player.CameraMinZoomDistance then
		player.CameraMaxZoomDistance = max
		player.CameraMinZoomDistance = min
	else
		player.CameraMinZoomDistance = min
		player.CameraMaxZoomDistance = max
	end
end

-- Checked every frame rather than on a change event, so a missed event cannot leave it stuck.
local function updateZoom(camera: Camera)
	local chased = player:GetAttribute("Chased") == true
	local now = os.clock()
	local normal = Config.Player.CameraMaxZoom

	if chased and not wasChased then
		-- Remember how far out the player had the camera, to put it back afterwards.
		local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		zoomBeforeChase = math.clamp(distance, FREE_MIN_ZOOM, normal)
	elseif wasChased and not chased then
		settleUntil = now + SETTLE_TIME
		checkZoomAt = now + 2
	end
	wasChased = chased

	if chased then
		setZoomRange(Config.Player.ChaseCameraZoom, Config.Player.ChaseCameraZoom)
	elseif now < settleUntil then
		setZoomRange(zoomBeforeChase, zoomBeforeChase) -- pin it there to pull the camera back in
	else
		setZoomRange(FREE_MIN_ZOOM, normal)
	end

	-- Diagnostic: report if the camera is still far out two seconds after a chase ended.
	if checkZoomAt and now >= checkZoomAt then
		checkZoomAt = nil
		local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		if not chased and distance > zoomBeforeChase + 3 then
			warn(
				"[ChaseCamera] Camera did not zoom back in after the chase.",
				"Distance:",
				math.round(distance),
				"Min:",
				player.CameraMinZoomDistance,
				"Max:",
				player.CameraMaxZoomDistance
			)
		end
	end
end

-- Shortest distance from a point to the line segment between two other points.
local function distanceToSegment(point: Vector3, from: Vector3, to: Vector3): number
	local segment = to - from
	local lengthSquared = segment:Dot(segment)
	if lengthSquared < 0.001 then
		return (point - from).Magnitude
	end
	local alpha = math.clamp((point - from):Dot(segment) / lengthSquared, 0, 1)
	return (point - (from + segment * alpha)).Magnitude
end

local function updateGuardianVisibility(camera: Camera, root: BasePart)
	for _, guardian in CollectionService:GetTagged("Guardian") do
		if guardian:IsA("Model") then
			-- Measure from the middle of its body rather than its feet.
			local centre = guardian:GetPivot().Position + Vector3.new(0, 6, 0)
			local blocking = distanceToSegment(centre, camera.CFrame.Position, root.Position)
				< Config.Guardian.SeeThroughDistance
			local transparency = if blocking then Config.Guardian.SeeThroughAmount else 0
			for _, part in guardian:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = transparency
				end
			end
		end
	end
end

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	updateZoom(camera)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		updateGuardianVisibility(camera, root)
	end
end)
