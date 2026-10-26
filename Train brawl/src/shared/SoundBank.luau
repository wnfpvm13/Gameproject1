--!strict
-- Plays the sounds named in Config.Sounds on this client: once at a part (3D) or for the whole screen, or as a loop.
-- Music goes to the "TrainBrawlMusic" SoundGroup (the music button mutes it), everything else to "TrainBrawlEffects".
-- A sound that has `seconds` is cut short (counted from when it has loaded), fading out over its last half second; a
-- sound that has `vary` plays a little higher or lower each time (by up to that share), so a flurry of punches does not
-- repeat one sample like a machine; a sound that fails to load just stays silent. preload() fetches them all at the start so the first home run is not
-- late. Shared so every client part can use it (client parts do not require each other); on the server it does
-- nothing.
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))

local SoundBank = {}

local FADE_SECONDS = 0.5
local ROLL_OFF = 140 -- a 3D sound fades out by this many studs away

local groups: { [string]: SoundGroup } = {}

-- The SoundGroup for music or for effects (made once).
local function group(music: boolean): SoundGroup
	local name = if music then "TrainBrawlMusic" else "TrainBrawlEffects"
	local found = groups[name]
	if found then
		return found
	end
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Volume = 1
	made.Parent = SoundService
	groups[name] = made
	return made
end

local function make(name: string, parent: Instance): Sound?
	if not RunService:IsClient() then
		return nil
	end
	local entry = (Config.Sounds :: any)[name]
	if not entry then
		warn("[TrainBrawl] no sound named " .. name)
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = entry.id
	sound.Volume = entry.volume
	sound.Looped = entry.looped == true
	if entry.vary then
		sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * entry.vary
	end
	sound.RollOffMaxDistance = ROLL_OFF
	sound.SoundGroup = group(entry.music == true)
	sound.Parent = parent
	return sound
end

-- Plays `name` once, at `at` (3D) or for the whole screen when nil; `speed` plays it that much faster (lower when
-- under 1) instead of its usual small variation.
function SoundBank.play(name: string, at: BasePart?, speed: number?)
	local sound = make(name, at or SoundService)
	if not sound then
		return
	end
	if speed then
		sound.PlaybackSpeed = speed
	end
	sound:Play()
	local entry = (Config.Sounds :: any)[name]
	-- Cut by how long it plays at its speed (slowed down, the same part of the recording takes longer).
	local cut: number? = if entry.seconds then entry.seconds / sound.PlaybackSpeed else nil
	if cut then
		local function startCut()
			task.delay(math.max(0, cut - FADE_SECONDS), function()
				if sound.Parent then
					TweenService:Create(sound, TweenInfo.new(FADE_SECONDS), { Volume = 0 }):Play()
				end
			end)
			Debris:AddItem(sound, cut + 0.1)
		end
		if sound.IsLoaded then
			startCut()
		else
			sound.Loaded:Once(startCut)
			Debris:AddItem(sound, 10) -- in case it never loads
		end
	else
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		Debris:AddItem(sound, 10) -- in case it never loads or ends
	end
end

-- A looping sound for the whole screen (not started): the caller plays and stops it.
function SoundBank.loop(name: string): Sound?
	return make(name, SoundService)
end

-- Fetches every sound in Config.Sounds in the background (once, at the start).
function SoundBank.preload()
	if not RunService:IsClient() then
		return
	end
	task.spawn(function()
		-- As Sound instances: a bare id string is fetched as an image and fails ("Asset type does not match").
		local sounds = {}
		for _, entry in Config.Sounds :: any do
			local sound = Instance.new("Sound")
			sound.SoundId = entry.id
			table.insert(sounds, sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
		for _, sound in sounds do
			sound:Destroy()
		end
	end)
end

-- Mutes or unmutes the music group.
function SoundBank.setMusic(on: boolean)
	if RunService:IsClient() then
		group(true).Volume = if on then 1 else 0
	end
end

return SoundBank
