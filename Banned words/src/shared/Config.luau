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
}
