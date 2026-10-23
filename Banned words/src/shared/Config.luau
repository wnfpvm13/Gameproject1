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

	-- Chat participants (docs/DESIGN_V3.md §7): their bubbles stand out and every bubble stays readable from the show
	-- camera (43-49 studs from the chairs) and the far stands (about 120 studs).
	CHAT_BUBBLE_MINIMIZE_DISTANCE = 150, -- studs; farther bubbles shrink to "..." (Roblox default 40)
	CHAT_BUBBLE_MAX_DISTANCE = 200, -- farther bubbles are hidden (default 100)
	CHAT_BUBBLE_TEXT_SIZE = 22, -- chat participants' bubbles (other bubbles keep the default 16)
	-- Chat bubbles go up by this many studs so they sit above the name + hearts tag (client Billboards: 1.6 + 1.7
	-- studs over the head). The banned words of bundle 5 add 1 stud per word row to that tag: raise this then.
	CHAT_BUBBLE_VERTICAL_OFFSET = 2.5,

	-- Presenter (docs/DESIGN_V3.md §8; bundle 3, owner 2026-10-23): a volunteer runs the round from the podium.
	PRESENTER_PICK_SECONDS = 15, -- the presenter picks the next mission in the last this-many seconds of free talk
	PRESENTER_MISSES = 2, -- picks missed in a row -> another presenter (or the system runs the round)
	PRESENTER_RECOMMENDED = 3, -- the mission menu marks this many at the top as recommended
	VOLUNTEER_COOLDOWN = 1, -- seconds between two "volunteer / stop" requests from one player
	PRESENTER_SOUND_COOLDOWN = 3, -- seconds before the same sound button works again
	PRESENTER_WALK_SPEED = 0, -- the presenter stays at the podium during a round (back to the defaults after)
	-- Sound buttons (owner 2026-10-23: five, Roblox-licensed APM Music / Pro Sound Effects). `text` = Config.TEXT key.
	PRESENTER_SOUNDS = {
		{ text = "SOUND_DRUMROLL", id = "rbxassetid://1840444182" }, -- Drum Rolls (A) (APM)
		{ text = "SOUND_APPLAUSE", id = "rbxassetid://9113137529" }, -- Applause Nightclub 1 (SFX)
		{ text = "SOUND_LAUGH", id = "rbxassetid://9114009960" }, -- Crowd Big Burst Of Laughter Cackling 1 (SFX)
		{ text = "SOUND_CORRECT", id = "rbxassetid://1839997929" }, -- Correct Answer 2 (APM game show toolkit)
		{ text = "SOUND_WRONG", id = "rbxassetid://1839997989" }, -- Wrong Answer 3 (APM game show toolkit)
	},

	-- Transcript intake guards (client-side STT). 10 s of Korean speech is roughly 70 syllables = 210 bytes.
	TRANSCRIPT_MAX_BYTES = 600,
	TRANSCRIPT_BURST = 6, -- at most this many transcripts per window per player (spam guard)
	TRANSCRIPT_BURST_WINDOW = 3,
	VOICE_PING_INTERVAL = 1,

	-- Fixed UI texts players may read aloud (checked against the word bank by tools/check_content.luau).
	-- %s / %d are filled in by the code (names, numbers).
	TEXT = {
		NEED_READY = "참가 준비된 플레이어 %d명 더 필요해요", -- voice ready or joining by chat
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
		-- Getting ready (MicPanel, docs/DESIGN_V3.md §2, §7): voice, or chat for players who cannot use voice.
		VOICE_NONE = "음성 채팅을 쓸 수 없는 계정이에요 (만 13세 이상 + 연령 인증 필요)",
		VOICE_CONNECT = "음성 채팅 연결 필요 · 왼쪽 위 ≡ 메뉴(또는 ESC) → 설정 → 음성 채팅 연결",
		VOICE_MUTED = "마이크가 꺼져 있어요",
		CONNECT_TO_PLAY = "음성을 연결하면 다음 판부터 참가할 수 있어요",
		MIC_ON = "마이크를 켜 주세요",
		MIC_TEST = "마이크 테스트 · 아무 말이나 해 보세요",
		MIC_TESTED = "마이크 확인 완료!",
		READY = "준비 완료!",
		READY_COUNT = "준비 완료! (준비된 사람 %d명)",
		HEADSET_TIP = "헤드셋을 쓰면 억울한 탈락을 막을 수 있어요", -- speakers feed others' voices back into the mic
		OR_CHAT = "음성 대신 채팅으로 참가할 수 있어요",
		NO_VOICE_NO_CHAT = "음성도 채팅도 쓸 수 없는 계정이라 관전만 할 수 있어요",
		CHAT_CHECKING = "채팅으로 참가할 수 있는지 확인하고 있어요",
		CHAT_CHECK_FAILED = "채팅 권한을 확인하지 못해서 지금은 관전만 할 수 있어요",
		CHAT_JOIN = "⌨ 채팅으로 참가",
		CHAT_CANCEL = "채팅 참가 취소",
		CHAT_JOINED = "채팅으로 참가해요 · 판 중에는 음성이 꺼져요",
		CHAT_TAG = "[채팅]", -- before a chat participant's name in the chat window
		-- Presenter (docs/DESIGN_V3.md §8).
		VOLUNTEER = "🎤 진행자 지원",
		VOLUNTEER_CANCEL = "진행자 지원 취소",
		STEP_DOWN = "진행 넘기기",
		VOLUNTEERED = "진행자로 지원했어요 · 조건이 맞으면 진행을 맡아요",
		PRESENTER_NAMED = "오늘의 진행자: %s",
		PRESENTER_CHANGED = "진행자가 바뀌었어요: %s",
		PRESENTER_NONE = "진행자 없이 자동으로 진행해요",
		PRESENTER_TAG = "🎤 진행자",
		ME_PRESENTER = "🎤 내가 진행자",
		PRESENTER_CREDIT = "진행 %s",
		PICK_MISSION = "다음 미션을 골라 주세요",
		PICK_RECOMMENDED = "추천",
		PICK_AUTO = "시간이 지나서 추천 미션으로 진행해요",
		TEST_MISSION_TITLE = "연습 미션",
		SOUND_DRUMROLL = "두구두구",
		SOUND_APPLAUSE = "박수",
		SOUND_LAUGH = "웃음",
		SOUND_CORRECT = "딩동",
		SOUND_WRONG = "땡",
	},

	-- Scoring (session leaderstats, casual only).
	SCORE_WIN = 3,
	SCORE_PRESENTER = 2, -- the presenter at the end of a round (owner 2026-10-23); launches earn nothing
	ASSIST_WINDOW = 10, -- (speech assist credit, used again with speech judging in phase 2)
	SCORE_ASSIST = 1,

	-- Spectators (V3): players who are out and late joiners watch from the stands, with reactions.
	REACTIONS = { "👏", "😂", "😱", "😮", "❤️" },
	STAGE_GUARD_CHECK = 1, -- seconds between "is a spectator on the stage?" checks
	STAGE_BEHIND_ROW = 8, -- studs behind the chair row that still count as the stage
	STAND_SPOTS_PER_ROW = 10, -- spectator spots along the stands marker, per tier row
	REACTION_COOLDOWN = 1.2,
	SYNC_COOLDOWN = 1, -- seconds between two "send me the state" requests from one player
	CHAT_JOIN_COOLDOWN = 1, -- seconds between two "join by chat / stop" requests from one player (each one broadcasts)
	CHAT_CHECK_RETRIES = { 5, 20 }, -- seconds before retrying a failed chat permission check (then: no chat for now)

	-- Roblox-licensed Pro Sound Effects (public, free).
	SOUND_BUZZER = "rbxassetid://9113085764", -- Alarm Buzzer 5 (SFX)
	SOUND_BANG = "rbxassetid://9114086657", -- Dirt Explosion 1: sharp bang (SFX), the flying chair firing
	SOUND_SPLASH = "rbxassetid://9120585252", -- Water Splash, Big Water Splash, Dive In 1 (SFX), the landing
}
