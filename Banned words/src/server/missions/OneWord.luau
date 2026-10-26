--!strict
-- "Say what you like" (docs/DESIGN_V3.md §5: bundle 4b's "a word to everyone", owner 2026-10-23: topics mostly about
-- yourself, the presenter picks on screen and the podium lever is pulled; bells and the floor since bundle 6b). First
-- the bells of everyone on the ground are open for BELL_ORDER_SECONDS. Then up to ONE_WORD_MAX_PERFORMERS take turns:
-- those who performed least first, among equals who rang first (in the order they rang), then the rest at random.
-- Each gets a topic (ONE_WORD_PREP_SECONDS to read it and swap it once), then has the floor (only they and the presenter
-- are heard, alive players see only their chat) for ONE_WORD_SECONDS (chat participants type for
-- ONE_WORD_CHAT_SECONDS). Then the presenter picks the one to launch (the saddest word) within PRESENTER_JUDGE_SECONDS;
-- with no pick everyone votes (VoteRules). Without a presenter it is played only with VOTE_MIN_VOTERS alive (else the
-- vote could not happen). The launch is subjective: in public servers it never takes a last life and hits a player at
-- most SUBJECTIVE_FLINGS times a round, so those players are not offered. Who flew during the performances or skipped
-- their turn is not offered (§4).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local VoteRules = require(shared:WaitForChild("VoteRules"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local OneWordTopics = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("OneWordTopics"))

-- MissionRunner.MissionCtx (missions cannot require services, so the shape is repeated here).
type Option = { id: string, title: string, recommended: boolean }
type Ctx = {
	final: boolean,
	players: () -> { Player },
	rng: Random,
	fail: (players: { Player }, key: string, subjective: boolean?) -> (),
	show: (text: string) -> (),
	cancelled: () -> boolean,
	stopped: () -> boolean,
	wait: (seconds: number) -> boolean,
	reveal: (seconds: number) -> (),
	flying: (player: Player) -> boolean,
	answers: (answered: { Player }, missed: { Player }) -> (),
	screen: (payload: { [string]: any }?) -> (),
	ask: (payload: { [string]: any }, choices: number, seconds: number, from: { Player }) -> { [Player]: number },
	canFling: (player: Player) -> boolean,
	presenterPick: (options: { Option }, seconds: number, kind: string?) -> string?,
	lever: () -> (),
	talk: (stage: string, topic: string?) -> (),
	presenterReroll: (seconds: number) -> boolean,
	bell: (from: { Player }, seconds: number, firstOnly: boolean,
		enough: (({ Player }, { [Player]: number }, { { player: Player, at: number } }) -> boolean)?, repeatEvery: number?)
		-> ({ Player }, { [Player]: number }, { { player: Player, at: number } }),
	screenTo: (player: Player, payload: { [string]: any }?) -> (),
	floor: (player: Player?) -> (),
	presenterVerdict: (answer: string, seconds: number) -> string?,
	score: (player: Player, amount: number) -> (),
	askText: (payload: { [string]: any }, seconds: number, from: { Player }) -> { [Player]: string },
	heads: (words: { [Player]: string }?, known: { [Player]: boolean }?) -> (),
	chat: (handler: ((Player, string) -> ())?) -> (),
}

local OneWord = {
	id = "oneWord",
	title = Config.TEXT.ONE_WORD_TITLE,
	brief = Config.TEXT.ONE_WORD_BRIEF, -- (the briefing before it)
	-- The time budget counts the longest run: the bells, everyone swaps the topic and types by chat, then a vote and the
	-- result.
	expectedSeconds = Config.BELL_ORDER_SECONDS
		+ Config.ONE_WORD_MAX_PERFORMERS * (2 * Config.ONE_WORD_PREP_SECONDS + Config.ONE_WORD_CHAT_SECONDS)
		+ Config.PRESENTER_JUDGE_SECONDS + Config.VOTE_SECONDS + Config.ONE_WORD_RESULT_SECONDS,
	expectedFor = nil :: ((players: number) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.ONE_WORD_MIN_PLAYERS :: number?,
	maxPlayers = nil :: number?,
	needsPresenter = nil :: boolean?,
}

-- Turns performed this round (the least go first; DESIGN §5 "이번 판에 안 해 본 사람 우선"); weak keys, so players
-- who left drop out.
local performed: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
local performedRound = -1 -- the round `performed` counts

local function ids(list: { Player }): { number }
	local out = {}
	for _, player in list do
		table.insert(out, player.UserId)
	end
	return out
end

-- Up to ONE_WORD_MAX_PERFORMERS alive players on the ground: those who performed least first; among equals who rang
-- the bell first (`rung`, first to last), then the others at random.
local function choosePerformers(ctx: Ctx, rung: { Player }): { Player }
	local pool = {}
	local order: { [Player]: number } = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(pool, player)
			local rank = table.find(rung, player)
			order[player] = if rank then rank else #rung + 1 + ctx.rng:NextNumber()
		end
	end
	table.sort(pool, function(a, b)
		local na, nb = performed[a] or 0, performed[b] or 0
		if na ~= nb then
			return na < nb
		end
		return order[a] < order[b]
	end)
	local list = {}
	for i = 1, math.min(#pool, Config.ONE_WORD_MAX_PERFORMERS) do
		table.insert(list, pool[i])
	end
	return list
end

local heard: { [string]: boolean } = {} -- topics given on this server (review 2026-10-25: they came back soon)

-- A topic not given yet in this run and free of the banned words in play (nil if none is left); one not heard yet on
-- this server first (when every free one was, they may come again).
local function pickTopic(ctx: Ctx, given: { [string]: boolean }): string?
	local words = Match.wordsInPlay()
	local free, fresh = {}, {}
	for _, topic in OneWordTopics do
		local clean = not given[topic]
		for _, word in words do
			clean = clean and string.find(topic, word, 1, true) == nil
		end
		if clean then
			table.insert(free, topic)
			if not heard[topic] then
				table.insert(fresh, topic)
			end
		end
	end
	if #free == 0 then
		return nil
	end
	if #fresh == 0 then
		table.clear(heard) -- (a new cycle for everything; this game's own topics stay out through `given`)
		fresh = free
	end
	local topic = fresh[ctx.rng:NextInteger(1, #fresh)]
	given[topic] = true
	heard[topic] = true
	return topic
end

local function stillIn(ctx: Ctx, player: Player): boolean
	return table.find(ctx.players(), player) ~= nil
end

-- What this run saw: who took their turn, who flew meanwhile (they are not offered as targets).
type Seen = { done: { [Player]: boolean }, flew: { [Player]: boolean } }

local function noteFlights(ctx: Ctx, performers: { Player }, seen: Seen)
	for _, player in performers do
		if ctx.flying(player) then
			seen.flew[player] = true
		end
	end
end

-- Waits `seconds` (false if cancelled), noting flights; ends early when the performer is gone.
local function watchWait(ctx: Ctx, seconds: number, performers: { Player }, performer: Player, seen: Seen): boolean
	local untilAt = os.clock() + seconds
	while os.clock() < untilAt do
		noteFlights(ctx, performers, seen)
		if not stillIn(ctx, performer) then
			return not ctx.cancelled()
		end
		if not ctx.wait(math.min(0.25, untilAt - os.clock())) then
			return false
		end
	end
	noteFlights(ctx, performers, seen)
	return true
end

-- One performer's turn. Returns false if the mission was cancelled.
local function turn(ctx: Ctx, performers: { Player }, index: number, given: { [string]: boolean }, seen: Seen): boolean
	local performer = performers[index]
	if not stillIn(ctx, performer) or ctx.flying(performer) then
		noteFlights(ctx, performers, seen)
		return not ctx.cancelled() -- gone or flying: the turn is skipped
	end
	local topic = pickTopic(ctx, given)
	if not topic then
		return not ctx.cancelled()
	end
	performed[performer] = (performed[performer] or 0) + 1
	seen.done[performer] = true
	local p = Match.participants[performer]
	local chat = p ~= nil and p.chat
	local function screen(phase: string, swapped: boolean, endsAt: number?)
		ctx.screen({ kind = "oneWord", ids = ids(performers), current = index, topic = topic, phase = phase,
			swapped = swapped, chat = chat, endsAt = endsAt })
	end
	ctx.show(string.format(Config.TEXT.ONE_WORD_TURN, performer.DisplayName, topic))
	-- Reading time; the performer may swap the topic once (their answer 1 = "swap").
	local swap = ctx.ask({ kind = "oneWord", ids = ids(performers), current = index, topic = topic, phase = "prep",
		swapped = false, chat = chat }, 1, Config.ONE_WORD_PREP_SECONDS, { performer })
	if ctx.cancelled() then
		return false
	end
	noteFlights(ctx, performers, seen)
	if swap[performer] then
		topic = pickTopic(ctx, given) or topic
		ctx.show(string.format(Config.TEXT.ONE_WORD_TURN, performer.DisplayName, topic))
		screen("prep", true, Match.now() + Config.ONE_WORD_PREP_SECONDS)
		if not watchWait(ctx, Config.ONE_WORD_PREP_SECONDS, performers, performer, seen) then
			return false
		end
	end
	local seconds = if chat then Config.ONE_WORD_CHAT_SECONDS else Config.ONE_WORD_SECONDS
	screen("talk", true, Match.now() + seconds)
	ctx.floor(performer)
	local going = watchWait(ctx, seconds, performers, performer, seen)
	ctx.floor(nil)
	return going
end

-- Who flies: the presenter's pick, else a vote; nil for nobody. `eligible()` gives the targets still allowed now
-- (they are looked at again after each wait: someone may leave or fly meanwhile).
local function judge(ctx: Ctx, eligible: () -> { Player }): (Player?, boolean)
	local targets = eligible()
	if #targets == 0 then
		return nil, false
	end
	ctx.screen({ kind = "oneWordJudge", ids = ids(targets) })
	ctx.show(Config.TEXT.JUDGE_WAIT)
	local options: { Option } = {}
	for _, player in targets do
		table.insert(options, { id = tostring(player.UserId), title = player.DisplayName, recommended = false })
	end
	local picked = ctx.presenterPick(options, Config.PRESENTER_JUDGE_SECONDS)
	if ctx.cancelled() then
		return nil, false
	end
	targets = eligible()
	if picked then
		for _, player in targets do
			if tostring(player.UserId) == picked then
				return player, true
			end
		end
	end
	if #targets == 0 then
		return nil, false
	end
	local voters = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(voters, player)
		end
	end
	if not VoteRules.canVote(#voters) then
		return nil, false
	end
	ctx.show(Config.TEXT.JUDGE_TO_VOTE)
	local answers = ctx.ask({ kind = "vote", ids = ids(targets) }, VoteRules.choices(#targets), Config.VOTE_SECONDS, voters)
	if ctx.cancelled() then
		return nil, false
	end
	-- Voters who left or went out meanwhile no longer count (the voters are the alive participants, §5).
	local stillVoting = {}
	for _, player in voters do
		if stillIn(ctx, player) then
			table.insert(stillVoting, player)
		end
	end
	local index = VoteRules.decide(answers, targets, stillVoting)
	local winner = if index then targets[index] else nil
	if winner and not table.find(eligible(), winner) then
		return nil, false -- the winner left or flew during the vote
	end
	return winner, false
end

-- Without a presenter only when a vote can decide (VOTE_MIN_VOTERS alive).
local function playable(alive: number): boolean
	return Match.presenter ~= nil or VoteRules.canVote(alive)
end

function OneWord.available(final: boolean): boolean
	return not final and #OneWordTopics > 0 and playable(#Match.aliveList())
end

-- Returns false when it could not start (no presenter and too few for a vote, or too few on the ground).
function OneWord.run(ctx: Ctx): boolean?
	if not playable(#ctx.players()) then
		return false
	end
	local ground = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(ground, player)
		end
	end
	if #ground < Config.ONE_WORD_MIN_PLAYERS then
		return false
	end
	if performedRound ~= Match.roundId then
		performedRound = Match.roundId
		table.clear(performed)
	end
	ctx.show(Config.TEXT.ONE_WORD_START)
	ctx.screen({ kind = "oneWordBell", endsAt = Match.now() + Config.BELL_ORDER_SECONDS })
	local rung = ctx.bell(ground, Config.BELL_ORDER_SECONDS, false)
	if ctx.cancelled() then
		return nil
	end
	local performers = choosePerformers(ctx, rung)
	if #performers < Config.ONE_WORD_MIN_PLAYERS then
		return nil -- (people flew or left during the bells: it was started, so it counts)
	end
	local given: { [string]: boolean } = {}
	local seen: Seen = { done = {}, flew = {} }
	-- Flights are noted all through the mission (also while the presenter chooses and during the vote).
	local running = true
	task.spawn(function()
		while running and not ctx.cancelled() do -- (an error in the mission still ends it with the round)
			noteFlights(ctx, performers, seen)
			task.wait(0.25)
		end
	end)
	local function finish(result: boolean?): boolean?
		running = false
		return result
	end
	for index = 1, #performers do
		if not turn(ctx, performers, index, given, seen) then
			return finish(nil)
		end
	end
	if not next(seen.done) then
		return finish(false) -- nobody could take a turn (no topic left)
	end
	local function eligible(): { Player }
		noteFlights(ctx, performers, seen)
		local targets = {}
		for _, player in performers do
			if seen.done[player] and not seen.flew[player] and stillIn(ctx, player) and ctx.canFling(player) then
				table.insert(targets, player)
			end
		end
		return targets
	end
	local target, byPresenter = judge(ctx, eligible)
	if ctx.cancelled() then
		return finish(nil)
	end
	if target and ctx.canFling(target) then
		if byPresenter then
			ctx.lever()
			if not ctx.wait(Config.LEVER_SECONDS) then
				return finish(nil)
			end
		end
		ctx.show(string.format(Config.TEXT.FLUNG, target.DisplayName))
		ctx.fail({ target }, "fling", true)
	else
		ctx.show(Config.TEXT.NOBODY_FLUNG)
	end
	ctx.reveal(Config.ONE_WORD_RESULT_SECONDS)
	return finish(nil)
end

return OneWord
