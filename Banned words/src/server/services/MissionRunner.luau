--!strict
-- Missions (docs/DESIGN_V3.md §5, §13): lists the missions that may run next (recommended order, also the presenter's
-- menu), picks the next one that fits the time left (the presenter's pick, else at random: missions played less this
-- round are likelier and the one just played is skipped when another fits), shows the screens between games (owner
-- 2026-10-24: the vote among a few of them with what the last game did, the presenter picking, the next game's
-- briefing) and runs one at a time with a
-- ctx (missions cannot require services, so everything they may do comes through the ctx RoundService builds). A
-- mission stops as soon as it is cancelled (the round was decided or is over): its waits wake up and its fails and
-- notices are dropped. Only this service requires the modules under server/missions (tools/tests/check_deps.py
-- checks it). It alone listens to the answer remote ("MissionAnswer") and hands answers to the running mission's
-- question (docs/DESIGN_V3.md §13: Net.listen cannot disconnect, so missions never listen themselves). What a mission
-- shows on everyone's screen goes out as "Mission" and is sent again on Sync.
-- Bundle 4: the quiz (also the final), the roulette, "say what you like" (4b, bells since 6b); bundle 6a: the
-- banned-word talk (only while speech judging is on); bundle 6b: the bell quiz (only with a presenter); bundle 6c:
-- crocodile teeth, the bomb, nunchi; bundle 6d: the balance game, red light, the liar; bundle 8b: 숫자 맞추기, 총잡이
-- 결투, 물병 세우기; bundle 8c: the 초성 quiz (Quiz.chosung), the O/X quiz, the number quiz; bundle 9c: 머리 위
-- 스무고개 instead of the banned-word talk (its code stays, off: Config.TALK_GAME_ON); and the Studio-only test mission.
-- A question may also take a short text instead of a choice (askText: 스무고개's answer).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local missionFolder = script.Parent.Parent:WaitForChild("missions")
local Quiz = require(missionFolder:WaitForChild("Quiz"))
local Roulette = require(missionFolder:WaitForChild("Roulette"))
local OneWord = require(missionFolder:WaitForChild("OneWord"))
local BannedTalk = require(missionFolder:WaitForChild("BannedTalk"))
local Crocodile = require(missionFolder:WaitForChild("Crocodile"))
local BombPass = require(missionFolder:WaitForChild("BombPass"))
local Nunchi = require(missionFolder:WaitForChild("Nunchi"))
local Balance = require(missionFolder:WaitForChild("Balance"))
local RedLight = require(missionFolder:WaitForChild("RedLight"))
local Liar = require(missionFolder:WaitForChild("Liar"))
local TestMission = require(missionFolder:WaitForChild("TestMission"))
local TimeGuess = require(missionFolder:WaitForChild("TimeGuess"))
local Duel = require(missionFolder:WaitForChild("Duel"))
local Bottle = require(missionFolder:WaitForChild("Bottle"))
local OXQuiz = require(missionFolder:WaitForChild("OXQuiz"))
local Estimate = require(missionFolder:WaitForChild("Estimate"))
local Twenty = require(missionFolder:WaitForChild("Twenty"))

local MissionRunner = {}

local POLL = 0.2 -- seconds between "cancelled yet?" checks while a mission waits

-- What RoundService gives for one run.
export type Ctx = {
	final: boolean, -- a final question (sudden death) instead of a main-game mission
	players: () -> { Player }, -- the alive participants now
	rng: Random,
	-- Who failed the mission's event `key` (one penalty per event: the same key never costs a player twice);
	-- RoundService turns that into lives and launches. `subjective`: the presenter or a vote decided (limits apply).
	fail: (players: { Player }, key: string, subjective: boolean?) -> (),
	show: (text: string) -> (), -- the status line and a toast
	cancelled: () -> boolean, -- the round was decided or another one began: stop
	stopped: () -> boolean, -- another round began (or the round broke): not even a result may stay on screen
	flying: (player: Player) -> boolean, -- launched and not back yet (cannot answer, takes no penalty)
	-- An answer mission closed: who answered and who did not (the AFK rule, docs/DESIGN_V3.md §4).
	answers: (answered: { Player }, missed: { Player }) -> (),
	canFling: (player: Player) -> boolean, -- a subjective launch may hit them now (public limits, not flying)
	-- The presenter picks one of `options` within `seconds` (nil: none in time, no presenter, or the round is over);
	-- `kind`: "judge" (who flies, the default) or "accuse" (who is the liar, bundle 6d).
	presenterPick: (options: { Option }, seconds: number, kind: string?) -> string?,
	-- The banned-word talk's stage (docs/DESIGN_V3.md §6): "prep" (words drawn avoiding `topic`, shown, chat rules on)
	-- or "talk" (judged from now on). RoundService runs the settle stage after the mission, whatever happened.
	talk: (stage: string, topic: string?) -> (),
	-- The presenter's re-draw window: waits `seconds` or until they press "start now"; false if cancelled meanwhile.
	presenterReroll: (seconds: number) -> boolean,
	-- The seat bells of `from` open for `seconds` (bundle 6b): who rang, first to last, and when (`firstOnly`: closes
	-- at the first ring; `enough(rung, times, presses)`: closes when the game knows its outcome, bundle 6c;
	-- `repeatEvery`: every press at least that far apart counts and comes back in `presses`, bundle 6d).
	bell: (from: { Player }, seconds: number, firstOnly: boolean,
		enough: (({ Player }, { [Player]: number }, { { player: Player, at: number } }) -> boolean)?, repeatEvery: number?,
		quiet: boolean?)
		-> ({ Player }, { [Player]: number }, { { player: Player, at: number } }),
	-- The floor (§5.1): only `player` (and the presenter) heard by everyone, alive players receive only their chat;
	-- nil ends it. RoundService ends it after every mission too.
	floor: (player: Player?) -> (),
	-- The presenter judges an answer (the bell quiz): "right", "wrong", or nil (none in time, no presenter, over).
	presenterVerdict: (answer: string, seconds: number) -> string?,
	score: (player: Player, amount: number) -> (), -- session points (a right bell-quiz answer)
	-- 머리 위 스무고개 (bundle 9c): the words over the players' heads (`words`; nil: they go). An owner sees their own
	-- word only once they are in `known`. While words are up, chat is guarded and a line holding a word never reaches
	-- that word's owner. RoundService takes them down after every mission too.
	heads: (words: { [Player]: string }?, known: { [Player]: boolean }?) -> (),
	-- The alive participants' chat lines while the mission runs and words are up (nil: no more). Called inside the
	-- delivery decision, as the line arrives: the handler decides at once, must not yield, and defers what follows (a
	-- launch).
	chat: (handler: ((Player, string) -> ())?) -> (),
}

-- What a mission gets: the same, with fail/show that do nothing once cancelled, and wait().
export type MissionCtx = {
	final: boolean,
	players: () -> { Player },
	rng: Random,
	fail: (players: { Player }, key: string, subjective: boolean?) -> (),
	show: (text: string) -> (),
	cancelled: () -> boolean,
	stopped: () -> boolean,
	-- Waits `seconds`; returns false at once if the mission is cancelled meanwhile (then the mission should return).
	wait: (seconds: number) -> boolean,
	-- Keeps a result already given on screen for `seconds`, also when that result decided the round (only a new round
	-- cuts it short).
	reveal: (seconds: number) -> (),
	flying: (player: Player) -> boolean,
	answers: (answered: { Player }, missed: { Player }) -> (),
	-- Everyone's mission screen (a table with `kind`; nil clears it). Cleared when the mission ends.
	screen: (payload: { [string]: any }?) -> (),
	-- Shows `payload` (with `endsAt` and the question number `id` added) and collects one answer (a choice
	-- 1..`choices`, sent with that number) from each of `from` for `seconds`, or until all of them still alive answered
	-- or the mission is cancelled. Returns the answers.
	ask: (payload: { [string]: any }, choices: number, seconds: number, from: { Player }) -> { [Player]: number },
	canFling: (player: Player) -> boolean,
	presenterPick: (options: { Option }, seconds: number, kind: string?) -> string?,
	lever: () -> (), -- everyone sees the podium lever pulled (the presenter's launch)
	talk: (stage: string, topic: string?) -> (),
	presenterReroll: (seconds: number) -> boolean,
	bell: (from: { Player }, seconds: number, firstOnly: boolean,
		enough: (({ Player }, { [Player]: number }, { { player: Player, at: number } }) -> boolean)?, repeatEvery: number?,
		quiet: boolean?)
		-> ({ Player }, { [Player]: number }, { { player: Player, at: number } }),
	-- One player's own screen instead of everyone's (the liar must not get the word; nil gives them everyone's
	-- again). Cleared by the next screen for everyone and when the mission ends.
	screenTo: (player: Player, payload: { [string]: any }?) -> (),
	floor: (player: Player?) -> (),
	presenterVerdict: (answer: string, seconds: number) -> string?,
	score: (player: Player, amount: number) -> (),
	-- Like ask, but each of `from` sends one short text (at most TWENTY_ANSWER_MAX letters) instead of a choice.
	askText: (payload: { [string]: any }, seconds: number, from: { Player }) -> { [Player]: string },
	heads: (words: { [Player]: string }?, known: { [Player]: boolean }?) -> (),
	chat: (handler: ((Player, string) -> ())?) -> (),
}

export type Mission = {
	id: string,
	title: string, -- shown in the presenter's menu
	brief: string?, -- its one-line rule for the briefing before it (owner 2026-10-24)
	expectedSeconds: number, -- for the time budget, without the launches afterwards
	expectedFor: ((players: number) -> number)?, -- the same for this many alive players, when it depends on them
	maxPerRound: number?, -- nil = no limit (docs/DESIGN_V3.md §5: the quiz; others 2, the roulette 1)
	minPlayers: number?, -- alive participants it needs (nil = any)
	needsPresenter: boolean?, -- offered only while someone presents (the one-word mission)
	available: (final: boolean) -> boolean,
	run: (ctx: MissionCtx) -> boolean?, -- false: it had nothing to play (a quiz with no clean question left)
}

-- An entry of a presenter's menu.
export type Option = { id: string, title: string, recommended: boolean }

local MISSIONS: { Mission } = { Quiz, Quiz.bell, Roulette, OneWord, Twenty, BannedTalk, Crocodile, BombPass, Nunchi,
	Balance, RedLight, Liar, TimeGuess, Duel, Bottle, Quiz.chosung, OXQuiz, Estimate, TestMission }

local played: { [string]: number } = {} -- main-game runs this round, per mission id
local screenNow: { [string]: any }? = nil -- what the running mission shows (sent again on Sync)
local privateScreens: { [Player]: { [string]: any } } = {} -- one player's own screen instead (the liar game)
-- The open question: its number, who may answer, how many choices, until when (server time), the answers so far (a
-- text question: the texts instead).
type Question = { id: number, from: { [Player]: boolean }, choices: number, endsAt: number, answers: { [Player]: number },
	changeable: boolean, text: boolean, texts: { [Player]: string } }
local question: Question? = nil
local questions = 0 -- question numbers so far (an answer sent for an older question never counts for a newer one)

local function fits(mission: Mission, secondsLeft: number, alive: number): boolean
	local byPlayers = mission.expectedFor
	local expected = if byPlayers then byPlayers(alive) else mission.expectedSeconds
	return expected + Config.FLING_RETURN_SECONDS <= secondsLeft
end

-- A new round: nothing played yet.
function MissionRunner.beginRound()
	table.clear(played)
end

-- The main-game missions that may run now, in recommended order (not played yet this round first): available, under
-- their per-round limit, enough players for them, a presenter if they need one, and fitting `secondsLeft` with the
-- launches.
function MissionRunner.candidates(secondsLeft: number, alive: number, presenter: boolean): { Mission }
	local list = {}
	for _, mission in MISSIONS do
		local count = played[mission.id] or 0
		if mission.available(false) and fits(mission, secondsLeft, alive) and (mission.maxPerRound == nil or count < mission.maxPerRound)
			and alive >= (mission.minPlayers or 0) and (presenter or not mission.needsPresenter) then
			table.insert(list, mission)
		end
	end
	local position: { [Mission]: number } = {}
	for i, mission in list do
		position[mission] = i
	end
	table.sort(list, function(a, b)
		local pa, pb = played[a.id] or 0, played[b.id] or 0
		if pa ~= pb then
			return pa < pb
		end
		return position[a] < position[b]
	end)
	return list
end

-- The presenter's menu for the same choice.
function MissionRunner.options(secondsLeft: number, alive: number): { Option }
	local options = {}
	for i, mission in MissionRunner.candidates(secondsLeft, alive, true) do
		table.insert(options, { id = mission.id, title = mission.title, recommended = i <= Config.PRESENTER_RECOMMENDED })
	end
	return options
end

-- Drops `lastId` (the game just played) from `list` while another one is left.
local function withoutLast(list: { Mission }, lastId: string?)
	if #list > 1 and lastId then
		for i, mission in list do
			if mission.id == lastId then
				table.remove(list, i)
				return
			end
		end
	end
end

-- The index of one of `list` (not empty) at random: weight 1 / (1 + runs this round).
local function drawIndex(list: { Mission }, rng: Random): number
	local total = 0
	for _, mission in list do
		total += 1 / (1 + (played[mission.id] or 0))
	end
	local roll = rng:NextNumber() * total
	for i, mission in list do
		roll -= 1 / (1 + (played[mission.id] or 0))
		if roll <= 0 then
			return i
		end
	end
	return #list
end

-- The next main-game mission: `pickedId` if it may still run, else one at random (docs/DESIGN_V3.md §5.1): weight
-- 1 / (1 + runs this round), and not `lastId` (the one just played) while another one fits. nil if none fits.
-- `presenter`: someone presents now.
function MissionRunner.choose(secondsLeft: number, alive: number, presenter: boolean, pickedId: string?, rng: Random,
	lastId: string?): Mission?
	local list = MissionRunner.candidates(secondsLeft, alive, presenter)
	for _, mission in list do
		if mission.id == pickedId then
			return mission
		end
	end
	withoutLast(list, lastId)
	if #list == 0 then
		return nil
	end
	return list[drawIndex(list, rng)]
end

-- Between games without a presenter (owner 2026-10-24): up to NEXT_VOTE_CHOICES missions for the vote, drawn like
-- choose() draws one (weight 1 / (1 + runs this round), not `lastId` while another one fits), all different.
function MissionRunner.ballot(secondsLeft: number, alive: number, rng: Random, lastId: string?): { Mission }
	local list = MissionRunner.candidates(secondsLeft, alive, false)
	withoutLast(list, lastId)
	local ballot: { Mission } = {}
	while #list > 0 and #ballot < Config.NEXT_VOTE_CHOICES do
		table.insert(ballot, table.remove(list, drawIndex(list, rng)) :: Mission)
	end
	return ballot
end

-- A mission that can ask final questions, or nil (then the survivors share the win).
function MissionRunner.finalMission(): Mission?
	for _, mission in MISSIONS do
		if mission.available(true) then
			return mission
		end
	end
	return nil
end

local function setScreen(payload: { [string]: any }?)
	screenNow = payload
	table.clear(privateScreens) -- (a new screen for everyone replaces the private ones)
	Net.toAll("Mission", payload or { kind = "none" })
end

local function waitOrCancel(ctx: Ctx, seconds: number, done: (() -> boolean)?, stop: (() -> boolean)?): boolean
	local untilAt = os.clock() + seconds
	local stopNow = stop or ctx.cancelled
	while os.clock() < untilAt do
		if stopNow() then
			return false
		end
		if done and done() then
			return true
		end
		task.wait(math.min(POLL, untilAt - os.clock()))
	end
	return not stopNow()
end

-- Shows `payload` (with `endsAt` and the question number `id` added) and collects one answer from each of `from` for
-- `seconds`, or until all of them still alive and on the ground answered, or until the mission is cancelled: a choice
-- 1..`choices`, or with `text` a short text (MissionRunner.start checks what comes in).
local function openQuestion(ctx: Ctx, payload: { [string]: any }, choices: number, seconds: number, from: { Player },
	text: boolean): Question
	questions += 1
	-- (`payload.changeable`: an answer may be changed until the time is up, so it never ends early)
	local open: Question = { id = questions, from = {}, choices = choices, endsAt = Match.now() + seconds, answers = {},
		changeable = payload.changeable == true, text = text, texts = {} }
	for _, player in from do
		open.from[player] = true
	end
	question = open
	local shown = table.clone(payload)
	-- (`shownEndsAt`: what the clients see instead of the real end, kept on the server — the bomb's bang)
	shown.endsAt = payload.shownEndsAt or open.endsAt
	shown.shownEndsAt = nil
	shown.id = open.id
	if not ctx.cancelled() then
		setScreen(shown)
	end
	waitOrCancel(ctx, seconds, function()
		if open.changeable then
			return false
		end
		local alive = ctx.players()
		for player in open.from do
			local answered = open.answers[player] ~= nil or open.texts[player] ~= nil
			if not answered and table.find(alive, player) and not ctx.flying(player) then
				return false -- (someone who left, went out or flies meanwhile is not waited for)
			end
		end
		return true
	end)
	if question == open then
		question = nil
	end
	return open
end

local function missionCtx(ctx: Ctx): MissionCtx
	return {
		final = ctx.final,
		players = ctx.players,
		rng = ctx.rng,
		cancelled = ctx.cancelled,
		stopped = ctx.stopped,
		flying = ctx.flying,
		answers = function(answered: { Player }, missed: { Player })
			if not ctx.cancelled() then
				ctx.answers(answered, missed)
			end
		end,
		screen = function(payload: { [string]: any }?)
			if not ctx.cancelled() then
				setScreen(payload)
			end
		end,
		ask = function(payload: { [string]: any }, choices: number, seconds: number, from: { Player }): { [Player]: number }
			return openQuestion(ctx, payload, choices, seconds, from, false).answers
		end,
		askText = function(payload: { [string]: any }, seconds: number, from: { Player }): { [Player]: string }
			return openQuestion(ctx, payload, 0, seconds, from, true).texts
		end,
		heads = function(words: { [Player]: string }?, known: { [Player]: boolean }?)
			if words == nil or not ctx.cancelled() then -- (taking them down always works)
				ctx.heads(words, known)
			end
		end,
		chat = function(handler: ((Player, string) -> ())?)
			if handler then
				ctx.chat(function(player: Player, text: string)
					if not ctx.cancelled() then
						handler(player, text)
					end
				end)
			else
				ctx.chat(nil)
			end
		end,
		fail = function(players: { Player }, key: string, subjective: boolean?)
			if not ctx.cancelled() then
				ctx.fail(players, key, subjective)
			end
		end,
		canFling = ctx.canFling,
		presenterPick = function(options: { Option }, seconds: number, kind: string?): string?
			if ctx.cancelled() then
				return nil
			end
			return ctx.presenterPick(options, seconds, kind)
		end,
		lever = function()
			if not ctx.cancelled() then
				Net.toAll("Lever", {})
			end
		end,
		talk = function(stage: string, topic: string?)
			if not ctx.cancelled() then
				ctx.talk(stage, topic)
			end
		end,
		presenterReroll = function(seconds: number): boolean
			if ctx.cancelled() then
				return false
			end
			return ctx.presenterReroll(seconds)
		end,
		bell = function(from: { Player }, seconds: number, firstOnly: boolean,
			enough: (({ Player }, { [Player]: number }, { { player: Player, at: number } }) -> boolean)?,
			repeatEvery: number?, quiet: boolean?): ({ Player }, { [Player]: number }, { { player: Player, at: number } })
			if ctx.cancelled() then
				return {}, {}, {}
			end
			return ctx.bell(from, seconds, firstOnly, enough, repeatEvery, quiet)
		end,
		screenTo = function(player: Player, payload: { [string]: any }?)
			if not ctx.cancelled() then
				if payload then
					privateScreens[player] = payload
				else
					privateScreens[player] = nil
				end
				Net.to(player, "Mission", payload or screenNow or { kind = "none" })
			end
		end,
		floor = ctx.floor, -- (also after a cancel: the floor must always be given back)
		presenterVerdict = function(answer: string, seconds: number): string?
			if ctx.cancelled() then
				return nil
			end
			return ctx.presenterVerdict(answer, seconds)
		end,
		score = function(player: Player, amount: number)
			if not ctx.cancelled() then
				ctx.score(player, amount)
			end
		end,
		show = function(text: string)
			if not ctx.cancelled() then
				ctx.show(text)
			end
		end,
		wait = function(seconds: number): boolean
			return waitOrCancel(ctx, seconds, nil)
		end,
		reveal = function(seconds: number)
			waitOrCancel(ctx, seconds, nil, ctx.stopped)
		end,
	}
end

-- Runs one mission to its end. Returns false if it raised an error (reported; that run is over), and whether it
-- played (false when it had nothing to play).
function MissionRunner.run(mission: Mission, ctx: Ctx): (boolean, boolean)
	if not ctx.final then
		played[mission.id] = (played[mission.id] or 0) + 1
	end
	local runCtx = missionCtx(ctx)
	local didPlay = true
	local ok, err = pcall(function(): any
		didPlay = mission.run(runCtx) ~= false
		return nil -- one return value, so the type checker reads pcall's results as (ok, error)
	end)
	if not ok then
		warn("[BannedWords] mission " .. mission.id .. " failed:", err)
	end
	question = nil
	if screenNow then
		setScreen(nil)
	end
	table.clear(privateScreens) -- (also when the mission cleared everyone's screen itself)
	return ok, didPlay
end

-- Between games (owner 2026-10-24): `voters` vote for the next game among `ballot` (2+ missions) on a screen that also
-- shows `recap` (what the last game did), for NEXT_VOTE_SECONDS or until every voter still here voted, or until
-- `stop`. The most votes win; a tie or no vote at all: at random among the tied (or all). No penalty for not voting.
-- Also returns the count per mission id (the beta's measurements).
function MissionRunner.vote(ballot: { Mission }, recap: string, voters: { Player }, rng: Random, stop: () -> boolean):
	(Mission, { [string]: number })
	questions += 1
	local open: Question = { id = questions, from = {}, choices = #ballot, endsAt = Match.now() + Config.NEXT_VOTE_SECONDS,
		answers = {}, changeable = false, text = false, texts = {} }
	for _, player in voters do
		open.from[player] = true
	end
	question = open
	local titles = {}
	for _, mission in ballot do
		table.insert(titles, mission.title)
	end
	setScreen({ kind = "nextVote", recap = recap, choices = titles, id = open.id, endsAt = open.endsAt })
	local untilAt = os.clock() + Config.NEXT_VOTE_SECONDS
	while os.clock() < untilAt and not stop() do
		local waiting = false
		for player in open.from do
			if not open.answers[player] and player.Parent then
				waiting = true
				break
			end
		end
		if not waiting then
			break
		end
		task.wait(math.min(POLL, untilAt - os.clock()))
	end
	if question == open then
		question = nil
	end
	local counts: { [number]: number } = {}
	for _, choice in open.answers do
		counts[choice] = (counts[choice] or 0) + 1
	end
	local best, tied = -1, {}
	local byId: { [string]: number } = {}
	for i = 1, #ballot do
		local votes = counts[i] or 0
		byId[ballot[i].id] = votes
		if votes > best then
			best, tied = votes, { i }
		elseif votes == best then
			table.insert(tied, i)
		end
	end
	return ballot[tied[rng:NextInteger(1, #tied)]], byId
end

-- The round's result on everyone's screen: who won and the round awards (owner 2026-10-24).
function MissionRunner.showRoundResult(title: string, lines: { string })
	setScreen({ kind = "roundResult", title = title, lines = lines })
end

-- Clears a between-games screen left over (the main game ended while it showed).
function MissionRunner.clearScreen()
	if screenNow then
		setScreen(nil)
	end
end

-- While the presenter picks the next game: what the last game did, and that they are picking.
function MissionRunner.showPicking(recap: string)
	setScreen({ kind = "nextPick", recap = recap })
end

-- The next game's briefing (owner 2026-10-24): its number, its name and its one-line rule, counting down BRIEF_SECONDS,
-- and `recap` (what the last game did) when no vote or picking screen showed it. False if `stop` came meanwhile. The
-- screen is cleared for the game's own.
function MissionRunner.brief(mission: Mission, game: number, games: number, recap: string, stop: () -> boolean): boolean
	setScreen({ kind = "brief", title = mission.title, rule = mission.brief or "", game = game, games = games,
		recap = recap, endsAt = Match.now() + Config.BRIEF_SECONDS })
	local untilAt = os.clock() + Config.BRIEF_SECONDS
	while os.clock() < untilAt do
		if stop() then
			return false
		end
		task.wait(math.min(POLL, untilAt - os.clock()))
	end
	setScreen(nil)
	return not stop()
end

-- Answers to the open question: its number, a whole number in 1..choices (a text question: a text of one to
-- TWENTY_ANSWER_MAX letters), from someone asked, before the end; the first one counts (the last one for a question
-- whose answers may change).
function MissionRunner.start()
	Net.listen("MissionAnswer", function(player, id, choice)
		local open = question
		if not open or id ~= open.id or not open.from[player] then
			return
		end
		if (open.answers[player] or open.texts[player]) and not open.changeable then
			return
		end
		if Match.now() > open.endsAt then
			return
		end
		if open.text then
			if typeof(choice) ~= "string" or #choice > 4 * Config.TWENTY_ANSWER_MAX then
				return
			end
			local letters = utf8.len(choice) -- (nil: not UTF-8)
			if letters and letters >= 1 and letters <= Config.TWENTY_ANSWER_MAX then
				open.texts[player] = choice
			end
		elseif typeof(choice) == "number" and choice % 1 == 0 and choice >= 1 and choice <= open.choices then
			open.answers[player] = choice
		end
	end)
end

-- The texts on the mission screen now (a question and its choices, a topic): a new banned word must not appear in
-- them (docs/DESIGN_V3.md §6).
function MissionRunner.screenTexts(): { string }
	local texts = {}
	local shown = screenNow
	if shown then
		for _, key in { "question", "topic" } do
			if typeof(shown[key]) == "string" then
				table.insert(texts, shown[key])
			end
		end
		if typeof(shown.choices) == "table" then
			for _, choice in shown.choices do
				table.insert(texts, tostring(choice))
			end
		end
		if typeof(shown.ids) == "table" then -- names on the wheel, the performers, the vote (shown by name)
			for _, userId in shown.ids do
				local player = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
				if player then
					table.insert(texts, player.DisplayName)
				end
			end
		end
	end
	return texts
end

-- A player asked for the whole state again: the mission screen too.
function MissionRunner.sendScreen(player: Player)
	local own = privateScreens[player] or screenNow
	if own then
		Net.to(player, "Mission", own)
	end
end

return MissionRunner
