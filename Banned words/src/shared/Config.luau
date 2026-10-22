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
	HABIT_WORD_CHANCE = 0.5, -- per player: chance that their third word is a speech habit (진짜, 대박 ...) instead of a noun

	-- When the round is decided (last elimination / time-out), speech still counts if it began before that moment
	-- and ended no later than END_TOLERANCE seconds after it. 0 = only speech that was over by then: a transcript has
	-- no word times, so speech running past the end may hold words said after it (not judged; raise only once
	-- word times exist). Judging stays open until every alive player's client says that speech has been sent
	-- (at most SETTLE_MAX seconds; a notice after SETTLE_NOTICE_AFTER).
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

	-- Mission cards (V2.1): card -> notice -> short vote -> follow-up, then the next mission. Nobody dies for them.
	-- The theme's missions are spread evenly over the talk (330/450/570 s with 3 missions -> 110/150/190 s each).
	MISSION_NOTICE_AT = 25, -- seconds after the card: a notice raises the stakes
	VOTE_OPEN_AFTER = 40, -- seconds after the card: the vote opens (talk first)
	VOTE_SECONDS = 12,
	VOTE_RESULT_SECONDS = 4, -- the result stays on screen this long (late joiners get it too)
	EVENT_SHOW_SECONDS = 7, -- a quiet-time event banner stays this long

	-- Quiet-time help next to the missions (no forced speaking, nobody dies for silence).
	QUIET_TOPIC = 30, -- seconds without speech -> a topic card on the left
	QUIET_EVENT = 60, -- seconds without speech -> a small situation event
	EVENT_COOLDOWN = 40,
	AFTER_LAUNCH_QUIET = 12, -- after a launch, no new stage / vote / event for this long (let people react)
	HOLD_AFTER_WORD = 8, -- after a new word takes effect, no new stage / vote / event for this long
	CARD_OPEN_SECONDS = 8, -- a new mission card is shown big this long, then folds to one line
	STAGE_HOLD = 5, -- after a notice or a vote result, no quiet-time event for this long

	-- Fixed UI texts players may read aloud (checked against the word bank by tools/check_content.luau).
	TEXT = {
		FREE_TALK = "선택하지 않아도 자유롭게 이야기할 수 있어요",
		VOTE_FREE = "투표는 자유예요 · 계속 이야기해도 돼요",
		SETTLING = "마지막 말을 확인하고 있어요…",
		RECOGNITION_UNSTABLE = "음성 인식이 불안정해요 · 마이크 연결을 확인해 주세요", -- shown to players during the talk
	},

	-- Scoring (session leaderstats, casual only): the last other alive speaker before a launch gets the assist.
	ASSIST_WINDOW = 10,
	SCORE_ASSIST = 1,
	SCORE_SURVIVE = 3,

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
