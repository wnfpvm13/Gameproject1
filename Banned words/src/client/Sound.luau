--!strict
-- The two sound groups (bundle 11a, docs/BUNDLE11_2026-10-27.md): "Effects" holds every game sound (client Fx),
-- "Music" the background music (client Music). A player's settings set the groups' volumes, on this screen only.
-- (init.client hands the groups to Fx and Music: client parts do not require each other.)
local SoundService = game:GetService("SoundService")

local Sound = {}

export type Groups = { music: SoundGroup, effects: SoundGroup }
export type Settings = { music: number, effects: number }

local groups: Groups? = nil

local function group(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Parent = SoundService
	return made
end

function Sound.init(): Groups
	local made = { music = group("BW_Music"), effects = group("BW_Effects") }
	groups = made
	return made
end

-- A player's volumes (0..1 each).
function Sound.apply(settings: Settings)
	local g = groups
	if not g then
		return
	end
	g.music.Volume = math.clamp(settings.music, 0, 1)
	g.effects.Volume = math.clamp(settings.effects, 0, 1)
end

return Sound
