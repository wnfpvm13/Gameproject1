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
	-- Difficulty modes (bundle 11b, owner 2026-10-27; shared/Modes, docs/BUNDLE11_2026-10-27.md): the seated players vote
	-- one during the assignment (MODE_VOTE_SECONDS, over once all voted), then the result shows MODE_RESULT_SECONDS.
	-- MODE_TUNING: the numbers a mode changes (every other number stays as below). Quiz banks: missions/Quiz, OXQuiz.
	MODE_VOTE_SECONDS = 8,
	MODE_RESULT_SECONDS = 2,
	MODE_TUNING = {
		easy = {
			QUIZ_SECONDS = 15,
			OX_SECONDS = 7,
			REDLIGHT_GOAL = 20,
			REDLIGHT_GRACE = 0.5,
			TIMEGUESS_VISIBLE_SECONDS = 4, -- (not 5: a target of 5.0 s would show on the clock itself)
			BOTTLE_ZONES = { 0.28, 0.2, 0.13 },
			BOTTLE_PERIOD = 1.4,
			NUNCHI_WINDOW = 0.35,
			CHOSUNG_FAR_DECOYS = true,
		},
		normal = {},
		hard = {
			QUIZ_SECONDS = 7,
			OX_SECONDS = 4,
			REDLIGHT_GOAL = 30,
			REDLIGHT_GRACE = 0.2,
			TIMEGUESS_VISIBLE_SECONDS = 2,
			BOTTLE_ZONES = { 0.17, 0.11, 0.07 }, -- (the bar's speed stays: narrower and faster left one 30 fps frame)
			NUNCHI_WINDOW = 0.6, -- (wider and a ring seen on screen could no longer be dodged)
		},
	},
	-- 초성 퀴즈's wrong choices (bundle 11b): the words of as many syllables whose initials are the least alike (the
	-- easy mode) instead of the most alike.
	CHOSUNG_FAR_DECOYS = false,
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
	QUIZ_SHUFFLE = true, -- the quiz's choices in a new order each time (not choices that are numbers; tests turn it off)
	QUIZ_INTRO_SECONDS = 2, -- the question shows before the buttons work
	QUIZ_SECONDS = 10, -- answer time
	QUIZ_REVEAL_SECONDS = 3, -- the right answer stays on screen
	-- Bundle 12 (owner 2026-10-27): when a quiz question's time is up (the 4-choice quiz, 초성, the final, each O/X
	-- statement, 숫자 근사), everyone's answer shows over their head this long before the right answer; then the tags
	-- turn right / wrong and the wrong ones fly (shared/Picks).
	PICKS_SECONDS = 2,
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
	-- 머리 위 스무고개 (bundle 9c, owner 2026-10-25: instead of the banned-word talk). Everyone on the ground gets a
	-- different word of one topic (ChosungBank, TWENTY_MIN_LETTERS letters or more) over their head; TWENTY_INTRO_SECONDS
	-- to look, then in a random order each one asks the others for TWENTY_TURN_SECONDS and may type one answer of
	-- TWENTY_ANSWER_MAX letters at most (its verdict shows TWENTY_VERDICT_SECONDS). Over once TWENTY_SHARE of the players
	-- (rounded up) are right, or after TWENTY_TRIES rounds (one answer a turn); whoever is not right flies.
	TWENTY_MIN_PLAYERS = 2,
	TWENTY_MAX_PLAYERS = 6, -- offered only with this many alive or fewer (owner 2026-10-26: ten could take ~7 minutes)
	TWENTY_MIN_LETTERS = 2, -- (one letter, like 배 or 자, hides in too many chat lines: writing it would fly people)
	TWENTY_INTRO_SECONDS = 5,
	TWENTY_TURN_SECONDS = 12,
	TWENTY_VERDICT_SECONDS = 1.5,
	TWENTY_TRIES = 3,
	TWENTY_SHARE = 0.3,
	TWENTY_ANSWER_MAX = 12,
	-- Writing someone else's word flies you only when it is written as a word of its own, maybe with one of these
	-- particles or endings after it (사과가, 사과야, 택배 기사는); inside a longer word it does not ("나라면" is not 라면,
	-- "배우고" is not 배우). Review 2026-10-25: the plain inside-match flew people for everyday lines.
	TWENTY_PARTICLES = { "이", "가", "은", "는", "을", "를", "의", "도", "만", "에", "에서", "에게", "한테", "께", "로", "으로",
		"와", "과", "랑", "이랑", "하고", "요", "야", "이야", "아", "이요", "예요", "에요", "이에요", "인가", "인가요", "인데",
		"이지", "지", "죠", "이죠", "다", "이다", "임", "냐", "이냐", "니", "이니", "나", "이나", "라", "이라", "라고", "이라고",
		"네", "이네", "잖아", "이잖아", "처럼", "보다", "부터", "까지", "들" },
	-- Words left out of 스무고개: an everyday word is spelled the same (사자 "let's buy", 판다 "sells", 화가 나, 배우다,
	-- 유도 질문, 인도 = sidewalk), so writing it innocently would fly someone.
	TWENTY_SKIP_WORDS = { "사자", "판다", "화가", "배우", "유도", "인도",
		-- (review 2026-10-25: everyday in chat — "사과해", "버스 태워 줘", "가위 바위 보", "선생님!" — or always said in this
		-- game of flying chairs over a pool)
		"사과", "버스", "가위", "선생님", "의자", "수영" },
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
	-- Owner 2026-10-25: 머리 위 스무고개 replaces the talk; its code stays (TALK_GAME_ON brings it back, tests use it).
	TALK_GAME_ON = false,
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
	-- The show camera frames a round of few players closer (client ShowCamera, review 2026-10-25): the seated chairs plus
	-- SHOW_MARGIN studs on each side, at least SHOW_MIN_HALF_WIDTH (whole row: the map's HalfWidth), FOV not under
	-- SHOW_MIN_FOV; the tops of the head tags (SHOW_KEEP_HEIGHT studs over the seats) keep their height on screen.
	INVITE_BELOW = 4, -- the "친구 초대" button shows between rounds while fewer than this are ready (client)
	NOTICE_KEEP_SECONDS = 1.5, -- a life-loss toast within this of a moment's line shows that line above it (client)
	SHOW_MARGIN = 8,
	SHOW_MIN_HALF_WIDTH = 22,
	SHOW_MIN_FOV = 20,
	SHOW_KEEP_HEIGHT = 8,

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
		NEED_READY = "%d명만 더 준비하면 시작해요", -- voice ready or joining by chat
		NEED_PLAYERS = "%d명만 더 오면 시작해요",
		COUNTDOWN = "곧 시작해요",
		RECOVERING = "앗, 문제가 생겼어요. 새 판을 준비할게요",
		ASSIGN = "목숨 %d개! 미션에 실패하면 날아가요",
		PLAY_START = "첫 미션 갑니다!",
		NEXT_GAME = "다음: %s",
		GAME_COUNT = "미션 %d/%d", -- the status board during the main game: the game now / games in a round
		NEXT_VOTE = "다음 미션 투표!",
		-- Difficulty modes (bundle 11b; names from the owner).
		MODE_VOTE = "이번 판 난이도 투표!",
		MODE_EASY = "바보 모드",
		MODE_EASY_BRIEF = "넌센스 퀴즈, 넉넉한 시간",
		MODE_NORMAL = "일반 모드",
		MODE_NORMAL_BRIEF = "고1 수준",
		MODE_HARD = "똑똑이 모드",
		MODE_HARD_BRIEF = "어려운 문제, 빠듯한 시간",
		MODE_RESULT = "이번 판은 %s!",
		RECAP_LOST = "%s 목숨 잃음",
		RECAP_OUT = "%s 탈락",
		RECAP_NONE = "모두 무사!",
		PICKING = "진행자가 고르는 중…",
		TEST_MISSION = "연습 미션 · 운에 맡겨 보세요",
		FINAL = "결승! 틀리면 바로 탈락",
		ALL_WRONG = "모두 틀렸어요! 이번 문제는 무효",
		TO_FINAL = "남은 사람 모두 목숨을 잃었어요! 결승에서 승부",
		LIFE_LOST = "%s 목숨 1개 잃음",
		OUT = "%s 탈락!",
		MY_LIFE_LOST = "목숨 1개를 잃었어요 · 남은 목숨 %d개",
		MY_NO_LIVES = "목숨을 모두 잃었어요", -- (the last one left, or everyone left fell at once)
		MY_OUT = "탈락! 관람석에서 응원해 주세요",
		LEFT = "%s 님이 나갔어요",
		WINNER = "%s 우승!",
		JOINT_WINNERS = "%s 공동 우승!",
		NO_WINNER = "우승자 없이 끝났어요",
		-- Round awards on the result screen (owner 2026-10-24).
		AWARD_FLIGHT = "비행왕 %s (%.1fm)",
		AWARD_SURVIVOR = "생존왕 %s (무사 통과 %d번)",
		SETTLING = "마지막 말을 확인하고 있어요…",
		RECOGNITION_UNSTABLE = "목소리가 잘 안 잡혀요. 마이크를 확인해 주세요",
		-- Getting ready (MicPanel, docs/DESIGN_V3.md §2, §7): voice, or chat for players who cannot use voice.
		VOICE_NONE = "음성 채팅을 켠 계정만 참가할 수 있어요 (13세 이상·연령 인증)",
		VOICE_CONNECT = "음성 연결: 왼쪽 위 ≡ 메뉴(ESC) → 설정 → 음성 채팅 연결",
		VOICE_MUTED = "마이크가 꺼져 있어요",
		CONNECT_TO_PLAY = "음성을 연결하면 다음 판부터 참가해요",
		MIC_ON = "마이크를 켜 주세요",
		MIC_TEST = "마이크 체크! 아무 말이나 해 보세요",
		MIC_TESTED = "마이크 확인 완료!",
		READY = "준비 완료!",
		READY_COUNT = "준비 완료! (준비 %d명)",
		READY_NEXT_ROUND = "준비 완료! 다음 판부터 같이 해요",
		INVITE = "친구 초대",
		-- The sound settings (bundle 11a).
		SETTINGS = "설정",
		SETTINGS_TITLE = "소리 설정",
		SETTINGS_MUSIC = "배경 음악",
		SETTINGS_EFFECTS = "효과음",
		SETTINGS_VOICE_NOTE = "음성 채팅 소리는 Roblox 메뉴(ESC)에서 바꿔요",
		SETTINGS_CLOSE = "닫기",
		INVITE_UNAVAILABLE = "이 계정은 여기서 초대를 보낼 수 없어요",
		HEADSET_TIP = "헤드셋을 쓰면 더 잘 들려요", -- speakers feed others' voices back into the mic
		NO_VOICE_WATCH = "관람석에서 구경할 수 있어요",
		CHAT_CHECKING = "계정 확인 중…",
		CHAT_JOIN = "말 대신 채팅으로 참가",
		CHAT_CANCEL = "채팅 참가 취소",
		CHAT_JOINED = "채팅으로 참가! 판 동안 내 마이크는 꺼져요",
		CHAT_TAG = "[채팅]", -- before a chat participant's name in the chat window
		-- Presenter (docs/DESIGN_V3.md §8).
		VOLUNTEER = "🎤 진행자 지원",
		VOLUNTEER_CANCEL = "진행자 지원 취소",
		STEP_DOWN = "진행 넘기기",
		VOLUNTEERED = "진행자 지원 완료! 뽑히면 알려 줄게요",
		PRESENTER_NAMED = "이번 판 진행자: %s",
		PRESENTER_CHANGED = "진행자 교체: %s",
		PRESENTER_NONE = "이제부터 자동 진행",
		PRESENTER_TAG = "🎤 진행자",
		ME_PRESENTER = "🎤 내가 진행자",
		PRESENTER_CREDIT = "진행: %s",
		PICK_MISSION = "다음 미션을 골라 주세요",
		PICK_AUTO = "시간 초과! 랜덤으로 골랐어요",
		TEST_MISSION_TITLE = "연습 미션",
		TEST_MISSION_BRIEF = "운에 맡겨요 · 가끔 날아가요", -- (the briefing before it, owner 2026-10-24)
		QUIZ_TITLE = "퀴즈",
		QUIZ_BRIEF = "4개 중 정답 고르기! 틀리면 날아가요", -- (the briefing before it, owner 2026-10-24)
		QUIZ_START = "정답은?",
		FINAL_QUIZ = "결승 문제 나갑니다!",
		QUIZ_ANSWER = "정답: %s",
		QUIZ_ALL_RIGHT = "모두 정답!",
		PICKS_REVEAL = "모두의 답 공개!",
		ROULETTE_TITLE = "룰렛",
		ROULETTE_BRIEF = "룰렛에 걸린 한 명이 날아가요", -- (the briefing before it, owner 2026-10-24)
		ROULETTE_START = "룰렛 돌아갑니다!",
		ROULETTE_HIT = "%s 당첨!",
		ONE_WORD_TITLE = "좋아하는 거 말하기",
		ONE_WORD_BRIEF = "벨 순서대로 한마디, 가장 아쉬운 한 명이 날아가요", -- (the briefing before it, owner 2026-10-24)
		ONE_WORD_START = "벨 누른 순서대로 말해요!",
		ONE_WORD_BELL = "🔔 벨을 누르면 먼저 말해요",
		ONE_WORD_TURN = "%s 차례 · %s",
		ONE_WORD_PREP = "곧 시작",
		ONE_WORD_SWAP = "주제 바꾸기",
		ONE_WORD_BY_CHAT = "채팅으로 한마디!",
		JUDGE_PICK = "날릴 사람을 골라 주세요",
		FLING_BUTTON = "날려!",
		JUDGE_WAIT = "진행자가 날릴 사람을 고르는 중",
		JUDGE_VOTE = "가장 아쉬운 한마디는?",
		JUDGE_TO_VOTE = "시간 초과! 투표로 정해요",
		VOTE_NONE = "아무도 안 날림",
		VOTE_ABSTAIN = "안 들려요",
		NOBODY_FLUNG = "아무도 안 날아가요",
		FLUNG = "%s 날아가요!",
		EAR_HIT = "🔔 금칙어! %s",
		RESCUE_WAIT = "🚨 %s 금칙어! 진행자가 구제할 수 있어요",
		RESCUED = "🛟 구제! %s 무사해요",
		RESCUE_BUTTON = "🛟 구제",
		MY_WORD_WAS = "내 금칙어: '%s'", -- (no particle: it would depend on the word's last syllable)
		BELL_BUTTON = "🔔 벨", -- (the seat bell's E prompt)
		BELL_QUIZ_TITLE = "벨 퀴즈",
		BELL_QUIZ_BRIEF = "먼저 벨 누르고 말로 답! 틀리면 날아가요", -- (the briefing before it, owner 2026-10-24)
		BELL_QUIZ_START = "손은 벨 위에!",
		BELL_QUIZ_WAIT = "🔔 아는 사람 벨!",
		BELL_QUIZ_ANSWERING = "%s 님이 답하는 중",
		BELL_QUIZ_RIGHT = "⭕ 정답! %s",
		BELL_QUIZ_WRONG = "❌ 땡! %s",
		BELL_QUIZ_NOBODY = "아무도 안 눌러서 모두 객관식으로!",
		VERDICT_PICK = "맞았나요? 정답: %s",
		CROC_TITLE = "악어 이빨",
		CROC_BRIEF = "차례로 이빨을 누르다 물리면 날아가요", -- (the briefing before it, owner 2026-10-24)
		CROC_START = "누가 물릴까?",
		CROC_TURN = "%s 차례",
		CROC_BITE = "😱 덥석! %s",
		CROC_LATE = "⏰ 시간 초과! %s",
		BOMB_TITLE = "폭탄 돌리기",
		BOMB_BRIEF = "터질 때 폭탄을 들고 있으면 날아가요", -- (the briefing before it)
		BOMB_START = "째깍째깍…",
		BOMB_PASS = "넘기기", -- (with the bomb picture, Config.IMAGES.BOMB)
		BOMB_MINE = "💣 나한테 왔다! 버튼이 켜지면 넘겨요",
		BOMB_HOLDER = "💣 %s",
		BOMB_BOOM = "💥 펑! %s",
		NUNCHI_TITLE = "눈치 게임",
		NUNCHI_BRIEF = "1부터 한 명씩 벨, 겹치거나 꼴찌면 날아가요", -- (the briefing before it, owner 2026-10-24)
		NUNCHI_START = "눈치껏 벨!",
		NUNCHI_CLASH = "💥 겹쳤다! %s",
		NUNCHI_LAST = "🐢 꼴찌! %s",
		NUNCHI_IDLE = "안 누른 %s 날아가요",
		NUNCHI_NEXT = "다음 숫자: %d",
		NUNCHI_ORDER = "%d %s",
		NUNCHI_NONE = "✕ %s",
		BALANCE_TITLE = "밸런스 게임",
		BALANCE_BRIEF = "둘 중 하나를 골라요, 적은 쪽이 날아가요", -- (the briefing before it, owner 2026-10-24)
		BALANCE_START = "둘 중 하나만 고른다면?",
		BALANCE_VS = "%s vs %s",
		BALANCE_BELL = "🔔 벨 누르면 먼저 설득!",
		BALANCE_TALK = "%s 설득 중!",
		BALANCE_PICK = "몰래 고르기! 끝나기 전엔 바꿔도 돼요",
		BALANCE_COUNT = "%s %d · %s %d",
		BALANCE_EVEN = "반반!",
		BALANCE_SAME = "만장일치!",
		BALANCE_EMPTY = "아무도 안 골랐어요",
		BALANCE_NOBODY = "아무도 안 날아가요",
		BALANCE_NONE = "안 고른 %s 날아가요",
		REDLIGHT_TITLE = "무궁화 꽃이 피었습니다",
		REDLIGHT_BRIEF = "초록불엔 벨 연타! 빨간불에 누르거나 도착 못 하면 날아가요", -- (the briefing before it, owner 2026-10-24)
		REDLIGHT_START = "끝까지 가야 살아요!",
		REDLIGHT_GREEN = "🟢 달려!",
		REDLIGHT_RED = "🔴 멈춰!",
		REDLIGHT_STEPS = "내 걸음 %d / %d",
		REDLIGHT_YOU_CAUGHT = "🔴 걸렸다! 이번 미션은 여기까지",
		REDLIGHT_YOU_SAFE = "🏁 도착! 이제 안전해요",
		REDLIGHT_CAUGHT = "🔴 움직였다! %s",
		REDLIGHT_SHORT = "🐌 도착 실패! %s",
		REDLIGHT_ALL_SAFE = "모두 도착!",
		LIAR_TITLE = "라이어 게임",
		LIAR_BRIEF = "라이어를 찾아요! 걸린 라이어가 제시어도 틀리면 날아가요", -- (the briefing before it, owner 2026-10-24)
		LIAR_START = "이 중에 라이어가 있다!",
		LIAR_CATEGORY = "주제: %s",
		LIAR_WORD = "제시어: %s",
		LIAR_YOU = "🤫 내가 라이어! 주제: %s",
		LIAR_CLUE = "%s 설명 차례",
		LIAR_ACCUSE = "라이어는 누구?",
		LIAR_VOTE = "라이어 같은 사람에게 투표!",
		LIAR_NONE = "모르겠음",
		LIAR_GUESS = "라이어의 반격! 제시어는?",
		LIAR_CAUGHT = "🎯 잡았다! 라이어는 %s · 제시어 %s",
		LIAR_ESCAPED = "😎 라이어 %s 승리! 제시어 %s",
		ACCUSE_PICK = "라이어로 지목할 사람",
		MINIGAME_TOO_FEW = "인원이 부족해서 이번 미션은 패스!",
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
		TIMEGUESS_BRIEF = "목표 시간에 벨! 시계는 %d초만 보여요, 가장 빗나가면 날아가요",
		TIMEGUESS_START = "%.2f초에 벨!",
		TIMEGUESS_TARGET = "목표 %.2f초",
		TIMEGUESS_HOW = "시계는 처음 %d초만 보여요. 그다음은 감으로 벨!",
		TIMEGUESS_RESULT = "목표 %.2f초 · %s 날아가요",
		TIMEGUESS_NONE = "안 누름",
		DUEL_TITLE = "총잡이 결투",
		DUEL_BRIEF = "'발사!'에 먼저 벨, 늦거나 미리 누르면 날아가요",
		DUEL_READY = "아직 쏘지 마요…",
		DUEL_WAIT = "준비…",
		DUEL_FIRE = "발사!",
		DUEL_VS = "상대: %s",
		DUEL_BYE = "이번엔 부전승!",
		DUEL_PAIR = "%s vs %s",
		DUEL_MS = "%s %dms",
		DUEL_FALSE = "%s 부정 출발",
		DUEL_NEVER = "%s 안 누름",
		DUEL_RESULT = "%s 날아가요",
		DUEL_DRAW = "동시! 아무도 안 날아가요",
		BOTTLE_TITLE = "물병 세우기",
		BOTTLE_BRIEF = "초록 칸에서 벨! %d번 중 가장 적게 세우면 날아가요",
		BOTTLE_START = "초록 칸에서 벨!",
		BOTTLE_THROW = "%d / %d번째",
		BOTTLE_STOOD = "%s %d개",
		BOTTLE_RESULT = "가장 적게 세운 %s 날아가요",
		BOTTLE_TIE = "모두 동점! 아무도 안 날아가요",
		-- Bundle 8c (owner 2026-10-24).
		CHOSUNG_TITLE = "초성 퀴즈",
		CHOSUNG_BRIEF = "초성 보고 정답 고르기! 틀리면 날아가요",
		CHOSUNG_Q = "%s · %s",
		OX_TITLE = "O/X 퀴즈",
		OX_BRIEF = "O/X %d문제, 가장 많이 틀리면 날아가요",
		OX_START = "맞으면 O, 틀리면 X",
		OX_QUESTION = "%d/%d · %s",
		OX_O = "O",
		OX_X = "X",
		OX_WRONG = "%s %d개 틀림",
		OX_RESULT = "가장 많이 틀린 %s 날아가요",
		OX_ALL_RIGHT = "모두 만점! 아무도 안 날아가요",
		ESTIMATE_TITLE = "숫자 근사 퀴즈",
		ESTIMATE_BRIEF = "정답에 가까운 숫자를 적어요! 가장 먼 사람이 날아가요",
		ESTIMATE_START = "숫자 적고 꼭 확인!",
		ESTIMATE_HINT = "숫자만 (1 이상)",
		ESTIMATE_SEND = "확인",
		ESTIMATE_SENT = "%d 냈어요",
		ESTIMATE_RIGHT = "정답 %d",
		ESTIMATE_GUESS = "%s %d",
		ESTIMATE_NONE = "%s 안 냄",
		ESTIMATE_RESULT = "정답 %d · %s 날아가요",
		ESTIMATE_NOBODY = "정답 %d! 모두 딱 맞혀서 아무도 안 날아가요",
		-- Bundle 9c (owner 2026-10-25).
		TWENTY_TITLE = "머리 위 스무고개",
		TWENTY_BRIEF = "질문으로 내 단어를 맞혀요, 못 맞히면 날아가요",
		TWENTY_INTRO = "차례마다 %d초 동안 묻고, 답은 한 번만!",
		TWENTY_TURN = "%s 님이 질문해요, 대답해 주세요",
		TWENTY_MY_TURN = "내 차례! 질문하고 아래에 답 쓰기",
		TWENTY_INFO = "주제 %s · %d/%d바퀴 · %d명 맞힘 (목표 %d명)",
		TWENTY_NO_LEAK = "남의 단어를 채팅에 쓰면 바로 날아가요",
		TWENTY_ONE_TRY = "답은 한 번만!",
		TWENTY_HINT = "내 단어는?",
		TWENTY_SEND = "답 내기",
		TWENTY_SENT = "'%s' 냈어요",
		TWENTY_RIGHT = "⭕ 정답! %s (%s)",
		TWENTY_WRONG = "❌ 땡! %s",
		TWENTY_TIMEOUT = "⏰ 시간 초과! %s",
		TWENTY_LEAK = "%s 님이 남의 단어를 흘려서 날아가요",
		TWENTY_LEAK_MINE = "💥 남의 단어를 채팅에 써 버렸어요! 내 단어: %s",
		TWENTY_RESULT = "못 맞힌 %s 날아가요",
		TWENTY_NOBODY = "날아갈 사람이 없어요",
		TWENTY_RESULT_TITLE = "머리 위 스무고개 · 주제: %s",
		TWENTY_RIGHT_LIST = "맞힘: %s",
		TWENTY_LEAKED = "%s(채팅)",
		TWENTY_MY_WORD = "내 단어: %s",
		TALK_BRIEF = "남의 머리 위 금칙어를 말하게 해요 · 내 금칙어를 말하면 날아가요", -- (the briefing before it, owner 2026-10-24)
		TALK_SOON = "곧 시작",
		TALK_PREP = "금칙어를 나눠 주는 중 · 내 머리 위 단어는 나만 몰라요",
		TALK_ON = "주제로 이야기하세요 · 자기 금칙어를 말하면 날아가요",
		TALK_TOPIC = "주제: %s",
		WORDS_HEARD = "🔔 들었다",
		AFK_OUT = "%s 님은 2번 연속 답이 없어서 관전으로 바뀌었어요",
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
	-- Sticker pictures (owner 2026-10-25: the whole UI in the look of the owner's bell picture). Drawn for this game as
	-- SVG (assets/icons, rendered to PNG) and uploaded to Roblox by the author on 2026-10-25.
	IMAGES = {
		BELL = "rbxassetid://137288878466546", -- the big bell button
		GUN = "rbxassetid://122610104192708", -- the same button in 총잡이 결투
		BOMB = "rbxassetid://82548273745326", -- the bomb's pass button
		CROC = "rbxassetid://133525735327902", -- 악어 이빨: the open jaws seen from the front (640 x 300)
	},
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
	-- (owner 2026-10-26, the recommended choice: sounds for the moments that had none, all Roblox-licensed APM Music /
	-- Pro Sound Effects; the owner listens in Studio and may swap any of them)
	SOUND_BELL = "rbxassetid://9125485591", -- Desk Bell Counter Service Single Ringing Ding 1 (SFX): the seat bell
	SOUND_RIGHT = "rbxassetid://1839997929", -- Correct Answer 2 (APM game show toolkit): my quiz answer was right
	SOUND_WIN = "rbxassetid://1839997889", -- Organ Fanfare (APM game show toolkit, 3 s): the round's winners
	SOUND_TICK = "rbxassetid://1839998128", -- Coconut Clock (APM game show toolkit, ticking): while the bomb goes round
	SOUND_ROLL = "rbxassetid://1839997904", -- Roll Reveal (APM game show toolkit, drum roll with a crash): the roulette
	SOUND_ROLL_CRASH_AT = 2.25, -- seconds into SOUND_ROLL where the crash is (measured 2026-10-26 with an AudioAnalyzer:
	-- the loudest hit after the roll); it starts so the crash meets the pick
	SOUND_WHISTLE = "rbxassetid://9118114334", -- Referee Whistle Interior Gymnasium 1 (SFX): 무궁화's red light
	SOUND_VOLUME = 0.5, -- these game sounds, under the voices

	-- Background music (bundle 11a, owner 2026-10-27: "너무 슴슴하네"; docs/BUNDLE11_2026-10-27.md). Roblox-licensed APM
	-- Music without vocals (the lobby mic test passes on any speech it hears, sung words from a speaker included); the
	-- owner listens and may swap any of them. The client plays the one for the phase (lobby: also the countdown, the
	-- assignment and the result).
	MUSIC_TRACKS = {
		lobby = "rbxassetid://1842174239", -- Game Show (KPM, "upbeat entertainment bed", 146 s)
		play = "rbxassetid://1842373862", -- A Little Mischief (KPM, "bouncy, playful theme", 194 s)
		final = "rbxassetid://1839997507", -- Four Heads Tension Bed (APM game show toolkit, 137 s)
	},
	MUSIC_VOLUME = 0.25, -- the music at a player's 100% (their setting scales it), under the voices
	MUSIC_FADE_SECONDS = 1, -- one track to the next
	MUSIC_DUCK = 0.3, -- while someone speaks for the game (a word to everyone, a clue, a bell answer ...)
	MUSIC_RESULT_DELAY = 3, -- the result's fanfare plays first
	-- A player's sound settings (bundle 11a): 0..1 in steps of SETTINGS_STEP, kept in a DataStore across visits.
	SETTINGS_DEFAULT = { music = 0.5, effects = 1 },
	SETTINGS_STEP = 0.1,
	SETTINGS_STORE = "BW_PlayerSettings_v1",
	SETTINGS_LOAD_RETRY = 2, -- seconds before the one retry of a failed load
	SETTINGS_SAVE_DELAY = 6, -- a change is saved this long after the last one (a drag is many changes)
	SETTINGS_SAVE_RETRIES = { 5, 15 }, -- seconds before retrying a failed save
	SETTINGS_RATE = 4, -- changes a second taken from one player
}
