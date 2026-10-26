--!strict
-- Round flow (V3, docs/DESIGN_V3.md §2; the only module that wires the services together):
--   Lobby -> Countdown -> Assign (chairs, lives) -> Play (ROUND_GAMES games: what the last one did + the next one
--   (the presenter picks, else the players vote) -> its briefing -> the game -> launches -> ...; no free talk since
--   the minigame overhaul, bundle 6a; games counted since the friend beta, 2026-10-24) -> Final (sudden death) ->
--   Result -> Countdown (quick rematch) ...
-- Rules live in the services: lives in LifeService, the game count, time cap and final trigger in Timeline, missions in
-- MissionRunner, flying chairs in SeatService, spectators in SpectatorService, voice routing in VoiceService, who may
-- join by chat in ChatService, the presenter in PresenterService, banned words in WordService, score in Scores, the round awards in Awards, the beta's measurements in Telemetry.
-- Bundle 6a: banned words exist only during the banned-word talk (a minigame, played while speech judging is on): its
-- prep stage draws them (the presenter may re-draw), the talk is judged in chat at once and in speech (JudgeService,
-- bundle 6e) — the presenter rescues, or without a presenter the hit flies at once — and by the presenter's ear, and
-- the settle stage (run here after every talk) waits for the last transcripts, ends the rescues, tells everyone their
-- word and clears the words and the chat rules. The other missions are
-- the quiz (also the final), the roulette, "a word to everyone" (plus the Studio-only test mission).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Judge = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Judge"))
local Match = require(script.Parent:WaitForChild("Match"))
local Net = require(script.Parent:WaitForChild("Net"))
local services = script.Parent:WaitForChild("services")
local LifeService = require(services:WaitForChild("LifeService"))
local Timeline = require(services:WaitForChild("Timeline"))
local MissionRunner = require(services:WaitForChild("MissionRunner"))
local WordService = require(services:WaitForChild("WordService"))
local JudgeService = require(services:WaitForChild("JudgeService"))
local RescueService = require(services:WaitForChild("RescueService"))
local ChatGate = require(services:WaitForChild("ChatGate"))
local BellService = require(services:WaitForChild("BellService"))
local SeatService = require(services:WaitForChild("SeatService"))
local SpectatorService = require(services:WaitForChild("SpectatorService"))
local VoiceService = require(services:WaitForChild("VoiceService"))
local ChatService = require(services:WaitForChild("ChatService"))
local PresenterService = require(services:WaitForChild("PresenterService"))
local Scores = require(services:WaitForChild("Scores"))
local Awards = require(services:WaitForChild("Awards"))
local Telemetry = require(services:WaitForChild("Telemetry"))

local RoundService = {}

type Reason = "fail" | "final" | "left" | "dev" | "afk"

local rng = Random.new() -- seat order and mission draws
local runs = 0 -- every mission run (and every Studio fail) gets its own number for the event ids
local toFinal = false -- everyone left fell at once: exactly those players play the final
local lastEndedAt = -math.huge -- os.clock() when the last result finished (quick rematch countdown)
-- The banned-word talk now being played (docs/DESIGN_V3.md §6): its number (results of an older talk are dropped), its
-- topic (new words avoid it), whether the presenter asked to start, and the public servers' re-draws used this round.
local talks = 0
local talkTopic = ""
local talkStartAsked = false
local rerollsUsed = 0
local earsPending = 0 -- ear judgments pressed in the talk whose lever has not landed yet (the settle stage waits)
-- Chat hits not rescued while other rescues still wait: they are judged together once the last wait is over (§4: the
-- order the waits end in must not decide who falls "at once").
local heldFails: { Player } = {}
local holdingLate = false -- the settle stage waits for the last transcripts: hits are held until it closes (6e)
-- A mission's words over the heads (머리 위 스무고개, bundle 9c) are up, and the running mission's chat watcher.
local headsUp = false
local missionChat: ((Player, string) -> ())? = nil

-- Alive participants and the presenter are heard by everyone; players who are out and spectators only by each other.
local function refreshSpeakers()
	local ids = {}
	for _, player in Match.aliveList() do
		table.insert(ids, player.UserId)
	end
	if Match.presenter then
		table.insert(ids, Match.presenter.UserId)
	end
	VoiceService.setSpeakers(ids)
end

-- Private servers play other rules (docs/DESIGN_V3.md §3). Studio has none, so a setting stands in for it there.
local function detectServerKind(): string
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute("BW_ServerKind")
		if forced == "public" or forced == "private" then
			return forced
		end
		return Config.STUDIO_SERVER_KIND
	end
	return if game.PrivateServerOwnerId ~= 0 then "private" else "public"
end

-- Speech judging of banned words (docs/DESIGN_V3.md §3): the banned-word talk is played only while it is on (owner
-- 2026-10-23). Studio has no speech recognition, so a setting pretends it is on there.
local function detectVoiceJudging(): boolean
	if RunService:IsStudio() and workspace:GetAttribute("BW_VoiceJudging") == true then
		return true
	end
	return Config.VOICE_JUDGING
end

-- Banned words are in play: the banned-word talk's prep, talk or settle stage (docs/DESIGN_V3.md §6).
local function talkOn(): boolean
	return Match.talk ~= nil
end

-- Tells everyone who lost a life or is out (one message per event, so the toast names them together; `final`: they
-- all fell at once and play the final among themselves).

local noteDecision: () -> () -- (below mainDecided) in the talk, the moment the main game is decided ends speech judging

-- The game being played: who lost a life in it and who went out (the recap before the next one, owner 2026-10-24).
local gameLost: { [Player]: boolean } = {}
local gameOut: { [Player]: boolean } = {}

-- `launchIn`: seconds until each one's launch goes off (a chain), for their screen (they keep the round camera).
local function tell(outcomes: { LifeService.Outcome }, reason: Reason, final: boolean, launchIn: { [Player]: number }?)
	local list = {}
	if Match.phase == "Play" and reason ~= "left" then
		for _, outcome in outcomes do
			if not gameLost[outcome.player] then
				Telemetry.lifeLost(outcome.player) -- (now: they may leave before the game is over)
			end
			gameLost[outcome.player] = true
			if outcome.out then
				gameOut[outcome.player] = true
			end
		end
	end
	for _, outcome in outcomes do
		table.insert(list, {
			userId = outcome.player.UserId,
			name = outcome.player.DisplayName,
			lives = outcome.livesLeft,
			out = outcome.out,
			launchIn = if launchIn then launchIn[outcome.player] else nil,
		})
	end
	Net.toAll("LifeLost", { reason = reason, players = list, final = final })
	noteDecision()
	refreshSpeakers()
	Match.broadcast()
	if talkOn() or headsUp then
		WordService.sendAll() -- who is out now sees every word, their own too
	end
end

-- Launches everyone who lost a life. Players who are out reach the stands after their flight (onFlightOver), or
-- right away when there was nothing to launch (no character on the chair at that moment). Owner 2026-10-24: several
-- go off one after another from the camera's left chair (CHAIN_DELAY apart; the lives are already settled, and each
-- counts as flying from now on), and the fewer lives left, the bigger the blast.
local function announce(outcomes: { LifeService.Outcome }, reason: Reason, final: boolean)
	if #outcomes == 0 then
		return
	end
	local order = table.clone(outcomes)
	table.sort(order, function(a, b)
		return (SeatService.seatIndexOf(a.player) or math.huge) < (SeatService.seatIndexOf(b.player) or math.huge)
	end)
	local launched = 0
	local launchIn: { [Player]: number } = {}
	for _, outcome in order do
		local lost = Config.LIVES - outcome.livesLeft -- (lives gone counting this one)
		local size = 1 + Config.BLAST_GROWTH * math.max(0, lost - 1)
		local delay = launched * Config.CHAIN_DELAY
		if SeatService.fling(outcome.player, Match.roundId, delay, size) then
			launched += 1
			launchIn[outcome.player] = delay
		elseif outcome.out then
			SpectatorService.toStands(outcome.player)
		end
	end
	tell(outcomes, reason, final, launchIn)
end

-- A main-game fail (a mission, a Studio test): a life each, or the final for exactly those players when nobody
-- would be left.
local function failPlayers(players: { Player }, eventId: string, reason: Reason, kind: LifeService.Kind?)
	local outcomes, everyone = LifeService.fail(players, eventId, kind or "objective")
	if everyone then
		toFinal = true
	end
	-- ("to the final" only when there is one: a single player left wins without it)
	announce(outcomes, reason, everyone and #outcomes > 1)
end

-- Flights in progress land and come back first (the next step, the final or the result waits for them). Returns
-- whether everyone landed. A flight ends FLING_RETURN_SECONDS after its launch; the cap only matters if launches kept
-- coming meanwhile.
local function waitFlights(): boolean
	local deadline = os.clock() + 3 * (Config.FLING_RETURN_SECONDS + 1)
	while SeatService.anyFlying() and os.clock() < deadline do
		task.wait(0.1)
	end
	return not SeatService.anyFlying()
end

-- Over without a final: one player left (of two or more), or nobody.
local function decided(): boolean
	local alive = #Match.aliveList()
	return alive == 0 or (Match.startedWith >= 2 and alive <= 1)
end

-- The main game's outcome is fixed: decided, everyone left fell at once, or so few are left that the final starts
-- at once. (The time running out is not one of these: a mission running then is played to its end.)
-- The moment the main game is decided (§2 "판이 결정되는 순간"): no new judgments count from here on.
local function mainDecided(): boolean
	return toFinal or decided() or Timeline.fewLeft(#Match.aliveList())
end

-- Speech judging (bundle 6e): speech begun after the moment the main game was decided in the talk is not judged
-- (§2), even when its transcript arrives in the settle stage (the talk goes on until the rescues have ended).
-- From then on, speech from before it is judged as in the settle stage: its hits are held and fall together there.
noteDecision = function()
	if Match.talk == "talk" and mainDecided() then
		Match.cutoffAt = math.min(Match.cutoffAt, Match.now())
		if Match.voiceJudging and Match.talkStartedAt < math.huge then
			holdingLate = true -- (released by settleTalk once the last transcripts are in)
		end
	end
end

-- ...and fixed: the rescues still waiting and the levers already pulled have ended first (they may change who is left).
local function mainSettled(): boolean
	return mainDecided() and RescueService.pending() == 0 and earsPending == 0
end

local releaseHeld: () -> () -- (below chatFail) the held hits fall together

-- The banned-word talk's settle stage (docs/DESIGN_V3.md §6), after every talk, also a cancelled or broken one: no new
-- judgments; chat is judged the moment it arrives, so nothing is queued; speech from before the end is waited for
-- (every voice player's client says it has sent it, at most SETTLE_MAX; bundle 6e); the rescues still waiting and the
-- levers already pulled end (they cost a life, but no new word any more); everyone who had a word is told it; then the
-- words, the speech judging and the chat rules go.
local TALK_POLL = 0.1
local function settleTalk()
	if not talkOn() then
		return
	end
	Match.talk = "settle"
	Match.cutoffAt = math.min(Match.cutoffAt, Match.now()) -- (speech begun after this is not judged)
	Match.broadcast()
	if Match.voiceJudging and Match.talkStartedAt < math.huge then
		-- Late hits are held meanwhile and fall together once no more can come (the order transcripts arrive in must
		-- not decide who falls first, e.g. who plays the final when everyone left falls).
		holdingLate = true
		local waitFrom = os.clock()
		JudgeService.settle(Match.cutoffAt)
		JudgeService.setOpen(false)
		local waited = os.clock() - waitFrom
		holdingLate = false
		releaseHeld()
		-- (for the live test: numbers only, never what was said; see docs/STT_LIVE_TEST_2026-10-24.md §3)
		local s = JudgeService.stats()
		print(string.format("[BannedWords] talk %d speech: %d transcripts received (with repeats) from %d speakers, %d"
			.. " judged in the talk, %d word matches, busiest minute window %d, settle waited %.1f s", talks,
			s.transcripts, s.players, s.judged, s.hits, s.peakMinute, waited))
	end
	local deadline = os.clock() + Config.RESCUE_SECONDS + Config.LEVER_SECONDS + Config.SETTLE_SLACK
	while (RescueService.pending() > 0 or earsPending > 0) and os.clock() < deadline do
		task.wait(TALK_POLL)
	end
	for player, p in Match.participants do
		local word = p.words[1]
		if word and player.Parent then
			Net.to(player, "Notice", { text = string.format(Config.TEXT.MY_WORD_WAS, word.text) })
		end
	end
	Match.talkStartedAt, Match.cutoffAt = math.huge, math.huge
	WordService.clear()
	Match.talk = nil
	ChatGate.setGuard(false)
	WordService.sendAll()
	Match.broadcast()
end

-- The floor (docs/DESIGN_V3.md §5.1): `player` and the presenter are heard by everyone, the other alive players by
-- nobody, and alive players receive only `player`'s chat; nil ends it.
local floorHolder: Player? = nil -- has the floor now (given again to the new presenter's routing when they change)
local function setFloor(player: Player?)
	floorHolder = player
	if player then
		local ids = { player.UserId }
		if Match.presenter then
			table.insert(ids, Match.presenter.UserId)
		end
		VoiceService.setFloor(ids)
	else
		VoiceService.setFloor(nil)
	end
	ChatGate.setFloor(player)
end

-- A mission's words over the heads (머리 위 스무고개, bundle 9c; nil: they go): the owners see theirs once `known`. While
-- they are up the chat rules are on (no one outside the game can tell a player their word, and a line holding a
-- player's word never reaches them, ChatGate).
local function setHeads(words: { [Player]: string }?, known: { [Player]: boolean }?)
	if talkOn() then
		return -- (the talk's words; never both)
	end
	if words then
		WordService.place(words, known or {})
		if not headsUp then
			headsUp = true
			ChatGate.setGuard(true)
		end
	elseif headsUp then
		headsUp = false
		WordService.clear()
		ChatGate.setGuard(false)
	else
		return
	end
	WordService.sendAll()
end

-- The talk's prep stage: words for everyone alive (not inside the topic), shown, chat rules on; then the talk itself.
local function setTalkStage(stage: string, topic: string?)
	if stage == "prep" then
		talks += 1
		talkTopic = topic or ""
		talkStartAsked = false
		WordService.assign(rng, { talkTopic })
		Match.talk = "prep"
		ChatGate.setGuard(true)
	elseif stage == "talk" and Match.talk == "prep" then
		Match.talk = "talk"
		Match.talkStartedAt, Match.cutoffAt = Match.now(), math.huge
		WordService.startJudging(Match.now())
		JudgeService.setOpen(Match.voiceJudging) -- (speech judging: only the talk stage's speech is judged)
	else
		return
	end
	Match.broadcast()
	WordService.sendAll()
end

-- The presenter's re-draw window: `seconds`, or until they press "start now"; false if the mission is cancelled.
local function rerollWindow(seconds: number, cancelled: () -> boolean): boolean
	local untilAt = os.clock() + seconds
	while os.clock() < untilAt and not talkStartAsked do
		if cancelled() then
			return false
		end
		task.wait(TALK_POLL)
	end
	return not cancelled()
end

-- What a mission may do (docs/DESIGN_V3.md §13). `onFail(players, key)`: who failed the mission's event `key`.
-- `settled()`: the outcome is already fixed, so the running mission stops and later results are dropped (§2 "확정 뒤에
-- 도착한 결과는 버린다").
local function missionCtx(myRound: number, final: boolean, onFail: ({ Player }, string, boolean?) -> (),
	settled: () -> boolean): MissionRunner.Ctx
	-- Who answered the last answer mission and who did not: counted with the fail that follows (the same event), so
	-- an AFK player going out cannot decide the round before the same question's wrong answers are taken.
	local pending: { answered: { Player }, missed: { Player } }? = nil
	local function countAnswers()
		local counted = pending
		pending = nil
		if not counted then
			return
		end
		for _, player in counted.answered do
			LifeService.noteAnswer(player, true)
		end
		local outcomes: { LifeService.Outcome } = {}
		for _, player in counted.missed do
			if LifeService.noteAnswer(player, false) then
				table.insert(outcomes, { player = player, livesLeft = 0, out = true })
			end
		end
		announce(outcomes, "afk", false)
	end
	return {
		final = final,
		players = Match.aliveList,
		rng = rng,
		fail = function(players: { Player }, key: string, subjective: boolean?)
			countAnswers()
			onFail(players, key, subjective)
		end,
		-- (a moment's line is a toast only; the status board keeps what is going on — the game's name — so the same
		-- sentence never shows twice at once, review 2026-10-25)
		show = function(text: string)
			Net.notice(text)
		end,
		cancelled = function()
			return Match.roundId ~= myRound or settled()
		end,
		stopped = function()
			return Match.roundId ~= myRound
		end,
		flying = SeatService.isFlying,
		-- Two answer missions missed in a row make a player a spectator (docs/DESIGN_V3.md §4). Counted when the
		-- mission reports its fail (before the launches: a launched player's miss would not count any more).
		answers = function(answered: { Player }, missed: { Player })
			pending = { answered = answered, missed = missed }
		end,
		canFling = function(player: Player): boolean
			return LifeService.canFail(player, "subjective")
		end,
		-- The one-word mission's launch: the presenter's choice (a missed one counts toward PRESENTER_MISSES).
		presenterPick = function(options, seconds, kind: string?)
			local function over(): boolean
				return Match.roundId ~= myRound or settled()
			end
			local picked = PresenterService.ask(if kind == "accuse" then "accuse" else "judge", options, seconds, over)
			return picked
		end,
		talk = setTalkStage,
		presenterReroll = function(seconds: number): boolean
			return rerollWindow(seconds, function()
				return Match.roundId ~= myRound or settled()
			end)
		end,
		bell = function(from: { Player }, seconds: number, firstOnly: boolean,
			enough: (({ Player }, { [Player]: number }, { BellService.Press }) -> boolean)?,
			repeatEvery: number?, quiet: boolean?): ({ Player }, { [Player]: number }, { BellService.Press })
			return BellService.collect(from, seconds, firstOnly, function()
				return Match.roundId ~= myRound or settled()
			end, enough, repeatEvery, quiet)
		end,
		floor = setFloor,
		presenterVerdict = function(answer: string, seconds: number): string?
			local options = {
				{ id = "right", title = Config.TEXT.VERDICT_RIGHT, recommended = false },
				{ id = "wrong", title = Config.TEXT.VERDICT_WRONG, recommended = false },
			}
			-- (also over when the one answering left or flew: nothing to judge any more, and the floor goes back)
			local holder = floorHolder
			local picked = PresenterService.ask("verdict", options, seconds, function()
				return Match.roundId ~= myRound or settled()
					or (holder ~= nil and (not Match.isAlive(holder) or SeatService.isFlying(holder)))
			end, answer)
			return picked
		end,
		score = function(player: Player, amount: number)
			Scores.add(player, amount)
		end,
		heads = setHeads,
		chat = function(handler: ((Player, string) -> ())?)
			missionChat = handler
		end,
	}
end

local function waitPhase(shouldStop: (() -> boolean)?)
	while Match.now() < Match.endsAt do
		if shouldStop and shouldStop() then
			return
		end
		task.wait(0.2)
	end
end

-- What the last game did, for the screens before the next one: who lost a life, who is out.
local function recapText(): string
	local lost, out = {}, {}
	for player in gameLost do
		table.insert(if gameOut[player] then out else lost, player.DisplayName)
	end
	table.sort(lost)
	table.sort(out)
	local parts = {}
	if #lost > 0 then
		table.insert(parts, string.format(Config.TEXT.RECAP_LOST, table.concat(lost, ", ")))
	end
	if #out > 0 then
		table.insert(parts, string.format(Config.TEXT.RECAP_OUT, table.concat(out, ", ")))
	end
	return if #parts > 0 then table.concat(parts, " · ") else Config.TEXT.RECAP_NONE
end

-- Main game: ROUND_GAMES missions back to back (owner 2026-10-24; no free talk, docs/DESIGN_V3.md §2) until the final
-- is due or the round is decided. Between games, once nobody is in the air, everyone sees what the last game did
-- while the next one is chosen: the presenter picks within PRESENTER_PICK_SECONDS (else at random, with a notice), or
-- without a presenter the alive players vote among a few (MissionRunner.vote); then its briefing (BRIEF_SECONDS). A
-- mission starts only if it fits the time cap; when none fits, the final starts at once.
local function playMain(myRound: number)
	-- Players who left during the assignment do not count as having started (§2: "4명 이상으로 시작한 판").
	Timeline.begin(#Match.aliveList())
	Match.game = 0
	Match.setPhase("Play", 0, Config.TEXT.PLAY_START) -- (no clock: the status board counts the games)
	local function over(): boolean
		return Match.roundId ~= myRound or mainSettled()
			or (Timeline.finalDue(#Match.aliveList()) and RescueService.pending() == 0) -- (the final waits for rescues too)
	end
	local lastId: string? = nil
	local recap = "" -- (nothing before the first game)
	local chosenBy, votes = "random", nil :: { [string]: number }?
	while true do
		local landed = waitFlights()
		if over() then
			return
		end
		if landed then
			local mission: MissionRunner.Mission? = nil
			-- (a presenter being replaced after missed picks no longer counts: the players vote meanwhile)
			local presenting = Match.presenter ~= nil and not Match.presenterPending
			if presenting then
				local options = MissionRunner.options(Timeline.left() - Config.PRESENTER_PICK_SECONDS - Config.BRIEF_SECONDS,
					#Match.aliveList())
				if #options == 0 then
					return -- nothing fits any more: the final
				end
				Match.setMessage(Config.TEXT.PICKING)
				MissionRunner.showPicking(recap)
				local picked, missed = PresenterService.ask("pick", options, Config.PRESENTER_PICK_SECONDS, over)
				if over() then
					return
				end
				if missed then
					Net.notice(Config.TEXT.PICK_AUTO)
				end
				mission = MissionRunner.choose(Timeline.left() - Config.BRIEF_SECONDS, #Match.aliveList(),
					Match.presenter ~= nil and not Match.presenterPending, picked, rng, lastId)
				chosenBy, votes = if mission and mission.id == picked then "presenter" else "random", nil
			else
				-- (the vote's seconds are counted before choosing, so the winner still fits once it is over; with one game
				-- or none to choose from there is no vote, and its seconds are not counted)
				local ballot = MissionRunner.ballot(Timeline.left() - Config.NEXT_VOTE_SECONDS - Config.BRIEF_SECONDS,
					#Match.aliveList(), rng, lastId)
				if #ballot > 1 then
					Match.setMessage(Config.TEXT.NEXT_VOTE)
					mission, votes = MissionRunner.vote(ballot, recap, Match.aliveList(), rng, over)
					chosenBy = "vote"
					if over() then
						return
					end
					recap = "" -- (shown on the vote screen)
				else
					mission = MissionRunner.choose(Timeline.left() - Config.BRIEF_SECONDS, #Match.aliveList(), false, nil,
						rng, lastId)
					chosenBy, votes = "random", nil
				end
			end
			if presenting then
				recap = "" -- (shown on the picking screen)
			end
			if not mission then
				return -- nothing fits any more: the final
			end
			Match.game = Config.ROUND_GAMES - Timeline.gamesLeft() + 1
			Match.setMessage(string.format(Config.TEXT.NEXT_GAME, mission.title))
			if not MissionRunner.brief(mission, Match.game, Config.ROUND_GAMES, recap, over) then
				return
			end
			if SeatService.anyFlying() then
				continue -- (launched meanwhile, e.g. the Studio fail key: land first, then choose again)
			end
			runs += 1
			local run = runs
			lastId = mission.id
			Match.setMessage(mission.title) -- (the status board names the game while it runs)
			table.clear(gameLost)
			table.clear(gameOut)
			local playing = Match.aliveList() -- (who plays this game)
			local startedAt = os.clock()
			Telemetry.gameStarted(playing, mission.id)
			local _, didPlay = MissionRunner.run(mission, missionCtx(myRound, false, function(players, key, subjective)
				failPlayers(players, "m" .. run .. ":" .. key, "fail", if subjective then "subjective" else "objective")
			end, mainSettled))
			if didPlay then
				Timeline.gameStarted() -- (a game with too few players to start is not one of the round's games)
			end
			setFloor(nil) -- (whatever the mission did: the bells close, everyone has their voice back)
			BellService.close()
			missionChat = nil
			setHeads(nil) -- (a mission's words go with it, also when it was cancelled or broke)
			settleTalk() -- (a banned-word talk ends with its settle stage, also when it was cancelled or broke)
			recap = recapText()
			if didPlay then
				local lost, kept = {}, {}
				for _, player in playing do
					table.insert(if gameLost[player] then lost else kept, player)
				end
				Awards.gameOver(kept)
				Telemetry.gameEnded({ round = myRound, game = Match.game, mission = mission.id, chosenBy = chosenBy,
					votes = votes, players = playing, lost = lost, seconds = os.clock() - startedAt })
			else
				Telemetry.gameEnded(nil)
			end
		end
	end
end

-- Final: sudden-death questions for the survivors until one is left or FINAL_MAX_SECONDS have passed (a question
-- begun before that is played to its end); a question everyone gets wrong puts nobody out. A question that breaks
-- ends the final (the survivors share the win). The final has no banned words (bundle 6a: they live in the talk).
local function playFinal(myRound: number)
	local mission = MissionRunner.finalMission()
	if not mission or #Match.aliveList() < 2 or Match.roundId ~= myRound then
		return
	end
	Match.setPhase("Final", Config.FINAL_MAX_SECONDS, Config.TEXT.FINAL)
	local deadline = os.clock() + Config.FINAL_MAX_SECONDS
	local function settled(): boolean
		return #Match.aliveList() < 2 -- the others left: the last one wins
	end
	-- One question's wrong answers go out together; if that would be everyone left, nobody does.
	local function judge(wrong: { Player }): boolean
		local alive = Match.aliveList()
		local out: { Player } = {}
		for _, player in wrong do
			if table.find(alive, player) then
				table.insert(out, player)
			end
		end
		if #out > 0 and #out >= #alive then
			Net.notice(Config.TEXT.ALL_WRONG)
		elseif #out > 0 then
			announce(LifeService.eliminate(out), "final", false)
			return true
		end
		return false
	end
	while not settled() and os.clock() < deadline and Match.roundId == myRound do
		-- The question's wrong answers are gathered and go out together (§2 "동시 탈락").
		local wrong: { Player } = {}
		local ok, played = MissionRunner.run(mission, missionCtx(myRound, true, function(players, _key)
			for _, player in players do
				if not table.find(wrong, player) then
					table.insert(wrong, player)
				end
			end
		end, settled))
		if not ok or not played or Match.roundId ~= myRound then
			if Match.roundId == myRound and judge(wrong) then
				waitFlights()
			end
			break -- (a final that cannot ask anything more: the survivors share the win)
		end
		if judge(wrong) then
			waitFlights()
		end
		task.wait() -- every question yields at least once, even one that returns at once
	end
end

-- Who won (everyone still in) and who presented to the end, with the session score.
local function resultText(): string
	local names = {}
	for _, player in Match.aliveList() do
		Scores.add(player, Config.SCORE_WIN)
		table.insert(names, player.DisplayName)
	end
	local text
	if #names == 0 then
		text = Config.TEXT.NO_WINNER
	elseif #names == 1 then
		text = string.format(Config.TEXT.WINNER, names[1])
	else
		text = string.format(Config.TEXT.JOINT_WINNERS, table.concat(names, ", "))
	end
	local presenter = Match.presenter
	if presenter and presenter.Parent then
		Scores.add(presenter, Config.SCORE_PRESENTER)
		text ..= " · " .. string.format(Config.TEXT.PRESENTER_CREDIT, presenter.DisplayName)
	end
	return text
end

local function shuffled(list: { Player }): { Player }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- Round over for the voice routing: everyone open again (chat participants too).
local function openVoices()
	VoiceService.setSpeakers(nil)
	VoiceService.setSilenced({})
end

local function cleanup()
	SeatService.releaseAll()
	setFloor(nil)
	BellService.close()
	RescueService.endRound() -- (before the presenter goes: their rescue banner is cleared)
	PresenterService.endRound()
	missionChat = nil
	setHeads(nil)
	ChatGate.setGuard(false)
	JudgeService.setOpen(false)
	openVoices()
	SpectatorService.endRound()
	Match.resetRound()
	toFinal = false
	talkStartAsked = false
	rerollsUsed = 0
	earsPending = 0
	heldFails = {}
	holdingLate = false
	table.clear(gameLost)
	table.clear(gameOut)
	MissionRunner.clearScreen() -- (a between-games screen left by a round that broke)
end

local function runRound()
	-- Countdown (short right after a result, so friends can go again quickly).
	local rematch = os.clock() - lastEndedAt < 20
	Match.setPhase("Countdown", if rematch then Config.REMATCH_COUNTDOWN else Config.LOBBY_COUNTDOWN, Config.TEXT.COUNTDOWN)
	waitPhase(function()
		return #Match.eligiblePlayers() < Config.MIN_PLAYERS
	end)
	local candidates = shuffled(Match.eligiblePlayers())
	if #candidates < Config.MIN_PLAYERS then
		return
	end

	-- Assign: the presenter (not seated, docs/DESIGN_V3.md §8), chairs, lives, and who plays by chat (their voice is
	-- off until the result, §7).
	Match.roundId += 1
	local myRound = Match.roundId
	Match.resetRound()
	Match.serverKind = detectServerKind()
	Match.voiceJudging = detectVoiceJudging()
	toFinal = false
	rerollsUsed = 0
	Scores.resetRound()
	Awards.beginRound()
	MissionRunner.beginRound()
	local presenter = PresenterService.choose(candidates) -- before the chairs are counted: every volunteer is looked at
	-- (the presenter checks wait on web calls: whoever left or stopped being ready meanwhile gets no chair, and with too
	-- few left there is no round — review 2026-10-25: a round of one, or a chair for someone already gone)
	local stillHere = Match.eligiblePlayers()
	for i = #candidates, 1, -1 do
		local player = candidates[i]
		if player == presenter or player.Parent == nil or not table.find(stillHere, player) then
			table.remove(candidates, i)
		end
	end
	if presenter and #candidates < Config.MIN_PLAYERS and presenter.Parent and table.find(stillHere, presenter) then
		PresenterService.endRound() -- (too few without them: they sit and play instead, the round goes on)
		table.insert(candidates, presenter)
		presenter = nil
	end
	if #candidates < Config.MIN_PLAYERS then
		cleanup()
		return
	end
	while #candidates > Config.MAX_PLAYERS do
		table.remove(candidates)
	end
	local seated = SeatService.seatPlayers(candidates)
	local chatIds = {}
	for _, player in candidates do
		if seated[player] then
			local chat = Match.chatJoin[player] == true
			Match.participants[player] =
				{ player = player, words = {}, alive = true, lives = Config.LIVES, afkMisses = 0, chat = chat }
			if chat then
				table.insert(chatIds, player.UserId)
			end
		end
	end
	Match.startedWith = #Match.aliveList()
	if Match.startedWith < Config.MIN_PLAYERS then -- (someone was respawning and got no chair)
		cleanup()
		return
	end
	LifeService.beginRound()
	ChatGate.setGuard(false) -- (chat rules come with the banned-word talk, §7)
	if Match.presenter then
		PresenterService.place(Match.presenter)
	end
	SpectatorService.beginRound()
	VoiceService.setSilenced(chatIds)
	refreshSpeakers()
	Match.setPhase("Assign", Config.ASSIGN_TIME, string.format(Config.TEXT.ASSIGN, Config.LIVES))
	WordService.sendAll() -- (nobody has a word: clients clear what they had)
	waitPhase()

	playMain(myRound)
	MissionRunner.clearScreen() -- (a between-games screen when the main game ended during it)
	waitFlights()
	playFinal(myRound)
	waitFlights()

	-- Result: winners and scores.
	local text = resultText()
	SeatService.releaseAll()
	RescueService.endRound() -- (before the presenter goes: their rescue banner is cleared)
	PresenterService.endRound()
	ChatGate.setGuard(false)
	openVoices()
	Match.setPhase("Result", Config.RESULT_TIME, text)
	local winnerIds = {}
	for _, player in Match.aliveList() do
		table.insert(winnerIds, player.UserId)
	end
	MissionRunner.showRoundResult(text, Awards.lines(), winnerIds)
	waitPhase()
	cleanup()
	lastEndedAt = os.clock()
end

-- FLING_RETURN_SECONDS after a launch (docs/DESIGN_V3.md §10 step 4): undo the ragdoll, then back on the chair if
-- the player is still in this round's game, else into the stands. A flight from an older round, or of a character
-- the player no longer has, only gets undone.
local function onFlightOver(player: Player, roundId: any, character: Model)
	SeatService.endFling(player)
	if not player.Parent or player.Character ~= character or roundId ~= Match.roundId or not Match.inRound() then
		return
	end
	if not (Match.isAlive(player) and SeatService.reseat(player)) then
		SpectatorService.toStands(player)
	end
end

-- A participant's new character (after a fall or a reset that slipped through) costs nothing: back on the chair
-- (docs/DESIGN_V3.md §4). Everyone else's goes to the stands (SpectatorService).
local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.5) -- let the engine finish placing it at the spawn
	if player.Character ~= character or not Match.inRound() then
		return
	end
	if Match.isAlive(player) then
		SeatService.reseat(player)
	elseif Match.presenter == player then
		PresenterService.place(player) -- back to the podium
	end
end

-- The presenter changed during a round (left, missed picks, stepped down): voices, the old presenter to the stands.
local function onPresenterChange(_reason: PresenterService.Change, old: Player?, _new: Player?)
	if not Match.inRound() then
		return
	end
	if old and old.Parent then
		SpectatorService.toStands(old)
	end
	refreshSpeakers()
	if floorHolder then
		setFloor(floorHolder) -- (the new presenter is heard during the floor too)
	end
	Match.broadcast()
	if talkOn() then
		WordService.sendAll()
		RescueService.send() -- the new presenter sees the hits waiting
	end
end

local function onSync(player: Player)
	Net.to(player, "RoundState", Match.payload())
	ChatService.sendAccess(player)
	PresenterService.sendMenu(player)
	MissionRunner.sendScreen(player)
	BellService.send(player)
	WordService.send(player)
	if player == Match.presenter then
		RescueService.send()
	end
end

-- Whether a banned word may count against `target` now (docs/DESIGN_V3.md §4, §6): the main game not yet decided, the
-- player alive and on the ground, no hit of theirs waiting for a rescue; new judgments only in the talk stage (`late`:
-- one already pressed or caught in it may still land in the settle stage). A result after the outcome is fixed is
-- dropped (§2).
local function judgingOpen(target: Player, late: boolean?): boolean
	if late then
		-- (pressed before the outcome was fixed: it lands even if the round was decided meanwhile; mainSettled waits)
		return (Match.talk == "talk" or Match.talk == "settle") and Match.phase == "Play" and Match.isAlive(target)
			and not SeatService.isFlying(target)
	end
	return Match.talk == "talk" and Match.phase == "Play" and not mainDecided() and Match.isAlive(target)
		and not SeatService.isFlying(target)
end

-- A judgment of `target`'s is still open: a hit waiting for a rescue, or one not rescued waiting to be judged together
-- with the other rescues (§4: nothing else counts against them meanwhile).
local function judgmentOpen(target: Player): boolean
	return RescueService.waiting(target) or table.find(heldFails, target) ~= nil
end

-- A new word after a hit, while the talk goes on (in the settle stage the word stays: it is the one they are told).
local function newWord(target: Player)
	if Match.talk == "talk" then
		WordService.replace(target, MissionRunner.screenTexts(), rng)
	end
end

-- The presenter heard `target` say their banned word (what the system missed, docs/DESIGN_V3.md §4): the lever, then a
-- launch and a new word at once (no rescue for ear judgments). Public servers: a subjective launch (its limits apply).
local earEvents = 0
local function onHeard(target: Player)
	local kind: LifeService.Kind = if Match.serverKind == "public" then "subjective" else "objective"
	if not judgingOpen(target) or judgmentOpen(target) or not LifeService.canFail(target, kind) then
		return
	end
	earEvents += 1
	local event = "ear" .. earEvents
	local myRound, myTalk = Match.roundId, talks
	earsPending += 1
	Net.toAll("Lever", {})
	task.delay(Config.LEVER_SECONDS, function()
		if Match.roundId ~= myRound then
			return -- (cleanup reset the count)
		end
		earsPending -= 1
		if talks ~= myTalk or not judgingOpen(target, true) or judgmentOpen(target) then
			return
		end
		Net.notice(string.format(Config.TEXT.EAR_HIT, target.DisplayName))
		newWord(target)
		failPlayers({ target }, event, "fail", kind)
		WordService.sendAll()
	end)
end

-- A banned word caught in chat (docs/DESIGN_V3.md §7): a "땡" for everyone, then RESCUE_SECONDS for the presenter's
-- rescue; without a presenter the hit flies at once (the system judges first, §4).
local chatEvents = 0
local function chatFail(targets: { Player })
	local list = {}
	for _, target in targets do
		if Match.isAlive(target) and not SeatService.isFlying(target) then
			table.insert(list, target)
		end
	end
	if #list > 0 then
		chatEvents += 1
		failPlayers(list, "chat" .. chatEvents, "fail")
	end
	WordService.sendAll()
end

-- The held hits fall together, once no rescue waits and the settle stage no longer holds them.
releaseHeld = function()
	if holdingLate or RescueService.pending() > 0 or #heldFails == 0 then
		return
	end
	local held = heldFails
	heldFails = {}
	chatFail(held)
end

-- A banned word caught by the system (chat or speech): a "땡", then the presenter's rescue wait, or at once a launch.
local function caught(player: Player, wordText: string)
	Net.toAll("Sound", { index = Config.HIT_SOUND })
	if not Match.presenter then
		newWord(player)
		if holdingLate then
			table.insert(heldFails, player) -- (falls with the other late hits, see settleTalk)
		else
			chatFail({ player })
		end
		return
	end
	if not RescueService.hit(player, wordText, { round = Match.roundId, talk = talks }) then
		return -- a hit of theirs is already waiting: merged
	end
	Net.notice(string.format(Config.TEXT.RESCUE_WAIT, player.DisplayName))
end

local function onChat(player: Player, text: string)
	local watcher = missionChat
	if watcher then
		watcher(player, text) -- (decides at once, as the line arrived; it never yields and defers any launch)
	end
	if not judgingOpen(player) or judgmentOpen(player) then
		return -- (a hit of theirs still open: this one is merged into it, §4)
	end
	local p = Match.participants[player]
	local word = p and p.words[1]
	if not (word and Judge.chatHit(word.text, text, word.aliases)) then
		return
	end
	caught(player, word.text)
end

-- Speech judging (bundle 6e): JudgeService found `wordText` in `player`'s speech from inside the talk (its time range
-- checked there). Its transcript may arrive in the settle stage (speech that began before the end; §6), or after the
-- round was decided, so a late one still lands then.
local function onSpeechHit(player: Player, wordText: string)
	-- (late: in the settle stage, or once the round was decided while the talk goes on — the same speech must count
	-- the same whenever its transcript arrives)
	if not judgingOpen(player, Match.talk == "settle" or mainDecided()) or judgmentOpen(player) then
		return -- (a hit of theirs still open: this one is merged into it, §4)
	end
	caught(player, wordText)
end

-- The rescue wait is over: a new word either way (while the talk goes on); without a rescue, a life. The lives are
-- taken once no other rescue waits, all together (the hit belongs to the talk it came in).
local function onRescueResolved(hit: RescueService.Hit)
	local data = hit.data
	local target = hit.player
	if data.round == Match.roundId and data.talk == talks and talkOn() and Match.isAlive(target) then
		newWord(target)
		if hit.rescued then
			Net.notice(string.format(Config.TEXT.RESCUED, target.DisplayName))
		elseif not table.find(heldFails, target) then
			table.insert(heldFails, target)
		end
		WordService.sendAll()
	end
	if data.round == Match.roundId then
		releaseHeld()
	end
end

-- The presenter re-draws words in the talk's prep stage: one player (private servers) or everyone at once, REROLLS_PUBLIC
-- times a round (public servers, docs/DESIGN_V3.md §6).
local function onReroll(target: Player?)
	if Match.talk ~= "prep" then
		return
	end
	if Match.serverKind == "public" then
		if target ~= nil or rerollsUsed >= Config.REROLLS_PUBLIC then
			return
		end
		rerollsUsed += 1
		WordService.assign(rng, { talkTopic })
	elseif target and Match.isAlive(target) then
		WordService.replace(target, { talkTopic }, rng)
	else
		return
	end
	WordService.sendAll()
end

-- The presenter starts the talk now (the prep stage ends early).
local function onTalkStart()
	if Match.talk == "prep" then
		talkStartAsked = true
	end
end

-- The player plays in or presents the round being played: their way of joining (voice or chat) holds until it is over.
local function lockedIn(player: Player): boolean
	return Match.inRound() and (Match.participants[player] ~= nil or Match.presenter == player)
end

-- Players another service owns right now: flying (SeatService) or presenting at the podium (PresenterService).
local function busy(player: Player): boolean
	return SeatService.isFlying(player) or Match.presenter == player
end

function RoundService.start()
	if Config.SHOW_OWN_WORD then
		warn("[BannedWords] SOLO speech test build: players see their own banned word - never publish this as the game")
	end
	VoiceService.start()
	Scores.start()
	ChatService.start()
	PresenterService.start({
		changed = onPresenterChange,
		busy = SeatService.isFlying,
		heard = onHeard,
		reroll = onReroll,
		talkStart = onTalkStart,
	})
	RescueService.start(onRescueResolved)
	ChatGate.start(onChat, WordService.hides)
	JudgeService.start(onSpeechHit)
	MissionRunner.start()
	BellService.start(SeatService.isFlying)
	LifeService.start(SeatService.isFlying)
	SpectatorService.start(busy)
	SeatService.init(onFlightOver, function(player, distance, _airTime)
		Awards.flight(player, distance)
	end)
	-- "Ready" changes take effect at once; the state broadcast they cause is gathered (at most one per
	-- READY_BROADCAST_DELAY), so a client flipping it fast cannot make the server message everyone each time.
	local readyBroadcastQueued = false
	-- (`linked`: voice connected, muted or not — a chat player needs it to hear everyone, owner 2026-10-25)
	Net.listen("Ready", function(player, isReady, linked)
		local value = isReady == true
		local link = linked == true or value
		if (Match.ready[player] == true) ~= value or (Match.voiceLinked[player] == true) ~= link then -- (repeats: nothing)
			Match.ready[player] = value
			Match.voiceLinked[player] = link
			if not readyBroadcastQueued then
				readyBroadcastQueued = true
				task.delay(Config.READY_BROADCAST_DELAY, function()
					readyBroadcastQueued = false
					Match.broadcast()
				end)
			end
		end
	end)
	local lastChatJoin: { [Player]: number } = {}
	Net.listen("ChatJoin", function(player, on)
		if typeof(on) ~= "boolean" then
			return
		end
		local now = os.clock()
		if now - (lastChatJoin[player] or -math.huge) < Config.CHAT_JOIN_COOLDOWN then
			return
		end
		lastChatJoin[player] = now
		if ChatService.request(player, on, lockedIn(player)) then
			Match.broadcast()
		end
	end)
	local lastSync: { [Player]: number } = {}
	Net.listen("Sync", function(player)
		local now = os.clock()
		if now - (lastSync[player] or -math.huge) >= Config.SYNC_COOLDOWN then
			lastSync[player] = now
			onSync(player)
		end
	end)
	-- Studio only (live servers ignore it): any time in the main game (not once it is settled) a seated player loses a
	-- life (F key), or with "out" is out at once, or with "show" is only launched (nothing lost). (Games come back to
	-- back since bundle 6a, so it also works while a mission runs: the fail counts like any other event.)
	Net.listen("DevFling", function(player, mode)
		if not (RunService:IsStudio() and Match.phase == "Play" and not mainSettled() and Match.isAlive(player)) then
			return
		end
		if mode == "out" then
			announce(LifeService.eliminate({ player }), "dev", false)
		elseif mode == "show" then
			SeatService.fling(player, Match.roundId)
		else
			runs += 1
			failPlayers({ player }, "dev" .. runs, "dev")
		end
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		lastSync[player] = nil
		lastChatJoin[player] = nil
		-- Leaving is out (docs/DESIGN_V3.md §4).
		local outcomes = if Match.inRound() then LifeService.eliminate({ player }) else {}
		Match.participants[player] = nil
		Match.ready[player] = nil
		Match.voiceLinked[player] = nil
		Match.chatJoin[player] = nil -- (before the broadcast below, so the ready count is right)
		if #outcomes > 0 then
			tell(outcomes, "left", false)
		else
			Match.broadcast()
		end
	end)

	task.spawn(function()
		while true do
			local shown = -1
			while #Match.eligiblePlayers() < Config.MIN_PLAYERS do
				local needed = Config.MIN_PLAYERS - #Match.eligiblePlayers()
				if needed ~= shown then
					shown = needed
					Match.setPhase("Lobby", 0, string.format(if Config.REQUIRE_VOICE_READY then Config.TEXT.NEED_READY else Config.TEXT.NEED_PLAYERS, needed))
				end
				task.wait(1)
			end
			local ok, err = xpcall(runRound, debug.traceback)
			if not ok then
				warn("[BannedWords] round crashed, recovering:", err)
				Match.roundId += 1 -- anything still holding the broken round's ctx sees it as cancelled
				cleanup()
				Match.setPhase("Lobby", 3, Config.TEXT.RECOVERING)
				task.wait(3)
			end
		end
	end)
end

return RoundService
