--!strict
-- Tunable numbers for 금칙어 게임 Korean (V2, 2026-10-20: free talk in a round lounge, words pile up 1 -> 2 -> 3).
-- Everything here is a first guess to adjust after playtests (docs/DESIGN_V2.md).
local RunService = game:GetService("RunService")

local isStudio = RunService:IsStudio()

return {
	-- Studio allows a solo round so one tester can watch the flow; live servers need two.
	MIN_PLAYERS = if isStudio then 1 else 2,
	MAX_PLAYERS = 10, -- one match per server for now (owner 2026-10-20)

	-- Only players who connected voice and passed the mic test take a seat (Studio test accounts have no voice).
	REQUIRE_VOICE_READY = not isStudio,

	LOBBY_COUNTDOWN = 15,
	REMATCH_COUNTDOWN = 8, -- the next round right after a result
	ASSIGN_TIME = 8,
	RESULT_TIME = 10,

	-- Maximum match length by starting player count (the round ends early once one survivor is left).
	MATCH_TIME = {
		{ upTo = 3, seconds = 330 },
		{ upTo = 6, seconds = 450 },
		{ upTo = 10, seconds = 570 },
	},

	-- Words pile up: everyone alive gets one more word at these fractions of the match time (max 3 words).
	WORD_STEPS = { 0.30, 0.65 },
	WORD_WARNING = 10, -- seconds of notice before a new word takes effect
	-- Two or more launches in the last WORD_DELAY_WINDOW seconds push the next word back (at most WORD_DELAY_MAX).
	WORD_DELAY_WINDOW = 30, -- counts eliminations except players leaving
	WORD_DELAY_MAX = 30,
	HABIT_WORD_CHANCE = 0.5, -- chance that the third word is a speech habit (진짜, 대박 ...) instead of a noun

	-- A transcript covers at most this many seconds of speech (Roblox cuts STT segments at about 10 s).
	-- Words that took effect inside that window are not used against the transcript.
	CHUNK_MAX = 12,

	-- After the last elimination / time-out: keep accepting late transcripts, and let the last launch finish.
	END_GRACE = 1.2,
	LAUNCH_POP_TIME = 0.5, -- seconds from launch to the "펑" (the body vanishes there)
	RESPAWN_TIME = 3,

	-- Transcript intake guards (client-side STT). 10 s of Korean speech is roughly 70 syllables = 210 bytes.
	TRANSCRIPT_MAX_BYTES = 600,
	TRANSCRIPT_BURST = 6, -- at most this many transcripts per window per player (spam guard)
	TRANSCRIPT_BURST_WINDOW = 3,
	VOICE_PING_INTERVAL = 1,

	-- Mission cards (V2.1): card -> notice -> short vote -> follow-up, then the next mission. Nobody dies for them.
	MISSION_NOTICE_AT = 25, -- seconds after the card: a notice raises the stakes
	VOTE_OPEN_AFTER = 40, -- seconds after the card: the vote opens (talk first)
	VOTE_SECONDS = 12,
	VOTE_RESULT_SECONDS = 4, -- the result stays on screen this long (late joiners get it too)
	EVENT_SHOW_SECONDS = 7, -- a quiet-time event banner stays this long
	MISSION_LENGTH = 120, -- seconds per mission before the next card

	-- Quiet-time help next to the missions (no forced speaking, nobody dies for silence).
	QUIET_TOPIC = 30, -- seconds without speech -> a topic card on the left
	QUIET_EVENT = 60, -- seconds without speech -> a small situation event
	EVENT_COOLDOWN = 40,
	AFTER_LAUNCH_QUIET = 12, -- no new event right after a launch, let people react

	-- Scoring (session leaderstats, casual only): the last other alive speaker before a launch gets the assist.
	ASSIST_WINDOW = 10,
	SCORE_ASSIST = 1,
	SCORE_SURVIVE = 3,

	-- Ghosts: eliminated players stay in the lounge, see-through, outside the chair ring, with reactions.
	GHOST_TRANSPARENCY = 0.6,
	REACTIONS = { "👏", "😂", "😱", "😮", "❤️" },
	GHOST_RING_CHECK = 1, -- seconds between "is an outsider inside the ring?" checks (backs up the barrier)
	REACTION_COOLDOWN = 1.2,

	-- Roblox-licensed Pro Sound Effects (public, free).
	SOUND_BUZZER = "rbxassetid://9113085764", -- Alarm Buzzer 5 (SFX)
}
