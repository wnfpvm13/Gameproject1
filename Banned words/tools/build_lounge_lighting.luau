-- Lighting for the 금칙어 게임 Korean studio set (direction A, owner 2026-10-21). Run in Studio's Edit datamodel after
-- tools/build_lounge_map.luau; running it again replaces its own effects. The lights themselves (keys, fill, rims,
-- light bars) are part of the map; this only sets the Lighting service: a dark studio under a ceiling, real shadows,
-- light post effects. Low-end phones drop shadows and effects on their own, so the set must still read without them.
local Lighting = game:GetService("Lighting")

Lighting.LightingStyle = Enum.LightingStyle.Realistic
Lighting.PrioritizeLightingQuality = true
Lighting.GlobalShadows = true
Lighting.ClockTime = 0
Lighting.Brightness = 0.4
-- Ambient keeps the spectator area readable outside the stage lights.
Lighting.Ambient = Color3.fromRGB(62, 66, 82)
Lighting.OutdoorAmbient = Color3.fromRGB(62, 66, 82)
Lighting.EnvironmentDiffuseScale = 0.3
Lighting.EnvironmentSpecularScale = 0.7
Lighting.ExposureCompensation = 0.2
Lighting.ShadowSoftness = 0.3

for _, child in Lighting:GetChildren() do
	if child:GetAttribute("BannedWordsLook") then
		child:Destroy()
	end
end

local function effect(class: string, props: { [string]: any })
	local o = Instance.new(class)
	for key, value in props do
		(o :: any)[key] = value
	end
	o.Name = "BannedWords" .. class
	o:SetAttribute("BannedWordsLook", true)
	o.Parent = Lighting
end
effect("ColorCorrectionEffect", { Contrast = 0.06, Saturation = 0.04, TintColor = Color3.fromRGB(255, 250, 246) })
-- Weak bloom: neon trims glow a little; the white word bubbles must not smear.
effect("BloomEffect", { Intensity = 0.25, Size = 18, Threshold = 1.1 })

return "studio lighting set"
