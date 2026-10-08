-- Sets the mood: a dark, misty night forest where the campfire and torch are the main lights.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local LightingSetup = {}

function LightingSetup.apply()
	local cfg = Config.Lighting

	-- A fresh Studio place comes with its own fog and effects; ours replace them.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end

	Lighting.ClockTime = cfg.ClockTime
	Lighting.Brightness = cfg.Brightness
	Lighting.Ambient = cfg.Ambient
	Lighting.OutdoorAmbient = cfg.OutdoorAmbient
	Lighting.ExposureCompensation = cfg.ExposureCompensation
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = cfg.FogDensity
	atmosphere.Offset = 0
	atmosphere.Haze = cfg.FogHaze
	atmosphere.Glare = 0
	atmosphere.Color = cfg.FogColor
	atmosphere.Decay = cfg.FogDecay
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.2
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Contrast = 0.12
	color.Saturation = -0.08
	color.TintColor = Color3.fromRGB(225, 240, 255)
	color.Parent = Lighting
end

return LightingSetup
