-- Mission tests (bundle 4a): the real quiz and roulette run through the real MissionRunner with a fake ctx (what
-- RoundService would give): answers come in through the "MissionAnswer" listener, screens are what "Mission" sent.
local Config = require(node("Config"))
local Match = require(node("Match"))
local QuizBank = require(node("QuizBank"))
local MissionRunner = require(node("MissionRunner"))
local Quiz = require(node("Quiz"))
local Roulette = require(node("Roulette"))
local VoteRules = require(node("VoteRules"))
local OneWord = require(node("OneWord"))
local OneWordTopics = require(node("OneWordTopics"))
local Crocodile = require(node("Crocodile"))
local BombPass = require(node("BombPass"))
local BombBank = require(node("BombBank"))
local Nunchi = require(node("Nunchi"))
local Balance = require(node("Balance"))
local RedLight = require(node("RedLight"))
local Liar = require(node("Liar"))

local fails = 0
local function check(name, ok, detail)
	print((if ok then "PASS " else "FAIL ") .. name .. (if not ok and detail then "  " .. tostring(detail) else ""))
	if not ok then
		fails += 1
	end
end

MissionRunner.start()
local listener = NetStub.listeners.MissionAnswer
-- The open question's number: the last "Mission" screen that carried one.
local function openId()
	for i = #NetStub.sent, 1, -1 do
		local m = NetStub.sent[i]
		if m.name == "Mission" and m.payload.id then
			return m.payload.id
		end
	end
	return 0
end
local function answer(player, choice)
	listener(player, openId(), choice)
end

local nextId = 0
local function newPlayers(n)
	local list = {}
	for _ = 1, n do
		nextId += 1
		table.insert(list, { UserId = nextId, Name = "P" .. nextId, DisplayName = "P" .. nextId, Parent = Players })
	end
	return list
end

-- A ctx like RoundService's: `alive` are the players, `flyingSet` cannot answer; fails, answers and shows are recorded.
local function fakeCtx(alive, final, flyingSet)
	local record = { fails = {}, answered = nil, missed = nil, shows = {}, cancel = false, bellCalls = {}, floors = {},
		verdicts = {}, scores = {} }
	record.ctx = {
		final = final,
		players = function() return alive end,
		rng = Random.new(7),
		fail = function(players, key, subjective)
			table.insert(record.fails, { players = players, key = key, subjective = subjective, at = now })
		end,
		show = function(text) table.insert(record.shows, text) end,
		cancelled = function() return record.cancel end,
		stopped = function() return record.stop == true end,
		flying = function(player) return flyingSet ~= nil and flyingSet[player] == true end,
		answers = function(answered, missed)
			record.answered, record.missed = answered, missed
		end,
		-- One-word mission: who a subjective launch may hit, the presenter's pick (record.pick(options) answers it).
		canFling = function(player) return not (record.protected and record.protected[player]) end,
		presenterPick = function(options, seconds)
			record.pickOptions = options
			record.pickSeconds = seconds
			return if record.pick then record.pick(options) else nil
		end,
		-- Bundle 6b: the bells answer at once with the next list of record.rings; floors, verdicts and points recorded.
		bell = function(from, seconds, firstOnly, enough, repeatEvery)
			if record.bellOverride then
				return record.bellOverride(from, seconds, firstOnly, enough, repeatEvery)
			end
			table.insert(record.bellCalls, { from = from, seconds = seconds, firstOnly = firstOnly, enough = enough })
			local rung = (if record.rings then table.remove(record.rings, 1) else nil) or {}
			local times = record.ringTimes or {}
			if not record.ringTimes then
				for i, player in rung do
					times[player] = i -- (a second apart unless a test says otherwise)
				end
			end
			return rung, times, {}
		end,
		screenTo = function(player, payload)
			NetStub.to(player, "Mission", payload) -- (what MissionRunner would send that player)
		end,
		floor = function(player)
			table.insert(record.floors, player or false)
		end,
		presenterVerdict = function(answer, seconds)
			table.insert(record.verdicts, { answer = answer, seconds = seconds })
			return if record.verdict then record.verdict(answer) else nil
		end,
		score = function(player, amount)
			table.insert(record.scores, { player = player, amount = amount })
		end,
	}
	return record
end

local function screens(since)
	local list = {}
	for _, m in NetStub.sent do
		if m.name == "Mission" and m.at >= since then
			table.insert(list, m)
		end
	end
	return list
end
local function lastScreenOf(since, kind)
	local found = nil
	for _, m in screens(since) do
		if m.payload.kind == kind then
			found = m.payload
		end
	end
	return found
end
local function levers(since)
	local n = 0
	for _, m in NetStub.sent do
		if m.name == "Lever" and m.at >= since then
			n += 1
		end
	end
	return n
end
local function has(list, player)
	return table.find(list or {}, player) ~= nil
end

-- Runs `mission` in its own thread (the test thread drives the clock). Returns a table that gets `done = true`.
local function start(mission, record)
	local state = { done = false, ok = nil, played = nil }
	task.spawn(function()
		state.ok, state.played = MissionRunner.run(mission, record.ctx)
		state.done = true
	end)
	return state
end

-- A small bank for the rules below; the real bank is checked on its own (section 4).
local realMain, realFinal = QuizBank.main, QuizBank.final
local function q(text, right, wrong1, wrong2, wrong3)
	return { q = text, choices = { right, wrong1, wrong2, wrong3 }, answer = 1 }
end

---------------------------------------------------------------- 1. the quiz
do
	QuizBank.main = { q("질문 하나", "가", "나", "다", "라") }
	local ps = newPlayers(4)
	local record = fakeCtx(ps, false, { [ps[4]] = true }) -- ps[4] is flying
	local since = now
	local run = start(Quiz, record)
	local intro = screens(since)
	check("1a the question shows at once, without the answer", #intro == 1 and intro[1].payload.kind == "quiz"
		and intro[1].payload.answer == nil and intro[1].payload.endsAt == nil)
	answer(ps[1], 1) -- before the buttons work: ignored
	at(now + Config.QUIZ_INTRO_SECONDS + 0.1)
	local open = screens(since)
	check("1b then the buttons work (the same question with endsAt)", #open == 2 and open[2].payload.endsAt ~= nil
		and open[2].payload.answer == nil)
	answer(ps[1], 1) -- right
	answer(ps[1], 2) -- a second answer: ignored
	answer(ps[2], 3) -- wrong
	answer(ps[4], 1) -- flying: not asked, ignored
	listener(ps[3], openId() - 1, 1) -- an older question's number: ignored
	answer(ps[3], 1.5) -- not a choice
	answer(ps[3], 0)
	answer(ps[3], 5)
	answer(ps[3], "1")
	at(now + Config.QUIZ_SECONDS + 0.2)
	local f = record.fails[1]
	check("1c a wrong answer or none fails; the right one, a flying player, early, repeated, malformed or old-question answers do not",
		#record.fails == 1 and f.key == "answer" and #f.players == 2 and has(f.players, ps[2]) and has(f.players, ps[3])
		and not has(f.players, ps[1]) and not has(f.players, ps[4]))
	check("1d the AFK rule hears who answered and who did not (flying players are neither)", has(record.answered, ps[1])
		and has(record.answered, ps[2]) and has(record.missed, ps[3]) and #record.missed == 1
		and not has(record.answered, ps[4]))
	local shown = screens(since)
	local result = shown[#shown].payload
	check("1e then everyone sees the right answer", result.kind == "quizResult" and result.answer == 1)
	at(now + Config.QUIZ_REVEAL_SECONDS + 0.5)
	local last = screens(since)
	check("1f the screen clears when the mission ends", run.done and run.ok and last[#last].payload.kind == "none")

	-- Everyone answers early: the question closes at once.
	local record2 = fakeCtx({ ps[1], ps[2] }, false, nil)
	QuizBank.main = { q("질문 둘", "가", "나", "다", "라") }
	local begun = now
	local run2 = start(Quiz, record2)
	at(now + Config.QUIZ_INTRO_SECONDS + 0.1)
	answer(ps[1], 1)
	answer(ps[2], 1)
	at(now + 0.5)
	check("1g when everyone asked has answered, the answer shows at once", #record2.fails == 1 and #record2.fails[1].players == 0
		and now < begun + Config.QUIZ_INTRO_SECONDS + Config.QUIZ_SECONDS)
	at(now + Config.QUIZ_REVEAL_SECONDS + 0.5)
	check("1h (and the mission ends after the reveal)", run2.done)

	-- A cancel while the question is open: no fail, the screen clears.
	local record3 = fakeCtx({ ps[1], ps[2] }, false, nil)
	local since3 = now
	local run3 = start(Quiz, record3)
	at(now + Config.QUIZ_INTRO_SECONDS + 1)
	record3.cancel = true
	at(now + 0.5)
	local s3 = screens(since3)
	check("1i a cancelled quiz fails nobody and clears the screen", run3.done and #record3.fails == 0
		and s3[#s3].payload.kind == "none" and record3.answered == nil)

	-- The answer itself decides the round (RoundService's cancel turns true with the fail): the right answer still
	-- stays on screen for QUIZ_REVEAL_SECONDS; only a new round cuts it short.
	local record4 = fakeCtx({ ps[1], ps[2] }, false, nil)
	record4.ctx.fail = function(players, key)
		table.insert(record4.fails, { players = players, key = key })
		record4.cancel = true
	end
	local since4 = now
	local run4 = start(Quiz, record4)
	at(now + Config.QUIZ_INTRO_SECONDS + 0.1)
	answer(ps[1], 1)
	answer(ps[2], 2)
	at(now + 1)
	local s4 = screens(since4)
	local stillShown = not run4.done and s4[#s4].payload.kind == "quizResult"
	at(now + Config.QUIZ_REVEAL_SECONDS)
	check("1j a result that decides the round still stays on screen for its reveal time", stillShown and run4.done)
	local record5 = fakeCtx({ ps[1], ps[2] }, false, nil)
	record5.ctx.fail = function(_players, _key)
		record5.stop = true -- a new round began
	end
	local run5 = start(Quiz, record5)
	at(now + Config.QUIZ_INTRO_SECONDS + Config.QUIZ_SECONDS + 0.5)
	check("1k ...but a new round ends it at once", run5.done)
end

---------------------------------------------------------------- 2. questions: no repeats, no words in play, the final
do
	local ps = newPlayers(2)
	local function asked(record, since)
		for _, m in screens(since) do
			if m.payload.kind == "quiz" then
				return m.payload.question
			end
		end
		return nil
	end
	local function once(final)
		local record = fakeCtx(ps, final, nil)
		local since = now
		local run = start(Quiz, record)
		at(now + Config.QUIZ_INTRO_SECONDS + Config.QUIZ_SECONDS + Config.QUIZ_REVEAL_SECONDS + 1)
		return asked(record, since), record, run
	end
	QuizBank.main = { q("A", "1", "2", "3", "4"), q("B", "1", "2", "3", "4"), q("C", "1", "2", "3", "4") }
	local seen = {}
	for _ = 1, 3 do
		local text = once(false)
		seen[text or "?"] = true
	end
	local fourth = once(false)
	check("2a no question repeats until all were asked, then they come again", seen.A and seen.B and seen.C and fourth ~= nil)

	-- A banned word in play (bundle 5 puts them on participants) in a question or any choice: skipped.
	Match.participants[ps[1]] = { player = ps[1], words = { { text = "사과" } }, alive = true, lives = 3, afkMisses = 0 }
	QuizBank.main = { q("사과는 무슨 색?", "빨강", "파랑", "검정", "흰색"), q("과일 고르기", "배", "사과", "돌", "흙"),
		q("바다의 맛은?", "짜다", "달다", "쓰다", "맵다") }
	local clean = true
	for _ = 1, 4 do
		clean = clean and once(false) == "바다의 맛은?"
	end
	check("2b a question whose text or any choice holds a word in play is never asked", clean)
	QuizBank.main = { q("사과는 무슨 색?", "빨강", "파랑", "검정", "흰색") }
	local text, record, emptyRun = once(false)
	check("2c no clean question: the quiz asks nothing, fails nobody and says it played nothing (a final ends then)",
		text == nil and #record.fails == 0 and emptyRun.ok == true and emptyRun.played == false)
	Match.participants[ps[1]] = nil

	QuizBank.final = { q("어려운 문제", "1", "2", "3", "4") }
	local finalText, finalRecord = once(true)
	check("2d a final question comes from the final bank, and a final miss is not an AFK miss", finalText == "어려운 문제"
		and finalRecord.answered == nil and #finalRecord.fails == 1 and #finalRecord.fails[1].players == 2)
	QuizBank.final = {}
	check("2e the quiz offers final questions only if the final bank has some", Quiz.available(false) and not Quiz.available(true))
end

---------------------------------------------------------------- 3. the roulette and the menu order
do
	local ps = newPlayers(4)
	local record = fakeCtx(ps, false, { [ps[2]] = true })
	local since = now
	local run = start(Roulette, record)
	local spin = screens(since)[1].payload
	at(now + Config.ROULETTE_SPIN_SECONDS + 0.1)
	local hit = record.fails[1]
	local onWheel = true
	for _, id in spin.ids do
		onWheel = onWheel and id ~= ps[2].UserId
	end
	check("3a the roulette spins the players on the ground and fails the one it shows", spin.kind == "roulette"
		and #spin.ids == 3 and onWheel and hit ~= nil and #hit.players == 1 and hit.players[1].UserId == spin.ids[spin.pick]
		and hit.key == "spin")
	at(now + Config.ROULETTE_REVEAL_SECONDS + 0.5)
	check("3b (and ends after the reveal)", run.done)
	local alone = fakeCtx({ ps[1], ps[2] }, false, { [ps[2]] = true })
	local aloneRun = start(Roulette, alone)
	at(now + Config.ROULETTE_SPIN_SECONDS + Config.ROULETTE_REVEAL_SECONDS + 1)
	check("3c fewer than ROULETTE_MIN_PLAYERS on the ground: nobody is picked (and no error)", #alone.fails == 0
		and aloneRun.done and aloneRun.ok == true)

	-- The menu order (the presenter's recommendations) from a fresh round: the games not played yet in list order (no
	-- presenter here: no bell quiz; too few for a vote: no "say what you like"; no speech judging: no talk), then the
	-- ones played; the roulette once a round.
	QuizBank.main = realMain
	QuizBank.final = realFinal
	MissionRunner.beginRound()
	local function menuIds()
		local list = {}
		for _, m in MissionRunner.candidates(300, 4, false) do
			if m.id ~= "test" then -- (the Studio test mission is listed too; leave it out)
				table.insert(list, m.id)
			end
		end
		return table.concat(list, ",")
	end
	local fresh = menuIds()
	start(Quiz, fakeCtx(newPlayers(4), false, nil))
	at(now + 30)
	local afterQuiz = menuIds()
	start(Roulette, fakeCtx(newPlayers(4), false, nil))
	at(now + 30)
	local afterRoulette = menuIds()
	check("3d the menu order: games not played yet first (list order), played ones after; the roulette once a round",
		fresh == "quiz,roulette,croc,bomb,nunchi,balance,redLight,liar"
		and afterQuiz == "roulette,croc,bomb,nunchi,balance,redLight,liar,quiz"
		and afterRoulette == "croc,bomb,nunchi,balance,redLight,liar,quiz", fresh .. " | " .. afterQuiz .. " | " .. afterRoulette)
	MissionRunner.beginRound()
	local small = MissionRunner.candidates(300, 1, false)
	local rouletteListed = false
	for _, m in small do
		rouletteListed = rouletteListed or m.id == "roulette"
	end
	check("3e the roulette is not offered with fewer than ROULETTE_MIN_PLAYERS alive", not rouletteListed)

	-- Choosing the next game (bundle 6a): the presenter's pick, else at random (fewer runs likelier, not the last one).
	MissionRunner.beginRound()
	local rng = Random.new(7)
	local picked = MissionRunner.choose(300, 4, false, "roulette", rng, "roulette")
	local avoided = true
	for _ = 1, 60 do
		local m = MissionRunner.choose(300, 4, false, nil, rng, "quiz")
		avoided = avoided and m ~= nil and m.id ~= "quiz"
	end
	check("3f the presenter's pick wins (even the last game); a random choice skips the game just played",
		picked ~= nil and picked.id == "roulette" and avoided)
	start(MissionRunner.choose(300, 4, false, "quiz", rng, nil) :: any, fakeCtx(newPlayers(4), false, nil))
	at(now + 30)
	start(MissionRunner.choose(300, 4, false, "quiz", rng, nil) :: any, fakeCtx(newPlayers(4), false, nil))
	at(now + 30)
	local quizzes, draws = 0, 400
	for _ = 1, draws do
		local m = MissionRunner.choose(300, 4, false, nil, rng, nil)
		if m and m.id == "quiz" then
			quizzes += 1
		end
	end
	-- quiz played twice: weight 1/3 against 1 for each game not played yet
	local others = #MissionRunner.candidates(300, 4, false) - 1
	local expected = draws * (1 / 3) / (others + 1 / 3)
	check("3g games played more this round are picked less often", quizzes > expected * 0.5 and quizzes < expected * 1.5,
		string.format("%d of %d (about %.0f expected)", quizzes, draws, expected))
	check("3h nothing fits the time left -> no game", MissionRunner.choose(5, 4, false, nil, rng, nil) == nil)
	local function listed(id)
		for _, m in MissionRunner.candidates(300, 4, false) do
			if m.id == id then
				return true
			end
		end
		return false
	end
	local offWithout = listed("bannedTalk")
	Match.voiceJudging = true
	local onWith = listed("bannedTalk")
	local inFinal = false
	for _, m in { MissionRunner.finalMission() } do
		inFinal = inFinal or m.id == "bannedTalk"
	end
	Match.voiceJudging = false
	check("3i the banned-word talk is offered only while speech judging is on (never in the final)", not offWithout and onWith
		and not inFinal)
end

---------------------------------------------------------------- 4. the real bank
do
	local function valid(bank)
		local texts = {}
		for i, question in bank do
			if type(question.q) ~= "string" or question.q == "" or #question.choices ~= 4 or texts[question.q] then
				return false, i
			end
			texts[question.q] = true
			if type(question.answer) ~= "number" or question.answer < 1 or question.answer > 4 or question.answer % 1 ~= 0 then
				return false, i
			end
			local distinct = {}
			for _, choice in question.choices do
				if type(choice) ~= "string" or choice == "" or distinct[choice] then
					return false, i
				end
				distinct[choice] = true
			end
		end
		return true, nil
	end
	local mainOk, mainBad = valid(QuizBank.main)
	local finalOk, finalBad = valid(QuizBank.final)
	check("4a every question has a text, four different choices and one right answer (main)", mainOk, mainBad)
	check("4b (final)", finalOk, finalBad)
	check("4c the bank has at least the 120 + 40 questions it started with", #QuizBank.main >= 120 and #QuizBank.final >= 40,
		#QuizBank.main .. "/" .. #QuizBank.final)
	local function spread(bank)
		local positions = { 0, 0, 0, 0 }
		for _, question in bank do
			positions[question.answer] += 1
		end
		for _, n in positions do
			if n < #bank / 8 then
				return false, table.concat(positions, ",")
			end
		end
		return true, nil
	end
	local mainSpread, mainCounts = spread(QuizBank.main)
	local finalSpread, finalCounts = spread(QuizBank.final)
	check("4d right answers are spread over the four buttons (each at least 1/8, both banks; facts are a reviewer's job)",
		mainSpread and finalSpread, mainCounts or finalCounts)
end

---------------------------------------------------------------- 5. vote rules
do
	local v = newPlayers(6)
	local cands = { v[1], v[2] } -- ballot: 1 = v1, 2 = v2, 3 = nobody, 4 = could not hear
	local function decide(ballot, voters)
		return VoteRules.decide(ballot, cands, voters or { v[1], v[2], v[3], v[4], v[5], v[6] })
	end
	check("5a fewer than VOTE_MIN_VOTERS voters: no vote", decide({ [v[3]] = 1, [v[4]] = 1, [v[5]] = 1 }, { v[3], v[4], v[5] }) == nil
		and not VoteRules.canVote(Config.VOTE_MIN_VOTERS - 1) and VoteRules.canVote(Config.VOTE_MIN_VOTERS))
	check("5b a clear top candidate with enough valid votes wins", decide({ [v[3]] = 1, [v[4]] = 1, [v[5]] = 1, [v[6]] = 2 }) == 1)
	check("5c fewer than VOTE_MIN_VALID valid votes: nobody", decide({ [v[3]] = 1, [v[4]] = 1 }) == nil)
	check("5d a tie: nobody", decide({ [v[3]] = 1, [v[4]] = 1, [v[5]] = 2, [v[6]] = 2 }) == nil)
	check("5e \"nobody\" on top: nobody", decide({ [v[3]] = 3, [v[4]] = 3, [v[5]] = 3, [v[6]] = 1 }) == nil)
	check("5f a vote for yourself does not count (v1's own vote would have tied it)",
		decide({ [v[1]] = 1, [v[3]] = 1, [v[4]] = 2, [v[5]] = 2 }) == 2)
	local seventh = newPlayers(1)[1]
	local seven = { v[1], v[2], v[3], v[4], v[5], v[6], seventh }
	check("5g abstaining voters leave the half rule; silent voters stay in it (3 of 7, one abstains: 3*2 >= 7-1)",
		VoteRules.decide({ [v[3]] = 1, [v[4]] = 1, [v[5]] = 1, [v[6]] = 4 }, cands, seven) == 1
		and VoteRules.decide({ [v[3]] = 1, [v[4]] = 1, [v[5]] = 1 }, cands, seven) == nil)
	check("5h the ballot is the candidates + nobody + could not hear", VoteRules.choices(3) == 5)
end

---------------------------------------------------------------- 6. a word to everyone
do
	local presenter = newPlayers(1)[1]
	local function oneWordRun(record)
		local run = start(OneWord, record)
		return run
	end
	local function turnSeconds(count)
		return count * (Config.ONE_WORD_PREP_SECONDS + Config.ONE_WORD_SECONDS)
	end
	local function lastScreen(since, kind)
		local found = nil
		for _, m in screens(since) do
			if kind == nil or m.payload.kind == kind then
				found = m.payload
			end
		end
		return found
	end

	-- 6A: no presenter and fewer than VOTE_MIN_VOTERS -> it does not start (nobody could decide who flies).
	Match.presenter = nil
	local nobody = fakeCtx(newPlayers(Config.VOTE_MIN_VOTERS - 1), false, nil)
	local idle = oneWordRun(nobody)
	at(now + 1)
	check("6a without a presenter and too few for a vote it does not start (and says it played nothing)", idle.done
		and idle.played == false and OneWord.needsPresenter == nil)

	-- 6B: seven alive (one flying): five performers on the ground, a swap, the presenter picks, the lever, a launch.
	Match.presenter = presenter
	local ps = newPlayers(7)
	local record = fakeCtx(ps, false, { [ps[7]] = true })
	local since = now
	local run = oneWordRun(record)
	local first = lastScreen(since, "oneWord")
	local performerIds = first.ids
	local onGround = true
	for _, id in performerIds do
		onGround = onGround and id ~= ps[7].UserId
	end
	check("6b at most ONE_WORD_MAX_PERFORMERS perform, nobody flying", #performerIds == Config.ONE_WORD_MAX_PERFORMERS and onGround)
	local firstPerformer = nil
	for _, p in ps do
		if p.UserId == performerIds[1] then
			firstPerformer = p
		end
	end
	local oldTopic = first.topic
	local other = nil
	for _, p in ps do
		if p ~= firstPerformer and p ~= ps[7] then
			other = p
			break
		end
	end
	answer(other, 1) -- not the performer: no swap
	answer(firstPerformer, 1) -- swap
	at(now + 0.3)
	local swapped = lastScreen(since, "oneWord")
	check("6c the performer (only) may swap the topic once while reading it", first.phase == "prep" and first.id ~= nil
		and swapped.swapped == true and swapped.topic ~= oldTopic and swapped.id == nil)
	at(now + Config.ONE_WORD_PREP_SECONDS + 0.2)
	local talking = lastScreen(since, "oneWord")
	check("6d then the talk with its end time (voice: ONE_WORD_SECONDS)", talking.phase == "talk" and talking.endsAt ~= nil
		and math.abs(talking.endsAt - now - Config.ONE_WORD_SECONDS) < 0.5)
	record.pick = function(options) return options[2].id end
	at(now + turnSeconds(Config.ONE_WORD_MAX_PERFORMERS) + 2)
	local f = record.fails[1]
	check("6e the presenter picks among the performers within PRESENTER_JUDGE_SECONDS; the lever, then a subjective launch",
		record.pickSeconds == Config.PRESENTER_JUDGE_SECONDS and #record.pickOptions == Config.ONE_WORD_MAX_PERFORMERS
		and levers(since) == 1 and f ~= nil and f.subjective == true and #f.players == 1
		and tostring(f.players[1].UserId) == record.pickOptions[2].id)
	at(now + 5)
	check("6f (the mission ends after the result)", run.done and run.ok)

	-- 6C: next run: who performed least goes first; protected players are not offered; no pick -> a vote.
	local record2 = fakeCtx(ps, false, nil)
	record2.protected = { [ps[1]] = true }
	local since2 = now
	local run2 = oneWordRun(record2)
	local ids2 = lastScreen(since2, "oneWord").ids
	local fresh = 0
	for _, id in ids2 do
		if not table.find(performerIds, id) then
			fresh += 1
		end
	end
	-- 7 players, 5 performed last time: both who never performed must be in this run.
	check("6g those who performed least go first", fresh == 7 - Config.ONE_WORD_MAX_PERFORMERS)
	at(now + turnSeconds(Config.ONE_WORD_MAX_PERFORMERS) + 1)
	local offered = true
	for _, option in record2.pickOptions or {} do
		offered = offered and option.id ~= tostring(ps[1].UserId)
	end
	check("6h a player a subjective launch may not hit (public limits) is not offered", record2.pickOptions ~= nil and offered)
	at(now + 0.5) -- (the fake presenter answers at once: no pick)
	local vote = lastScreen(since2, "vote")
	check("6i no pick from the presenter: everyone votes on the same names", vote ~= nil and vote.id ~= nil
		and #vote.ids == #record2.pickOptions)
	-- Everyone on the ground votes for the first candidate (whoever is not that candidate).
	local target = nil
	for _, p in ps do
		if p.UserId == vote.ids[1] then
			target = p
		end
	end
	for _, p in ps do
		answer(p, 1)
	end
	at(now + Config.VOTE_SECONDS + 1)
	local f2 = record2.fails[1]
	check("6j the vote's winner is launched (subjective, no lever)", f2 ~= nil and f2.players[1] == target and f2.subjective == true
		and levers(since2) == 0)
	at(now + 5)
	check("6k (and it ends)", run2.done)

	-- 6D: a chat participant types for ONE_WORD_CHAT_SECONDS; a topic holding a word in play is never given (every
	-- topic but the last is "in play" here, so only that one may come, and only once).
	local cs = newPlayers(4)
	local inPlay = {}
	for i = 1, #OneWordTopics - 1 do
		table.insert(inPlay, { text = OneWordTopics[i] })
	end
	Match.participants[cs[1]] = { player = cs[1], words = inPlay, alive = true, lives = 3, afkMisses = 0, chat = true }
	for i = 2, 4 do
		Match.participants[cs[i]] = { player = cs[i], words = {}, alive = true, lives = 3, afkMisses = 0, chat = true }
	end
	local record3 = fakeCtx(cs, false, nil)
	local since3 = now
	local run3 = oneWordRun(record3)
	at(now + Config.ONE_WORD_PREP_SECONDS + 0.2)
	local chatTalk = lastScreen(since3, "oneWord")
	check("6l a chat participant types for ONE_WORD_CHAT_SECONDS", chatTalk.phase == "talk" and chatTalk.chat == true
		and math.abs(chatTalk.endsAt - now - Config.ONE_WORD_CHAT_SECONDS) < 0.5)
	at(now + 4 * (Config.ONE_WORD_PREP_SECONDS + Config.ONE_WORD_CHAT_SECONDS) + 30)
	local given = {}
	for _, m in screens(since3) do
		if m.payload.kind == "oneWord" then
			given[m.payload.topic] = true
		end
	end
	local onlyClean = true
	for topic in given do
		onlyClean = onlyClean and topic == OneWordTopics[#OneWordTopics]
	end
	check("6m a topic holding a banned word in play is never given (the only clean one, to one performer)", onlyClean
		and given[OneWordTopics[#OneWordTopics]] == true and run3.done)
	for _, p in cs do
		Match.participants[p] = nil
	end
	check("6n the topic list has 60 topics, none empty or repeated", (function()
		local seen = {}
		for _, topic in OneWordTopics do
			if topic == "" or seen[topic] then
				return false
			end
			seen[topic] = true
		end
		return #OneWordTopics >= 60
	end)())

	-- 6E: a performer who flies during the performances is not offered; a voter who leaves during the vote no longer
	-- counts (their vote with them).
	local es = newPlayers(7)
	local alive = table.clone(es)
	local flyingNow = {}
	local record5 = fakeCtx(alive, false, flyingNow)
	local since5 = now
	local begun5 = now
	local run5 = oneWordRun(record5)
	local ids5 = lastScreen(since5, "oneWord").ids
	local function byId(id)
		for _, p in es do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	at(now + Config.ONE_WORD_PREP_SECONDS + 1)
	local flier = byId(ids5[1])
	flyingNow[flier] = true -- launched (a banned word in bundle 5) while talking
	at(now + Config.FLING_RETURN_SECONDS)
	flyingNow[flier] = nil -- back on the chair long before the judging
	at(begun5 + turnSeconds(Config.ONE_WORD_MAX_PERFORMERS) + 0.5) -- the judging (the fake presenter does not pick)
	local offeredFlier = false
	for _, option in record5.pickOptions or {} do
		offeredFlier = offeredFlier or option.id == tostring(flier.UserId)
	end
	check("6o a performer who flew during the performances is not offered (even back on the chair)",
		record5.pickOptions ~= nil and not offeredFlier)
	local vote5 = lastScreen(since5, "vote")
	local c1, c2 = byId(vote5.ids[1]), byId(vote5.ids[2])
	local others = {}
	for _, p in es do
		if not table.find(ids5, p.UserId) then
			table.insert(others, p) -- the two who did not perform
		end
	end
	local c3 = byId(vote5.ids[3])
	local c4 = byId(vote5.ids[4])
	answer(others[1], 1)
	answer(others[2], 1)
	answer(c3, 1)
	answer(c4, 2)
	answer(c1, 2)
	table.remove(alive, table.find(alive, others[1])) -- leaves during the vote: c1 2 - 2 c2, a tie
	at(now + Config.VOTE_SECONDS + 1)
	check("6p a voter who leaves during the vote no longer counts (here: a tie, nobody flies)", c2 ~= nil
		and vote5.endsAt > now - Config.VOTE_SECONDS and #record5.fails == 0)
	at(now + 5)
	check("6q (and it ends)", run5.done)

	-- 6F (bundle 6b): the bells first; who rang first speaks first (among those who spoke least); the floor per turn;
	-- without a presenter it is played with VOTE_MIN_VOTERS.
	Match.presenter = nil
	local bs = newPlayers(Config.VOTE_MIN_VOTERS + 1)
	local record6 = fakeCtx(bs, false, { [bs[1]] = true })
	record6.rings = { { bs[4], bs[2] } }
	local since6 = now
	local run6 = oneWordRun(record6)
	local call = record6.bellCalls[1]
	local ids6 = lastScreen(since6, "oneWord").ids
	local bellScreen = lastScreen(since6, "oneWordBell")
	check("6r the bells of everyone on the ground open first (BELL_ORDER_SECONDS); who rang first speaks first",
		call ~= nil and #call.from == #bs - 1 and not table.find(call.from, bs[1]) and call.seconds == Config.BELL_ORDER_SECONDS
		and call.firstOnly == false and bellScreen ~= nil and ids6[1] == bs[4].UserId and ids6[2] == bs[2].UserId)
	at(now + Config.ONE_WORD_PREP_SECONDS + 0.5)
	local floorDuring = record6.floors[#record6.floors]
	at(now + Config.ONE_WORD_SECONDS)
	check("6s each performer has the floor while they speak, given back after the turn", floorDuring == bs[4]
		and record6.floors[2] == false)
	at(now + 4 * (Config.ONE_WORD_PREP_SECONDS + Config.ONE_WORD_SECONDS) + 1)
	check("6t without a presenter (enough players) it is played: the vote follows", lastScreen(since6, "vote") ~= nil)
	at(now + Config.VOTE_SECONDS + 5)
	check("6u (and it ends)", run6.done)
	Match.presenter = nil
end

---------------------------------------------------------------- 7. the bell quiz (bundle 6b)
do
	local BellQuiz = Quiz.bell
	local presenter = newPlayers(1)[1]
	QuizBank.main = { q("하나", "정답", "나", "다", "라"), q("둘", "정답", "바", "사", "아"), q("셋", "정답", "차", "카", "타") } -- (drawn in any order)
	Match.presenter = presenter
	local ps = newPlayers(3)
	local record = fakeCtx(ps, false, nil)
	-- Question 1: ps[1] rings, right. Question 2: ps[2] wrong, then ps[3] with no verdict, then nobody. Question 3: no
	-- ring at all -> everyone answers with four choices.
	record.rings = { { ps[1] }, { ps[2] }, { ps[3] }, {}, {} }
	local verdicts = { "right", "wrong", nil }
	local calls = 0
	record.verdict = function(_answer)
		calls += 1
		return verdicts[calls]
	end
	local since = now
	local run = start(BellQuiz, record)
	at(now + 0.5)
	local first = record.verdicts[1]
	check("7a the first ring answers; the presenter judges with the right answer shown; right -> a point, no launch",
		record.bellCalls[1] ~= nil and record.bellCalls[1].firstOnly == true and #record.bellCalls[1].from == 3
		and first ~= nil and first.answer == "정답" and first.seconds == Config.BELL_ANSWER_SECONDS + Config.BELL_VERDICT_SECONDS
		and #record.scores == 1 and record.scores[1].player == ps[1] and record.scores[1].amount == Config.SCORE_BELL_QUIZ
		and #record.fails == 0 and record.floors[1] == ps[1] and record.floors[2] == false)
	at(now + Config.QUIZ_REVEAL_SECONDS + 0.5)
	local f = record.fails[1]
	local second, third = record.bellCalls[3], record.bellCalls[4]
	check("7b wrong -> a subjective launch and the bells open again without them; no verdict in time -> no launch",
		f ~= nil and f.subjective == true and #f.players == 1 and f.players[1] == ps[2] and #record.fails == 1
		and second ~= nil and #second.from == 2 and not table.find(second.from, ps[2])
		and third ~= nil and #third.from == 1 and third.from[1] == ps[1])
	at(now + Config.QUIZ_REVEAL_SECONDS + 0.5)
	local quiz = lastScreenOf(since, "quiz")
	check("7c nobody rings at all -> that question goes to everyone with four choices", quiz ~= nil and quiz.question ~= nil
		and #quiz.choices == 4 and #record.bellCalls == 5)
	at(now + Config.QUIZ_INTRO_SECONDS + Config.QUIZ_SECONDS + Config.QUIZ_REVEAL_SECONDS + 1)
	check("7d (it ends after BELL_QUIZ_QUESTIONS questions)", run.done and run.ok == true)
	-- Without a presenter the questions go to everyone; a protected player's wrong answer does not launch them.
	Match.presenter = nil
	local record2 = fakeCtx(ps, false, nil)
	local since2 = now
	local run2 = start(BellQuiz, record2)
	at(now + 0.5)
	check("7e no presenter (any more) -> the questions go to everyone with four choices", #record2.bellCalls == 0
		and lastScreenOf(since2, "quiz") ~= nil)
	record2.cancel = true
	at(now + Config.QUIZ_INTRO_SECONDS + Config.QUIZ_SECONDS + 1)
	Match.presenter = presenter
	local record3 = fakeCtx(ps, false, nil)
	record3.protected = { [ps[2]] = true }
	record3.rings = { { ps[2] }, {} }
	record3.verdict = function() return "wrong" end
	local run3 = start(BellQuiz, record3)
	at(now + 0.5)
	check("7f a player a subjective launch may not hit (public limits) is not launched for a wrong answer", #record3.fails == 0)
	record3.cancel = true
	at(now + 2)
	check("7g (cancelled runs end)", run2.done and run3.done)
	-- The presenter leaves before anyone answered a question: that question goes to everyone with four choices.
	local record4 = fakeCtx(ps, false, nil)
	record4.rings = { { ps[1] } }
	record4.verdict = function()
		Match.presenter = nil -- gone while ps[1] answers: no verdict
		return nil
	end
	local since4 = now
	local run4 = start(BellQuiz, record4)
	at(now + Config.QUIZ_INTRO_SECONDS + 0.5)
	check("7h the presenter gone mid-question: that question goes to everyone with four choices", lastScreenOf(since4, "quiz") ~= nil)
	record4.cancel = true
	at(now + Config.QUIZ_SECONDS + 2)
	check("7i the time budget covers the longest run (every answer chance with its own bells, by chat, judged last)",
		BellQuiz.expectedSeconds >= Config.BELL_QUIZ_QUESTIONS * (Config.BELL_TRIES * (Config.BELL_WAIT_SECONDS
			+ Config.BELL_ANSWER_CHAT_SECONDS + Config.BELL_VERDICT_SECONDS) + Config.QUIZ_REVEAL_SECONDS) and run4.done)
	Match.presenter = nil
	QuizBank.main = realMain
end

---------------------------------------------------------------- 8. crocodile teeth (bundle 6c)
do
	local ps = newPlayers(3)
	local function byId(id)
		for _, p in ps do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	local record = fakeCtx(ps, false, nil)
	local since = now
	local run = start(Crocodile, record)
	local pressedBy = {}
	local strangerIgnored = nil
	local guard = 0
	while not run.done and guard < 20 and not lastScreenOf(since, "crocResult") do
		guard += 1
		local shown = lastScreenOf(since, "croc")
		local current = byId(shown.ids[shown.current])
		local tooth = 1
		while shown.down[tooth] do
			tooth += 1
		end
		if strangerIgnored == nil then
			answer(if current == ps[1] then ps[2] else ps[1], tooth) -- not their turn
			at(now + 0.1)
			strangerIgnored = lastScreenOf(since, "croc").current == shown.current and #record.fails == 0
		end
		answer(current, tooth)
		table.insert(pressedBy, { player = current, tooth = tooth })
		at(now + 0.3)
	end
	local result = lastScreenOf(since, "crocResult")
	local lastPress = pressedBy[#pressedBy]
	local f = record.fails[1]
	check("8a crocodile teeth: turns in a drawn order, only the one whose turn it is presses; the hidden tooth bites them",
		strangerIgnored == true and result ~= nil and lastPress ~= nil and result.bad == lastPress.tooth and f ~= nil
		and #f.players == 1 and f.players[1] == lastPress.player and f.subjective == nil)
	local unique = true
	local seen = {}
	for _, press in pressedBy do
		unique = unique and not seen[press.tooth]
		seen[press.tooth] = true
	end
	check("8b teeth stay down (never pressed twice); it always ends within CROC_TEETH presses", unique
		and #pressedBy <= Config.CROC_TEETH)
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	local record2 = fakeCtx(ps, false, nil)
	local since2 = now
	local run2 = start(Crocodile, record2)
	local first = lastScreenOf(since2, "croc")
	at(now + Config.CROC_TURN_SECONDS + 0.5)
	local late = record2.fails[1]
	check("8c too late on your turn: you fly (and it counts as a missed answer)", late ~= nil
		and late.players[1].UserId == first.ids[first.current] and record2.missed ~= nil and #record2.missed == 1)
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	check("8d (both runs end)", run.done and run2.done)
	-- A press on a tooth already down is ignored (the turn goes on); someone flying when their turn comes is skipped.
	local flying = {}
	local record3 = fakeCtx(ps, false, flying)
	local since3 = now
	local run3 = start(Crocodile, record3)
	local ignored, skipped = nil, nil
	for _ = 1, 12 do
		local shown = lastScreenOf(since3, "croc")
		if lastScreenOf(since3, "crocResult") or not shown then
			break
		end
		local current = byId(shown.ids[shown.current])
		local downTooth = table.find(shown.down, true)
		if downTooth and ignored == nil then
			answer(current, downTooth)
			at(now + 0.3)
			local again = lastScreenOf(since3, "croc")
			ignored = again.current == shown.current and #record3.fails == 0
		end
		if ignored ~= nil and skipped == nil then
			flying[current] = true -- launched on their turn: skipped, no tooth goes down
			at(now + 0.5)
			local after = lastScreenOf(since3, "croc")
			skipped = after.current ~= shown.current and #record3.fails == 0
			flying[current] = nil
			break
		end
		local tooth = 1
		while shown.down[tooth] do
			tooth += 1
		end
		answer(current, tooth)
		at(now + 0.3)
	end
	check("8e a press on a tooth already down is ignored; a player flying on their turn is skipped",
		(ignored == nil or ignored == true) and (skipped == nil or skipped == true) and (ignored ~= nil or run3.done))
	record3.cancel = true
	at(now + 1)
end

---------------------------------------------------------------- 9. the bomb (bundle 6c)
do
	local ps = newPlayers(3)
	local function byId(id)
		for _, p in ps do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	local function rightOf(shown) -- (the choices come in a random order: find the right one by its text)
		for _, question in BombBank do
			if question.q == shown.question then
				return table.find(shown.choices, question.choices[question.answer]) or 1
			end
		end
		return 1
	end
	local record = fakeCtx(ps, false, nil)
	local since = now
	local run = start(BombPass, record)
	local first = lastScreenOf(since, "bomb")
	local holder1 = byId(first.ids[first.holder])
	answer(holder1, 3 - rightOf(first)) -- wrong
	at(now + 0.3)
	local locked = lastScreenOf(since, "bomb")
	at(now + Config.BOMB_ANSWER_SECONDS)
	local afterWrong = lastScreenOf(since, "bomb")
	answer(byId(afterWrong.ids[afterWrong.holder]), rightOf(afterWrong)) -- right
	at(now + 0.3)
	local afterRight = lastScreenOf(since, "bomb")
	check("9a wrong keeps the bomb: the rest of that question's time first, then a new question; right passes it on",
		locked.id == first.id and afterWrong.ids[afterWrong.holder] == holder1.UserId and afterWrong.question ~= first.question
		and afterRight.holder == first.holder % #first.ids + 1)
	check("9f the question timer sent to clients is always BOMB_ANSWER_SECONDS (the bang stays on the server)",
		first.shownEndsAt == nil and math.abs(first.endsAt - (since + Config.BOMB_ANSWER_SECONDS)) < 0.5)
	local untilAt = now + Config.BOMB_MAX_SECONDS + 5
	while not lastScreenOf(since, "bombResult") and now < untilAt do
		at(now + 0.25)
	end
	local result = lastScreenOf(since, "bombResult")
	local f = record.fails[1]
	check("9b it goes off between BOMB_MIN_SECONDS and BOMB_MAX_SECONDS; whoever holds it flies", result ~= nil and f ~= nil
		and f.players[1].UserId == result.ids[result.holder] and now - since >= Config.BOMB_MIN_SECONDS - 0.5
		and now - since <= Config.BOMB_MAX_SECONDS + 1)
	check("9c who held it and never answered missed an answer; who answered did not", record.missed ~= nil
		and record.answered ~= nil and table.find(record.answered, holder1) ~= nil and table.find(record.missed, holder1) == nil)
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	check("9d (it ends)", run.done)
	-- A holder who starts flying hands it on at once.
	local flying = {}
	local record2 = fakeCtx(ps, false, flying)
	local since2 = now
	local run2 = start(BombPass, record2)
	local held = lastScreenOf(since2, "bomb")
	flying[byId(held.ids[held.holder])] = true
	at(now + 0.5)
	local handed = lastScreenOf(since2, "bomb")
	check("9g a holder who starts flying hands the bomb on at once", handed.holder ~= held.holder)
	record2.cancel = true
	at(now + 1)
	local _ = run2
	local bankOk = #BombBank >= 40
	local seenQ = {}
	for _, question in BombBank do
		bankOk = bankOk and #question.choices == 2 and question.answer >= 1 and question.answer <= 2 and not seenQ[question.q]
		seenQ[question.q] = true
	end
	check("9e the bomb bank: two choices each, the answer one of them, no question twice", bankOk)
end

---------------------------------------------------------------- 10. nunchi (bundle 6c)
do
	local ps = newPlayers(4)
	local a, b, c, d = ps[1], ps[2], ps[3], ps[4]
	local function play(rings, times)
		local record = fakeCtx(ps, false, nil)
		record.rings = { rings }
		record.ringTimes = times
		local run = start(Nunchi, record)
		at(now + Config.MINIGAME_RESULT_SECONDS + 1)
		return record, run
	end
	-- (ring times are relative to now: the fake bells answer at once, as if the game had just been played)
	local clash = play({ a, b, c }, { [a] = now - 3, [b] = now - 2.7, [c] = now - 1 })
	local f = clash.fails[1]
	check("10a two rings within NUNCHI_WINDOW clash: both fly", f ~= nil and #f.players == 2 and table.find(f.players, a) ~= nil
		and table.find(f.players, b) ~= nil and clash.bellCalls[1].seconds == Config.NUNCHI_MAX_SECONDS
		and clash.bellCalls[1].enough ~= nil and #clash.bellCalls[1].from == 4)
	local last = play({ a, b, c }, { [a] = now - 2.6, [b] = now - 1.6, [c] = now - 0.6 })
	local f2 = last.fails[1]
	check("10b no clash: the one who never rang flies (not an AFK miss)", f2 ~= nil and #f2.players == 1 and f2.players[1] == d
		and last.missed ~= nil and #last.missed == 0)
	local idle = play({ a }, { [a] = now - Config.NUNCHI_IDLE_SECONDS - 1 })
	local f3 = idle.fails[1]
	check("10c too long without a ring: everyone who did not ring flies (and missed an answer)", f3 ~= nil and #f3.players == 3
		and not table.find(f3.players, a) and idle.missed ~= nil and #idle.missed == 3)
	local three = Nunchi.clash({ a, b, c, d }, { [a] = 0, [b] = 0.2, [c] = 0.45, [d] = 3 })
	check("10d the window counts from the first ring of a number: three at once all clash", three ~= nil and #three == 3)
	local tooFew = start(Nunchi, fakeCtx({ a, b }, false, nil))
	at(now + 0.5)
	check("10e fewer than NUNCHI_MIN_PLAYERS on the ground: it does not start", tooFew.done and tooFew.played == false)
	-- Everyone rang (the last in the very last moment, no clash): the last to ring is the last.
	local all = play({ a, b, c, d }, { [a] = now - 3.6, [b] = now - 2.6, [c] = now - 1.6, [d] = now - 1.05 })
	local f4 = all.fails[1]
	check("10f everyone rang with no clash (the last just in the final moment): the last to ring flies", f4 ~= nil
		and #f4.players == 1 and f4.players[1] == d)
	-- The game's own "settled" rule, asked at chosen moments: a clash closes only when its window is over (a third ring
	-- inside it still clashes); all but one rang -> closes after the window; long quiet -> closes.
	local probe = fakeCtx(ps, false, nil)
	probe.rings = { {} }
	start(Nunchi, probe)
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	local settle = probe.bellCalls[1].enough
	local t0 = now
	local inWindow = settle({ a, b }, { [a] = t0 - 0.2, [b] = t0 - 0.1 })
	local afterWindow = settle({ a, b }, { [a] = t0 - 0.6, [b] = t0 - 0.5 })
	local threeLeftOneOpen = settle({ a, b, c }, { [a] = t0 - 3, [b] = t0 - 2, [c] = t0 - 0.2 })
	local threeLeftOneDone = settle({ a, b, c }, { [a] = t0 - 3, [b] = t0 - 2, [c] = t0 - 0.6 })
	local quiet = settle({ a }, { [a] = t0 - Config.NUNCHI_IDLE_SECONDS - 0.1 })
	local busy = settle({ a }, { [a] = t0 - 1 })
	check("10g the bells close at the right moments: a clash after its window, all but one after the window, long quiet",
		inWindow == false and afterWindow == true and threeLeftOneOpen == false and threeLeftOneDone == true
		and quiet == true and busy == false)
end

---------------------------------------------------------------- 11. the balance game (bundle 6d)
do
	local ps = newPlayers(4)
	local record = fakeCtx(ps, false, nil)
	record.rings = { { ps[1], ps[2], ps[3], ps[4] } }
	local since = now
	local run = start(Balance, record)
	local untilAt = now + 30
	while now < untilAt do
		local shown = lastScreenOf(since, "balance")
		if shown and shown.stage == "pick" then
			break
		end
		at(now + 0.25)
	end
	local talkers = {}
	for _, floorHolder in record.floors do
		if floorHolder then
			table.insert(talkers, floorHolder)
		end
	end
	answer(ps[1], 1)
	answer(ps[1], 2) -- changed: the last pick counts
	answer(ps[2], 2)
	answer(ps[3], 1)
	-- ps[4] picks nothing
	at(now + Config.BALANCE_PICK_SECONDS + 0.5)
	local f = record.fails[1]
	check("11a the first BALANCE_TALKERS to ring argue on the floor in turn", #talkers == Config.BALANCE_TALKERS
		and talkers[1] == ps[1] and talkers[2] == ps[2] and talkers[3] == ps[3])
	check("11b a pick may change until the time is up; the smaller side flies, and so does whoever did not pick (a miss)",
		f ~= nil and #f.players == 2 and table.find(f.players, ps[3]) ~= nil and table.find(f.players, ps[4]) ~= nil
		and record.missed ~= nil and #record.missed == 1 and record.missed[1] == ps[4])
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	-- A tie: nobody flies.
	local record2 = fakeCtx(ps, false, nil)
	local since2 = now
	local run2 = start(Balance, record2)
	local untilAt2 = now + 30
	while now < untilAt2 do
		local shown = lastScreenOf(since2, "balance")
		if shown and shown.stage == "pick" then
			break
		end
		at(now + 0.25)
	end
	answer(ps[1], 1)
	answer(ps[2], 1)
	answer(ps[3], 2)
	answer(ps[4], 2)
	at(now + Config.BALANCE_PICK_SECONDS + 0.5)
	local f2 = record2.fails[1]
	check("11c a tie: nobody flies", f2 ~= nil and #f2.players == 0)
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	check("11d (both end)", run.done and run2.done)
end

---------------------------------------------------------------- 12. red light, green light (bundle 6d)
do
	local ps = newPlayers(5)
	local a, b, c, d, e = ps[1], ps[2], ps[3], ps[4], ps[5]
	local realLights = RedLight.lights
	local t0 = now
	-- Fixed lights for the test: green 0-5 s, red 5-10 s, green 10-30 s.
	RedLight.lights = function(startAt, _rng)
		return { { light = "green", from = startAt, to = startAt + 5 }, { light = "red", from = startAt + 5, to = startAt + 10 },
			{ light = "green", from = startAt + 10, to = startAt + 30 } }
	end
	local presses = {}
	for i = 1, Config.REDLIGHT_GOAL do
		table.insert(presses, { player = a, at = t0 + 0.1 + i * 0.18 }) -- a reaches the goal on green
	end
	for i = 1, 5 do
		table.insert(presses, { player = b, at = t0 + i * 0.3 })
	end
	table.insert(presses, { player = b, at = t0 + 6 }) -- b moves on red
	for i = 1, 5 do
		table.insert(presses, { player = d, at = t0 + i * 0.3 }) -- d is short of the goal
	end
	for i = 1, 10 do
		table.insert(presses, { player = e, at = t0 + i * 0.3 })
	end
	table.insert(presses, { player = e, at = t0 + 5.2 }) -- e within the grace of the red light: not caught
	for i = 1, Config.REDLIGHT_GOAL - 10 do
		table.insert(presses, { player = e, at = t0 + 10 + i * 0.3 }) -- ...and reaches the goal on the next green
	end
	table.sort(presses, function(x, y) return x.at < y.at end)
	local record = fakeCtx(ps, false, nil)
	record.bellOverride = function(_from, seconds, _firstOnly, enough, repeatEvery)
		record.repeatEvery = repeatEvery
		record.bellSeconds = seconds
		local rung, times = {}, {}
		for _, press in presses do
			if not times[press.player] then
				table.insert(rung, press.player)
				times[press.player] = press.at
			end
		end
		if enough then
			enough(rung, times, presses)
		end
		return rung, times, presses
	end
	local run = start(RedLight, record)
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	RedLight.lights = realLights
	local f = record.fails[1]
	local function has(player)
		return f ~= nil and table.find(f.players, player) ~= nil
	end
	check("12a a press on red (after the grace) is out; short of the goal flies; the goal is safe; within the grace is not caught",
		f ~= nil and has(b) and has(c) and has(d) and not has(e) and not has(a))
	check("12b the bells count at most REDLIGHT_MAX_PRESS a second, for REDLIGHT_SECONDS", record.repeatEvery ~= nil
		and math.abs(record.repeatEvery - 1 / Config.REDLIGHT_MAX_PRESS) < 1e-9 and record.bellSeconds == Config.REDLIGHT_SECONDS)
	check("12c who never pressed missed an answer (only them)", record.missed ~= nil and #record.missed == 1 and record.missed[1] == c)
	local phases = RedLight.lights(1000, Random.new(3))
	local alternating, covers = true, phases[#phases].to >= 1000 + Config.REDLIGHT_SECONDS
	for i, phase in phases do
		alternating = alternating and phase.light == (if i % 2 == 1 then "green" else "red")
	end
	check("12d the lights alternate, green first, and cover REDLIGHT_SECONDS", alternating and covers and run.done)
end

---------------------------------------------------------------- 13. the liar (bundle 6d)
do
	local presenter = newPlayers(1)[1]
	local ps = newPlayers(4)
	playerList = { presenter, ps[1], ps[2], ps[3], ps[4] }
	Match.presenter = presenter
	local function play(pick, guessRight, votesFor)
		local record = fakeCtx(ps, false, nil)
		local since = now
		record.startedAt = now
		local run = start(Liar, record)
		at(now + 0.2)
		local liar, wordTo, liarSawWord, presenterWord = nil, {}, false, nil
		for _, m in NetStub.sent do
			if m.name == "Mission" and m.at >= since and m.to and m.payload.kind == "liar" then
				if m.payload.liar then
					liar = m.to
					liarSawWord = liarSawWord or m.payload.word ~= nil
				elseif m.payload.word then
					wordTo[m.to] = m.payload.word
					if m.to == presenter then
						presenterWord = m.payload.word
					end
				end
			end
		end
		local shared = nil -- the screen everyone gets (not someone's own)
		for _, m in NetStub.sent do
			if m.name == "Mission" and m.at >= since and not m.to and m.payload.kind == "liar" then
				shared = m.payload
			end
		end
		record.pick = function(options)
			record.accuseOptions = options
			return pick(options, liar)
		end
		local untilAt = now + 120
		while now < untilAt and not lastScreenOf(since, "liarGuess") and not lastScreenOf(since, "liarResult")
			and not lastScreenOf(since, "vote") do
			at(now + 0.25)
		end
		local vote = lastScreenOf(since, "vote")
		if vote and votesFor then
			for _, p in ps do
				answer(p, table.find(vote.ids, votesFor(liar).UserId) or 1)
			end
			at(now + 0.5)
			local untilVote = now + Config.VOTE_SECONDS + 1
			while now < untilVote and not lastScreenOf(since, "liarGuess") and not lastScreenOf(since, "liarResult") do
				at(now + 0.25)
			end
		end
		local guess = lastScreenOf(since, "liarGuess")
		if guess then
			local word = nil
			for _, w in wordTo do
				word = w
			end
			local index = table.find(guess.choices, word)
			answer(liar, if guessRight then index else (index % #guess.choices) + 1)
		end
		at(now + Config.LIAR_GUESS_SECONDS + Config.MINIGAME_RESULT_SECONDS + 1)
		return record, run, liar, wordTo, liarSawWord, presenterWord, shared, guess
	end
	-- The presenter names the liar; the liar guesses wrong -> the liar flies.
	local r1, run1, liar1, words1, sawWord1, presenterWord1, shared1, guess1 = play(function(_options, liar)
		return tostring(liar.UserId)
	end, false)
	local wordCount = 0
	for _ in words1 do
		wordCount += 1
	end
	check("13a the word goes only to the players who may see it (the three others and the presenter); the liar is told, never sent the word; the shared screen has no word",
		liar1 ~= nil and not sawWord1 and wordCount == 4 and presenterWord1 ~= nil and shared1 ~= nil and shared1.word == nil
		and words1[liar1] == nil, string.format("liar %s sawWord %s words %d presenter %s shared %s", tostring(liar1 and liar1.Name),
		tostring(sawWord1), wordCount, tostring(presenterWord1), tostring(shared1 and shared1.word)))
	check("13b the presenter names the liar (an \"accuse\" menu of everyone on the ground); a wrong guess among four -> the liar flies",
		r1.accuseOptions ~= nil and #r1.accuseOptions == 4 and guess1 ~= nil and #guess1.choices == 4 and r1.fails[1] ~= nil
		and #r1.fails[1].players == 1 and r1.fails[1].players[1] == liar1 and r1.fails[1].subjective == nil and #r1.scores == 0)
	local leverAt = nil
	for _, m in NetStub.sent do
		if m.name == "Lever" and m.at >= r1.startedAt then
			leverAt = m.at
		end
	end
	check("13b2 the lever is pulled LEVER_SECONDS before a wrong-guessing liar flies", leverAt ~= nil and r1.fails[1] ~= nil
		and r1.fails[1].at - leverAt >= Config.LEVER_SECONDS - 1e-6)
	-- Someone else named: nobody flies, the liar scores.
	local r2, _, liar2 = play(function(options, liar)
		for _, option in options do
			if option.id ~= tostring(liar.UserId) then
				return option.id
			end
		end
		return nil
	end, false)
	check("13c someone else named: nobody flies and the liar scores SCORE_LIAR_WIN", r2.fails[1] ~= nil and #r2.fails[1].players == 0
		and #r2.scores == 1 and r2.scores[1].player == liar2 and r2.scores[1].amount == Config.SCORE_LIAR_WIN)
	-- No pick from the presenter: everyone votes for the liar; the liar guesses right -> nobody flies, the liar scores.
	local r3, run3, liar3 = play(function()
		return nil
	end, true, function(liar)
		return liar
	end)
	check("13d no pick: a vote names the liar; a right guess -> nobody flies, the liar scores", r3.fails[1] ~= nil
		and #r3.fails[1].players == 0 and #r3.scores == 1 and r3.scores[1].player == liar3)
	check("13e (the runs end)", run1.done and run3.done)
	Match.presenter = nil
	playerList = {}
	local _ = liar2
end

---------------------------------------------------------------- 14. leaves in the middle, the last presses, a resync (6d review)
do
	-- The balance game: 3 start, one leaves during the talk -> too few: no penalty, no misses.
	local ps = newPlayers(3)
	local alive = table.clone(ps)
	local record = fakeCtx(alive, false, nil)
	record.rings = { { ps[1], ps[2], ps[3] } }
	local run = start(Balance, record)
	at(now + 1)
	table.remove(alive, table.find(alive, ps[3]))
	at(now + Config.BALANCE_TALKERS * Config.BALANCE_TALK_CHAT_SECONDS + Config.BALANCE_PICK_SECONDS + 5)
	check("14a balance: below BALANCE_MIN_PLAYERS in the middle -> ends with no penalty", run.done and #record.fails == 0
		and record.missed == nil)

	-- Red light: presses the bells took after the last check still count (here: a's last steps reach the goal).
	local qs = newPlayers(2)
	local a, b = qs[1], qs[2]
	local t0 = now
	local realLights = RedLight.lights
	RedLight.lights = function(startAt, _rng)
		return { { light = "green", from = startAt, to = startAt + Config.REDLIGHT_SECONDS } }
	end
	local presses = {}
	for i = 1, Config.REDLIGHT_GOAL do
		table.insert(presses, { player = a, at = t0 + i * 0.3 })
		table.insert(presses, { player = b, at = t0 + i * 0.3 + 0.1 })
	end
	local record2 = fakeCtx(qs, false, nil)
	record2.bellOverride = function(_from, _seconds, _firstOnly, enough, _repeatEvery)
		local rung, times = { a, b }, { [a] = t0, [b] = t0 }
		if enough then
			enough(rung, times, table.move(presses, 1, #presses - 2, 1, {})) -- (the last check saw all but two)
		end
		return rung, times, presses
	end
	local run2 = start(RedLight, record2)
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	check("14b red light: the presses after the last check count (both reach the goal, nobody flies)", run2.done
		and record2.fails[1] ~= nil and #record2.fails[1].players == 0)

	-- Red light: 2 start, one leaves -> too few: no penalty.
	local alive3 = table.clone(qs)
	local record3 = fakeCtx(alive3, false, nil)
	record3.bellOverride = function(_from, _seconds, _firstOnly, enough, _repeatEvery)
		table.remove(alive3, table.find(alive3, b))
		if enough then
			enough({}, {}, {})
		end
		return {}, {}, {}
	end
	local run3 = start(RedLight, record3)
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	RedLight.lights = realLights
	check("14c red light: below REDLIGHT_MIN_PLAYERS -> ends with no penalty", run3.done and #record3.fails == 0)

	-- The liar: the liar leaves during the clues -> no penalty, no points; a resync sends the liar no word and the
	-- others theirs.
	local presenter = newPlayers(1)[1]
	local ls = newPlayers(5)
	local aliveL = table.clone(ls)
	playerList = { presenter, ls[1], ls[2], ls[3], ls[4], ls[5] }
	Match.presenter = presenter
	local record4 = fakeCtx(aliveL, false, nil)
	local since = now
	local run4 = start(Liar, record4)
	at(now + 0.2)
	local liar = nil
	for _, m in NetStub.sent do
		if m.name == "Mission" and m.at >= since and m.to and m.payload.kind == "liar" and m.payload.liar then
			liar = m.to
		end
	end
	local other = if ls[1] ~= liar then ls[1] else ls[2]
	local mark = #NetStub.sent
	MissionRunner.sendScreen(liar)
	MissionRunner.sendScreen(other)
	local liarGot, otherGot = nil, nil
	for i = mark + 1, #NetStub.sent do
		local m = NetStub.sent[i]
		if m.name == "Mission" and m.to == liar then
			liarGot = m.payload
		elseif m.name == "Mission" and m.to == other then
			otherGot = m.payload
		end
	end
	check("14d a resync: the liar gets their own screen without the word, another player theirs with it",
		liarGot ~= nil and liarGot.liar == true and liarGot.word == nil and otherGot ~= nil and otherGot.word ~= nil)
	at(now + Config.LIAR_READ_SECONDS + Config.LIAR_BELL_SECONDS + 2)
	table.remove(aliveL, table.find(aliveL, liar))
	at(now + 5 * Config.LIAR_CLUE_CHAT_SECONDS + Config.PRESENTER_JUDGE_SECONDS + Config.VOTE_SECONDS + 20)
	check("14e the liar leaves in the middle -> ends with no penalty and no points", run4.done and #record4.fails == 0
		and #record4.scores == 0)
	local mark2 = #NetStub.sent
	MissionRunner.sendScreen(other)
	local after = nil
	for i = mark2 + 1, #NetStub.sent do
		local m = NetStub.sent[i]
		if m.name == "Mission" and m.to == other then
			after = m.payload
		end
	end
	check("14f after the game no private screen is left to resend", after == nil or after.word == nil)
	Match.presenter = nil
	playerList = {}
end

print(if fails == 0 then "ALL PASS" else fails .. " FAILED")
