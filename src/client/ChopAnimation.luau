-- Chopping visuals on the player's own screen: the axe swing, the raised torch arm,
-- and the tree's shake when a swing lands.
-- No animation assets are needed. The swing is made of two movements:
--   1. the axe pivots in the hand (works on every avatar), and
--   2. the right arm swings from the shoulder (R15 avatars only).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ChopAnimation = {}

-- Time from the start of a swing until the axe lands.
ChopAnimation.IMPACT_DELAY = 0.18

local SWING_TIME = 0.36 -- must stay shorter than Config.Tree.SwingCooldown
local WINDUP_TIME = 0.1

-- Shoulder angles in degrees: 0 = arm hanging down, 90 = straight out in front, 180 = straight up.
local ARM_REST = 90
local ARM_WINDUP = 165
local ARM_IMPACT = 45
local TORCH_ARM = CFrame.Angles(math.rad(85), 0, 0)

-- How far the axe tips in the hand, in degrees: positive = back over the shoulder, negative = forward.
local AXE_WINDUP = 50
local AXE_IMPACT = -65

local player = Players.LocalPlayer
local swingStart: number? = nil

-- The weld that holds the axe in the hand, and its position when not swinging.
local axeGrip: JointInstance? = nil
local axeGripRest = CFrame.new()
local warnedNoShoulder = false

local function lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

-- A swing goes rest -> windup -> impact -> rest. Returns the angle at a moment in the swing.
local function swingAngle(elapsed: number, rest: number, windup: number, impact: number): number
	if elapsed < WINDUP_TIME then
		return lerp(rest, windup, elapsed / WINDUP_TIME)
	elseif elapsed < ChopAnimation.IMPACT_DELAY then
		local alpha = (elapsed - WINDUP_TIME) / (ChopAnimation.IMPACT_DELAY - WINDUP_TIME)
		return lerp(windup, impact, alpha * alpha)
	else
		local alpha = (elapsed - ChopAnimation.IMPACT_DELAY)
			/ (SWING_TIME - ChopAnimation.IMPACT_DELAY)
		return lerp(impact, rest, alpha)
	end
end

-- Roblox avatars use either Motor6D or AnimationConstraint for joints; both have a Transform.
local function shoulder(character: Model, armName: string, jointName: string): any
	local arm = character:FindFirstChild(armName)
	local joint = arm and arm:FindFirstChild(jointName)
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
		return joint
	end
	return nil
end

-- Finds the weld Roblox creates between the right hand and the equipped axe.
local function findAxeGrip(character: Model): JointInstance?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local grip = hand and hand:FindFirstChild("RightGrip")
	if grip and grip:IsA("JointInstance") then
		return grip
	end
	return nil
end

local function poseAxe(character: Model, degrees: number)
	local grip = findAxeGrip(character)
	if grip ~= axeGrip then
		-- A new axe was equipped (for example after respawning); remember its resting position.
		axeGrip = grip
		if grip then
			axeGripRest = grip.C0
		end
	end
	if grip then
		grip.C0 = axeGripRest * CFrame.Angles(math.rad(degrees), 0, 0)
	end
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
			poseAxe(character, 0)
		else
			poseAxe(character, swingAngle(elapsed, 0, AXE_WINDUP, AXE_IMPACT))

			local right = shoulder(character, "RightUpperArm", "RightShoulder")
			if right then
				local degrees = swingAngle(elapsed, ARM_REST, ARM_WINDUP, ARM_IMPACT)
				right.Transform = CFrame.Angles(math.rad(degrees), 0, 0)
			elseif not warnedNoShoulder then
				warnedNoShoulder = true
				local arm = character:FindFirstChild("RightUpperArm")
				local found = arm and arm:FindFirstChild("RightShoulder")
				warn(
					"[ChopAnimation] No usable right shoulder joint, so the arm will not swing.",
					"RightUpperArm:",
					if arm then "found" else "missing",
					"RightShoulder:",
					if found then found.ClassName else "missing"
				)
			end
		end
	end
end)

return ChopAnimation
