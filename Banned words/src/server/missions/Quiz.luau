--!strict
-- The quiz (docs/DESIGN_V3.md §5; bundle 4a): everyone alive answers one four-choice question at once; the right
-- answer stays on the server until the time is up. A wrong answer or none is a fail. As a final question it uses the
-- harder questions and a wrong answer is out (RoundService decides that). Players flying when the question opens
-- cannot answer and are neither failed nor counted as missing (§4). Questions never repeat until the bank runs out,
-- and a question whose text or any choice contains a banned word in play is skipped.
-- The bell quiz (`Quiz.bell`, bundle 6b, owner 2026-10-23: the first to ring answers by voice, the presenter judges)
-- lives here too, so both draw from the same bank without repeats. BELL_QUIZ_QUESTIONS questions; for each the bells
-- of everyone on the ground are open BELL_WAIT_SECONDS; the first ring gets the floor and the presenter presses right
-- or wrong (they see the right answer). Wrong: a subjective launch, and the bells open again for those who have not
-- answered it, BELL_TRIES answers at most; no verdict in time: no penalty, the next ring. Nobody rings at all: that
-- question goes to everyone with four choices (like the quiz). Only with a presenter; if they are gone mid-way the
-- remaining questions go to everyone the same way.
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
	bell: (from: { Player }, seconds: number, firstOnly: boolean,
		enough: (({ Player }, { [Player]: number }) -> boolean)?) -> ({ Player }, { [Player]: number }),
	floor: (player: Player?) -> (),
	presenterVerdict: (answer: string, seconds: number) -> string?,
	score: (player: Player, amount: number) -> (),
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

-- Everyone on the ground answers `question` with four choices; wrong or none is a fail (event `key`). Returns false if
-- cancelled.
local function askEveryone(ctx: Ctx, question: QuizBank.Question, key: string): boolean
	ctx.show(if ctx.final then Config.TEXT.FINAL_QUIZ else Config.TEXT.QUIZ_START)
	local shown = { kind = "quiz", final = ctx.final, question = question.q, choices = question.choices }
	ctx.screen(shown)
	if not ctx.wait(Config.QUIZ_INTRO_SECONDS) then
		return false
	end
	local asked = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(asked, player)
		end
	end
	local answers = ctx.ask(shown, #question.choices, Config.QUIZ_SECONDS, asked)
	if ctx.cancelled() then
		return false
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
	ctx.fail(wrong, key)
	ctx.reveal(Config.QUIZ_REVEAL_SECONDS) -- also when this answer decided the round
	return true
end

-- Returns false when no clean question is left (nothing was asked).
function Quiz.run(ctx: Ctx): boolean?
	local question = pick(if ctx.final then QuizBank.final else QuizBank.main, ctx.rng)
	if not question then
		return false
	end
	askEveryone(ctx, question, "answer")
	return nil
end

local BellQuiz = {
	id = "bellQuiz",
	title = Config.TEXT.BELL_QUIZ_TITLE,
	-- The longest run: every question with every answer chance (each its own bells, an answer by chat, judged at the
	-- last moment).
	expectedSeconds = Config.BELL_QUIZ_QUESTIONS * (Config.BELL_TRIES
		* (Config.BELL_WAIT_SECONDS + Config.BELL_ANSWER_CHAT_SECONDS + Config.BELL_VERDICT_SECONDS) + Config.QUIZ_REVEAL_SECONDS),
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.BELL_QUIZ_MIN_PLAYERS :: number?,
	needsPresenter = true :: boolean?,
}

function BellQuiz.available(final: boolean): boolean
	return not final and #QuizBank.main > 0
end

-- One question by the bells. Returns false if cancelled.
local function ringFor(ctx: Ctx, question: QuizBank.Question, number: number): boolean
	local right = question.choices[question.answer]
	local tried: { [Player]: boolean } = {}
	for _ = 1, Config.BELL_TRIES do
		local from = {}
		for _, player in ctx.players() do
			if not ctx.flying(player) and not tried[player] then
				table.insert(from, player)
			end
		end
		if not Match.presenter then
			return askEveryone(ctx, question, "answer" .. number) -- (the presenter is gone: four choices for everyone)
		end
		if #from == 0 then
			break
		end
		ctx.screen({ kind = "bellQuiz", question = question.q, stage = "wait", endsAt = Match.now() + Config.BELL_WAIT_SECONDS })
		ctx.show(Config.TEXT.BELL_QUIZ_WAIT)
		local holder = ctx.bell(from, Config.BELL_WAIT_SECONDS, true)[1]
		if ctx.cancelled() then
			return false
		end
		if not holder then
			if next(tried) == nil then
				ctx.show(Config.TEXT.BELL_QUIZ_NOBODY)
				return askEveryone(ctx, question, "answer" .. number) -- (nobody rang at all: everyone answers with four choices)
			end
			break
		end
		tried[holder] = true
		local p = Match.participants[holder]
		local answerSeconds = if p and p.chat then Config.BELL_ANSWER_CHAT_SECONDS else Config.BELL_ANSWER_SECONDS
		local seconds = answerSeconds + Config.BELL_VERDICT_SECONDS
		ctx.screen({ kind = "bellQuiz", question = question.q, stage = "answer", ids = { holder.UserId },
			endsAt = Match.now() + seconds })
		ctx.show(string.format(Config.TEXT.BELL_QUIZ_ANSWERING, holder.DisplayName))
		ctx.floor(holder)
		local verdict = ctx.presenterVerdict(right, seconds)
		ctx.floor(nil)
		if ctx.cancelled() then
			return false
		end
		if verdict == nil and not Match.presenter then
			return askEveryone(ctx, question, "answer" .. number) -- (the presenter left while judging)
		end
		if verdict == "right" then
			ctx.score(holder, Config.SCORE_BELL_QUIZ)
			ctx.show(string.format(Config.TEXT.BELL_QUIZ_RIGHT, holder.DisplayName))
			break
		elseif verdict == "wrong" then
			ctx.show(string.format(Config.TEXT.BELL_QUIZ_WRONG, holder.DisplayName))
			if ctx.canFling(holder) then
				ctx.fail({ holder }, "bell" .. number .. ":" .. holder.UserId, true)
			end
		end
	end
	ctx.screen({ kind = "quizResult", final = false, question = question.q, choices = question.choices, answer = question.answer })
	ctx.show(string.format(Config.TEXT.QUIZ_ANSWER, right))
	return ctx.wait(Config.QUIZ_REVEAL_SECONDS)
end

-- Returns false when no clean question was left (nothing was asked).
function BellQuiz.run(ctx: Ctx): boolean?
	ctx.show(Config.TEXT.BELL_QUIZ_START)
	local asked = 0
	for number = 1, Config.BELL_QUIZ_QUESTIONS do
		local question = pick(QuizBank.main, ctx.rng)
		if not question then
			break
		end
		asked += 1
		-- (no presenter any more: the rest go to everyone with four choices)
		local going = if Match.presenter then ringFor(ctx, question, number) else askEveryone(ctx, question, "answer" .. number)
		if not going then
			return nil
		end
	end
	return if asked > 0 then nil else false
end

Quiz.bell = BellQuiz

return Quiz
