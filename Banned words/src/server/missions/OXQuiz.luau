--!strict
-- O/X 퀴즈 (bundle 8c, owner 2026-10-24): OX_QUESTIONS statements in a row, each shown OX_INTRO_SECONDS before the
-- O / X buttons work for OX_SECONDS (on the quiz's own screen). After the last one, whoever got the most wrong flies
-- (a statement not answered counts as wrong; ties all; nobody when everyone got every one right). A statement asked
-- while someone was launched or gone does not count for them, and only those still here and on the ground at the end
-- are judged and shown. Who answered none missed an answer (the AFK rule). Statements never repeat until every clean
-- one was asked, and one containing a banned word in play is skipped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local OXBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("OXBank"))

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
}

local OXQuiz = {
	id = "oxQuiz",
	title = Config.TEXT.OX_TITLE,
	brief = string.format(Config.TEXT.OX_BRIEF, Config.OX_QUESTIONS), -- (the briefing before it)
	expectedSeconds = Config.OX_QUESTIONS * (Config.OX_INTRO_SECONDS + Config.OX_SECONDS + Config.OX_REVEAL_SECONDS)
		+ Config.MINIGAME_RESULT_SECONDS,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = nil :: number?,
	needsPresenter = nil :: boolean?,
}

local used: { [OXBank.Statement]: boolean } = {}

-- `count` different statements free of the words in play: the ones not asked yet first; once those run out, the asked
-- ones come back for the rest. Fewer if the bank has fewer clean ones. Exposed for the tests.
function OXQuiz.draw(count: number, rng: Random): { OXBank.Statement }
	local words = Match.wordsInPlay()
	local clean, fresh = {}, {}
	for _, statement in OXBank do
		local hit = false
		for _, word in words do
			hit = hit or string.find(statement.s, word, 1, true) ~= nil
		end
		if not hit then
			table.insert(clean, statement)
			if not used[statement] then
				table.insert(fresh, statement)
			end
		end
	end
	local out: { OXBank.Statement } = {}
	local function take(from: { OXBank.Statement })
		while #out < count and #from > 0 do
			local statement = table.remove(from, rng:NextInteger(1, #from)) :: OXBank.Statement
			used[statement] = true
			table.insert(out, statement)
		end
	end
	take(fresh)
	if #out < count then -- (every clean one was asked: they come back, except the ones just taken)
		local again = {}
		for _, statement in clean do
			if not table.find(out, statement) then
				used[statement] = nil
				table.insert(again, statement)
			end
		end
		take(again)
	end
	return out
end

function OXQuiz.available(final: boolean): boolean
	return not final and #OXBank > 0
end

-- Who flies from the wrong counts: the most wrong (ties all), nobody when nobody got any wrong. Pure, for the tests.
function OXQuiz.losers(players: { Player }, wrong: { [Player]: number }): { Player }
	local most = 0
	for _, player in players do
		most = math.max(most, wrong[player] or 0)
	end
	local out = {}
	if most > 0 then
		for _, player in players do
			if (wrong[player] or 0) == most then
				table.insert(out, player)
			end
		end
	end
	return out
end

-- Returns false when nothing could be asked (no clean statement).
function OXQuiz.run(ctx: Ctx): boolean?
	local statements = OXQuiz.draw(Config.OX_QUESTIONS, ctx.rng)
	if #statements == 0 then
		return false
	end
	local players = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(players, player)
		end
	end
	-- (still here, alive and on the ground)
	local function present(): { Player }
		local list = {}
		for _, player in players do
			if table.find(ctx.players(), player) and not ctx.flying(player) then
				table.insert(list, player)
			end
		end
		return list
	end
	local wrong: { [Player]: number } = {}
	local touched: { [Player]: boolean } = {}
	local asked: { [Player]: boolean } = {}
	local choices = { Config.TEXT.OX_O, Config.TEXT.OX_X }
	ctx.show(Config.TEXT.OX_START)
	for i, statement in statements do
		local question = string.format(Config.TEXT.OX_QUESTION, i, #statements, statement.s)
		local shown = { kind = "quiz", final = false, question = question, choices = choices }
		ctx.screen(shown)
		if not ctx.wait(Config.OX_INTRO_SECONDS) then
			return nil
		end
		local from = present()
		local answers = ctx.ask(shown, #choices, Config.OX_SECONDS, from)
		if ctx.cancelled() then
			return nil
		end
		local right = if statement.o then 1 else 2
		local still = present()
		for _, player in from do
			if not table.find(still, player) then
				continue -- (launched or gone meanwhile: this one does not count for them)
			end
			asked[player] = true
			local choice = answers[player]
			if choice then
				touched[player] = true
			end
			if choice ~= right then
				wrong[player] = (wrong[player] or 0) + 1
			end
		end
		ctx.screen({ kind = "quizResult", final = false, question = question, choices = choices, answer = right })
		if not ctx.wait(Config.OX_REVEAL_SECONDS) then
			return nil
		end
	end
	local judged, pressed, never = {}, {}, {}
	for _, player in present() do
		if asked[player] then
			table.insert(judged, player)
			table.insert(if touched[player] then pressed else never, player)
		end
	end
	local losers = OXQuiz.losers(judged, wrong)
	local ids, counts, loserIds = {}, {}, {}
	for _, player in judged do
		table.insert(ids, player.UserId)
		table.insert(counts, wrong[player] or 0)
	end
	for _, player in losers do
		table.insert(loserIds, player.UserId)
	end
	ctx.screen({ kind = "oxResult", ids = ids, wrong = counts, losers = loserIds, total = #statements })
	local names = {}
	for _, player in losers do
		table.insert(names, player.DisplayName)
	end
	ctx.show(if #losers > 0 then string.format(Config.TEXT.OX_RESULT, table.concat(names, ", ")) else Config.TEXT.OX_ALL_RIGHT)
	ctx.answers(pressed, never) -- (before the fail: a launched player's miss would not count)
	ctx.fail(losers, "ox")
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return OXQuiz
