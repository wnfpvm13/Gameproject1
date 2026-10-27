--!strict
-- Background music (bundle 11a, owner 2026-10-27: "너무 슴슴하네"; docs/BUNDLE11_2026-10-27.md). One looping track for
-- each part of the round (Config.MUSIC_TRACKS: lobby — also the countdown, the assignment and the result —, play,
-- final), crossfaded over MUSIC_FADE_SECONDS. In the result the track waits MUSIC_RESULT_DELAY for the fanfare.
-- Quieter (MUSIC_DUCK) while someone speaks for the game; silent while my mic test listens (the recognizer would hear
-- it from a speaker) and until my saved settings came (muted ones must not blare first). The player's volume is the
-- group's (client Sound); fades and ducking move each track's own volume, so neither overwrites the other.
local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BannedWords"):WaitForChild("Config"))

local Music = {}

local DUCK_SECONDS = 0.4 -- ducking and the mic test move this fast (a track change fades slower)

local tracks: { [string]: Sound } = {}
local tweens: { [string]: Tween } = {}
local wanted: string? = nil -- the track for the phase now (nil: none)
local released = false -- my settings came
local ducked = false
local micTest = false
local resultFrom = 0 -- os.clock() from which the result's track may play
local phaseNow = ""

-- Which track goes with a phase.
local function trackFor(phase: string): string?
	if phase == "Play" then
		return "play"
	elseif phase == "Final" then
		return "final"
	elseif phase == "Lobby" or phase == "Countdown" or phase == "Assign" or phase == "Result" then
		return "lobby"
	end
	return nil
end

-- Every track to its volume now: the wanted one at full (ducked, held or silenced as needed), the others at 0 and
-- stopped once faded out.
local function update(seconds: number)
	local level = if not released or micTest then 0 elseif ducked then Config.MUSIC_DUCK else 1
	if phaseNow == "Result" and os.clock() < resultFrom then
		level = 0
	end
	for name, sound in tracks do
		local target = if name == wanted then Config.MUSIC_VOLUME * level else 0
		if math.abs(sound.Volume - target) < 1e-3 and (target > 0) == sound.IsPlaying then
			continue
		end
		local running = tweens[name]
		if running then
			running:Cancel()
		end
		if target > 0 and not sound.IsPlaying then
			sound:Play()
		end
		local tween = TweenService:Create(sound, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = target })
		tweens[name] = tween
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and target == 0 and tweens[name] == tween then
				sound:Stop() -- (a track that comes back starts from its beginning)
			end
		end)
		tween:Play()
	end
end

-- Makes the tracks in `group` (the Music sound group).
function Music.init(group: SoundGroup)
	for name, id in Config.MUSIC_TRACKS :: { [string]: string } do
		local sound = Instance.new("Sound")
		sound.Name = "Music_" .. name
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = group
		sound.Parent = group
		tracks[name] = sound
	end
end

-- The round's phase (RoundState).
function Music.setPhase(phase: string)
	if phase == phaseNow then
		return
	end
	if phase == "Result" then
		resultFrom = os.clock() + Config.MUSIC_RESULT_DELAY
		task.delay(Config.MUSIC_RESULT_DELAY + 0.05, function()
			if phaseNow == "Result" then
				update(Config.MUSIC_FADE_SECONDS)
			end
		end)
	end
	phaseNow = phase
	wanted = trackFor(phase)
	update(Config.MUSIC_FADE_SECONDS)
end

-- Someone speaks for the game now (a word to everyone, a clue, a bell answer, 스무고개's turns, the banned-word talk).
function Music.setDucked(on: boolean)
	if on ~= ducked then
		ducked = on
		update(DUCK_SECONDS)
	end
end

-- My mic test is listening (voice players who have not passed it yet).
function Music.setMicTest(on: boolean)
	if on ~= micTest then
		micTest = on
		update(DUCK_SECONDS)
	end
end

-- My settings came (the group volume is set): the music may play.
function Music.release()
	if not released then
		released = true
		update(Config.MUSIC_FADE_SECONDS)
	end
end

-- Whether a mission screen is one where someone speaks for the game (MUSIC_DUCK). One-word turns call their stage
-- `phase`; the others `stage`.
function Music.speaking(payload: { [string]: any }): boolean
	local kind = payload.kind
	if kind == "oneWord" then
		return payload.phase == "talk"
	elseif kind == "balance" then
		return payload.stage == "talk"
	elseif kind == "liar" then
		return payload.stage == "clue"
	elseif kind == "bellQuiz" then
		return payload.stage == "answer"
	elseif kind == "twenty" then
		return payload.stage == "ask" or payload.stage == "verdict"
	end
	return false
end

return Music
