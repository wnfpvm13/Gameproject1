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
	local record = { fails = {}, answered = nil, missed = nil, shows = {}, cancel = false }
	record.ctx = {
		final = final,
		players = function() return alive end,
		rng = Random.new(7),
		fail = function(players, key, subjective)
			table.insert(record.fails, { players = players, key = key, subjective = subjective })
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

	-- Menu order from a fresh round: the quiz, the roulette (once), then quizzes; the roulette needs two players.
	QuizBank.main = realMain
	QuizBank.final = realFinal
	MissionRunner.beginRound()
	local order = {}
	for _ = 1, 4 do
		local pickNow = nil
		for _, m in MissionRunner.candidates(300, 4, false) do
			if m.id ~= "test" then -- (the Studio test mission is listed too; leave it out)
				pickNow = m
				break
			end
		end
		table.insert(order, if pickNow then pickNow.id else "none")
		if pickNow then
			start(pickNow, fakeCtx(newPlayers(4), false, nil))
			at(now + 30)
		end
	end
	check("3d automatic order: quiz, roulette, then quizzes (the roulette once a round)", order[1] == "quiz"
		and order[2] == "roulette" and order[3] == "quiz" and order[4] == "quiz", table.concat(order, ","))
	MissionRunner.beginRound()
	local small = MissionRunner.candidates(300, 1, false)
	local rouletteListed = false
	for _, m in small do
		rouletteListed = rouletteListed or m.id == "roulette"
	end
	check("3e the roulette is not offered with fewer than ROULETTE_MIN_PLAYERS alive", not rouletteListed)
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

	-- 6A: no presenter -> it does not start.
	Match.presenter = nil
	local nobody = fakeCtx(newPlayers(4), false, nil)
	local idle = oneWordRun(nobody)
	at(now + 1)
	check("6a without a presenter it does not start (and says it played nothing)", idle.done and idle.played == false
		and OneWord.needsPresenter == true)

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
	Match.presenter = nil
end

print(if fails == 0 then "ALL PASS" else fails .. " FAILED")
