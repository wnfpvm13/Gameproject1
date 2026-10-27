--!strict
-- The quiz (docs/DESIGN_V3.md §5; bundle 4a): everyone alive answers one four-choice question at once; the right
-- answer stays on the server until the time is up. A wrong answer or none is a fail. As a final question it uses the
-- harder questions and a wrong answer is out (RoundService decides that). Players flying when the question opens
-- cannot answer and are neither failed nor counted as missing (§4). Questions never repeat until the bank runs out,
-- and a question whose text or any choice contains a banned word in play is skipped.
-- The 초성 quiz (`Quiz.chosung`, bundle 8c) lives here too and asks the same way (see it at the end).
-- The bell quiz (`Quiz.bell`, bundle 6b, owner 2026-10-23: the first to ring answers by voice, the presenter judges)
-- lives here too, so both draw from the same bank without repeats. BELL_QUIZ_QUESTIONS questions; for each the bells
-- of everyone on the ground are open BELL_WAIT_SECONDS; the first ring gets the floor and the presenter presses right
-- or wrong (they see the right answer). Wrong: a subjective launch, and the bells open again for those who have not
-- answered it, BELL_TRIES answers at most; no verdict in time: no penalty, the next ring. Nobody rings at all: that
-- question goes to everyone with four choices (like the quiz). Only with a presenter; if they are gone mid-way the
-- remaining questions go to everyone the same way.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Modes = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Modes"))
local Picks = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Picks"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local QuizBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("QuizBank"))
local ChosungBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("ChosungBank"))
local Hangul = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Hangul"))

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

-- The difficulty modes (bundle 11b, docs/BUNDLE11_2026-10-27.md; Match.mode): each has its banks (bankFor) and the
-- answer time Modes.value(mode, "QUIZ_SECONDS"). A question asked in this round is not asked again in it, even when the
-- server's history of a bank runs out and starts over (the easy mode's final asks the main game's bank).
local Quiz = {
	id = "quiz",
	title = Config.TEXT.QUIZ_TITLE,
	brief = Config.TEXT.QUIZ_BRIEF, -- (the briefing before it)
	expectedSeconds = Config.QUIZ_INTRO_SECONDS + Config.QUIZ_SECONDS + Config.PICKS_SECONDS + Config.QUIZ_REVEAL_SECONDS,
	briefFor = nil :: ((mode: string) -> string)?,
	expectedFor = nil :: ((players: number, mode: string) -> number)?,
	maxPerRound = nil :: number?, -- the basic mission: no limit (§5)
	minPlayers = nil :: number?,
	maxPlayers = nil :: number?,
	needsPresenter = nil :: boolean?,
}

local used: { [QuizBank.Question]: boolean } = {} -- asked on this server (main and final banks alike)
local usedThisRound: { [QuizBank.Question]: boolean } = {} -- asked in the round `usedRound`
local usedRound = -1

-- The answer time of a four-choice question in `mode`, and the quiz's time budget with it.
local function quizSeconds(mode: string?): number
	return Modes.value(mode, "QUIZ_SECONDS") :: number
end
local function quizExpected(_players: number, mode: string): number
	return Config.QUIZ_INTRO_SECONDS + quizSeconds(mode) + Config.PICKS_SECONDS + Config.QUIZ_REVEAL_SECONDS
end
Quiz.expectedFor = quizExpected

-- The bank a question comes from in `mode` (read at each call: the tests swap the banks). `bell`: the bell quiz,
-- which asks no 넌센스 (said without choices, a joke's answer splits).
local function bankFor(mode: string?, final: boolean, bell: boolean?): { QuizBank.Question }
	if mode == "easy" then
		if bell then
			local plain = {}
			for _, question in QuizBank.easy do
				if not question.nonsense then
					table.insert(plain, question)
				end
			end
			return plain
		end
		return QuizBank.easy
	elseif mode == "hard" then
		if final then
			return QuizBank.hardFinal
		end
		local bank = table.clone(QuizBank.final) -- (the same question tables: one history with the normal final)
		for _, question in QuizBank.hardMain do
			table.insert(bank, question)
		end
		return bank
	end
	return if final then QuizBank.final else QuizBank.main
end

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
-- (When the clean ones come again, those of this round still wait: a question is never asked twice in one round
-- unless the bank has nothing else.)
local function pick(bank: { QuizBank.Question }, rng: Random): QuizBank.Question?
	if Match.roundId ~= usedRound then
		usedRound = Match.roundId
		table.clear(usedThisRound)
	end
	local words = Match.wordsInPlay()
	local clean, fresh = {}, {}
	for _, question in bank do
		if not mentions(question, words) then
			table.insert(clean, question)
			if not used[question] and not usedThisRound[question] then
				table.insert(fresh, question)
			end
		end
	end
	if #fresh == 0 then
		-- (every clean one was asked: they come again, but not this round's — their history stays, so a later pick in
		-- this round skips them too; review 2026-10-27)
		for _, question in clean do
			if not usedThisRound[question] then
				used[question] = nil
				table.insert(fresh, question)
			end
		end
		if #fresh == 0 then
			fresh = clean -- (this round asked the whole bank: one of them again)
		end
	end
	if #fresh == 0 then
		return nil
	end
	local question = fresh[rng:NextInteger(1, #fresh)]
	used[question] = true
	usedThisRound[question] = true
	return question
end

function Quiz.available(final: boolean): boolean
	return #bankFor(Match.mode, final) > 0
end

-- `question`'s choices in a new order for this asking, and where the right one is now (review 2026-10-25: it sat in
-- the same place every time, so a player who met a question again knew the spot). Choices that all hold a number
-- (3만 km, 30만 km ...) keep their order. Config.QUIZ_SHUFFLE off keeps every order (the tests). The bank is not changed.
local function shuffledChoices(question: QuizBank.Question, rng: Random): ({ string }, number)
	local numbers = true
	for _, choice in question.choices do
		numbers = numbers and string.find(choice, "%d") ~= nil
	end
	if numbers or not Config.QUIZ_SHUFFLE then
		return question.choices, question.answer
	end
	local order = {}
	for i = 1, #question.choices do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local choices, answer = {}, question.answer
	for place, from in order do
		choices[place] = question.choices[from]
		if from == question.answer then
			answer = place
		end
	end
	return choices, answer
end

-- Everyone on the ground answers `question` with four choices; wrong or none is a fail (event `key`). When the time is
-- up, everyone's answer shows over their head for PICKS_SECONDS (bundle 12), then the right one with the tags turned
-- right / wrong, and the wrong ones fly. Returns false if cancelled.
local function askEveryone(ctx: Ctx, question: QuizBank.Question, key: string): boolean
	ctx.show(if ctx.final then Config.TEXT.FINAL_QUIZ else Config.TEXT.QUIZ_START)
	local choices, rightAt = shuffledChoices(question, ctx.rng)
	local shown = { kind = "quiz", final = ctx.final, question = question.q, choices = choices }
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
	local answers = ctx.ask(shown, #choices, quizSeconds(Match.mode), asked)
	if ctx.cancelled() then
		return false
	end
	local function label(player: Player): string?
		return Picks.choiceLabel(answers[player], choices)
	end
	ctx.screen({ kind = "quizResult", final = ctx.final, question = question.q, choices = choices,
		picks = Picks.build(asked, label) })
	ctx.show(Config.TEXT.PICKS_REVEAL)
	if not ctx.wait(Config.PICKS_SECONDS) then
		return false
	end
	local answered, missed, wrong, rightIds = {}, {}, {}, {}
	for _, player in asked do
		local choice = answers[player]
		if choice then
			table.insert(answered, player)
		else
			table.insert(missed, player)
		end
		if choice ~= rightAt then
			table.insert(wrong, player)
		else
			table.insert(rightIds, player.UserId)
		end
	end
	-- (`right`: who the server counted right — their "correct" sound, review 2026-10-26)
	ctx.screen({ kind = "quizResult", final = ctx.final, question = question.q, choices = choices, answer = rightAt,
		right = rightIds, picks = Picks.build(asked, label, function(player)
			return if answers[player] == rightAt then "right" else "wrong"
		end) })
	ctx.show(if #wrong == 0 then Config.TEXT.QUIZ_ALL_RIGHT
		else string.format(Config.TEXT.QUIZ_ANSWER, choices[rightAt]))
	if not ctx.final then
		ctx.answers(answered, missed) -- before the fail: a launched player's miss would not count any more
	end
	ctx.fail(wrong, key)
	ctx.reveal(Config.QUIZ_REVEAL_SECONDS) -- also when this answer decided the round
	return true
end

-- Returns false when no clean question is left (nothing was asked).
function Quiz.run(ctx: Ctx): boolean?
	local question = pick(bankFor(Match.mode, ctx.final), ctx.rng)
	if not question then
		return false
	end
	askEveryone(ctx, question, "answer")
	return nil
end

local BellQuiz = {
	id = "bellQuiz",
	title = Config.TEXT.BELL_QUIZ_TITLE,
	brief = Config.TEXT.BELL_QUIZ_BRIEF, -- (the briefing before it)
	-- The longest run: every question with every answer chance (each its own bells, an answer by chat, judged at the
	-- last moment).
	expectedSeconds = Config.BELL_QUIZ_QUESTIONS * (Config.BELL_TRIES
		* (Config.BELL_WAIT_SECONDS + Config.BELL_ANSWER_CHAT_SECONDS + Config.BELL_VERDICT_SECONDS) + Config.QUIZ_REVEAL_SECONDS),
	briefFor = nil :: ((mode: string) -> string)?,
	expectedFor = nil :: ((players: number, mode: string) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.BELL_QUIZ_MIN_PLAYERS :: number?,
	maxPlayers = nil :: number?,
	needsPresenter = true :: boolean?,
}

function BellQuiz.available(final: boolean): boolean
	return not final and #bankFor(Match.mode, false, true) > 0
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
		local question = pick(bankFor(Match.mode, false, true), ctx.rng)
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

-- 초성 퀴즈 (`Quiz.chosung`, bundle 8c, owner 2026-10-24): a word's initial consonants with its category (ChosungBank,
-- shared/Hangul), and four words of that category to choose from — the right one and three whose initials differ,
-- the ones closest to the right initials (as many syllables, the most initials in the same places) so a glance is not
-- enough. The rest is the quiz's (askEveryone: wrong or none is a fail). Words or categories containing a banned word
-- in play are left out; a word is not asked again until every word that can make a question was.
local ChosungQuiz = {
	id = "chosung",
	title = Config.TEXT.CHOSUNG_TITLE,
	brief = Config.TEXT.CHOSUNG_BRIEF, -- (the briefing before it)
	expectedSeconds = Quiz.expectedSeconds,
	briefFor = nil :: ((mode: string) -> string)?,
	expectedFor = nil :: ((players: number, mode: string) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = nil :: number?,
	maxPlayers = nil :: number?,
	needsPresenter = nil :: boolean?,
}

ChosungQuiz.expectedFor = quizExpected -- (its answer time is the quiz's, by mode)

local usedWords: { [string]: boolean } = {} -- by "category/word" (a word may sit in two categories)
type Candidate = { key: string, category: string, word: string, initials: string, decoys: { string } }

function ChosungQuiz.available(final: boolean): boolean
	return not final and #ChosungBank > 0
end

-- A word's initials as a list of characters.
local function letters(initials: string): { number }
	local out = {}
	for _, code in utf8.codes(initials) do
		table.insert(out, code)
	end
	return out
end

-- How close a wrong choice's initials are to the right ones: as many syllables first, then initials in the same places.
-- `far` (the easy mode, Config.CHOSUNG_FAR_DECOYS): as many syllables first, then the fewest initials in the same
-- places — told apart at a glance, yet not by length alone; a category short of such words fills up with the next best.
local function likeness(right: { number }, other: { number }, far: boolean): number
	local score = if #other == #right then 100 else 0
	for i = 1, math.min(#right, #other) do
		if right[i] == other[i] then
			score += if far then -1 else 1
		end
	end
	return score
end

-- A question (nil when no word can make one: a clean word with three clean words of other initials in its clean
-- category); `words`: the banned words in play.
function ChosungQuiz.question(rng: Random, words: { string }): QuizBank.Question?
	local function clean(text: string): boolean
		for _, banned in words do
			if string.find(text, banned, 1, true) then
				return false
			end
		end
		return true
	end
	local usable: { Candidate } = {}
	for _, entry in ChosungBank do
		if clean(entry.category) then
			local cleanWords = {}
			for _, word in entry.words do
				if clean(word) then
					table.insert(cleanWords, { word = word, initials = Hangul.initials(word) })
				end
			end
			for _, this in cleanWords do
				local decoys = {}
				for _, other in cleanWords do
					if other.initials ~= this.initials then
						table.insert(decoys, other.word)
					end
				end
				if #decoys >= 3 then
					table.insert(usable, { key = entry.category .. "/" .. this.word, category = entry.category,
						word = this.word, initials = this.initials, decoys = decoys })
				end
			end
		end
	end
	local fresh = {}
	for _, candidate in usable do
		if not usedWords[candidate.key] then
			table.insert(fresh, candidate)
		end
	end
	if #fresh == 0 then -- (every word that can make a question was asked: they come back)
		table.clear(usedWords)
		fresh = usable
	end
	if #fresh == 0 then
		return nil
	end
	local candidate = fresh[rng:NextInteger(1, #fresh)]
	usedWords[candidate.key] = true
	-- The three closest wrong choices (a random pick among equally close ones; the easy mode: the least alike).
	local right = letters(candidate.initials)
	local far = Modes.value(Match.mode, "CHOSUNG_FAR_DECOYS") == true
	local ranked = {}
	for _, other in candidate.decoys do
		table.insert(ranked, { word = other, score = likeness(right, letters(Hangul.initials(other)), far) + rng:NextNumber() * 0.5 })
	end
	table.sort(ranked, function(a, b)
		return a.score > b.score
	end)
	local choices = { candidate.word }
	for i = 1, 3 do
		table.insert(choices, ranked[i].word)
	end
	for i = #choices, 2, -1 do
		local j = rng:NextInteger(1, i)
		choices[i], choices[j] = choices[j], choices[i]
	end
	return { q = string.format(Config.TEXT.CHOSUNG_Q, candidate.category, candidate.initials), choices = choices,
		answer = table.find(choices, candidate.word) :: number }
end

-- Returns false when no question could be made (nothing was asked).
function ChosungQuiz.run(ctx: Ctx): boolean?
	local question = ChosungQuiz.question(ctx.rng, Match.wordsInPlay())
	if not question then
		return false
	end
	askEveryone(ctx, question, "answer")
	return nil
end

Quiz.chosung = ChosungQuiz

return Quiz
