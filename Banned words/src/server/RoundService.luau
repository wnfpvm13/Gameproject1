--!strict
-- Round flow (V3, docs/DESIGN_V3.md §2; the only module that wires the services together):
--   Lobby -> Countdown -> Assign (chairs, lives) -> Play (ROUND_SECONDS: free talk -> mission -> launches -> ...)
--   -> Final (sudden death) -> Result -> Countdown (quick rematch) ...
-- Rules live in the services: lives in LifeService, the time budget and the final trigger in Timeline, missions in
-- MissionRunner, flying chairs in SeatService, spectators in SpectatorService, voice routing in VoiceService, who may
-- join by chat in ChatService, the presenter in PresenterService, banned words in WordService, score in Scores.
-- Up to bundle 5b: banned words on private servers (stage 1), judged by the presenter's ear and in chat (with the
-- presenter's rescue, RescueService; chat rules in ChatGate); the missions are the quiz (also the final), the roulette,
-- "a word to everyone" (plus the Studio-only test mission).
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
local RescueService = require(services:WaitForChild("RescueService"))
local ChatGate = require(services:WaitForChild("ChatGate"))
local SeatService = require(services:WaitForChild("SeatService"))
local SpectatorService = require(services:WaitForChild("SpectatorService"))
local VoiceService = require(services:WaitForChild("VoiceService"))
local ChatService = require(services:WaitForChild("ChatService"))
local PresenterService = require(services:WaitForChild("PresenterService"))
local Scores = require(services:WaitForChild("Scores"))

local RoundService = {}

type Reason = "fail" | "final" | "left" | "dev" | "afk"

local rng = Random.new() -- seat order and mission draws
local runs = 0 -- every mission run (and every Studio fail) gets its own number for the event ids
local toFinal = false -- everyone left fell at once: exactly those players play the final
local freeTalk = false -- free talk in the main game (the Studio fail key works only then, so no launch starts while
-- a mission runs or the round waits for flights)
local lastEndedAt = -math.huge -- os.clock() when the last result finished (quick rematch countdown)

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

-- Banned words play on private servers in stage 1 (docs/DESIGN_V3.md §3); public servers get them in stage 2.
local function wordsOn(): boolean
	return Match.serverKind == "private"
end

-- Tells everyone who lost a life or is out (one message per event, so the toast names them together; `final`: they
-- all fell at once and play the final among themselves).

local function tell(outcomes: { LifeService.Outcome }, reason: Reason, final: boolean)
	local list = {}
	for _, outcome in outcomes do
		table.insert(list, {
			userId = outcome.player.UserId,
			name = outcome.player.DisplayName,
			lives = outcome.livesLeft,
			out = outcome.out,
		})
	end
	Net.toAll("LifeLost", { reason = reason, players = list, final = final })
	refreshSpeakers()
	Match.broadcast()
	if wordsOn() then
		WordService.sendAll() -- who is out now sees every word, their own too
	end
end

-- Launches everyone who lost a life. Players who are out reach the stands after their flight (onFlightOver), or
-- right away when there was nothing to launch (no character on the chair at that moment).
local function announce(outcomes: { LifeService.Outcome }, reason: Reason, final: boolean)
	if #outcomes == 0 then
		return
	end
	for _, outcome in outcomes do
		if not SeatService.fling(outcome.player, Match.roundId) and outcome.out then
			SpectatorService.toStands(outcome.player)
		end
	end
	tell(outcomes, reason, final)
end

-- A main-game fail (a mission, a Studio test): a life each, or the final for exactly those players when nobody
-- would be left.
local function failPlayers(players: { Player }, eventId: string, reason: Reason, kind: LifeService.Kind?)
	local outcomes, everyone = LifeService.fail(players, eventId, kind or "objective")
	if everyone then
		toFinal = true
	end
	announce(outcomes, reason, everyone)
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

-- ...and fixed: the rescues still waiting have ended first (they may change who is left).
local function mainSettled(): boolean
	return mainDecided() and RescueService.pending() == 0
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
		show = function(text: string)
			Match.setMessage(text)
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
		presenterPick = function(options, seconds)
			local function over(): boolean
				return Match.roundId ~= myRound or settled()
			end
			local picked = PresenterService.ask("judge", options, seconds, over)
			return picked
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

-- Main game: free talk and missions until the time is up, the final is due or the round is decided. A mission
-- that would not fit in the time left is not started; one running when the time is up is played to its end. A
-- mission starts only when nobody is in the air (else another free talk first).
local function playMain(myRound: number)
	-- Players who left during the assignment do not count as having started (§2: "4명 이상으로 시작한 판").
	Timeline.begin(#Match.aliveList())
	Match.setPhase("Play", Config.ROUND_SECONDS, Config.TEXT.FREE_TALK)
	local function over(): boolean
		return Match.roundId ~= myRound or mainSettled()
			or (Timeline.finalDue(#Match.aliveList()) and RescueService.pending() == 0) -- (the final waits for rescues too)
	end
	local function talk(untilAt: number)
		freeTalk = true
		while os.clock() < untilAt and not over() do
			task.wait(0.2)
		end
		freeTalk = false
	end
	while true do
		-- Free talk; in its last PRESENTER_PICK_SECONDS the presenter picks the next mission (docs/DESIGN_V3.md §2).
		local talkUntil = os.clock() + Config.FREE_TALK_SECONDS
		talk(talkUntil - Config.PRESENTER_PICK_SECONDS)
		local picked: string? = nil
		if Match.presenter and not over() then
			local options = MissionRunner.options(Timeline.left() - Config.PRESENTER_PICK_SECONDS, #Match.aliveList())
			if #options > 0 then
				freeTalk = true
				local missed
				picked, missed = PresenterService.ask("pick", options, Config.PRESENTER_PICK_SECONDS, over)
				freeTalk = false
				if missed then
					Net.notice(Config.TEXT.PICK_AUTO)
				end
			end
		end
		talk(talkUntil)
		local landed = waitFlights()
		if over() then
			return
		end
		local mission = if landed then MissionRunner.choose(Timeline.left(), #Match.aliveList(), Match.presenter ~= nil, picked) else nil
		if landed and not mission then
			talk(math.huge) -- nothing fits any more: free talk to the end
			return
		end
		if mission then
			runs += 1
			local run = runs
			MissionRunner.run(mission, missionCtx(myRound, false, function(players, key, subjective)
				failPlayers(players, "m" .. run .. ":" .. key, "fail", if subjective then "subjective" else "objective")
			end, mainSettled))
			waitFlights()
			if over() then
				return
			end
			Match.setMessage(Config.TEXT.FREE_TALK)
		end
	end
end

-- Final: sudden-death questions for the survivors until one is left or FINAL_MAX_SECONDS have passed (a question
-- begun before that is played to its end); a question everyone gets wrong puts nobody out. A question that breaks
-- ends the final (the survivors share the win).
-- The final's ear judgments go into the bucket of the question they were pressed in (`finalHits`, a fresh table per
-- question; nil when no question is coming). A closed bucket takes no late arrivals.
local finalHits: { Player }? = nil
local finalOpen = false -- the final still takes new judgments (closed once no question is coming)
local BUCKET_MARGIN = 0.2 -- seconds of slack after the longest wait (a lever, a rescue)
local BUCKET_POLL = 0.05
local pendingIn: { [{ Player }]: number } = {} -- bucket -> judgments still on their way into it (a lever, a rescue wait)
local closedBuckets: { [{ Player }]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- A final question is over: its bucket is swapped for a new one, then the judgments made during it land (a lever's
-- time for the ear, the rescue wait for chat) before it is closed and judged.
local function closeBucket(): { Player }
	local bucket = finalHits or {}
	finalHits = {}
	local deadline = os.clock() + math.max(Config.LEVER_SECONDS, Config.RESCUE_SECONDS) + BUCKET_MARGIN
	while (pendingIn[bucket] or 0) > 0 and os.clock() < deadline do
		task.wait(BUCKET_POLL)
	end
	closedBuckets[bucket] = true
	pendingIn[bucket] = nil
	return bucket
end

local function playFinal(myRound: number)
	local mission = MissionRunner.finalMission()
	if not mission or #Match.aliveList() < 2 or Match.roundId ~= myRound then
		return
	end
	if toFinal and wordsOn() then
		-- Everyone left fell at once: they play the final with new words (docs/DESIGN_V3.md §2).
		for _, player in Match.aliveList() do
			WordService.replace(player, nil, rng)
		end
		WordService.sendAll()
	end
	finalHits = {}
	finalOpen = true
	Match.setPhase("Final", Config.FINAL_MAX_SECONDS, Config.TEXT.FINAL)
	local deadline = os.clock() + Config.FINAL_MAX_SECONDS
	local function settled(): boolean
		return #Match.aliveList() < 2 -- the others left: the last one wins
	end
	-- One question's wrong answers and banned words go out together; if that would be everyone left, nobody does.
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
		-- Wrong answers and banned words heard during this question are out together (§2 "동시 탈락").
		local ok, played = MissionRunner.run(mission, missionCtx(myRound, true, function(players, _key)
			local hits = finalHits or {}
			for _, player in players do
				if not table.find(hits, player) then
					table.insert(hits, player)
				end
			end
			finalHits = hits
		end, settled))
		if os.clock() >= deadline then
			finalOpen = false -- past the final's time: what came in is judged, nothing new
		end
		local wrong = closeBucket()
		if not ok or not played or Match.roundId ~= myRound then
			if Match.roundId == myRound and judge(wrong) then
				waitFlights()
			end
			break -- (a final that cannot ask anything more: the survivors share the win)
		end
		local anyOut = judge(wrong)
		if os.clock() >= deadline or settled() then
			finalOpen = false -- no question is coming: no new judgments while the last flights land
		end
		if anyOut then
			waitFlights()
		end
		task.wait() -- every question yields at least once, even one that returns at once
	end
	-- The final is over: what was caught but not yet judged (a rescue still waiting) is judged before the result (§2).
	finalOpen = false
	if Match.roundId == myRound then
		if judge(closeBucket()) then
			waitFlights()
		end
	end
	finalHits = nil
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
	RescueService.endRound() -- (before the presenter goes: their rescue banner is cleared)
	PresenterService.endRound()
	ChatGate.setGuard(false)
	openVoices()
	SpectatorService.endRound()
	Match.resetRound()
	toFinal = false
	freeTalk = false
	table.clear(pendingIn)
	finalOpen = false
	-- Chat participants whose voice got ready during the round join by voice from now on.
	for player in Match.chatJoin do
		if Match.ready[player] then
			ChatService.voiceReady(player, false)
		end
	end
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
	toFinal = false
	Scores.resetRound()
	MissionRunner.beginRound()
	local presenter = PresenterService.choose(candidates) -- before the chairs are counted: every volunteer is looked at
	if presenter then
		table.remove(candidates, table.find(candidates, presenter))
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
	LifeService.beginRound()
	if wordsOn() then
		WordService.assign(rng)
	end
	ChatGate.setGuard(wordsOn()) -- chat rules from the assignment to the result (words are seen from now on, §7)
	if Match.presenter then
		PresenterService.place(Match.presenter)
	end
	SpectatorService.beginRound()
	VoiceService.setSilenced(chatIds)
	refreshSpeakers()
	-- With words and a presenter the assignment lasts longer: the presenter may re-draw words (§2 step 4).
	local assignSeconds = if wordsOn() and Match.presenter then Config.ASSIGN_REROLL_SECONDS else Config.ASSIGN_TIME
	Match.setPhase("Assign", assignSeconds, string.format(Config.TEXT.ASSIGN, Config.LIVES))
	WordService.sendAll() -- (after the Assign state: clients clear their words on the Countdown state)
	waitPhase()

	playMain(myRound)
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
	if wordsOn() then
		WordService.sendAll() -- the result shows everyone their own word too
	end
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
	Match.broadcast()
	if wordsOn() then
		WordService.sendAll()
		RescueService.send() -- the new presenter sees the hits waiting
	end
end

local function onSync(player: Player)
	Net.to(player, "RoundState", Match.payload())
	ChatService.sendAccess(player)
	PresenterService.sendMenu(player)
	MissionRunner.sendScreen(player)
	WordService.send(player)
	if player == Match.presenter then
		RescueService.send()
	end
end

-- The presenter heard `target` say their banned word (private servers, docs/DESIGN_V3.md §3-4): the lever, then a
-- launch and a new word at once (no rescue for ear judgments). In the final the hit joins the current question's
-- wrong answers (they go out together).
local earEvents = 0
-- Whether an ear judgment may count now: the main game not yet decided, or a final question still to come; the
-- player alive and on the ground (a result after the outcome is fixed is dropped, §2).
local function earOpen(target: Player): boolean
	if not wordsOn() or not Match.isAlive(target) or SeatService.isFlying(target) then
		return false
	end
	if Match.phase == "Play" then
		-- (Past the main game's time with a rescue still waiting, the final is only waiting for it: no new judgments.)
		local closing = Timeline.finalDue(#Match.aliveList()) and RescueService.pending() > 0
		return not mainDecided() and not closing
	end
	-- The final: while questions go on (two or more left; one left has won).
	return Match.phase == "Final" and finalOpen and finalHits ~= nil and #Match.aliveList() >= 2
end

local function onHeard(target: Player)
	if not earOpen(target) then
		return
	end
	earEvents += 1
	local event = "ear" .. earEvents
	local myRound = Match.roundId
	local pressedIn = Match.phase -- the rule of the stage it was heard in (§4); a stage change meanwhile drops it
	local bucket = if pressedIn == "Final" then finalHits else nil -- (the final question it was heard in)
	if bucket then
		pendingIn[bucket] = (pendingIn[bucket] or 0) + 1
	end
	Net.toAll("Lever", {})
	task.delay(Config.LEVER_SECONDS, function()
		if bucket then
			if pendingIn[bucket] then
				pendingIn[bucket] -= 1
			end
			if closedBuckets[bucket] then
				return -- its question was judged already
			end
		end
		if Match.roundId ~= myRound or Match.phase ~= pressedIn or not earOpen(target) then
			return
		end
		Net.notice(string.format(Config.TEXT.EAR_HIT, target.DisplayName))
		WordService.replace(target, MissionRunner.screenTexts(), rng)
		if bucket then
			if not table.find(bucket, target) then
				table.insert(bucket, target)
			end
			WordService.sendAll()
		else
			failPlayers({ target }, event, "fail")
			WordService.sendAll()
		end
	end)
end

-- A banned word caught in chat (docs/DESIGN_V3.md §7): a "땡" for everyone, then RESCUE_SECONDS for the presenter's
-- rescue. Judging needs a presenter on a private server (§3: without one it stops). The stage is the one the message
-- arrived in (§4); in the final the hit belongs to the question it arrived in.
local function onChat(player: Player, text: string)
	if not Match.presenter or not earOpen(player) then
		return
	end
	local p = Match.participants[player]
	local word = p and p.words[1]
	if not (word and Judge.chatHit(word.text, text, word.aliases)) then
		return
	end
	local stage = Match.phase
	local bucket = if stage == "Final" then finalHits else nil
	if not RescueService.hit(player, word.text, { round = Match.roundId, stage = stage, bucket = bucket }) then
		return -- a hit of theirs is already waiting: merged
	end
	if bucket then
		pendingIn[bucket] = (pendingIn[bucket] or 0) + 1
	end
	Net.toAll("Sound", { index = Config.HIT_SOUND })
	Net.notice(string.format(Config.TEXT.RESCUE_WAIT, player.DisplayName))
end

-- The rescue wait is over: a new word either way; without a rescue, the penalty of the stage it happened in.
local chatEvents = 0
local function onRescueResolved(hit: RescueService.Hit)
	local data = hit.data
	local bucket = data.bucket :: { Player }?
	if bucket and pendingIn[bucket] then
		pendingIn[bucket] -= 1
	end
	local target = hit.player
	if data.round ~= Match.roundId or Match.phase ~= data.stage or not Match.isAlive(target) then
		return
	end
	WordService.replace(target, MissionRunner.screenTexts(), rng)
	if hit.rescued or not Match.presenter then
		-- Rescued, or nobody presents any more (judging stops without a presenter, §3): only the new word.
		if hit.rescued then
			Net.notice(string.format(Config.TEXT.RESCUED, target.DisplayName))
		end
	elseif bucket then
		if not closedBuckets[bucket] and not table.find(bucket, target) then
			table.insert(bucket, target)
		end
	elseif not SeatService.isFlying(target) then
		chatEvents += 1
		failPlayers({ target }, "chat" .. chatEvents, "fail")
	end
	WordService.sendAll()
end

-- The presenter re-draws `target`'s word during the assignment (private servers, one player at a time).
local function onReroll(target: Player)
	if wordsOn() and Match.phase == "Assign" and Match.participants[target] then
		WordService.replace(target, nil, rng)
		WordService.sendAll()
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
	VoiceService.start()
	Scores.start()
	ChatService.start()
	PresenterService.start({
		changed = onPresenterChange,
		busy = SeatService.isFlying,
		heard = onHeard,
		reroll = onReroll,
	})
	RescueService.start(onRescueResolved)
	ChatGate.start(onChat)
	MissionRunner.start()
	LifeService.start(SeatService.isFlying)
	SpectatorService.start(busy)
	SeatService.init(onFlightOver)
	-- "Ready" changes take effect at once; the state broadcast they cause is gathered (at most one per
	-- READY_BROADCAST_DELAY), so a client flipping it fast cannot make the server message everyone each time.
	local readyBroadcastQueued = false
	Net.listen("Ready", function(player, isReady)
		local value = isReady == true
		if (Match.ready[player] == true) ~= value then -- repeats change nothing and send nothing
			Match.ready[player] = value
			if value then
				ChatService.voiceReady(player, lockedIn(player)) -- voice players join by voice
			end
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
	-- Studio only (live servers ignore it): during free talk in the main game (not once it is settled) a seated player
	-- loses a life (F key), or with "out" is out at once, or with "show" is only launched (nothing lost).
	Net.listen("DevFling", function(player, mode)
		if not (RunService:IsStudio() and freeTalk and not mainSettled() and Match.isAlive(player)) then
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
