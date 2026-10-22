-- Lighting for the V3 indoor pool hall (docs/DESIGN_V3.md §9). Run in Studio's Edit datamodel after
-- tools/build_pool_hall.luau; running it again replaces its own effects. The lights themselves (downlights, keys,
-- fill) are part of the hall; this only sets the Lighting service: a bright midday outside the windows and skylights
-- (owner 2026-10-22: daytime, a bright white indoor pool), real shadows, light post effects. The hall must still read
-- without shadows and effects (white walls, a bright ambient), because lower quality levels drop them.
local Lighting = game:GetService("Lighting")

Lighting.LightingStyle = Enum.LightingStyle.Realistic
-- false = when the quality level drops, keep the view distance and give up shadows / shader quality first: the landing
-- zone is 95-130 studs from the show camera and must stay visible on low-end phones.
Lighting.PrioritizeLightingQuality = false
Lighting.GlobalShadows = true
Lighting.ClockTime = 13.2 -- early afternoon: sun high enough to fall through the skylights, blue sky in the windows
Lighting.GeographicLatitude = 37
Lighting.Brightness = 3
Lighting.Ambient = Color3.fromRGB(150, 156, 166) -- the roof shades most of the hall, so this carries the interior
Lighting.OutdoorAmbient = Color3.fromRGB(170, 176, 186)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6
Lighting.ExposureCompensation = 0.2
Lighting.ShadowSoftness = 0.4

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
if not Lighting:FindFirstChildOfClass("Sky") then
	effect("Sky", {}) -- the default sky (sun and clouds) so the windows show a day sky, not the void
end
effect("ColorCorrectionEffect", { Contrast = 0.04, Saturation = 0.06, TintColor = Color3.fromRGB(255, 253, 250) })
-- Weak bloom: the LED panels and the pool glow shine a little; the word bubbles must not smear.
effect("BloomEffect", { Intensity = 0.2, Size = 18, Threshold = 1.2 })

return "pool hall lighting set"
