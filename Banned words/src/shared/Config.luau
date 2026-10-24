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

	-- Round (docs/DESIGN_V3.md §2, §4; minigame overhaul 2026-10-23; owner 2026-10-24: a number of games, like the
	-- minigame collections on Roblox): ROUND_GAMES minigames back to back (no free talk), then a sudden-death final.
	-- ROUND_MAX_SECONDS only caps a round of long games (a game that would not fit is not started).
	LIVES = 3,
	ROUND_GAMES = 6,
	ROUND_MAX_SECONDS = 720,
	FINAL_AT_ALIVE = 3, -- a round begun with 4+ players goes to the final as soon as this few are left
	FINAL_MAX_SECONDS = 90, -- past this the survivors share the win
	-- Between games (owner 2026-10-24): what the last game did, then without a presenter the alive players vote for the
	-- next game among NEXT_VOTE_CHOICES (NEXT_VOTE_SECONDS, over once all voted; none: at random), then the next
	-- game's briefing (its name and one-line rule, 3-2-1) for BRIEF_SECONDS.
	NEXT_VOTE_CHOICES = 3,
	NEXT_VOTE_SECONDS = 7,
	BRIEF_SECONDS = 3,
	AFK_MISSES = 2, -- answer missions missed in a row -> out (a spectator)
	SUBJECTIVE_FLINGS = 1, -- public servers: launches by the presenter or a vote, per player per round
	-- Studio has no private servers: this says which rules a Studio round plays (workspace attribute BW_ServerKind =
	-- "public" / "private" overrides it while testing).
	STUDIO_SERVER_KIND = "public",
	-- Speech judging of banned words (bundle 6e, after a live test). The banned-word talk is played only while it is on
	-- (owner 2026-10-23); Studio can pretend it is with the workspace attribute BW_VoiceJudging = true. On since the
	-- friend beta (owner 2026-10-24: that test is also the live speech test, docs/STT_LIVE_TEST_2026-10-24.md).
	VOICE_JUDGING = true,
	-- The solo speech test build only (tools/install_game.py --voice-judging --solo, docs/STT_LIVE_TEST_2026-10-24.md):
	-- a player also sees their own banned word, so one tester knows what to say. Never on in a real game.
	SHOW_OWN_WORD = false,

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
	-- The bomb (a pass button, owner 2026-10-25): whoever gets it holds it a random BOMB_HOLD_MIN-MAX seconds, then
	-- "넘기기" lights up and passes it on (a ring in an order drawn at the start); it goes off after a hidden time
	-- between BOMB_MIN_SECONDS and BOMB_MAX_SECONDS, and whoever holds it then flies. The button lit BOMB_IDLE_SECONDS
	-- without a press is a missed answer.
	BOMB_MIN_SECONDS = 12,
	BOMB_MAX_SECONDS = 25,
	BOMB_HOLD_MIN = 0.6,
	BOMB_HOLD_MAX = 1.5,
	BOMB_IDLE_SECONDS = 5,
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
	-- Timing games (bundle 8b, owner 2026-10-24). Presses count from the moment the player made them: the server's
	-- arrival time less half their round trip, up to TIMING_PING_CAP of round trip (shared/PressTiming).
	TIMING_PING_CAP = 0.5,
	TIMING_GRACE = 0.3, -- the bells stay open this much past the shown end, for presses made in time arriving late
	-- 숫자 맞추기: ring once at a target between TIMEGUESS_MIN and TIMEGUESS_MAX seconds (two decimals), shown
	-- TIMEGUESS_READ_SECONDS before the clock starts; the clock is visible TIMEGUESS_VISIBLE_SECONDS, the bells stay
	-- open TIMEGUESS_LATE past the target. The farthest from it flies.
	TIMEGUESS_MIN = 5,
	TIMEGUESS_MAX = 10,
	TIMEGUESS_READ_SECONDS = 3,
	TIMEGUESS_VISIBLE_SECONDS = 3,
	TIMEGUESS_LATE = 3,
	TIMEGUESS_MIN_PLAYERS = 2,
	-- 총잡이 결투: pairs at random; "fire!" DUEL_READY_MIN-MAX seconds after "ready", then DUEL_WINDOW to ring.
	DUEL_READY_MIN = 2,
	DUEL_READY_MAX = 5,
	DUEL_WINDOW = 2,
	DUEL_MIN_PLAYERS = 2,
	-- 물병 세우기: one throw per zone width (fractions of the bar, narrower each time); the bar starts
	-- BOTTLE_LEAD_SECONDS after the throw shows and sweeps there and back every BOTTLE_PERIOD; BOTTLE_THROW_SECONDS to
	-- ring; the throw's result shows BOTTLE_SHOW_SECONDS. A zone keeps BOTTLE_EDGE from the bar's ends.
	BOTTLE_ZONES = { 0.2, 0.13, 0.08 }, -- (harder, owner 2026-10-25: was 0.3, 0.2, 0.12 at 1.6 s)
	BOTTLE_PERIOD = 1.15,
	BOTTLE_LEAD_SECONDS = 1,
	BOTTLE_THROW_SECONDS = 5,
	BOTTLE_SHOW_SECONDS = 2,
	BOTTLE_EDGE = 0.05,
	BOTTLE_MIN_PLAYERS = 2,
	-- More quiz kinds (bundle 8c, owner 2026-10-24). O/X: OX_QUESTIONS statements in a row (each shown OX_INTRO_SECONDS,
	-- OX_SECONDS to answer, the right answer OX_REVEAL_SECONDS); the most wrong fly. 숫자 근사: one question shown
	-- ESTIMATE_INTRO_SECONDS, ESTIMATE_SECONDS to type a whole number from 1 to ESTIMATE_MAX; the farthest flies (with
	-- ESTIMATE_MIN_PLAYERS on the ground: alone, "the farthest" is always you). ESTIMATE_MAX keeps a number short enough
	-- that it cannot carry a phone number (the numbers show to everyone; its digits are the input box's limit).
	OX_QUESTIONS = 3,
	OX_INTRO_SECONDS = 1.5,
	OX_SECONDS = 5,
	OX_REVEAL_SECONDS = 1.5,
	ESTIMATE_INTRO_SECONDS = 2,
	ESTIMATE_SECONDS = 15,
	ESTIMATE_MAX = 999999,
	ESTIMATE_MIN_PLAYERS = 2,
	LEVER_SECONDS = 0.7, -- the podium lever is pulled this long before the launch
	LEVER_DEGREES = 55, -- how far the lever handle swings down (in the first 30% of LEVER_SECONDS)
	LEVER_RETURN_SECONDS = 0.4, -- then it comes back up
	-- Votes (docs/DESIGN_V3.md §5): the top choice wins with VOTE_MIN_VALID valid votes, at least half of the voters
	-- who did not abstain, and no tie; fewer than VOTE_MIN_VOTERS voters -> no vote.
	VOTE_SECONDS = 10,
	VOTE_MIN_VALID = 3,
	VOTE_MIN_VOTERS = 4,

	-- The Studio-only practice mission (bundle 2b; since 2026-10-25 only with the workspace attribute BW_TestMission):
	-- everyone alive fails with TEST_FAIL_CHANCE; a final question knocks out each finalist with TEST_FINAL_FAIL_CHANCE.
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

	-- V3 flying chair (docs/DESIGN_V3.md §10; owner 2026-10-24: an explosion, no flight path): a blast in front of the
	-- chair throws the player off as a ragdoll, and they are back on the seat FLING_RETURN_SECONDS after the launch.
	-- Owner 2026-10-25: faster, harder and anywhere behind or to the sides (it may bounce off the walls and the ceiling
	-- and come down outside the pool).
	FLING_RETURN_SECONDS = 5,
	BLAST_FORWARD = 1.5, -- studs in front of the seated body where the blast goes off (drawn by the clients)
	BLAST_BELOW = 1, -- and this far below its root
	BLAST_SPEED_MIN = 150, -- studs/s the blast gives the body (a random speed in this range; was 90-125)
	BLAST_SPEED_MAX = 205,
	BLAST_PITCH_MIN = 22, -- degrees above the ground (a random angle; a steep fast one hits the ceiling and bounces)
	BLAST_PITCH_MAX = 62,
	BLAST_SPREAD = 75, -- degrees left or right of straight back at most (a random direction; was 15, kept over the pool)
	BLAST_SPIN = 26, -- rad/s tumble about a random axis (was 12)
	FLIGHT_LOST_DEPTH = 30, -- a flying body this far under the water is out of the hall: it is put back over the pool
	FLIGHT_LOST_DROP = 6, -- (this far above the landing zone)
	BLAST_RADIUS = 12, -- size of the drawn explosion (studs; it pushes nothing itself)
	-- Owner 2026-10-24: the fewer lives left, the bigger the blast (drawn only; the throw keeps its speed until the
	-- pool's length is checked): size = 1 + BLAST_GROWTH x the lives lost before this one, so with three lives 1, 1.5,
	-- 2 (the last life and going out).
	BLAST_GROWTH = 0.5,
	CHAIN_DELAY = 0.2, -- several launched by one event go off one after another, from the camera's left chair
	SHAKE_SECONDS = 0.45, -- the round camera shakes this long at a blast (not with the device's reduced motion)
	SHAKE_STUDS = 0.35, -- how far it moves at a normal blast (times the blast's size)
	FLASH_FROM_SIZE = 2, -- blasts this big also flash the screen white for a moment
	FLASH_WHITE_ALPHA = 0.45, -- its transparency at the start
	FLASH_WHITE_SECONDS = 0.35, -- and how long it takes to fade
	-- The flight record (owner 2026-10-24): where a flight first comes down — the water, or wherever it stops moving
	-- (slower than FLIGHT_STOPPED_SPEED studs/s) after FLIGHT_SETTLE_SECONDS.
	FLIGHT_SETTLE_SECONDS = 0.4,
	FLIGHT_STOPPED_SPEED = 4,
	STUDS_TO_METERS = 0.28, -- (Roblox's usual conversion, for the "longest flight" line)
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
	-- studs over the head). While words show over heads the tag is taller: ChatLook adds their rows (owner 2026-10-25:
	-- a chat bubble was hidden behind the words).
	CHAT_BUBBLE_VERTICAL_OFFSET = 2.5,

	-- Presenter (docs/DESIGN_V3.md §8; bundle 3, owner 2026-10-23): a volunteer runs the round from the podium.
	PRESENTER_PICK_SECONDS = 10, -- the presenter picks the next game between games (then a random one)
	PRESENTER_MISSES = 2, -- picks missed in a row -> another presenter (or the system runs the round)
	PRESENTER_RECOMMENDED = 3, -- the mission menu lists this many suited ones first (no mark, owner 2026-10-25)
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
		GAME_COUNT = "미션 %d/%d", -- the status board during the main game: the game now / games in a round
		NEXT_VOTE = "다음에 할 미션을 골라요",
		RECAP_LOST = "%s 목숨 잃음",
		RECAP_OUT = "%s 탈락",
		RECAP_NONE = "아무도 안 날아갔어요",
		PICKING = "진행자가 다음 미션을 고르는 중",
		TEST_MISSION = "연습 미션 · 운에 맡겨 보세요",
		FINAL = "결승 · 틀리면 바로 탈락",
		ALL_WRONG = "모두 틀려서 아무도 탈락하지 않아요 · 다시!",
		TO_FINAL = "남은 사람이 한꺼번에 떨어져서 그대로 결승으로 가요",
		LIFE_LOST = "%s · 목숨 1개 잃음",
		OUT = "%s 탈락!",
		MY_LIFE_LOST = "목숨 1개를 잃었어요 · 남은 목숨 %d개",
		MY_NO_LIVES = "목숨을 모두 잃었어요", -- (the last one left, or everyone left fell at once)
		MY_OUT = "탈락! 관람석에서 응원해 주세요",
		LEFT = "%s 님이 나갔어요",
		WINNER = "%s 우승!",
		JOINT_WINNERS = "%s 공동 우승!",
		NO_WINNER = "우승자 없이 끝났어요",
		-- Round awards on the result screen (owner 2026-10-24).
		AWARD_FLIGHT = "최장 비행 %s · %.1fm",
		AWARD_SURVIVOR = "목숨을 안 잃은 미션 최다 %s · %d개",
		SETTLING = "마지막 말을 확인하고 있어요…",
		RECOGNITION_UNSTABLE = "음성 인식이 불안정해요 · 마이크 연결을 확인해 주세요",
		-- Getting ready (MicPanel, docs/DESIGN_V3.md §2, §7): voice, or chat for players who cannot use voice.
		VOICE_NONE = "음성 채팅이 켜진 계정만 참가할 수 있어요 (만 13세 이상 + 연령 인증 필요)",
		VOICE_CONNECT = "음성 채팅 연결 필요 · 왼쪽 위 ≡ 메뉴(또는 ESC) → 설정 → 음성 채팅 연결",
		VOICE_MUTED = "마이크가 꺼져 있어요",
		CONNECT_TO_PLAY = "음성을 연결하면 다음 판부터 참가할 수 있어요",
		MIC_ON = "마이크를 켜 주세요",
		MIC_TEST = "마이크 테스트 · 아무 말이나 해 보세요",
		MIC_TESTED = "마이크 확인 완료!",
		READY = "준비 완료!",
		READY_COUNT = "준비 완료! (준비된 사람 %d명)",
		HEADSET_TIP = "헤드셋을 쓰면 억울한 탈락을 막을 수 있어요", -- speakers feed others' voices back into the mic
		NO_VOICE_WATCH = "지금은 관전만 할 수 있어요",
		CHAT_CHECKING = "계정을 확인하고 있어요",
		CHAT_JOIN = "⌨ 말 대신 채팅으로 참가",
		CHAT_CANCEL = "채팅 참가 취소",
		CHAT_JOINED = "채팅으로 참가해요 · 다른 사람 음성은 들리고, 판 중 내 마이크는 꺼져요",
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
		PICK_AUTO = "시간이 지나서 무작위로 골랐어요",
		TEST_MISSION_TITLE = "연습 미션",
		TEST_MISSION_BRIEF = "운에 맡겨요 · 가끔 날아가요", -- (the briefing before it, owner 2026-10-24)
		QUIZ_TITLE = "퀴즈",
		QUIZ_BRIEF = "4개 중 정답을 골라요 · 틀리거나 안 고르면 날아가요", -- (the briefing before it, owner 2026-10-24)
		QUIZ_START = "퀴즈 · 정답을 골라요 · 틀리거나 안 고르면 날아가요",
		FINAL_QUIZ = "결승 퀴즈 · 틀리면 바로 탈락",
		QUIZ_ANSWER = "정답: %s",
		QUIZ_ALL_RIGHT = "모두 정답!",
		ROULETTE_TITLE = "룰렛",
		ROULETTE_BRIEF = "원판이 한 명을 골라요 · 걸리면 날아가요", -- (the briefing before it, owner 2026-10-24)
		ROULETTE_START = "룰렛이 돌아가요 · 걸린 한 명이 날아가요",
		ROULETTE_HIT = "%s 당첨!",
		ONE_WORD_TITLE = "좋아하는 거 말하기",
		ONE_WORD_BRIEF = "벨 순서대로 주제에 맞게 말해요 · 진행자나 투표로 한 명이 날아가요", -- (the briefing before it, owner 2026-10-24)
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
		BELL_QUIZ_BRIEF = "먼저 벨을 누르고 말로 답해요 · 진행자가 판정해요", -- (the briefing before it, owner 2026-10-24)
		BELL_QUIZ_START = "벨 퀴즈 · 먼저 벨을 누른 사람이 말로 답해요",
		BELL_QUIZ_WAIT = "🔔 벨을 눌러 답하세요",
		BELL_QUIZ_ANSWERING = "%s 님이 답하는 중",
		BELL_QUIZ_RIGHT = "⭕ 정답! %s",
		BELL_QUIZ_WRONG = "❌ 땡! %s",
		BELL_QUIZ_NOBODY = "아무도 안 눌러서 모두 답해요",
		VERDICT_PICK = "맞았나요? 정답: %s",
		CROC_TITLE = "악어 이빨",
		CROC_BRIEF = "차례대로 이빨을 하나씩 눌러요 · 무는 이빨이면 날아가요", -- (the briefing before it, owner 2026-10-24)
		CROC_START = "악어 이빨 · 차례대로 이빨을 하나 눌러요 · 물리면 날아가요",
		CROC_TURN = "%s 차례",
		CROC_BITE = "😱 덥석! %s",
		CROC_LATE = "⏰ 시간 초과! %s",
		BOMB_TITLE = "폭탄 돌리기",
		BOMB_BRIEF = "폭탄을 받으면 버튼이 켜질 때 넘겨요 · 터질 때 들고 있으면 날아가요", -- (the briefing before it)
		BOMB_START = "폭탄 돌리기 · 버튼이 켜지면 바로 넘겨요",
		BOMB_PASS = "넘기기 💣",
		BOMB_MINE = "💣 폭탄이 나한테! 버튼이 켜지면 넘겨요",
		BOMB_HOLDER = "💣 %s",
		BOMB_BOOM = "💥 펑! %s",
		NUNCHI_TITLE = "눈치 게임",
		NUNCHI_BRIEF = "1부터 한 명씩 벨을 눌러요 · 겹치거나 마지막이면 날아가요", -- (the briefing before it, owner 2026-10-24)
		NUNCHI_START = "눈치 게임 · 1부터 한 명씩 벨! 겹치거나 꼴찌면 날아가요",
		NUNCHI_CLASH = "💥 겹쳤다! %s",
		NUNCHI_LAST = "🐢 꼴찌! %s",
		NUNCHI_IDLE = "벨을 안 눌러서 날아가요: %s",
		NUNCHI_NEXT = "다음 숫자: %d",
		NUNCHI_ORDER = "%d %s",
		NUNCHI_NONE = "✕ %s",
		BALANCE_TITLE = "밸런스 게임",
		BALANCE_BRIEF = "둘 중 하나를 몰래 골라요 · 적은 쪽이 날아가요", -- (the briefing before it, owner 2026-10-24)
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
		REDLIGHT_BRIEF = "초록불에 벨을 눌러 앞으로 · 빨간불에 누르면 날아가요", -- (the briefing before it, owner 2026-10-24)
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
		LIAR_BRIEF = "제시어를 모르는 라이어를 찾아요 · 라이어가 못 맞히면 라이어만 날아가요", -- (the briefing before it, owner 2026-10-24)
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
		-- Bundle 8b (owner 2026-10-24).
		TIMEGUESS_TITLE = "숫자 맞추기",
		TIMEGUESS_BRIEF = "목표 시간에 맞춰 벨 · 시계는 %d초만 보여요 · 가장 많이 빗나간 사람이 날아가요",
		TIMEGUESS_START = "%.2f초에 맞춰 벨을 눌러요",
		TIMEGUESS_TARGET = "목표 %.2f초",
		TIMEGUESS_HOW = "시계는 처음 %d초만 보여요 · 맞다 싶을 때 벨 한 번",
		TIMEGUESS_RESULT = "목표 %.2f초 · %s 날아가요",
		TIMEGUESS_NONE = "안 누름",
		DUEL_TITLE = "총잡이 결투",
		DUEL_BRIEF = "발사! 신호에 먼저 벨 · 신호 전에 누르면 날아가요",
		DUEL_READY = "준비… 신호를 기다려요",
		DUEL_WAIT = "준비…",
		DUEL_FIRE = "발사!",
		DUEL_VS = "상대: %s",
		DUEL_BYE = "이번엔 쉬어요",
		DUEL_PAIR = "%s 대 %s",
		DUEL_MS = "%s %dms",
		DUEL_FALSE = "%s 부정 출발",
		DUEL_NEVER = "%s 안 누름",
		DUEL_RESULT = "%s 날아가요",
		DUEL_DRAW = "동시! 아무도 안 날아가요",
		BOTTLE_TITLE = "물병 세우기",
		BOTTLE_BRIEF = "움직이는 막대를 초록 칸에서 벨로 멈춰요 · %d번 · 가장 적게 세운 사람이 날아가요",
		BOTTLE_START = "막대가 초록 칸에 올 때 벨",
		BOTTLE_THROW = "%d / %d번째",
		BOTTLE_STOOD = "%s %d개",
		BOTTLE_RESULT = "가장 적게 세운 %s 날아가요",
		BOTTLE_TIE = "모두 똑같이 세웠어요 · 아무도 안 날아가요",
		-- Bundle 8c (owner 2026-10-24).
		CHOSUNG_TITLE = "초성 퀴즈",
		CHOSUNG_BRIEF = "초성을 보고 어떤 낱말인지 골라요 · 틀리거나 안 고르면 날아가요",
		CHOSUNG_Q = "%s · %s",
		OX_TITLE = "O/X 퀴즈",
		OX_BRIEF = "문장 %d개 · 맞으면 O, 틀리면 X · 가장 많이 틀린 사람이 날아가요",
		OX_START = "맞으면 O, 틀리면 X",
		OX_QUESTION = "%d/%d · %s",
		OX_O = "O",
		OX_X = "X",
		OX_WRONG = "%s %d개 틀림",
		OX_RESULT = "가장 많이 틀린 %s 날아가요",
		OX_ALL_RIGHT = "모두 다 맞혔어요 · 아무도 안 날아가요",
		ESTIMATE_TITLE = "숫자 근사 퀴즈",
		ESTIMATE_BRIEF = "정답에 가까운 숫자를 적어요 · 가장 먼 사람이 날아가요",
		ESTIMATE_START = "숫자를 적고 확인을 눌러요",
		ESTIMATE_HINT = "숫자만 (1 이상)",
		ESTIMATE_SEND = "확인",
		ESTIMATE_SENT = "%d 냈어요",
		ESTIMATE_RIGHT = "정답 %d",
		ESTIMATE_GUESS = "%s %d",
		ESTIMATE_NONE = "%s 안 냄",
		ESTIMATE_RESULT = "정답 %d · %s 날아가요",
		ESTIMATE_NOBODY = "정답 %d · 모두 딱 맞혔어요 · 아무도 안 날아가요",
		TALK_BRIEF = "남의 머리 위 금칙어를 말하게 해요 · 내 금칙어를 말하면 날아가요", -- (the briefing before it, owner 2026-10-24)
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
	SOUND_BELL = "rbxassetid://1839997929", -- the seat bell's ding (APM game show toolkit, Correct Answer 2; replace
	-- with a shorter desk-bell sound after the owner hears it)
}
