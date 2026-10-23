--!strict
-- The quiz (docs/DESIGN_V3.md §5; bundle 4a): everyone alive answers one four-choice question at once; the right
-- answer stays on the server until the time is up. A wrong answer or none is a fail. As a final question it uses the
-- harder questions and a wrong answer is out (RoundService decides that). Players flying when the question opens
-- cannot answer and are neither failed nor counted as missing (§4). Questions never repeat until the bank runs out,
-- and a question whose text or any choice contains a banned word in play is skipped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local QuizBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("QuizBank"))

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
	presenterPick: (options: { { id: string, title: string, recommended: boolean } }, seconds: number) -> string?,
	lever: () -> (),
	talk: (stage: string, topic: string?) -> (),
	presenterReroll: (seconds: number) -> boolean,
}

local Quiz = {
	id = "quiz",
	title = Config.TEXT.QUIZ_TITLE,
	expectedSeconds = Config.QUIZ_INTRO_SECONDS + Config.QUIZ_SECONDS + Config.QUIZ_REVEAL_SECONDS,
	maxPerRound = nil :: number?, -- the basic mission: no limit (§5)
	minPlayers = nil :: number?,
	needsPresenter = nil :: boolean?,
}

local used: { [QuizBank.Question]: boolean } = {} -- asked on this server (main and final banks alike)

local function mentions(question: QuizBank.Question, words: { string }): boolean
	for _, word in words do
		if string.find(question.q, word, 1, true) then
			return true
		end
		for _, choice in question.choices do
			if string.find(choice, word, 1, true) then
				return true
			end
		end
	end
	return false
end

-- A question from `bank` not asked yet and free of the words in play; when every clean one was asked, they may come
-- again. nil if none is clean.
local function pick(bank: { QuizBank.Question }, rng: Random): QuizBank.Question?
	local words = Match.wordsInPlay()
	local clean, fresh = {}, {}
	for _, question in bank do
		if not mentions(question, words) then
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

function Quiz.available(final: boolean): boolean
	return #(if final then QuizBank.final else QuizBank.main) > 0
end

-- Returns false when no clean question is left (nothing was asked).
function Quiz.run(ctx: Ctx): boolean?
	local question = pick(if ctx.final then QuizBank.final else QuizBank.main, ctx.rng)
	if not question then
		return false
	end
	ctx.show(if ctx.final then Config.TEXT.FINAL_QUIZ else Config.TEXT.QUIZ_START)
	local shown = { kind = "quiz", final = ctx.final, question = question.q, choices = question.choices }
	ctx.screen(shown)
	if not ctx.wait(Config.QUIZ_INTRO_SECONDS) then
		return nil
	end
	local asked = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(asked, player)
		end
	end
	local answers = ctx.ask(shown, #question.choices, Config.QUIZ_SECONDS, asked)
	if ctx.cancelled() then
		return nil
	end
	local answered, missed, wrong = {}, {}, {}
	for _, player in asked do
		local choice = answers[player]
		if choice then
			table.insert(answered, player)
		else
			table.insert(missed, player)
		end
		if choice ~= question.answer then
			table.insert(wrong, player)
		end
	end
	ctx.screen({ kind = "quizResult", final = ctx.final, question = question.q, choices = question.choices, answer = question.answer })
	ctx.show(if #wrong == 0 then Config.TEXT.QUIZ_ALL_RIGHT
		else string.format(Config.TEXT.QUIZ_ANSWER, question.choices[question.answer]))
	if not ctx.final then
		ctx.answers(answered, missed) -- before the fail: a launched player's miss would not count any more
	end
	ctx.fail(wrong, "answer")
	ctx.reveal(Config.QUIZ_REVEAL_SECONDS) -- also when this answer decided the round
	return nil
end

return Quiz
