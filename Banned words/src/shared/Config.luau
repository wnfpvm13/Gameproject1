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

	-- Round (docs/DESIGN_V3.md §2, §4; minigame overhaul 2026-10-23): 8 minutes of minigames back to back (no free
	-- talk), then a sudden-death final.
	LIVES = 3,
	ROUND_SECONDS = 480,
	FINAL_AT_ALIVE = 3, -- a round begun with 4+ players goes to the final as soon as this few are left
	FINAL_MAX_SECONDS = 90, -- past this the survivors share the win
	NEXT_GAME_CARD_SECONDS = 3, -- without a presenter: "next: ..." shows this long before a game starts
	AFK_MISSES = 2, -- answer missions missed in a row -> out (a spectator)
	SUBJECTIVE_FLINGS = 1, -- public servers: launches by the presenter or a vote, per player per round
	-- Studio has no private servers: this says which rules a Studio round plays (workspace attribute BW_ServerKind =
	-- "public" / "private" overrides it while testing).
	STUDIO_SERVER_KIND = "public",
	-- Speech judging of banned words (bundle 6e, after a live test). The banned-word talk is played only while it is on
	-- (owner 2026-10-23); Studio can pretend it is with the workspace attribute BW_VoiceJudging = true.
	VOICE_JUDGING = false,

	-- Missions (docs/DESIGN_V3.md §5; bundle 4a, owner 2026-10-23). The quiz: everyone alive answers at once (four
	-- choices); a wrong answer or none is a fail. The final asks harder questions the same way. The roulette picks one
	-- alive player (once a round).
	QUIZ_INTRO_SECONDS = 2, -- the question shows before the buttons work
	QUIZ_SECONDS = 10, -- answer time
	QUIZ_REVEAL_SECONDS = 3, -- the right answer stays on screen
	ROULETTE_SPIN_SECONDS = 6,
	ROULETTE_REVEAL_SECONDS = 2,
	ROULETTE_MIN_PLAYERS = 2,
	ROULETTE_PER_ROUND = 1,
	-- "Say what you like" (bundle 4b's "a word to everyone", bells since 6b): the bells are open BELL_ORDER_SECONDS
	-- (who rang first speaks first among those who spoke least), then up to ONE_WORD_MAX_PERFORMERS take turns on a
	-- topic (ONE_WORD_PREP_SECONDS to read it and maybe swap it once, then ONE_WORD_SECONDS alone on the floor by voice
	-- or ONE_WORD_CHAT_SECONDS by chat); then the presenter picks the one to launch within PRESENTER_JUDGE_SECONDS,
	-- else everyone votes for VOTE_SECONDS (without a presenter only with VOTE_MIN_VOTERS). GAME_PER_ROUND a round.
	ONE_WORD_MAX_PERFORMERS = 5,
	BELL_ORDER_SECONDS = 5,
	ONE_WORD_PREP_SECONDS = 3,
	ONE_WORD_SECONDS = 8,
	ONE_WORD_CHAT_SECONDS = 15,
	GAME_PER_ROUND = 2, -- runs a round of each minigame other than the quiz (no limit) and the roulette (1)
	ONE_WORD_MIN_PLAYERS = 2, -- performers it needs (alive, on the ground)
	ONE_WORD_RESULT_SECONDS = 2, -- who flies (or nobody) stays on the status line this long
	PRESENTER_JUDGE_SECONDS = 10,
	-- The seat bells (bundle 6b): one ring per player each time they are open, at least BELL_COOLDOWN apart.
	BELL_COOLDOWN = 0.2,
	-- The bell quiz (bundle 6b, owner 2026-10-23: the first to ring answers by voice and the presenter judges, so only
	-- with a presenter): BELL_QUIZ_QUESTIONS questions; for each the bells are open BELL_WAIT_SECONDS, the first ring
	-- gets the floor for BELL_ANSWER_SECONDS (chat participants type for BELL_ANSWER_CHAT_SECONDS) and the presenter
	-- then has BELL_VERDICT_SECONDS more to press right or wrong; a wrong answer flies (subjective) and the bells open
	-- again for the others, BELL_TRIES answers a question at most. Nobody rings: everyone answers with four choices.
	BELL_QUIZ_QUESTIONS = 3,
	BELL_QUIZ_MIN_PLAYERS = 2,
	BELL_WAIT_SECONDS = 8,
	BELL_TRIES = 3,
	BELL_ANSWER_SECONDS = 5,
	BELL_ANSWER_CHAT_SECONDS = 10,
	BELL_VERDICT_SECONDS = 5,
	-- System minigames (bundle 6c, docs/DESIGN_V3.md §5.2). Each result stays on screen MINIGAME_RESULT_SECONDS.
	MINIGAME_RESULT_SECONDS = 3,
	-- Crocodile teeth: in a random order everyone presses one of CROC_TEETH teeth in turn (CROC_TURN_SECONDS each,
	-- too late is bitten too); one tooth, hidden on the server, bites.
	CROC_TEETH = 10,
	CROC_TURN_SECONDS = 5,
	CROC_MIN_PLAYERS = 2,
	-- The bomb: whoever holds it answers a two-choice question in BOMB_ANSWER_SECONDS; right passes it on (a ring in
	-- an order drawn at the start), wrong or too late keeps it with a new question; it goes off after a hidden time
	-- between BOMB_MIN_SECONDS and BOMB_MAX_SECONDS, and whoever holds it then flies.
	BOMB_MIN_SECONDS = 20,
	BOMB_MAX_SECONDS = 35,
	BOMB_ANSWER_SECONDS = 4,
	BOMB_MIN_PLAYERS = 2,
	-- Nunchi: everyone rings once to take the next number; two rings within NUNCHI_WINDOW of each other clash (both fly,
	-- it ends there); with no clash the one who never rang flies; NUNCHI_IDLE_SECONDS without a ring (or
	-- NUNCHI_MAX_SECONDS in all) and everyone who has not rung flies.
	NUNCHI_WINDOW = 0.5,
	NUNCHI_IDLE_SECONDS = 8,
	NUNCHI_MAX_SECONDS = 30,
	NUNCHI_MIN_PLAYERS = 3,
	-- The balance game (bundle 6d): "A vs B"; the bells open BALANCE_BELL_SECONDS and the first BALANCE_TALKERS to ring
	-- argue in turn on the floor (BALANCE_TALK_SECONDS, chat participants BALANCE_TALK_CHAT_SECONDS); then everyone picks
	-- in secret within BALANCE_PICK_SECONDS (a pick may change until then); the smaller side flies (a tie or one side:
	-- nobody), and so does whoever did not pick.
	BALANCE_MIN_PLAYERS = 3,
	BALANCE_BELL_SECONDS = 4,
	BALANCE_TALKERS = 3,
	BALANCE_TALK_SECONDS = 4,
	BALANCE_TALK_CHAT_SECONDS = 8,
	BALANCE_PICK_SECONDS = 10,
	-- Red light, green light (무궁화 꽃이 피었습니다, bundle 6d): REDLIGHT_SECONDS of lights (green REDLIGHT_GREEN_MIN-MAX
	-- seconds, red REDLIGHT_RED_MIN-MAX, starting green); each bell press on green moves a player one step (at most
	-- REDLIGHT_MAX_PRESS a second count); a press on red after REDLIGHT_GRACE is out; at the end whoever is short of
	-- REDLIGHT_GOAL steps flies too. Reaching the goal is safe.
	REDLIGHT_SECONDS = 30,
	REDLIGHT_GREEN_MIN = 2,
	REDLIGHT_GREEN_MAX = 4,
	REDLIGHT_RED_MIN = 1.5,
	REDLIGHT_RED_MAX = 3,
	REDLIGHT_MAX_PRESS = 4,
	REDLIGHT_GRACE = 0.3, -- plus the player's round trip (the light reaches them late), up to REDLIGHT_PING_CAP
	REDLIGHT_PING_CAP = 0.5,
	REDLIGHT_GOAL = 25,
	REDLIGHT_UPDATE = 0.5, -- seconds between progress updates on screen
	REDLIGHT_MIN_PLAYERS = 2,
	-- The liar game (bundle 6d): one liar does not know the word, only its category. LIAR_READ_SECONDS to read, the bells
	-- open LIAR_BELL_SECONDS for the order, then each gives one clue on the floor (LIAR_CLUE_SECONDS, chat
	-- LIAR_CLUE_CHAT_SECONDS); the presenter names the liar (PRESENTER_JUDGE_SECONDS) or everyone votes; a named liar
	-- guesses the word from four within LIAR_GUESS_SECONDS: wrong or none flies, right (or the liar not named) gets
	-- SCORE_LIAR_WIN. Nobody else ever flies.
	LIAR_MIN_PLAYERS = 4,
	LIAR_READ_SECONDS = 5,
	LIAR_BELL_SECONDS = 4,
	LIAR_CLUE_SECONDS = 6,
	LIAR_CLUE_CHAT_SECONDS = 12,
	LIAR_GUESS_SECONDS = 8,
	LIAR_GUESS_CHOICES = 4, -- the word among this many of its category
	LEVER_SECONDS = 0.7, -- the podium lever is pulled this long before the launch
	LEVER_DEGREES = 55, -- how far the lever handle swings down (in the first 30% of LEVER_SECONDS)
	LEVER_RETURN_SECONDS = 0.4, -- then it comes back up
	-- Votes (docs/DESIGN_V3.md §5): the top choice wins with VOTE_MIN_VALID valid votes, at least half of the voters
	-- who did not abstain, and no tie; fewer than VOTE_MIN_VOTERS voters -> no vote.
	VOTE_SECONDS = 10,
	VOTE_MIN_VALID = 3,
	VOTE_MIN_VOTERS = 4,

	-- The Studio-only test mission (bundle 2b, until the real missions of bundle 4): everyone alive fails with
	-- TEST_FAIL_CHANCE; a final question knocks out each finalist with TEST_FINAL_FAIL_CHANCE.
	TEST_MISSION_SECONDS = 8,
	TEST_FAIL_CHANCE = 0.3,
	TEST_FINAL_FAIL_CHANCE = 0.4,

	-- Banned words (docs/DESIGN_V3.md §6; bundle 5a, the banned-word talk of bundle 6a): one each, only during the talk.
	HABIT_WORD_CHANCE = 0.3, -- per player: chance that a word is a speech habit (진짜, 대박 ...) instead of a noun
	TALK_SECONDS = 60, -- the talk itself (judged)
	TALK_MIN_PLAYERS = 2,
	TALK_PREP_SECONDS = 5, -- without a presenter: words and topic show this long before the talk
	TALK_REROLL_SECONDS = 15, -- with a presenter: time to re-draw words (or press "start now")
	REROLLS_PUBLIC = 1, -- public servers: the presenter re-draws everyone's words this often a round
	RESCUES_PUBLIC = 1, -- public servers: the presenter rescues this often a round (private: no limit)
	EAR_COOLDOWN = 1, -- seconds between two "I heard a banned word" presses of the presenter
	RESCUE_SECONDS = 3, -- a banned word caught in chat waits this long for the presenter's rescue (bundle 5b)
	HIT_SOUND = 5, -- the sound everyone hears when chat catches a banned word (index in PRESENTER_SOUNDS: 땡)
	-- Speech judging (JudgeService, bundle 6e; only while VOICE_JUDGING): speech in the banned-word talk counts if it
	-- began inside the talk (before its end, or the moment the round was decided) and ended no later than END_TOLERANCE
	-- after that; the settle stage waits until every alive voice player's client says that speech has been sent
	-- (SETTLE_MAX at most).
	END_TOLERANCE = 0,
	SETTLE_MAX = 5,
	SETTLE_NOTICE_AFTER = 1.2,
	SETTLE_SLACK = 1, -- the settle stage waits at most this much past the rescue and the lever for them to end
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
	PRESENTER_PICK_SECONDS = 10, -- the presenter picks the next game between games (then a random one)
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

	-- Fixed UI texts players may read aloud (checked against the word bank by tools/check_content.luau).
	-- %s / %d are filled in by the code (names, numbers).
	TEXT = {
		NEED_READY = "참가 준비된 플레이어 %d명 더 필요해요", -- voice ready or joining by chat
		NEED_PLAYERS = "플레이어 %d명 더 필요해요",
		COUNTDOWN = "곧 시작해요",
		RECOVERING = "잠시 문제가 생겨서 다음 판을 준비해요",
		ASSIGN = "목숨은 %d개예요 · 미션에 실패하면 날아가요",
		PLAY_START = "본 경기 시작!",
		NEXT_GAME = "다음: %s",
		PICKING = "진행자가 다음 미션을 고르는 중",
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
		PICK_AUTO = "시간이 지나서 무작위로 골랐어요",
		TEST_MISSION_TITLE = "연습 미션",
		QUIZ_TITLE = "퀴즈",
		QUIZ_START = "퀴즈 · 정답을 골라요 · 틀리거나 안 고르면 날아가요",
		FINAL_QUIZ = "결승 퀴즈 · 틀리면 바로 탈락",
		QUIZ_ANSWER = "정답: %s",
		QUIZ_ALL_RIGHT = "모두 정답!",
		ROULETTE_TITLE = "룰렛",
		ROULETTE_START = "룰렛이 돌아가요 · 걸린 한 명이 날아가요",
		ROULETTE_HIT = "%s 당첨!",
		ONE_WORD_TITLE = "좋아하는 거 말하기",
		ONE_WORD_START = "좋아하는 거 말하기 · 벨을 누르면 먼저 말해요",
		ONE_WORD_BELL = "🔔 벨을 누르면 먼저 말해요",
		ONE_WORD_TURN = "%s 차례 · %s",
		ONE_WORD_PREP = "곧 시작",
		ONE_WORD_SWAP = "주제 바꾸기",
		ONE_WORD_BY_CHAT = "채팅으로 한마디!",
		JUDGE_PICK = "날릴 사람을 골라 주세요",
		FLING_BUTTON = "날려!",
		JUDGE_WAIT = "진행자가 날릴 사람을 고르는 중",
		JUDGE_VOTE = "투표 · 가장 아쉬운 한마디는?",
		JUDGE_TO_VOTE = "시간이 지나서 투표로 정해요",
		VOTE_NONE = "안 날림",
		VOTE_ABSTAIN = "안 들려요",
		NOBODY_FLUNG = "아무도 안 날아가요",
		FLUNG = "%s 날아가요!",
		EAR_HIT = "🔔 금칙어! %s",
		RESCUE_WAIT = "🚨 %s 금칙어! 진행자가 구제할 수 있어요",
		RESCUED = "🛟 구제! %s 무사해요",
		RESCUE_BUTTON = "🛟 구제",
		MY_WORD_WAS = "내 금칙어: '%s'", -- (no particle: it would depend on the word's last syllable)
		BELL_BUTTON = "🔔 벨",
		BELL_QUIZ_TITLE = "벨 퀴즈",
		BELL_QUIZ_START = "벨 퀴즈 · 먼저 벨을 누른 사람이 말로 답해요",
		BELL_QUIZ_WAIT = "🔔 벨을 눌러 답하세요",
		BELL_QUIZ_ANSWERING = "%s 님이 답하는 중",
		BELL_QUIZ_RIGHT = "⭕ 정답! %s",
		BELL_QUIZ_WRONG = "❌ 땡! %s",
		BELL_QUIZ_NOBODY = "아무도 안 눌러서 모두 답해요",
		VERDICT_PICK = "맞았나요? 정답: %s",
		CROC_TITLE = "악어 이빨",
		CROC_START = "악어 이빨 · 차례대로 이빨을 하나 눌러요 · 물리면 날아가요",
		CROC_TURN = "%s 차례",
		CROC_BITE = "😱 덥석! %s",
		CROC_LATE = "⏰ 시간 초과! %s",
		BOMB_TITLE = "폭탄 돌리기",
		BOMB_START = "폭탄 돌리기 · 맞히면 다음 사람에게 넘어가요",
		BOMB_HOLDER = "💣 %s",
		BOMB_BOOM = "💥 펑! %s",
		NUNCHI_TITLE = "눈치 게임",
		NUNCHI_START = "눈치 게임 · 1부터 한 명씩 벨! 겹치거나 꼴찌면 날아가요",
		NUNCHI_CLASH = "💥 겹쳤다! %s",
		NUNCHI_LAST = "🐢 꼴찌! %s",
		NUNCHI_IDLE = "벨을 안 눌러서 날아가요: %s",
		NUNCHI_NEXT = "다음 숫자: %d",
		NUNCHI_ORDER = "%d %s",
		NUNCHI_NONE = "✕ %s",
		BALANCE_TITLE = "밸런스 게임",
		BALANCE_START = "밸런스 게임 · 적은 쪽이 날아가요",
		BALANCE_VS = "%s vs %s",
		BALANCE_BELL = "🔔 벨을 누르면 먼저 말해요",
		BALANCE_TALK = "%s 님 차례",
		BALANCE_PICK = "몰래 골라요 · 시간 안에 바꿀 수 있어요",
		BALANCE_COUNT = "%s %d · %s %d",
		BALANCE_EVEN = "반반!",
		BALANCE_SAME = "모두 같은 쪽!",
		BALANCE_NOBODY = "아무도 안 날아가요",
		BALANCE_NONE = "안 고름: %s",
		REDLIGHT_TITLE = "무궁화 꽃이 피었습니다",
		REDLIGHT_START = "무궁화 꽃이 피었습니다 · 초록불에 벨! 빨간불엔 멈춰요",
		REDLIGHT_GREEN = "🟢 가세요!",
		REDLIGHT_RED = "🔴 멈춰요!",
		REDLIGHT_STEPS = "내 걸음 %d / %d",
		REDLIGHT_YOU_CAUGHT = "🔴 걸렸어요! 이번 게임은 여기까지",
		REDLIGHT_YOU_SAFE = "🏁 도착! 이제 안전해요",
		REDLIGHT_CAUGHT = "🔴 움직였다! %s",
		REDLIGHT_SHORT = "🐌 못 왔다! %s",
		REDLIGHT_ALL_SAFE = "모두 도착!",
		LIAR_TITLE = "라이어 게임",
		LIAR_START = "라이어 게임 · 제시어를 모르는 한 명을 찾아요",
		LIAR_CATEGORY = "주제: %s",
		LIAR_WORD = "제시어: %s",
		LIAR_YOU = "🤫 당신이 라이어! 주제: %s",
		LIAR_CLUE = "%s 님의 설명",
		LIAR_ACCUSE = "라이어는 누구?",
		LIAR_VOTE = "투표 · 라이어는 누구?",
		LIAR_NONE = "모르겠음",
		LIAR_GUESS = "라이어의 마지막 기회 · 제시어는?",
		LIAR_CAUGHT = "🎯 잡았다! 라이어는 %s · 제시어 %s",
		LIAR_ESCAPED = "😎 라이어 %s 승리! 제시어 %s",
		ACCUSE_PICK = "라이어로 지목할 사람",
		MINIGAME_TOO_FEW = "사람이 너무 적어져서 이번 게임은 그냥 끝나요",
		ACCUSE_BUTTON = "지목!",
		VERDICT_RIGHT = "⭕ 맞음",
		VERDICT_WRONG = "❌ 틀림",
		WORDS_TITLE = "금칙어 명단",
		WORDS_REROLL = "다시 뽑기",
		WORDS_REROLL_ALL = "전원 다시 뽑기",
		TALK_START_NOW = "▶ 바로 시작",
		TALK_TITLE = "금칙어 토크",
		TALK_SOON = "곧 시작",
		TALK_PREP = "금칙어를 나눠 주는 중 · 내 머리 위 단어는 나만 몰라요",
		TALK_ON = "주제로 이야기하세요 · 자기 금칙어를 말하면 날아가요",
		TALK_TOPIC = "주제: %s",
		WORDS_HEARD = "🔔 들었다",
		AFK_OUT = "%s 님은 두 번 연속 답하지 않아 관전으로 바뀌었어요",
		SOUND_DRUMROLL = "두구두구",
		SOUND_APPLAUSE = "박수",
		SOUND_LAUGH = "웃음",
		SOUND_CORRECT = "딩동",
		SOUND_WRONG = "땡",
	},

	-- Scoring (session leaderstats, casual only).
	SCORE_WIN = 3,
	SCORE_PRESENTER = 2, -- the presenter at the end of a round (owner 2026-10-23); launches earn nothing
	SCORE_BELL_QUIZ = 1, -- a right answer in the bell quiz
	SCORE_LIAR_WIN = 2, -- the liar not caught, or caught and guessing the word
	ASSIST_WINDOW = 10, -- (speech assist credit, used again with speech judging in phase 2)
	SCORE_ASSIST = 1,

	-- Spectators (V3): players who are out and late joiners watch from the stands, with reactions.
	REACTIONS = { "👏", "😂", "😱", "😮", "❤️" },
	STAGE_GUARD_CHECK = 1, -- seconds between "is a spectator on the stage?" checks
	STAGE_BEHIND_ROW = 8, -- studs behind the chair row that still count as the stage
	STAND_SPOTS_PER_ROW = 10, -- spectator spots along the stands marker, per tier row
	REACTION_COOLDOWN = 1.2,
	SYNC_COOLDOWN = 1, -- seconds between two "send me the state" requests from one player
	READY_BROADCAST_DELAY = 0.5, -- "ready" changes are gathered into one state broadcast at most this often
	CHAT_JOIN_COOLDOWN = 1, -- seconds between two "join by chat / stop" requests from one player (each one broadcasts)
	CHAT_CHECK_RETRIES = { 5, 20 }, -- seconds before retrying a failed chat permission check (then: no chat for now)

	-- Roblox-licensed Pro Sound Effects (public, free).
	SOUND_BUZZER = "rbxassetid://9113085764", -- Alarm Buzzer 5 (SFX)
	SOUND_BANG = "rbxassetid://9114086657", -- Dirt Explosion 1: sharp bang (SFX), the flying chair firing
	SOUND_SPLASH = "rbxassetid://9120585252", -- Water Splash, Big Water Splash, Dive In 1 (SFX), the landing
	SOUND_BELL = "rbxassetid://1839997929", -- the seat bell's ding (APM game show toolkit, Correct Answer 2; replace
	-- with a shorter desk-bell sound after the owner hears it)
}
