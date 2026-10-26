--!strict
-- 머리 위 스무고개 (bundle 9c, owner 2026-10-25: instead of the banned-word talk). Everyone on the ground gets a
-- different word of one topic (ChosungBank, TWENTY_MIN_LETTERS letters or more, none inside another, not one of
-- TWENTY_SKIP_WORDS) over their head: they see everyone's but their own, and the topic. In a random order each one has
-- TWENTY_TURN_SECONDS to ask the others about their word (voice or chat; the others answer) and may type one answer in
-- the card any time in it (the turn ends with it). A right answer is safe and the owner sees their word from then on.
-- After each round (everyone had the same turns, owner: "각자 물어보는 시간이 끝나면"): once TWENTY_SHARE of those who
-- began (rounded up, at least one) are right, or after TWENTY_TRIES rounds, the result shows (everyone sees their own
-- word) and then everyone still here who is not right flies. Writing someone else's hidden word in chat as a word of
-- its own (TWENTY_PARTICLES may follow) flies the writer at once (also one who is already right), judged as the line
-- arrives (lines arriving together fly together, so one launch deciding the round cannot drop the others), and the
-- writer is told their own word on their own (the card steps aside while they fly); any line holding a word never
-- reaches that word's owner (RoundService's chat rule while words are up). Only
-- right / wrong and the bank's words travel and show, never what a player typed (no free text to filter). A verdict
-- shows on the card only (no toast: in the middle of a small screen a toast covers the words over the heads, Studio
-- check 2026-10-25).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Judge = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Judge"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local ChosungBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("ChosungBank"))
local WordAliases = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("WordAliases"))

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
		enough: (({ Player }, { [Player]: number }, { { player: Player, at: number } }) -> boolean)?, repeatEvery: number?,
		quiet: boolean?)
		-> ({ Player }, { [Player]: number }, { { player: Player, at: number } }),
	screenTo: (player: Player, payload: { [string]: any }?) -> (),
	floor: (player: Player?) -> (),
	presenterVerdict: (answer: string, seconds: number) -> string?,
	score: (player: Player, amount: number) -> (),
	askText: (payload: { [string]: any }, seconds: number, from: { Player }) -> { [Player]: string },
	heads: (words: { [Player]: string }?, known: { [Player]: boolean }?) -> (),
	chat: (handler: ((Player, string) -> ())?) -> (),
}

local Twenty = {
	id = "twenty",
	title = Config.TEXT.TWENTY_TITLE,
	brief = Config.TEXT.TWENTY_BRIEF, -- (the briefing before it)
	-- (the longest run with MAX_PLAYERS: every turn used to the end; expectedFor counts the players there are)
	expectedSeconds = 0,
	expectedFor = nil :: ((players: number) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.TWENTY_MIN_PLAYERS :: number?,
	-- (owner 2026-10-26, the recommended choice: with more alive a game runs long, up to about 7 minutes with ten)
	maxPlayers = Config.TWENTY_MAX_PLAYERS :: number?,
	needsPresenter = nil :: boolean?,
}

-- The longest run with `players` on the ground: the look at the words, every turn to its end with its verdict, the
-- result.
local function longest(players: number): number
	return Config.TWENTY_INTRO_SECONDS + Config.TWENTY_TRIES * players
		* (Config.TWENTY_TURN_SECONDS + Config.TWENTY_VERDICT_SECONDS) + Config.MINIGAME_RESULT_SECONDS
end
Twenty.expectedFor = longest
Twenty.expectedSeconds = longest(Config.TWENTY_MAX_PLAYERS) -- (expectedFor counts the players there are)

function Twenty.available(final: boolean): boolean
	return not final and #ChosungBank > 0
end

-- How many right answers end the game for `players` who began: TWENTY_SHARE rounded up, at least one.
function Twenty.needed(players: number): number
	return math.max(1, math.ceil(players * Config.TWENTY_SHARE - 1e-9))
end

-- `word` and the other ways it is written (content/WordAliases: 돈가스, 돈까스).
function Twenty.forms(word: string): { string }
	local list = { word }
	local more: { string } = WordAliases[word] or {}
	for _, alias in more do
		table.insert(list, alias)
	end
	return list
end

-- Whether `typed` is `word` or one of its other forms: the same letters, whatever spaces or marks are around them
-- (택배기사 = 택배 기사).
function Twenty.isRight(typed: string, word: string): boolean
	local guess = Judge.normalizeChat(typed)
	if guess == "" then
		return false
	end
	for _, form in Twenty.forms(word) do
		if guess == Judge.normalizeChat(form) then
			return true
		end
	end
	return false
end

-- A topic and `count` different words of it (pure, for the tests): words of TWENTY_MIN_LETTERS letters or more, not
-- in TWENTY_SKIP_WORDS, none inside another, spaces aside (연필 / 색연필 never play together), at random. nil when no
-- topic has enough.
function Twenty.draw(rng: Random, count: number): (string?, { string })
	local topics = {}
	for _, entry in ChosungBank do
		table.insert(topics, entry)
	end
	while #topics > 0 do
		local entry = table.remove(topics, rng:NextInteger(1, #topics)) :: typeof(ChosungBank[1])
		local pool = {}
		for _, word in entry.words do
			if (utf8.len(Judge.normalizeChat(word)) or 0) >= Config.TWENTY_MIN_LETTERS
				and not table.find(Config.TWENTY_SKIP_WORDS, word) then
				table.insert(pool, word)
			end
		end
		local picked: { string } = {}
		while #pool > 0 and #picked < count do
			local word = table.remove(pool, rng:NextInteger(1, #pool)) :: string
			local clash = false
			for _, other in picked do
				for _, mine in Twenty.forms(word) do -- (other forms too: 경찰 would sit inside 경찰관)
					for _, theirs in Twenty.forms(other) do
						local a, b = Judge.normalizeChat(mine), Judge.normalizeChat(theirs)
						clash = clash or string.find(a, b, 1, true) ~= nil or string.find(b, a, 1, true) ~= nil
					end
				end
			end
			if not clash then
				table.insert(picked, word)
			end
		end
		if #picked == count then
			return entry.category, picked
		end
	end
	return nil, {}
end

local particles: { [string]: boolean } = {}
for _, ending in Config.TWENTY_PARTICLES do
	particles[ending] = true
end

-- Whether chat line `text` writes `word` as a word of its own: its words in a row (spaces and marks aside) are the
-- word, maybe with a particle or ending after it (사과가, 택배 기사는). Inside a longer word it is not ("나라면" does not
-- write 라면, "배우고" not 배우). Pure, for the tests.
function Twenty.writes(text: string, word: string): boolean
	local parts = Judge.chatWords(word)
	local target = table.concat(parts)
	if target == "" then
		return false
	end
	local words = Judge.chatWords(text)
	for i = 1, #words do
		for span = 1, math.min(#parts, #words - i + 1) do -- (택배 기사 may be written 택배기사)
			local joined = table.concat(words, "", i, i + span - 1)
			if joined == target or (string.sub(joined, 1, #target) == target and particles[string.sub(joined, #target + 1)])
			then
				return true
			end
		end
	end
	return false
end

-- Whether `text` (a chat line of `sender`'s) writes another player's word in `hidden` (the words their owners do not
-- see yet), or one of its other forms. Pure, for the tests.
function Twenty.leaks(text: string, sender: Player, hidden: { [Player]: string }): boolean
	for other, word in hidden do
		if other ~= sender then
			for _, form in Twenty.forms(word) do
				if Twenty.writes(text, form) then
					return true
				end
			end
		end
	end
	return false
end

local function idsOf(list: { Player }): { number }
	local ids = {}
	for _, player in list do
		table.insert(ids, player.UserId)
	end
	return ids
end

-- Returns false when too few are on the ground or no topic has enough words.
function Twenty.run(ctx: Ctx): boolean?
	local order = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(order, player)
		end
	end
	if #order < Config.TWENTY_MIN_PLAYERS then
		return false
	end
	local topic, words = Twenty.draw(ctx.rng, #order)
	if not topic then
		return false
	end
	for i = #order, 2, -1 do -- (who asks first: at random)
		local j = ctx.rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local wordOf: { [Player]: string } = {}
	for i, player in order do
		wordOf[player] = words[i]
	end
	local need = Twenty.needed(#order)
	local right: { [Player]: boolean } = {}
	local leaked: { [Player]: boolean } = {} -- wrote someone else's word: flew, out of this game
	local tried: { [Player]: boolean } = {} -- typed an answer or wrote in chat (not away)
	local known: { [Player]: boolean } = {} -- see their own word: right or leaked
	local ids = idsOf(order)

	local function here(player: Player): boolean
		return table.find(ctx.players(), player) ~= nil
	end
	local function rightCount(): number
		local count = 0
		for _ in right do
			count += 1
		end
		return count
	end
	local function rightIds(): { number }
		local list = {}
		for _, player in order do
			if right[player] then
				table.insert(list, player.UserId)
			end
		end
		return list
	end
	-- Still guessing: here, not right, not out of this game.
	local function guessing(player: Player): boolean
		return here(player) and not right[player] and not leaked[player]
	end
	-- Nobody is guessing any more (all right, gone or out of this game): no more turns.
	local function nobodyGuessing(): boolean
		for _, player in order do
			if guessing(player) then
				return false
			end
		end
		return true
	end
	local function screen(stage: string, round: number, extra: { [string]: any }?): { [string]: any }
		local payload: { [string]: any } = { kind = "twenty", stage = stage, topic = topic, ids = ids, round = round,
			rounds = Config.TWENTY_TRIES, need = need, right = rightIds() }
		local more: { [string]: any } = extra or {}
		for key, value in more do
			payload[key] = value
		end
		return payload
	end

	local ended = false
	-- Writers judged but not launched yet: launched together right after the lines that came in the same moment.
	local pending: { Player } = {}
	local function launchWriters()
		local list = pending
		pending = {}
		local names = {}
		for _, player in list do
			known[player] = true
			table.insert(names, player.DisplayName)
		end
		if not ended then
			ctx.heads(wordOf, known)
		end
		ctx.fail(list, "twenty")
		ctx.show(string.format(Config.TEXT.TWENTY_LEAK, table.concat(names, ", ")))
		-- (last, so it is the toast they see while flying; also when the launch decided the round)
		for _, player in list do
			if player.Parent ~= nil then
				Net.to(player, "Notice", { text = string.format(Config.TEXT.TWENTY_LEAK_MINE, wordOf[player]) })
			end
		end
	end
	ctx.heads(wordOf, known)
	-- A chat line, as it arrives (inside the delivery decision: decide now, never yield). Whose words are still hidden
	-- counts as at that moment; the launch follows right after.
	ctx.chat(function(sender: Player, text: string)
		if not wordOf[sender] or leaked[sender] or ctx.flying(sender) then
			return
		end
		tried[sender] = true
		local hidden = {}
		for other, word in wordOf do
			if here(other) and not known[other] then
				hidden[other] = word
			end
		end
		if Twenty.leaks(text, sender, hidden) then
			leaked[sender] = true
			table.insert(pending, sender)
			if #pending == 1 then
				task.defer(launchWriters)
			end
		end
	end)
	-- (the card says what to do; no toast while everyone reads the words over the heads)
	ctx.screen(screen("intro", 1, { endsAt = Match.now() + Config.TWENTY_INTRO_SECONDS }))
	if not ctx.wait(Config.TWENTY_INTRO_SECONDS) then
		return nil
	end
	for round = 1, Config.TWENTY_TRIES do
		for index, player in order do
			if nobodyGuessing() then
				break
			end
			if guessing(player) and not ctx.flying(player) then
				local typed = ctx.askText(screen("ask", round, { asker = index }), Config.TWENTY_TURN_SECONDS, { player })
				if ctx.cancelled() then
					return nil
				end
				local guess = typed[player]
				if guess then
					tried[player] = true
				end
				if guessing(player) then -- (one who left or wrote a word meanwhile gets no verdict)
					local verdict
					if guess and Twenty.isRight(guess, wordOf[player]) then
						right[player] = true
						known[player] = true
						ctx.heads(wordOf, known)
						verdict = "right"
					else
						verdict = if guess then "wrong" else "none"
					end
					ctx.screen(screen("verdict", round, { asker = index, verdict = verdict,
						word = if verdict == "right" then wordOf[player] else nil }))
					if not ctx.wait(Config.TWENTY_VERDICT_SECONDS) then
						return nil
					end
				end
			end
		end
		-- (checked once everyone had this round's turn)
		if rightCount() >= need or nobodyGuessing() then
			break
		end
	end

	-- The result first (everyone sees their own word, also one who went out writing a word: to whoever is still in the
	-- server), then everyone still here and on the ground who is not right flies (one who wrote a word already flew).
	local function losersNow(): { Player }
		local list = {}
		for _, player in order do
			if here(player) and not right[player] and not leaked[player] and not ctx.flying(player) then
				table.insert(list, player)
			end
		end
		return list
	end
	local losers, names, active, leakers = losersNow(), {}, {}, {}
	for _, player in losers do
		table.insert(names, player.DisplayName)
	end
	for _, player in order do
		if here(player) and (tried[player] or right[player]) then
			table.insert(active, player)
		end
		if leaked[player] then
			table.insert(leakers, player)
		end
	end
	for player in wordOf do
		known[player] = true
	end
	ctx.heads(wordOf, known)
	local result = { kind = "twentyResult", topic = topic, ids = ids, right = rightIds(), losers = idsOf(losers),
		leaked = idsOf(leakers) }
	ctx.screen(result)
	for _, player in order do
		if player.Parent ~= nil then
			local own = table.clone(result)
			own.myWord = wordOf[player]
			ctx.screenTo(player, own)
		end
	end
	ctx.show(if #losers > 0 then string.format(Config.TEXT.TWENTY_RESULT, table.concat(names, ", "))
		else Config.TEXT.TWENTY_NOBODY)
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	ended = true
	-- (asking by voice is playing too, so no one is counted as away here; who typed or chatted is counted as there)
	ctx.answers(active, {})
	local flying = {} -- (those of the shown list still here and on the ground)
	for _, player in losersNow() do
		if table.find(losers, player) then
			table.insert(flying, player)
		end
	end
	ctx.fail(flying, "twenty")
	ctx.chat(nil)
	ctx.heads(nil)
	return nil
end

return Twenty
