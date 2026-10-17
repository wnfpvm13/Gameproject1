--!strict
-- Tunable numbers for 금칙어 게임 Korean. Everything here is a first guess to adjust after playtests.
local RunService = game:GetService("RunService")

local isStudio = RunService:IsStudio()

return {
	-- Studio allows a solo round so one tester can watch the flow; live servers need two.
	MIN_PLAYERS = if isStudio then 1 else 2,
	MAX_PLAYERS = 10,

	-- Only players who connected voice and passed the mic test take a seat (Studio test accounts have no voice).
	REQUIRE_VOICE_READY = not isStudio,

	LOBBY_COUNTDOWN = 15,
	ASSIGN_TIME = 6,
	TALK_TIME = 180, -- owner decision 2026-10-18 (was 240)
	RESULT_TIME = 8,

	-- After the last elimination / time-out: keep accepting late transcripts, and let the last launch land.
	END_GRACE = 1.2,

	-- Elimination: seconds in the air before landing in the pool, then death.
	LAUNCH_FLIGHT_TIME = 1.2,
	DEATH_DELAY = 1.3,

	-- Transcript intake guards (client-side STT, see docs/DESIGN.md).
	TRANSCRIPT_MIN_INTERVAL = 0.25,
	TRANSCRIPT_MAX_LEN = 200,
	DUPLICATE_WINDOW = 2,

	-- Question cards (silence breaker): issued on a fixed schedule so everyone gets about two per round.
	QUESTION_ANSWER_TIME = 10,
	QUESTION_MIN_INTERVAL = 10,
	QUESTION_MAX_INTERVAL = 30,
	QUESTION_STRIKES = 2, -- missed cards before elimination (first one is a warning)
	-- A missed card does not count if the player's mic picked up speech during the window (recognition failure).
	VOICE_PING_INTERVAL = 1,

	-- Scoring (session leaderstats): the last other alive speaker before an elimination gets the assist.
	ASSIST_WINDOW = 10,
	SCORE_ASSIST = 1,
	SCORE_SURVIVE = 3,
	SCORE_GUEST_HIT = 1, -- talk show: per panelist the guest launches

	-- Talk show: one guest plus at least three panelists, so the first launch does not end the round.
	TALKSHOW_MIN_PLAYERS = 4,
	GUEST_MAX_HITS_PER_SENTENCE = 2,
	GUEST_LIST_LIMIT = 3, -- a guest sentence with this many word-bank words is treated as listing (no launches)
	GUEST_HIT_COOLDOWN = 6,

	-- Roblox-licensed Pro Sound Effects (public, free).
	SOUND_BUZZER = "rbxassetid://9113085764", -- Alarm Buzzer 5 (SFX)
	SOUND_SPLASH = "rbxassetid://9120585252", -- Water Splash Big Water Splash Dive In 1 (SFX)
}
