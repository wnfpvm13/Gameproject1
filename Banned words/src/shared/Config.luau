--!strict
-- Tunable numbers for 금칙어 게임 Korean (V3, 2026-10-22: indoor pool missions, 3 lives, the flying chair).
-- Everything here is a first guess to adjust after playtests (docs/DESIGN_V3.md §14).
local RunService = game:GetService("RunService")

local isStudio = RunService:IsStudio()

return {
	-- Studio allows a solo round so one tester can watch the flow; live servers need two.
	MIN_PLAYERS = if isStudio then 1 else 2,
	MAX_PLAYERS = 10, -- one match per server, ten chairs

	-- Only players who connected voice and passed the mic test take a seat (Studio test accounts have no voice).
	REQUIRE_VOICE_READY = not isStudio,

	LOBBY_COUNTDOWN = 15,
	REMATCH_COUNTDOWN = 8, -- the next round right after a result
	ASSIGN_TIME = 8,
	RESULT_TIME = 10,

	-- Round (docs/DESIGN_V3.md §2, §4): 8 minutes of free talk and missions, then a sudden-death final.
	LIVES = 3,
	ROUND_SECONDS = 480,
	FINAL_AT_ALIVE = 3, -- a round begun with 4+ players goes to the final as soon as this few are left
	FINAL_MAX_SECONDS = 90, -- past this the survivors share the win
	FREE_TALK_SECONDS = 40, -- between missions
	AFK_MISSES = 2, -- answer missions missed in a row -> out (a spectator)
	SUBJECTIVE_FLINGS = 1, -- public servers: launches by the presenter or a vote, per player per round
	-- Studio has no private servers: this says which rules a Studio round plays (workspace attribute BW_ServerKind =
	-- "public" / "private" overrides it while testing).
	STUDIO_SERVER_KIND = "public",

	-- The Studio-only test mission (bundle 2b, until the real missions of bundle 4): everyone alive fails with
	-- TEST_FAIL_CHANCE; a final question knocks out each finalist with TEST_FINAL_FAIL_CHANCE.
	TEST_MISSION_SECONDS = 8,
	TEST_FAIL_CHANCE = 0.3,
	TEST_FINAL_FAIL_CHANCE = 0.4,

	-- V2 word schedule and speech judging (WordService / JudgeService). Not used by the V3 round until the banned
	-- words come back (bundle 5) and speech judging (phase 2); kept for those modules and their tests.
	WORD_STEPS = { 0.30, 0.65 },
	WORD_WARNING = 10, -- seconds of notice before a new word takes effect
	WORD_DELAY_WINDOW = 30, -- two or more launches in this window push the next word back (at most WORD_DELAY_MAX)
	WORD_DELAY_MAX = 30,
	HOLD_AFTER_WORD = 8,
	HABIT_WORD_CHANCE = 0.5, -- per player: chance that a word is a speech habit (진짜, 대박 ...) instead of a noun
	-- Speech still counts if it began before the moment the round was decided and ended no later than END_TOLERANCE
	-- after it; judging waits until every alive player's client says that speech has been sent (SETTLE_MAX at most).
	END_TOLERANCE = 0,
	SETTLE_MAX = 5,
	SETTLE_NOTICE_AFTER = 1.2,
	RESPAWN_TIME = 3,

	-- V3 flying chair (docs/DESIGN_V3.md §10, owner 2026-10-22): the seat flap snaps back with a bang, the player flies
	-- off as a ragdoll far into the pool and is back on the seat FLING_RETURN_SECONDS after the launch.
	FLING_RETURN_SECONDS = 5,
	FLING_APEX_HEIGHT = 20, -- studs above the launch point at the top of the arc (keeps it under the show camera's
	-- top edge and the HUD; also capped under PoolHall CeilingY)
	FLING_BODY_TOP = 4, -- studs from the root to the top of a tumbling body (keeps the whole body under CeilingY)
	FLING_SPIN = 7, -- rad/s backward tumble at the launch
	FLING_FLOAT_DENSITY = 0.45, -- body density while flying, so it floats on the water (avatars sink otherwise)
	FLING_COLLIDE_DELAY = 0.2, -- body parts start colliding this long after the launch (seated feet touch the carpet,
	-- and colliding from the first frame cost ~10% of the throw in the Studio test)
	CHAIR_FLAP_DEGREES = 80, -- how far the seat flap snaps back
	CHAIR_SNAP_SECONDS = 0.12, -- the snap itself, overshooting by CHAIR_OVERSHOOT_DEGREES
	CHAIR_OVERSHOOT_DEGREES = 10,
	CHAIR_SETTLE_SECONDS = 0.15, -- back from the overshoot
	CHAIR_HOLD_SECONDS = 0.8, -- the flap stays up this long
	CHAIR_RECOVER_SECONDS = 2.5, -- then eases back down (done before the player is back)
	GETUP_RETRY_SECONDS = 0.2, -- after a launch my client stands my character up, retrying until it took
	GETUP_TRIES = 5, -- (the network ownership comes back with or after PlatformStand)

	-- Transcript intake guards (client-side STT). 10 s of Korean speech is roughly 70 syllables = 210 bytes.
	TRANSCRIPT_MAX_BYTES = 600,
	TRANSCRIPT_BURST = 6, -- at most this many transcripts per window per player (spam guard)
	TRANSCRIPT_BURST_WINDOW = 3,
	VOICE_PING_INTERVAL = 1,

	-- Fixed UI texts players may read aloud (checked against the word bank by tools/check_content.luau).
	-- %s / %d are filled in by the code (names, numbers).
	TEXT = {
		NEED_READY = "마이크 준비된 플레이어 %d명 더 필요해요",
		NEED_PLAYERS = "플레이어 %d명 더 필요해요",
		COUNTDOWN = "곧 시작해요",
		RECOVERING = "잠시 문제가 생겨서 다음 판을 준비해요",
		ASSIGN = "목숨은 %d개예요 · 미션에 실패하면 날아가요",
		PLAY_START = "본 경기 시작!",
		FREE_TALK = "자유롭게 이야기하세요",
		TEST_MISSION = "연습 미션 · 운에 맡겨 보세요",
		FINAL = "결승 · 틀리면 바로 탈락",
		ALL_WRONG = "모두 틀려서 아무도 탈락하지 않아요 · 다시!",
		TO_FINAL = "남은 사람이 한꺼번에 떨어져서 그대로 결승으로 가요",
		LIFE_LOST = "%s 목숨 -1",
		OUT = "%s 탈락!",
		MY_LIFE_LOST = "내 목숨 -1 · 남은 목숨 %d",
		MY_OUT = "탈락! 관람석에서 응원해 주세요",
		LEFT = "%s 님이 나갔어요",
		WINNER = "%s 우승!",
		JOINT_WINNERS = "%s 공동 우승!",
		NO_WINNER = "우승자 없이 끝났어요",
		SETTLING = "마지막 말을 확인하고 있어요…",
		RECOGNITION_UNSTABLE = "음성 인식이 불안정해요 · 마이크 연결을 확인해 주세요",
	},

	-- Scoring (session leaderstats, casual only).
	SCORE_WIN = 3,
	ASSIST_WINDOW = 10, -- (speech assist credit, used again with speech judging in phase 2)
	SCORE_ASSIST = 1,

	-- Spectators (V3): players who are out and late joiners watch from the stands, with reactions.
	REACTIONS = { "👏", "😂", "😱", "😮", "❤️" },
	STAGE_GUARD_CHECK = 1, -- seconds between "is a spectator on the stage?" checks
	STAGE_BEHIND_ROW = 8, -- studs behind the chair row that still count as the stage
	STAND_SPOTS_PER_ROW = 10, -- spectator spots along the stands marker, per tier row
	REACTION_COOLDOWN = 1.2,
	SYNC_COOLDOWN = 1, -- seconds between two "send me the state" requests from one player

	-- Roblox-licensed Pro Sound Effects (public, free).
	SOUND_BUZZER = "rbxassetid://9113085764", -- Alarm Buzzer 5 (SFX)
	SOUND_BANG = "rbxassetid://9114086657", -- Dirt Explosion 1: sharp bang (SFX), the flying chair firing
	SOUND_SPLASH = "rbxassetid://9120585252", -- Water Splash, Big Water Splash, Dive In 1 (SFX), the landing
}
