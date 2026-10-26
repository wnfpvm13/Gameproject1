--!strict
-- The liar game (docs/DESIGN_V3.md §5.2; bundle 6d, owner 2026-10-23: the objective rule). One player on the ground is
-- the liar: everyone else on the ground and the presenter see the word, the liar (and anyone not playing) sees only
-- its category — the word is sent to each player who may see it on their own screen, so it never reaches the liar's
-- client. LIAR_READ_SECONDS to read; the bells open LIAR_BELL_SECONDS for the order (who rang first goes first, the
-- rest after in a drawn order); each on the ground gives one clue on the floor (LIAR_CLUE_SECONDS, chat participants
-- LIAR_CLUE_CHAT_SECONDS). Then the presenter names someone within PRESENTER_JUDGE_SECONDS ("accuse"), else everyone
-- votes (VoteRules; "I don't know" counts as nobody, "could not hear" abstains; a vote needs VOTE_MIN_VOTERS; who does
-- not vote missed an answer). A named liar guesses the word among four of its category within LIAR_GUESS_SECONDS:
-- wrong or none, the liar flies. Otherwise (a right guess, someone else named, nobody named) nobody flies and the liar
-- scores SCORE_LIAR_WIN. The presenter knows the word but not the liar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local VoteRules = require(shared:WaitForChild("VoteRules"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local LiarBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("LiarBank"))

-- MissionRunner.MissionCtx (missions cannot require services, so the shape is repeated here).
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
	presenterPick: (options: { { id: string, title: string, recommended: boolean } }, seconds: number, kind: string?) -> string?,
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

local Liar = {
	id = "liar",
	title = Config.TEXT.LIAR_TITLE,
	brief = Config.TEXT.LIAR_BRIEF, -- (the briefing before it)
	-- The longest run: everyone (MAX_PLAYERS) clues by chat, the presenter misses, a vote, the guess.
	expectedSeconds = Config.LIAR_READ_SECONDS + Config.LIAR_BELL_SECONDS
		+ Config.MAX_PLAYERS * Config.LIAR_CLUE_CHAT_SECONDS + Config.PRESENTER_JUDGE_SECONDS + Config.VOTE_SECONDS
		+ Config.LIAR_GUESS_SECONDS + Config.LEVER_SECONDS + Config.MINIGAME_RESULT_SECONDS,
	expectedFor = nil :: ((players: number) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.LIAR_MIN_PLAYERS :: number?,
	needsPresenter = nil :: boolean?,
}

local function ids(list: { Player }): { number }
	local out = {}
	for _, player in list do
		table.insert(out, player.UserId)
	end
	return out
end

-- `talker` holds the floor for `seconds`, or less once they left, went out or fly (review 2026-10-25: the others stayed
-- muted for the rest of it). False if the mission was cancelled. (Balance.luau has the same small helper.)
local function talkFor(ctx: Ctx, talker: Player, seconds: number): boolean
	local untilAt = os.clock() + seconds
	ctx.floor(talker)
	local going = true
	while going and os.clock() < untilAt do
		going = ctx.wait(math.min(0.25, untilAt - os.clock()))
		if talker.Parent == nil or not table.find(ctx.players(), talker) or ctx.flying(talker) then
			break
		end
	end
	ctx.floor(nil)
	return going
end

local function shuffled(list: { any }, rng: Random): { any }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

function Liar.available(final: boolean): boolean
	return not final and #LiarBank > 0
end

-- Returns false when too few were on the ground to start.
function Liar.run(ctx: Ctx): boolean?
	local players = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(players, player)
		end
	end
	if #players < Config.LIAR_MIN_PLAYERS then
		return false
	end
	local entry = LiarBank[ctx.rng:NextInteger(1, #LiarBank)]
	local word = entry.words[ctx.rng:NextInteger(1, #entry.words)]
	local liar = players[ctx.rng:NextInteger(1, #players)]
	local function stillIn(player: Player): boolean
		return table.find(ctx.players(), player) ~= nil and not ctx.flying(player)
	end
	-- Too few left in the middle (leaves), or the liar gone: the game ends with no penalty (§4).
	local function tooFew(): boolean
		local here = 0
		for _, player in players do
			if table.find(ctx.players(), player) then
				here += 1
			end
		end
		return here < Config.LIAR_MIN_PLAYERS or not table.find(ctx.players(), liar)
	end
	local function endEarly(): nil
		ctx.screen(nil)
		ctx.show(Config.TEXT.MINIGAME_TOO_FEW)
		return nil
	end
	-- Everyone's screen shows the category; the word goes to each player who may see it, the liar gets told.
	local function show(stage: string, extra: { [string]: any }?)
		local base: { [string]: any } = { kind = "liar", stage = stage, category = entry.category }
		local more: { [string]: any } = extra or {}
		for key, value in more do
			base[key] = value
		end
		ctx.screen(base)
		for _, player in Players:GetPlayers() do
			local sees = player == Match.presenter or (table.find(players, player) ~= nil and player ~= liar)
			if sees or player == liar then
				local own = table.clone(base)
				if player == liar then
					own.liar = true
				else
					own.word = word
				end
				ctx.screenTo(player, own)
			end
		end
	end
	ctx.show(Config.TEXT.LIAR_START)
	show("read", { endsAt = Match.now() + Config.LIAR_READ_SECONDS })
	if not ctx.wait(Config.LIAR_READ_SECONDS) then
		return nil
	end
	if tooFew() then
		return endEarly()
	end
	show("bell", { endsAt = Match.now() + Config.LIAR_BELL_SECONDS })
	local rung = ctx.bell(players, Config.LIAR_BELL_SECONDS, false, function(rungNow: { Player }): boolean
		return #rungNow >= #players -- (everyone rang: on to the clues)
	end)
	if ctx.cancelled() then
		return nil
	end
	if tooFew() then
		return endEarly()
	end
	local order = table.clone(rung)
	for _, player in shuffled(players, ctx.rng) do
		if not table.find(order, player) then
			table.insert(order, player)
		end
	end
	for _, player in order do
		if ctx.cancelled() then
			return nil
		end
		if tooFew() then
			return endEarly()
		end
		if stillIn(player) then
			local p = Match.participants[player]
			local seconds = if p and p.chat then Config.LIAR_CLUE_CHAT_SECONDS else Config.LIAR_CLUE_SECONDS
			show("clue", { ids = { player.UserId }, endsAt = Match.now() + seconds })
			ctx.show(string.format(Config.TEXT.LIAR_CLUE, player.DisplayName))
			talkFor(ctx, player, seconds)
		end
	end
	if ctx.cancelled() then
		return nil
	end
	if tooFew() then
		return endEarly()
	end
	-- Who is the liar: the presenter, else a vote.
	local candidates = {}
	for _, player in players do
		if stillIn(player) then
			table.insert(candidates, player)
		end
	end
	show("accuse", { ids = ids(candidates) })
	ctx.show(Config.TEXT.LIAR_ACCUSE)
	local options = {}
	for _, player in candidates do
		table.insert(options, { id = tostring(player.UserId), title = player.DisplayName, recommended = false })
	end
	local picked = ctx.presenterPick(options, Config.PRESENTER_JUDGE_SECONDS, "accuse")
	if ctx.cancelled() then
		return nil
	end
	if tooFew() then
		return endEarly()
	end
	local named: Player? = nil
	for _, player in candidates do
		if tostring(player.UserId) == picked then
			named = player
		end
	end
	if not named then
		local voters = {}
		for _, player in candidates do
			if stillIn(player) then
				table.insert(voters, player)
			end
		end
		if VoteRules.canVote(#voters) then
			local votes = ctx.ask({ kind = "vote", prompt = "liar", ids = ids(candidates) }, VoteRules.choices(#candidates),
				Config.VOTE_SECONDS, voters)
			if ctx.cancelled() then
				return nil
			end
			if tooFew() then
				return endEarly()
			end
			local voted, silent, stillVoting = {}, {}, {}
			for _, player in voters do
				if table.find(ctx.players(), player) then
					table.insert(stillVoting, player) -- (voters who left or went out meanwhile no longer count)
					table.insert(if votes[player] then voted else silent, player)
				end
			end
			ctx.answers(voted, silent)
			local index = VoteRules.decide(votes, candidates, stillVoting)
			named = if index then candidates[index] else nil
		end
	end
	local caught = false
	if named == liar and table.find(ctx.players(), liar) then
		local choices = { word }
		for _, other in shuffled(entry.words, ctx.rng) do
			if #choices < Config.LIAR_GUESS_CHOICES and other ~= word then
				table.insert(choices, other)
			end
		end
		choices = shuffled(choices, ctx.rng)
		ctx.show(Config.TEXT.LIAR_GUESS)
		local guess = ctx.ask({ kind = "liarGuess", category = entry.category, ids = { liar.UserId }, choices = choices },
			#choices, Config.LIAR_GUESS_SECONDS, { liar })
		if ctx.cancelled() then
			return nil
		end
		if tooFew() then
			return endEarly()
		end
		caught = choices[guess[liar] or 0] ~= word
	end
	ctx.screen({ kind = "liarResult", category = entry.category, word = word, ids = { liar.UserId }, caught = caught })
	ctx.show(string.format(if caught then Config.TEXT.LIAR_CAUGHT else Config.TEXT.LIAR_ESCAPED, liar.DisplayName, word))
	if caught then
		ctx.lever() -- (§5.2: the lever is pulled only for a liar who guessed wrong)
		if not ctx.wait(Config.LEVER_SECONDS) then
			return nil
		end
		if tooFew() then
			return endEarly() -- (the liar left while the lever came down)
		end
		ctx.fail({ liar }, "liar")
	else
		-- The points first: the fail counts the votes' answers, which may decide the round and cancel the rest.
		ctx.score(liar, Config.SCORE_LIAR_WIN)
		ctx.fail({}, "liar")
	end
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return Liar
