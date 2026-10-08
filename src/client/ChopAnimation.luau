-- Chopping visuals on the player's own screen: the axe swing, the raised torch arm,
-- and the tree's shake when a swing lands.
-- Arms are posed by turning the shoulder joints directly, so no animation assets are needed.
-- This only works on R15 avatars (the Roblox default); on others the arms are left alone.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ChopAnimation = {}

-- Time from the start of a swing until the axe lands.
ChopAnimation.IMPACT_DELAY = 0.18

local SWING_TIME = 0.36 -- must stay shorter than Config.Tree.SwingCooldown
local WINDUP_TIME = 0.1

-- Shoulder angles in degrees: 0 = arm hanging down, 90 = straight out in front, 180 = straight up.
local REST_ANGLE = 90
local WINDUP_ANGLE = 165
local IMPACT_ANGLE = 45
local TORCH_ARM = CFrame.Angles(math.rad(85), 0, 0)

local player = Players.LocalPlayer
local swingStart: number? = nil

local function lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

local function swingAngle(elapsed: number): number
	if elapsed < WINDUP_TIME then
		return lerp(REST_ANGLE, WINDUP_ANGLE, elapsed / WINDUP_TIME)
	elseif elapsed < ChopAnimation.IMPACT_DELAY then
		local alpha = (elapsed - WINDUP_TIME) / (ChopAnimation.IMPACT_DELAY - WINDUP_TIME)
		return lerp(WINDUP_ANGLE, IMPACT_ANGLE, alpha * alpha)
	else
		local alpha = (elapsed - ChopAnimation.IMPACT_DELAY)
			/ (SWING_TIME - ChopAnimation.IMPACT_DELAY)
		return lerp(IMPACT_ANGLE, REST_ANGLE, alpha)
	end
end

local function shoulder(character: Model, armName: string, jointName: string): Motor6D?
	local arm = character:FindFirstChild(armName)
	local joint = arm and arm:FindFirstChild(jointName)
	if joint and joint:IsA("Motor6D") then
		return joint
	end
	return nil
end

function ChopAnimation.swing()
	swingStart = os.clock()
end

-- Quick wobble away from the player that settles back upright.
function ChopAnimation.shakeTree(tree: Model, from: Vector3)
	local trunk = tree.PrimaryPart
	if not trunk then
		return
	end

	-- The trunk is a cylinder lying along its own X axis, so Size.X is its height.
	local base = trunk.Position - Vector3.new(0, trunk.Size.X / 2 - 2, 0)
	local offset = (base - from) * Vector3.new(1, 0, 1)
	local direction = if offset.Magnitude > 0.01 then offset.Unit else Vector3.new(1, 0, 0)
	local axis = Vector3.new(0, 1, 0):Cross(direction)
	local upright = tree:GetPivot()

	task.spawn(function()
		local duration = 0.25
		local start = os.clock()
		while true do
			local elapsed = os.clock() - start
			if elapsed >= duration or not tree.Parent then
				break
			end
			local angle = math.rad(2) * math.sin(elapsed * 40) * (1 - elapsed / duration)
			tree:PivotTo(
				CFrame.new(base) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-base) * upright
			)
			RunService.RenderStepped:Wait()
		end
		if tree.Parent then
			tree:PivotTo(upright)
		end
	end)
end

-- Joint poses must be set here, after Roblox has applied its own animations for the frame.
RunService.PreSimulation:Connect(function()
	local character = player.Character
	if not character then
		return
	end

	local left = shoulder(character, "LeftUpperArm", "LeftShoulder")
	if left then
		left.Transform = TORCH_ARM
	end

	if swingStart then
		local elapsed = os.clock() - swingStart
		if elapsed >= SWING_TIME then
			swingStart = nil
		else
			local right = shoulder(character, "RightUpperArm", "RightShoulder")
			if right then
				right.Transform = CFrame.Angles(math.rad(swingAngle(elapsed)), 0, 0)
			end
		end
	end
end)

return ChopAnimation
