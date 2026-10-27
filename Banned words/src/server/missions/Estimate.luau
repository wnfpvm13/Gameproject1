--!strict
-- 숫자 근사 퀴즈 (bundle 8c, owner 2026-10-24): one question with a whole-number answer (EstimateBank); the question
-- shows ESTIMATE_INTRO_SECONDS, then everyone types a whole number (1 to ESTIMATE_MAX) within ESTIMATE_SECONDS. The
-- one farthest from the answer flies (ties all; nobody when everyone hit it exactly); whoever typed nothing flies
-- instead (and missed an answer). It needs ESTIMATE_MIN_PLAYERS on the ground, at the start and at the end; only those
-- still here and on the ground at the end count. Only numbers travel and show, never free text. Questions never
-- repeat until the bank runs out, and one containing a banned word in play is skipped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local EstimateBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("EstimateBank"))

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

local Estimate = {
	id = "estimate",
	title = Config.TEXT.ESTIMATE_TITLE,
	brief = Config.TEXT.ESTIMATE_BRIEF, -- (the briefing before it)
	expectedSeconds = Config.ESTIMATE_INTRO_SECONDS + Config.ESTIMATE_SECONDS + Config.MINIGAME_RESULT_SECONDS,
	briefFor = nil :: ((mode: string) -> string)?,
	expectedFor = nil :: ((players: number, mode: string) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.ESTIMATE_MIN_PLAYERS :: number?,
	maxPlayers = nil :: number?,
	needsPresenter = nil :: boolean?,
}

local used: { [EstimateBank.Question]: boolean } = {}

local function pick(rng: Random): EstimateBank.Question?
	local words = Match.wordsInPlay()
	local clean, fresh = {}, {}
	for _, question in EstimateBank do
		local hit = false
		for _, word in words do
			hit = hit or string.find(question.q, word, 1, true) ~= nil
		end
		if not hit then
			table.insert(clean, question)
			if not used[question] then
				table.insert(fresh, question)
			end
		end
	end
	if #fresh == 0 then
		for _, question in clean do
			used[question] = nil
		end
		fresh = clean
	end
	if #fresh == 0 then
		return nil
	end
	local question = fresh[rng:NextInteger(1, #fresh)]
	used[question] = true
	return question
end

function Estimate.available(final: boolean): boolean
	return not final and #EstimateBank > 0
end

-- Who flies from the guesses (nil = none): who typed nothing, else the farthest from `answer` (ties all; nobody when
-- every guess is exact). Pure, for the tests.
function Estimate.losers(players: { Player }, guesses: { [Player]: number }, answer: number): { Player }
	local none = {}
	for _, player in players do
		if guesses[player] == nil then
			table.insert(none, player)
		end
	end
	if #none > 0 then
		return none
	end
	local worst = -1
	for _, player in players do
		worst = math.max(worst, math.abs(guesses[player] - answer))
	end
	local out = {}
	if worst <= 0 then
		return out
	end
	for _, player in players do
		if math.abs(guesses[player] - answer) == worst then
			table.insert(out, player)
		end
	end
	return out
end

-- Returns false when no clean question is left or too few were on the ground.
function Estimate.run(ctx: Ctx): boolean?
	local question = pick(ctx.rng)
	if not question then
		return false
	end
	local asked = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(asked, player)
		end
	end
	if #asked < Config.ESTIMATE_MIN_PLAYERS then
		return false
	end
	ctx.show(Config.TEXT.ESTIMATE_START)
	local shown = { kind = "estimate", question = question.q }
	ctx.screen(shown)
	if not ctx.wait(Config.ESTIMATE_INTRO_SECONDS) then
		return nil
	end
	local answers = ctx.ask(shown, Config.ESTIMATE_MAX, Config.ESTIMATE_SECONDS, asked)
	if ctx.cancelled() then
		return nil
	end
	-- (still here, alive and on the ground: a player launched meanwhile is neither judged nor shown)
	local present, guesses, typed, none = {}, {}, {}, {}
	for _, player in asked do
		if table.find(ctx.players(), player) and not ctx.flying(player) then
			table.insert(present, player)
			guesses[player] = answers[player]
			table.insert(if answers[player] then typed else none, player)
		end
	end
	if #present < Config.ESTIMATE_MIN_PLAYERS then
		ctx.screen(nil)
		ctx.show(Config.TEXT.MINIGAME_TOO_FEW)
		return nil
	end
	local losers = Estimate.losers(present, guesses, question.answer)
	local ids, shownGuesses, loserIds, names = {}, {}, {}, {}
	for _, player in present do
		table.insert(ids, player.UserId)
		table.insert(shownGuesses, answers[player] or -1)
	end
	for _, player in losers do
		table.insert(loserIds, player.UserId)
		table.insert(names, player.DisplayName)
	end
	ctx.screen({ kind = "estimateResult", question = question.q, answer = question.answer, ids = ids,
		guesses = shownGuesses, losers = loserIds })
	ctx.show(if #losers > 0 then string.format(Config.TEXT.ESTIMATE_RESULT, question.answer, table.concat(names, ", "))
		else string.format(Config.TEXT.ESTIMATE_NOBODY, question.answer))
	ctx.answers(typed, none) -- (before the fail: a launched player's miss would not count)
	ctx.fail(losers, "estimate")
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return Estimate
