--!strict
-- Tunable numbers for 금칙어 게임 Korean. Everything here is a first guess to adjust after playtests.
local RunService = game:GetService("RunService")

return {
	-- Studio allows a solo round so one tester can watch the flow; live servers need two.
	MIN_PLAYERS = if RunService:IsStudio() then 1 else 2,
	MAX_PLAYERS = 10,

	LOBBY_COUNTDOWN = 15,
	ASSIGN_TIME = 6,
	TALK_TIME = 240,
	RESULT_TIME = 8,

	-- Elimination: seconds in the air before landing near the pool centre, then death.
	LAUNCH_FLIGHT_TIME = 1.2,
	DEATH_DELAY = 1.3,

	-- Transcript intake guards (client-side STT, see docs/DESIGN.md).
	TRANSCRIPT_MIN_INTERVAL = 0.25,
	TRANSCRIPT_MAX_LEN = 200,
	DUPLICATE_WINDOW = 2,

	-- Question cards (silence breaker): everyone gets about two cards per round.
	QUESTION_ANSWER_TIME = 10,
	QUESTION_MIN_INTERVAL = 10,
	QUESTION_MAX_INTERVAL = 30,
	QUESTION_STRIKES = 2, -- missed cards before elimination (first one is a warning)

	-- Scoring (session leaderstats): the last other speaker before an elimination gets the assist.
	ASSIST_WINDOW = 10,
	SCORE_ASSIST = 1,
	SCORE_SURVIVE = 3,
	SCORE_GUEST_HIT = 1, -- talk show: per panelist the guest launches

	-- Talk show needs one guest plus two panelists.
	TALKSHOW_MIN_PLAYERS = 3,

	-- Roblox-licensed Pro Sound Effects (public, free).
	SOUND_BUZZER = "rbxassetid://9113085764", -- Alarm Buzzer 5 (SFX)
	SOUND_SPLASH = "rbxassetid://9120585252", -- Water Splash Big Water Splash Dive In 1 (SFX)
}
