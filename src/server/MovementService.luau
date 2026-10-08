-- Stamina and movement speed. The server owns both.
-- Speed = walk or sprint speed x carry slowdown x tired slowdown.
-- Stamina is published as a `Stamina` attribute on the Player for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)

local MovementService = {}

local TICK = 0.1

type MoveState = {
	Stamina: number,
	WantsSprint: boolean, -- sprint key is held
	Exhausted: boolean, -- ran dry while sprinting; must recover a little before sprinting again
	LastEffort: number, -- time of the last swing or sprint; stamina refills only after a pause
}

local states: { [Player]: MoveState } = {}

local function publish(player: Player, state: MoveState)
	player:SetAttribute("Stamina", math.floor(state.Stamina * 10 + 0.5) / 10)
end

-- Speed multiplier from carried wood, interpolated between the points in Config.Carry.
local function carryMultiplier(haul: number): number
	local points = Config.Carry
	for i = 2, #points do
		local low, high = points[i - 1], points[i]
		if haul <= high.Haul then
			local alpha = (haul - low.Haul) / (high.Haul - low.Haul)
			return low.Speed + (high.Speed - low.Speed) * math.clamp(alpha, 0, 1)
		end
	end
	return points[#points].Speed
end

-- Full speed above the low threshold, easing down to the minimum at zero stamina.
local function tiredMultiplier(stamina: number): number
	local cfg = Config.Stamina
	if stamina >= cfg.LowThreshold then
		return 1
	end
	return cfg.LowSpeedMultiplier + (1 - cfg.LowSpeedMultiplier) * (stamina / cfg.LowThreshold)
end

-- Takes stamina for an action such as an axe swing. Returns false if there is not enough.
function MovementService.spendStamina(player: Player, amount: number): boolean
	local state = states[player]
	if not state or state.Stamina < amount then
		return false
	end
	state.Stamina -= amount
	state.LastEffort = os.clock()
	publish(player, state)
	return true
end

local function step(player: Player, state: MoveState, dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local cfg = Config.Stamina
	local now = os.clock()

	if state.Exhausted and state.Stamina >= cfg.SprintMinToStart then
		state.Exhausted = false
	end

	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sprinting = state.WantsSprint and moving and not state.Exhausted and state.Stamina > 0

	if sprinting then
		state.Stamina = math.max(state.Stamina - cfg.SprintDrainPerSecond * dt, 0)
		state.LastEffort = now
		if state.Stamina <= 0 then
			state.Exhausted = true
		end
	elseif now - state.LastEffort >= cfg.RegenDelay then
		state.Stamina = math.min(state.Stamina + cfg.RegenPerSecond * dt, cfg.Max)
	end

	local baseSpeed = if sprinting then Config.Player.SprintSpeed else Config.Player.WalkSpeed
	humanoid.WalkSpeed = baseSpeed
		* carryMultiplier(PlayerState.getHaul(player))
		* tiredMultiplier(state.Stamina)

	publish(player, state)
end

local function onPlayerAdded(player: Player)
	local state: MoveState = {
		Stamina = Config.Stamina.Max,
		WantsSprint = false,
		Exhausted = false,
		LastEffort = 0,
	}
	states[player] = state
	publish(player, state)

	-- Every respawn starts fresh.
	player.CharacterAdded:Connect(function()
		state.Stamina = Config.Stamina.Max
		state.Exhausted = false
		publish(player, state)
	end)
end

function MovementService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	Remotes.SetSprinting.OnServerEvent:Connect(function(player, wantsSprint)
		local state = states[player]
		if state then
			state.WantsSprint = wantsSprint == true
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			local dt = now - last
			last = now
			for player, state in states do
				step(player, state, dt)
			end
		end
	end)
end

return MovementService
