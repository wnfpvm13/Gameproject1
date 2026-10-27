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
local Nunchi = require(node("Nunchi"))
local Balance = require(node("Balance"))
local RedLight = require(node("RedLight"))
local Liar = require(node("Liar"))

local fails = 0
Config.QUIZ_SHUFFLE = false -- (these tests answer by place; one test below turns it on)
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
		verdicts = {}, scores = {}, heads = {}, chatHandler = nil }
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
		bell = function(from, seconds, firstOnly, enough, repeatEvery, quiet)
			record.bellQuiet = quiet == true
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
		-- Bundle 9c: the words over the heads (each call recorded) and the chat watcher (a test calls it).
		heads = function(words, known)
			table.insert(record.heads, { words = words and table.clone(words), known = known and table.clone(known) })
		end,
		chat = function(handler)
			record.chatHandler = handler
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
	-- Bundle 12: first everyone's answers over their heads (no right answer yet, nobody failed), then the result.
	local picking = screens(since)
	local picksShown = picking[#picking].payload
	local p = picksShown.picks or {}
	check("1l when the time is up everyone's answer shows first (numbered; none = ?), without the right one and before"
		.. " any fail", picksShown.kind == "quizResult" and picksShown.answer == nil and #record.fails == 0
		and p[tostring(ps[1].UserId)].text == "1" and p[tostring(ps[2].UserId)].text == "3"
		and p[tostring(ps[3].UserId)].text == "?" and p[tostring(ps[4].UserId)] == nil
		and p[tostring(ps[1].UserId)].verdict == nil)
	at(now + Config.PICKS_SECONDS)
	local f = record.fails[1]
	check("1c a wrong answer or none fails; the right one, a flying player, early, repeated, malformed or old-question answers do not",
		#record.fails == 1 and f.key == "answer" and #f.players == 2 and has(f.players, ps[2]) and has(f.players, ps[3])
		and not has(f.players, ps[1]) and not has(f.players, ps[4]))
	check("1d the AFK rule hears who answered and who did not (flying players are neither)", has(record.answered, ps[1])
		and has(record.answered, ps[2]) and has(record.missed, ps[3]) and #record.missed == 1
		and not has(record.answered, ps[4]))
	local shown = screens(since)
	local result = shown[#shown].payload
	local rp = result.picks or {}
	check("1e then everyone sees the right answer, the answers over the heads turned right / wrong", result.kind == "quizResult"
		and result.answer == 1 and rp[tostring(ps[1].UserId)].verdict == "right"
		and rp[tostring(ps[2].UserId)].verdict == "wrong" and rp[tostring(ps[3].UserId)].verdict == "wrong")
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
	at(now + Config.PICKS_SECONDS + 0.5)
	check("1g when everyone asked has answered, the answer shows at once (after the answers over the heads)", #record2.fails == 1 and #record2.fails[1].players == 0
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
	at(now + Config.PICKS_SECONDS + 1)
	local s4 = screens(since4)
	local stillShown = not run4.done and s4[#s4].payload.kind == "quizResult"
	at(now + Config.QUIZ_REVEAL_SECONDS)
	check("1j a result that decides the round still stays on screen for its reveal time", stillShown and run4.done)
	local record5 = fakeCtx({ ps[1], ps[2] }, false, nil)
	record5.ctx.fail = function(_players, _key)
		record5.stop = true -- a new round began
	end
	local run5 = start(Quiz, record5)
	at(now + Config.QUIZ_INTRO_SECONDS + Config.QUIZ_SECONDS + Config.PICKS_SECONDS + 0.5)
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
		fresh == "quiz,roulette,twenty,croc,bomb,nunchi,balance,redLight,liar,timeGuess,duel,bottle,chosung,oxQuiz,estimate"
		and afterQuiz
			== "roulette,twenty,croc,bomb,nunchi,balance,redLight,liar,timeGuess,duel,bottle,chosung,oxQuiz,estimate,quiz"
		and afterRoulette
			== "twenty,croc,bomb,nunchi,balance,redLight,liar,timeGuess,duel,bottle,chosung,oxQuiz,estimate,quiz",
		fresh .. " | " .. afterQuiz .. " | " .. afterRoulette)
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
	local offShipped = listed("bannedTalk") -- (owner 2026-10-25: 머리 위 스무고개 replaces it)
	Config.TALK_GAME_ON = true
	local onWith = listed("bannedTalk")
	local inFinal = false
	for _, m in { MissionRunner.finalMission() } do
		inFinal = inFinal or m.id == "bannedTalk"
	end
	Config.TALK_GAME_ON = false
	Match.voiceJudging = false
	check("3i the banned-word talk is off in the shipped game (TALK_GAME_ON); on, only while speech judging is on (never"
		.. " in the final)", not offWithout and not offShipped and onWith and not inFinal)
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
	-- Measured (Codex review 2026-10-27): the slowest 바보 mode run — every bell open its full time, every answer by chat
	-- judged at the last moment, and the presenter gone at the very last verdict (four choices for everyone, nobody
	-- answers) — ends within the mode's budget.
	local realEasy = QuizBank.easy
	QuizBank.easy = QuizBank.main
	Match.mode = "easy"
	Match.presenter = presenter
	for _, p in ps do
		Match.participants[p] = { player = p, words = {}, alive = true, lives = 3, afkMisses = 0, chat = true }
	end
	local record5 = fakeCtx(ps, false, nil)
	record5.bellOverride = function(from, seconds)
		task.wait(seconds)
		return { from[1] }, { [from[1]] = 1 }, {}
	end
	local verdicts5 = 0
	record5.verdict = function(_answer)
		verdicts5 += 1
		task.wait(record5.verdicts[#record5.verdicts].seconds)
		if verdicts5 == Config.BELL_QUIZ_QUESTIONS * Config.BELL_TRIES then
			Match.presenter = nil
			return nil
		end
		return "wrong"
	end
	local since5 = now
	local run5 = start(BellQuiz, record5)
	local budget5 = BellQuiz.expectedFor(#ps, "easy")
	while not run5.done and now < since5 + budget5 + 60 do
		at(now + 0.5)
	end
	check(string.format("7j the slowest 바보 run (presenter gone at the last verdict) fits its budget (%.1f of %d s)",
		now - since5, budget5), run5.done and now - since5 <= budget5 + 0.5 and verdicts5 == 9
		and lastScreenOf(since5, "quiz") ~= nil)
	check("7k the bell quiz's budget grows with the mode's answer time",
		BellQuiz.expectedFor(3, "easy") > BellQuiz.expectedFor(3, "normal")
			and BellQuiz.expectedFor(3, "normal") > BellQuiz.expectedFor(3, "hard"))
	for _, p in ps do
		Match.participants[p] = nil
	end
	Match.mode = nil
	Match.presenter = nil
	QuizBank.easy = realEasy
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

---------------------------------------------------------------- 9. the bomb (bundle 6c; a pass button, owner 2026-10-25)
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
	local run = start(BombPass, record)
	local first = lastScreenOf(since, "bomb")
	local holder1 = byId(first.ids[first.holder])
	answer(holder1, 1) -- (too early: no pass is open yet)
	at(now + 0.3)
	local still = lastScreenOf(since, "bomb")
	at(now + Config.BOMB_HOLD_MAX)
	local lit = lastScreenOf(since, "bomb")
	answer(holder1, 1)
	at(now + 0.3)
	local passed = lastScreenOf(since, "bomb")
	check("9a the bomb comes with the button off; it lights within BOMB_HOLD_MIN-MAX and a press passes it to the next",
		first.id == nil and still.id == nil and still.holder == first.holder and lit.id ~= nil
		and lit.holder == first.holder and passed.holder == first.holder % #first.ids + 1
		and #first.choices == 1 and first.choices[1] == Config.TEXT.BOMB_PASS)
	check("9f the time sent with the button is BOMB_MAX_SECONDS ahead (the bang stays on the server)",
		lit.shownEndsAt == nil and math.abs(lit.endsAt - (since + Config.BOMB_MAX_SECONDS)) < 0.5)
	local untilAt = now + Config.BOMB_MAX_SECONDS + 5
	while not lastScreenOf(since, "bombResult") and now < untilAt do
		at(now + 0.25)
	end
	local result = lastScreenOf(since, "bombResult")
	local f = record.fails[1]
	local loser = if result then byId(result.ids[result.holder]) else nil
	check("9b it goes off between BOMB_MIN_SECONDS and BOMB_MAX_SECONDS; whoever holds it flies", result ~= nil and f ~= nil
		and f.players[1] == loser and now - since >= Config.BOMB_MIN_SECONDS - 0.5
		and now - since <= Config.BOMB_MAX_SECONDS + 1)
	check("9c who pressed did not miss an answer; who held the lit button BOMB_IDLE_SECONDS and never pressed did",
		record.answered ~= nil and table.find(record.answered, holder1) ~= nil and table.find(record.missed or {}, holder1) == nil
		and loser ~= holder1 and table.find(record.missed or {}, loser) ~= nil)
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
do
	-- Review 2026-10-25: a talker who leaves gives the floor back at once (the others were kept muted for the rest).
	local ps = newPlayers(4)
	local record = fakeCtx(ps, false, nil)
	record.rings = { { ps[1], ps[2], ps[3] } }
	local run = start(Balance, record)
	local untilAt = now + 30
	while now < untilAt and record.floors[1] ~= ps[1] do
		at(now + 0.1)
	end
	local gotAt = now
	at(now + 1)
	ps[1].Parent = nil
	at(now + 0.5)
	check("11e a talker who leaves gives the floor back at once", record.floors[1] == ps[1] and record.floors[2] == false
		and now - gotAt < Config.BALANCE_TALK_SECONDS)
	record.cancel = true
	at(now + 30)
	check("11f (ends)", run.done)
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

---------------------------------------------------------------- 15. between games (owner 2026-10-24)
do
	MissionRunner.beginRound()
	local rng = Random.new(11)
	local ballot = MissionRunner.ballot(600, 4, rng, "quiz")
	local ids, distinct = {}, true
	for _, m in ballot do
		distinct = distinct and not ids[m.id]
		ids[m.id] = true
	end
	check("15a the ballot: NEXT_VOTE_CHOICES different games, never the one just played", #ballot == Config.NEXT_VOTE_CHOICES
		and distinct and not ids.quiz)
	local small = MissionRunner.ballot(600, 2, rng, nil)
	local allowed = #small > 0
	for _, m in small do
		allowed = allowed and (m.minPlayers or 0) <= 2 and not m.needsPresenter
	end
	check("15b the ballot offers only games that may run now (enough players, no presenter needed)", allowed)
	check("15c nothing fits the time left -> an empty ballot", #MissionRunner.ballot(5, 4, rng, nil) == 0)

	local voters = newPlayers(3)
	local result = nil
	local since = now
	task.spawn(function()
		result = MissionRunner.vote(ballot, "recap!", voters, Random.new(3), function() return false end)
	end)
	at(now + 0.3)
	local screen = lastScreenOf(since, "nextVote")
	answer(voters[1], 2)
	answer(voters[2], 2)
	answer(newPlayers(1)[1], 1) -- not a voter: does not count
	answer(voters[3], 1)
	at(now + 0.5)
	check("15d the vote shows the recap and the choices, ends once everyone voted, the most votes win", screen ~= nil
		and screen.recap == "recap!" and #screen.choices == #ballot and screen.choices[1] == ballot[1].title
		and screen.endsAt ~= nil and result == ballot[2] and now - since < 1.5)

	local seen, inBallot, slow = {}, true, false
	for seed = 1, 12 do
		local r = nil
		local started = now
		task.spawn(function()
			-- (seeds spread out: the fake Random's first draw from a small seed is always small)
			r = MissionRunner.vote(ballot, "", voters, Random.new(seed * 104729 + 17), function() return false end)
		end)
		at(now + Config.NEXT_VOTE_SECONDS + 0.3)
		inBallot = inBallot and r ~= nil and table.find(ballot, r) ~= nil
		slow = slow or now - started < Config.NEXT_VOTE_SECONDS
		if r then
			seen[r.id] = true
		end
	end
	local kinds = 0
	for _ in seen do
		kinds += 1
	end
	check("15e nobody votes: after NEXT_VOTE_SECONDS one of the ballot at random", inBallot and not slow and kinds >= 2,
		string.format("inBallot %s slow %s kinds %d", tostring(inBallot), tostring(slow), kinds))

	local tieOk = true
	for seed = 1, 8 do
		local r = nil
		local gone = newPlayers(1)[1]
		local group = { voters[1], voters[2], gone }
		task.spawn(function()
			r = MissionRunner.vote(ballot, "", group, Random.new(seed * 104729 + 17), function() return false end)
		end)
		at(now + 0.2)
		answer(voters[1], 1)
		answer(voters[2], 3)
		gone.Parent = nil -- left: not waited for
		at(now + 0.5)
		tieOk = tieOk and (r == ballot[1] or r == ballot[3])
	end
	check("15f a tie: one of the tied at random; a voter who left is not waited for", tieOk)

	local stopped = false
	local r2 = "running" :: any
	task.spawn(function()
		r2 = MissionRunner.vote(ballot, "", voters, Random.new(1), function() return stopped end)
	end)
	at(now + 0.5)
	stopped = true
	at(now + 0.5)
	check("15g the vote ends when the main game does (it still names a game)", r2 ~= "running" and table.find(ballot, r2) ~= nil)

	local briefed = nil
	local since2 = now
	task.spawn(function()
		briefed = MissionRunner.brief(Quiz, 2, Config.ROUND_GAMES, "recap?", function() return false end)
	end)
	at(now + 0.3)
	local shown = lastScreenOf(since2, "brief")
	local early = briefed
	at(since2 + Config.BRIEF_SECONDS + 0.3)
	check("15h the briefing: the game's name, its rule, its number, a 3-2-1; then the screen is left for the game",
		shown ~= nil and shown.title == Quiz.title and shown.rule == Quiz.brief and shown.rule ~= "" and shown.game == 2
		and shown.games == Config.ROUND_GAMES and shown.recap == "recap?" and early == nil and briefed == true
		and lastScreenOf(since2, "none") ~= nil)
	local stopNow = false
	local b2 = nil
	task.spawn(function()
		b2 = MissionRunner.brief(Quiz, 1, Config.ROUND_GAMES, "", function() return stopNow end)
	end)
	at(now + 0.5)
	stopNow = true
	at(now + 0.5)
	check("15i a briefing cut short by the end of the main game says so", b2 == false)
	local everyBrief = true
	for _, mission in { Quiz, Quiz.bell, Roulette, OneWord, Crocodile, BombPass, Nunchi, Balance, RedLight, Liar,
		require(node("BannedTalk")), require(node("TestMission")), require(node("Twenty")) } do
		everyBrief = everyBrief and typeof(mission.brief) == "string" and mission.brief ~= ""
	end
	check("15j every game has a one-line rule for its briefing", everyBrief)
end

---------------------------------------------------------------- 16. timing games (bundle 8b, owner 2026-10-24)
local TimeGuess = require(node("TimeGuess"))
local Duel = require(node("Duel"))
local Bottle = require(node("Bottle"))
local PowerBar = require(node("PowerBar"))
-- A bell stand-in: `pressAt(player, screen)` gives each player's press time (nil = never) from the latest screen.
local function timedBell(record, kind, since, pressAt)
	record.bellOverride = function(from, _seconds, _firstOnly, enough, _repeatEvery)
		local screen = lastScreenOf(since, kind)
		local rung, times, presses = {}, {}, {}
		for _, player in from do
			local at = pressAt(player, screen)
			if at then
				table.insert(rung, player)
				times[player] = at
				table.insert(presses, { player = player, at = at })
			end
		end
		if enough then
			enough(rung, times, presses)
		end
		return rung, times, presses
	end
end
do
	local a, b, c = table.unpack(newPlayers(3))
	check("16a 숫자 맞추기: the farthest from the target flies (ties all); who never rang flies instead",
		#TimeGuess.losers({ a, b, c }, { [a] = 7.30, [b] = 7.0, [c] = 8.0 }, 7.32) == 1
		and TimeGuess.losers({ a, b, c }, { [a] = 7.30, [b] = 7.0, [c] = 8.0 }, 7.32)[1] == c
		and #TimeGuess.losers({ a, b }, { [a] = 7.0, [b] = 8.0 }, 7.5) == 2
		and #TimeGuess.losers({ a, b, c }, { [a] = 7.30, [b] = 9.9 }, 7.32) == 1
		and TimeGuess.losers({ a, b, c }, { [a] = 7.30, [b] = 9.9 }, 7.32)[1] == c)

	local since = now
	local record = fakeCtx({ a, b, c }, false, nil)
	timedBell(record, "timeGuess", since, function(player, screen)
		if player == a then
			return screen.startAt + screen.target + 0.05
		elseif player == b then
			return screen.startAt + screen.target - 0.5
		end
		return nil
	end)
	local run = start(TimeGuess, record)
	at(now + Config.TIMEGUESS_READ_SECONDS + Config.TIMEGUESS_MAX + Config.TIMEGUESS_LATE + Config.MINIGAME_RESULT_SECONDS + 1)
	local first = lastScreenOf(since, "timeGuess")
	local result = lastScreenOf(since, "timeGuessResult")
	local f = record.fails[1]
	local target = first and first.target or 0
	check("16b 숫자 맞추기 runs: a target in 5-10 with two decimals, shown before the clock starts; the one who never rang"
		.. " flies and missed an answer", run.done and first ~= nil and target >= Config.TIMEGUESS_MIN
		and target <= Config.TIMEGUESS_MAX and math.abs(target * 100 - math.round(target * 100)) < 1e-6
		and first.startAt - since >= Config.TIMEGUESS_READ_SECONDS - 0.01 and first.visibleFor == Config.TIMEGUESS_VISIBLE_SECONDS
		and f ~= nil and #f.players == 1 and f.players[1] == c and has(record.missed, c) and not has(record.missed, a)
		and result ~= nil and result.seconds[3] == -1 and math.abs(result.seconds[1] - (target + 0.05)) < 1e-9
		and record.bellQuiet == true)
end
do
	local a, b, c = table.unpack(newPlayers(3))
	local function lose(x, y, reactX, reactY)
		local out = Duel.loserOf(x, y, reactX, reactY)
		local names = {}
		for _, p in out do
			table.insert(names, p.Name)
		end
		table.sort(names)
		return table.concat(names, ",")
	end
	check("16c 총잡이 결투: the slower flies; a false start flies (both: both); who never rang flies; exactly equal: nobody",
		lose(a, b, 0.2, 0.3) == b.Name and lose(a, b, -0.1, 0.3) == a.Name
		and lose(a, b, -0.1, -0.2) == table.concat({ a.Name, b.Name }, ",") and lose(a, b, 0.2, nil) == b.Name
		and lose(a, b, nil, nil) == table.concat({ a.Name, b.Name }, ",") and lose(a, b, 0.2, 0.2) == ""
		and lose(a, b, nil, -1.0) == b.Name)

	-- A bell stand-in that waits for "fire!" (sent at its moment, never ahead) and answers from when it was sent.
	local function duelBell(record, since, offsets)
		record.bellOverride = function(from, _seconds, _firstOnly, enough, _repeatEvery)
			local readyAt = now
			local fireSent = nil
			while not fireSent and now - readyAt < Config.DUEL_READY_MAX + 1 do
				for _, m in screens(since) do
					if m.payload.kind == "duel" and m.payload.stage == "fire" then
						fireSent = m.at
					end
				end
				if not fireSent then
					task.wait(0.05)
				end
			end
			local ready = lastScreenOf(since, "duel")
			local rung, times = {}, {}
			for _, player in from do
				local index = table.find(ready.ids, player.UserId)
				local offset = offsets[index or 0]
				if offset and fireSent then
					table.insert(rung, player)
					times[player] = fireSent + offset
				end
			end
			if enough then
				enough(rung, times, {})
			end
			return rung, times, {}
		end
	end
	local since = now
	local record = fakeCtx({ a, b, c }, false, nil)
	duelBell(record, since, { 0.2, 0.3 })
	local run = start(Duel, record)
	at(now + Config.DUEL_READY_MAX + Config.DUEL_WINDOW + Config.TIMING_GRACE + Config.MINIGAME_RESULT_SECONDS + 1)
	local ready, fire = nil, nil
	for _, m in screens(since) do
		if m.payload.kind == "duel" and m.payload.stage == "ready" then
			ready = m
		elseif m.payload.kind == "duel" and m.payload.stage == "fire" then
			fire = m
		end
	end
	local result = lastScreenOf(since, "duelResult")
	local f = record.fails[1]
	check("16d a duel of three: one pair (the slower flies), the third sits out safe; \"fire!\" sent READY_MIN-MAX after"
		.. " \"ready\" and never told ahead; the screen lists the reactions", run.done and ready ~= nil and fire ~= nil
		and ready.payload.hasBye == true and ready.payload.fireAt == nil
		and fire.at - ready.at >= Config.DUEL_READY_MIN - 0.01 and fire.at - ready.at <= Config.DUEL_READY_MAX + 0.01
		and f ~= nil and #f.players == 1 and f.players[1].UserId == ready.payload.ids[2]
		and result ~= nil and result.ms[1] == 200 and result.ms[2] == 300)

	-- A false start: the other side is safe and not an AFK miss even without ringing.
	local since2 = now
	local record2 = fakeCtx({ a, b }, false, nil)
	duelBell(record2, since2, { -0.4 })
	local run2 = start(Duel, record2)
	at(now + Config.DUEL_READY_MAX + Config.DUEL_WINDOW + Config.TIMING_GRACE + Config.MINIGAME_RESULT_SECONDS + 1)
	local ready2 = lastScreenOf(since2, "duel")
	local result2 = lastScreenOf(since2, "duelResult")
	local f2 = record2.fails[1]
	local starter = ready2 and ready2.ids[1]
	check("16d2 a false start flies alone (shown as negative ms); the other, who never rang, is not counted as AFK",
		run2.done and f2 ~= nil and #f2.players == 1 and f2.players[1].UserId == starter and result2 ~= nil
		and result2.ms[1] <= -1 and result2.ms[2] == false and #(record2.missed or {}) == 0)

	-- The other player leaves: the duel is off (no penalty, nothing to play).
	local since3 = now
	local both = { a, b }
	local record3 = fakeCtx(both, false, nil)
	record3.bellOverride = function(_from, _seconds, _firstOnly, _enough, _repeatEvery)
		table.remove(both, 2)
		return {}, {}, {}
	end
	local run3 = start(Duel, record3)
	at(now + Config.DUEL_READY_MAX + 2)
	check("16d3 the other player leaves: the duel is off, no penalty", run3.done and #record3.fails == 0
		and lastScreenOf(since3, "duelResult") == nil)
end

do
	-- PressTiming: the trip read when the press is seen, capped; half for a start told ahead, all for a signal.
	local PressTiming = require(node("PressTiming"))
	local slow = newPlayers(1)[1]
	local ping = 0.2
	slow.GetNetworkPing = function() return ping end
	local far = newPlayers(1)[1]
	far.GetNetworkPing = function() return 3 end
	local rec = PressTiming.recorder()
	rec.note({ [slow] = 10, [far] = 10 })
	ping = 0.4 -- (changed after the press was seen: must not move it)
	check("16h PressTiming: a press counts from when it was made — half the round trip for a start told ahead, the whole"
		.. " round trip for a signal sent at its moment; read when seen; capped at TIMING_PING_CAP",
		math.abs(rec.pressedAt(slow, 10) - 9.9) < 1e-9 and math.abs(rec.reactedAt(slow, 10) - 9.8) < 1e-9
		and math.abs(rec.reactedAt(far, 10) - (10 - Config.TIMING_PING_CAP)) < 1e-9)
end
do
	local a, b, c = table.unpack(newPlayers(3))
	check("16e 물병 세우기: the fewest standing fly; everyone the same: nobody", #Bottle.losers({ a, b, c }, { [a] = 2, [b] = 1, [c] = 1 }) == 2
		and #Bottle.losers({ a, b, c }, { [a] = 2, [b] = 2, [c] = 2 }) == 0
		and #Bottle.losers({ a, b }, { [a] = 0, [b] = 0 }) == 0)
	local p = Config.BOTTLE_PERIOD
	check("16f the power bar goes 0 -> 1 -> 0 once a period (and stays at 0 before it starts)",
		PowerBar.at(0, p) == 0 and math.abs(PowerBar.at(p / 4, p) - 0.5) < 1e-9 and math.abs(PowerBar.at(p / 2, p) - 1) < 1e-9
		and math.abs(PowerBar.at(3 * p / 4, p) - 0.5) < 1e-9 and PowerBar.at(-1, p) == 0)

	local since = now
	local throw = 0
	local record = fakeCtx({ a, b, c }, false, nil)
	-- a always hits the zone's middle; b hits it twice then stops at the far end; c never rings.
	timedBell(record, "bottle", since, function(player, screen)
		if player == a then
			return screen.barStartAt + screen.center * p / 2
		elseif player == b then
			local far = if screen.center < 0.5 then p / 2 else 0
			return screen.barStartAt + (if screen.throw < 3 then screen.center * p / 2 else far)
		end
		return nil
	end)
	local run = start(Bottle, record)
	at(now + Bottle.expectedSeconds + 2)
	local throws = {}
	for _, m in screens(since) do
		if m.payload.kind == "bottleThrow" then
			table.insert(throws, m.payload)
		end
	end
	local result = lastScreenOf(since, "bottleResult")
	local f = record.fails[1]
	local zones = true
	for _, m in screens(since) do
		if m.payload.kind == "bottle" then
			throw += 1
			zones = zones and m.payload.width == Config.BOTTLE_ZONES[throw]
				and m.payload.center - m.payload.width / 2 >= Config.BOTTLE_EDGE - 1e-9
				and m.payload.center + m.payload.width / 2 <= 1 - Config.BOTTLE_EDGE + 1e-9
		end
	end
	check("16g 물병 세우기 runs: three throws with narrower zones; stood 3, 2, 0 -> the one at 0 flies and missed an answer",
		run.done and throw == #Config.BOTTLE_ZONES and zones and #throws == #Config.BOTTLE_ZONES
		and throws[3].landed[1] == true and throws[3].landed[2] == false and result ~= nil
		and result.stood[1] == 3 and result.stood[2] == 2 and result.stood[3] == 0
		and f ~= nil and #f.players == 1 and f.players[1] == c and has(record.missed, c) and not has(record.missed, b))
end

---------------------------------------------------------------- 17. more quiz kinds (bundle 8c, owner 2026-10-24)
local Hangul = require(node("Hangul"))
local ChosungBank = require(node("ChosungBank"))
local OXBank = require(node("OXBank"))
local EstimateBank = require(node("EstimateBank"))
local OXQuiz = require(node("OXQuiz"))
local Estimate = require(node("Estimate"))
check("17a 초성: a word's initial consonants (spaces and other characters kept)", Hangul.initials("바나나") == "ㅂㄴㄴ"
	and Hangul.initials("택배 기사") == "ㅌㅂ ㄱㅅ" and Hangul.initials("까치") == "ㄲㅊ" and Hangul.initials("A1") == "A1")
check("17a2 초성 on screen: lone consonants bigger and spaced (RichText), the rest escaped; nil without any",
	Hangul.richInitials("과일 · ㅂㄴㄴ", 44) == '과일 · <font size="44">ㅂ ㄴ ㄴ</font>'
	and Hangul.richInitials("a<b & ㄱ", 30) == 'a&lt;b &amp; <font size="30">ㄱ</font>'
	and Hangul.richInitials("1/3 · 0은 짝수다", 44) == nil
	and Hangul.richInitials("직업 · ㅌㅂ ㄱㅅ", 40) == '직업 · <font size="40">ㅌ ㅂ   ㄱ ㅅ</font>'
	and Hangul.richInitials("ㄱ 다", 40) == '<font size="40">ㄱ</font> 다')
do
	local rng = Random.new(12345)
	local ok, seen = true, 0
	for _ = 1, 40 do
		local q = Quiz.chosung.question(rng, {})
		if q then
			seen += 1
			local right = q.choices[q.answer]
			local initials = Hangul.initials(right)
			local distinct = {}
			for _, c in q.choices do
				distinct[c] = true
			end
			local count = 0
			for _ in distinct do
				count += 1
			end
			ok = ok and #q.choices == 4 and count == 4 and string.find(q.q, initials, 1, true) ~= nil
			for i, c in q.choices do
				ok = ok and (i == q.answer or Hangul.initials(c) ~= initials)
			end
		else
			ok = false
		end
	end
	local avoided = true
	for _ = 1, 20 do
		local q = Quiz.chosung.question(rng, { "바나나" })
		for _, c in (q and q.choices or {}) do
			avoided = avoided and c ~= "바나나"
		end
	end
	check("17b 초성 questions: four different words of one category, only the right one has the initials shown; a word"
		.. " in play is never on screen", ok and seen == 40 and avoided)
	local banks = true
	for _, entry in ChosungBank do
		local initials = {}
		for _, word in entry.words do
			initials[Hangul.initials(word)] = true
		end
		local n = 0
		for _ in initials do
			n += 1
		end
		banks = banks and n >= 4 -- (every category can make a question)
	end
	check("17c every 초성 category has words of at least four different initials", banks and #ChosungBank > 0)
end
do
	local a, b, c = table.unpack(newPlayers(3))
	check("17d O/X: the most wrong fly (ties all), nobody when nobody got any wrong",
		#OXQuiz.losers({ a, b, c }, { [a] = 2, [b] = 1, [c] = 2 }) == 2 and #OXQuiz.losers({ a, b }, {}) == 0
		and OXQuiz.losers({ a, b, c }, { [b] = 1 })[1] == b)
	local o, x = 0, 0
	for _, s in OXBank do
		if s.o then
			o += 1
		else
			x += 1
		end
	end
	check("17e the O/X bank: enough statements, both answers well represented", #OXBank >= 30 and o >= 10 and x >= 10)
	do
		local rng, seen, order = Random.new(99), {}, {}
		for _ = 1, math.ceil(#OXBank / Config.OX_QUESTIONS) + 1 do
			for _, s in OXQuiz.draw(Config.OX_QUESTIONS, rng) do
				table.insert(order, s)
			end
		end
		local distinct = true
		for i = 1, #OXBank do
			distinct = distinct and order[i] ~= nil and not seen[order[i]]
			if order[i] then
				seen[order[i]] = true
			end
		end
		local each = true
		for start = 1, #order, Config.OX_QUESTIONS do -- (and one draw never holds the same statement twice)
			local inDraw = {}
			for i = start, math.min(#order, start + Config.OX_QUESTIONS - 1) do
				each = each and not inDraw[order[i]]
				inDraw[order[i]] = true
			end
		end
		check("17e2 the O/X draw asks every clean statement once before any comes back (the last few first, then the"
			.. " rest), never one twice in a game", distinct and each)
	end

	local since = now
	local record = fakeCtx({ a, b, c }, false, nil)
	local run = start(OXQuiz, record)
	-- a answers right every time, b wrong every time, c never
	for _ = 1, Config.OX_QUESTIONS do
		at(now + Config.OX_INTRO_SECONDS + 0.2)
		local shown = nil
		for i = #NetStub.sent, 1, -1 do
			local m = NetStub.sent[i]
			if m.name == "Mission" and m.payload.kind == "quiz" and m.payload.id then
				shown = m.payload
				break
			end
		end
		local statement = nil
		for _, s in OXBank do
			if shown and string.find(shown.question, s.s, 1, true) then
				statement = s
			end
		end
		local right = if statement and statement.o then 1 else 2
		answer(a, right)
		answer(b, 3 - right)
		at(now + Config.OX_SECONDS + Config.PICKS_SECONDS + Config.OX_REVEAL_SECONDS)
	end
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	local result = lastScreenOf(since, "oxResult")
	local f = record.fails[1]
	check("17f O/X runs: OX_QUESTIONS statements on the quiz screen; the most wrong (here two tied) fly; who never"
		.. " answered missed", run.done and result ~= nil and result.wrong[1] == 0 and result.wrong[2] == Config.OX_QUESTIONS
		and result.wrong[3] == Config.OX_QUESTIONS and f ~= nil and #f.players == 2 and has(record.missed, c)
		and not has(record.missed, b))
	-- Bundle 12: each statement's answers over the heads first (O / X, none = ?), then turned right / wrong.
	local before, after = nil, nil
	for _, m in screens(since) do
		if m.payload.kind == "quizResult" and m.payload.picks then
			if m.payload.answer == nil then
				before = before or m.payload
			else
				after = after or m.payload
			end
		end
	end
	local bp, ap = before and before.picks or {}, after and after.picks or {}
	local aKey, bKey, cKey = tostring(a.UserId), tostring(b.UserId), tostring(c.UserId)
	check("17o O/X: each statement's O / X over the heads before its answer (none = ?), then right / wrong",
		before ~= nil and after ~= nil and (bp[aKey].text == "O" or bp[aKey].text == "X") and bp[aKey].text ~= bp[bKey].text
		and bp[cKey].text == "?" and bp[aKey].verdict == nil and ap[aKey].verdict == "right" and ap[bKey].verdict == "wrong"
		and ap[cKey].verdict == "wrong")
end
do
	local a, b, c = table.unpack(newPlayers(3))
	check("17g 숫자 근사: the farthest from the answer flies (ties all; nobody when everyone hit it); who typed nothing"
		.. " flies instead",
		#Estimate.losers({ a, b, c }, { [a] = 150, [b] = 300, [c] = 250 }, 200) == 1
		and Estimate.losers({ a, b, c }, { [a] = 150, [b] = 300, [c] = 250 }, 200)[1] == b
		and #Estimate.losers({ a, b }, { [a] = 100, [b] = 300 }, 200) == 2
		and Estimate.losers({ a, b, c }, { [a] = 100, [b] = 300 }, 200)[1] == c
		and #Estimate.losers({ a, b }, { [a] = 200, [b] = 200 }, 200) == 0)
	local whole = #EstimateBank >= 20
	for _, q in EstimateBank do
		whole = whole and q.answer >= 1 and q.answer % 1 == 0 and q.answer <= Config.ESTIMATE_MAX
	end
	check("17h the number bank: whole answers between 1 and ESTIMATE_MAX (short enough not to carry a phone number)",
		whole and #tostring(Config.ESTIMATE_MAX) <= 6)

	local since = now
	local record = fakeCtx({ a, b, c }, false, nil)
	local run = start(Estimate, record)
	at(now + Config.ESTIMATE_INTRO_SECONDS + 0.2)
	local shown = lastScreenOf(since, "estimate")
	local q = nil
	for _, item in EstimateBank do
		if shown and item.q == shown.question then
			q = item
		end
	end
	local target = if q then q.answer else 1
	answer(a, target)
	answer(b, target + 1000)
	answer(c, 0) -- (out of range: ignored, counts as none)
	at(now + Config.ESTIMATE_SECONDS + Config.PICKS_SECONDS + Config.MINIGAME_RESULT_SECONDS + 1)
	local result = lastScreenOf(since, "estimateResult")
	local f = record.fails[1]
	check("17i the number quiz runs: whole numbers only (0 is not taken); who typed nothing flies and missed an answer",
		run.done and q ~= nil and result ~= nil and result.answer == target and result.guesses[1] == target
		and result.guesses[3] == -1 and f ~= nil and #f.players == 1 and f.players[1] == c and has(record.missed, c))
	local picksFirst = nil
	for _, m in screens(since) do
		if m.payload.kind == "estimate" and m.payload.picks and not picksFirst then
			picksFirst = m.payload
		end
	end
	local fp, rp = picksFirst and picksFirst.picks or {}, result and result.picks or {}
	check("17p 숫자 근사: everyone's number over the heads first (no box, none = ?), then the one who flies turned wrong",
		picksFirst ~= nil and picksFirst.id == nil and fp[tostring(b.UserId)] ~= nil and fp[tostring(c.UserId)].text == "?"
		and rp[tostring(c.UserId)].verdict == "wrong" and rp[tostring(a.UserId)].verdict == "right")
end
do
	-- Codex review 2026-10-27. 숫자 근사: who leaves while the numbers show is looked at again — the farthest of those
	-- still there flies (not the one gone), and too few left ends it without a launch.
	local a, b, c, d = table.unpack(newPlayers(4))
	local alive = { a, b, c, d }
	local record = fakeCtx(alive, false, nil)
	local since = now
	local run = start(Estimate, record)
	at(now + Config.ESTIMATE_INTRO_SECONDS + 0.2)
	local shown = lastScreenOf(since, "estimate")
	local target = 1
	for _, item in EstimateBank do
		if shown and item.q == shown.question then
			target = item.answer
		end
	end
	local sign = if target > 2000 then -1 else 1
	answer(a, target)
	answer(b, target + sign * 10)
	answer(c, target + sign * 1000) -- (the farthest of those who answered; d answers nothing)
	at(now + Config.ESTIMATE_SECONDS + 0.2) -- (everyone's numbers show now)
	table.remove(alive, table.find(alive, d) :: number) -- d leaves while they show
	at(now + Config.PICKS_SECONDS + Config.MINIGAME_RESULT_SECONDS + 1)
	local result = lastScreenOf(since, "estimateResult")
	local f = record.fails[1]
	local rp = result and result.picks or {}
	check("17q 숫자 근사: who left while the numbers showed is not judged; the farthest of the rest flies",
		run.done and f ~= nil and #f.players == 1 and f.players[1] == c and rp[tostring(d.UserId)] == nil
		and not has(record.missed, d))
	local e, g = table.unpack(newPlayers(2))
	local alive2 = { e, g }
	local record2 = fakeCtx(alive2, false, nil)
	local since2 = now
	local run2 = start(Estimate, record2)
	at(now + Config.ESTIMATE_INTRO_SECONDS + 0.2)
	answer(e, 5)
	answer(g, 7)
	at(now + 0.3) -- (both answered: the numbers show)
	table.remove(alive2, table.find(alive2, g) :: number)
	at(now + Config.PICKS_SECONDS + Config.MINIGAME_RESULT_SECONDS + 1)
	check("17r 숫자 근사: too few left after the numbers showed: nobody flies, no result", run2.done
		and #record2.fails == 0 and lastScreenOf(since2, "estimateResult") == nil
		and table.find(record2.shows, Config.TEXT.MINIGAME_TOO_FEW) ~= nil)

	-- O/X: someone in the game but not asked (launched when the statement opened) who is back while the answers show
	-- gets no tag.
	local oa, ob, oc = table.unpack(newPlayers(3))
	local flying = {}
	local record3 = fakeCtx({ oa, ob, oc }, false, flying)
	local since3 = now
	start(OXQuiz, record3) -- (oc on the ground: one of the game's players)
	flying[oc] = true -- (launched before the first statement opens)
	at(now + Config.OX_INTRO_SECONDS + 0.2)
	answer(oa, 1)
	answer(ob, 2)
	at(now + 0.3) -- (both asked answered: the answers show)
	flying[oc] = nil
	at(now + Config.PICKS_SECONDS + 0.2)
	local result3 = nil
	for _, m in screens(since3) do
		if m.payload.kind == "quizResult" and m.payload.answer ~= nil and not result3 then
			result3 = m.payload
		end
	end
	local p3 = result3 and result3.picks or {}
	check("17s O/X: who was not asked gets no right / wrong tag when back during the reveal", result3 ~= nil
		and p3[tostring(oc.UserId)] == nil and p3[tostring(oa.UserId)] ~= nil and p3[tostring(ob.UserId)] ~= nil)
	record3.cancel = true
	at(now + 2)
end
do
	-- Bundle 12 (Codex review 2026-10-27): a quiz answer typed in chat (MissionRunner.chatAnswer; ChatGate hides it).
	QuizBank.main = { q("채팅 질문", "가", "나", "다", "라") }
	local qa, qb, qc, qd = table.unpack(newPlayers(4))
	local record = fakeCtx({ qa, qb, qc, qd }, false, { [qd] = true })
	local since = now
	local run = start(Quiz, record)
	local early = MissionRunner.chatAnswer(qa, "1") -- (the question shows; the answers are not open yet)
	at(now + Config.QUIZ_INTRO_SECONDS + 0.1)
	local open = lastScreenOf(since, "quiz")
	local rightAt = open and table.find(open.choices, "가") or 1
	local wrongAt = if rightAt == 1 then 2 else 1
	local c1 = MissionRunner.chatAnswer(qa, " " .. rightAt .. "번 ")
	local c1b = MissionRunner.chatAnswer(qa, tostring(wrongAt)) -- (a second one: hidden, not counted)
	answer(qa, wrongAt) -- (a button after it: the first answer stays)
	local c2 = MissionRunner.chatAnswer(qb, "아마 " .. wrongAt)
	local c3 = MissionRunner.chatAnswer(qb, "5")
	local c4 = MissionRunner.chatAnswer(qd, tostring(rightAt)) -- (flying: not asked)
	answer(qb, wrongAt)
	at(now + Config.QUIZ_SECONDS + 0.2)
	local picks = nil
	for _, m in screens(since) do
		if m.payload.kind == "quizResult" and m.payload.picks and m.payload.answer == nil then
			picks = m.payload.picks
		end
	end
	local late = MissionRunner.chatAnswer(qc, "1") -- (the time is up)
	local notices = {}
	for _, m in NetStub.sent do
		if m.name == "Notice" and m.to == qa and m.at >= since then
			table.insert(notices, m.payload.text)
		end
	end
	check("17t a 4-choice answer typed in chat (\"3\" or \"3번\") counts, the first one only (a private notice); other"
		.. " lines, other numbers, someone not asked, before or after the answer time: not an answer",
		early == false and c1 == true and c1b == true and c2 == false and c3 == false and c4 == false and late == false
		and picks ~= nil and picks[tostring(qa.UserId)].text == tostring(rightAt)
		and picks[tostring(qb.UserId)].text == tostring(wrongAt) and picks[tostring(qc.UserId)].text == "?"
		and #notices == 2 and notices[1] == string.format(Config.TEXT.CHAT_ANSWERED, tostring(rightAt))
		and notices[2] == Config.TEXT.CHAT_ANSWER_KEPT)
	at(now + Config.PICKS_SECONDS + Config.QUIZ_REVEAL_SECONDS + 1)
	check("17u (and the quiz ends)", run.done)

	local xa, xb, xc = table.unpack(newPlayers(3))
	local record2 = fakeCtx({ xa, xb, xc }, false, nil)
	local since2 = now
	start(OXQuiz, record2)
	at(now + Config.OX_INTRO_SECONDS + 0.2)
	local o1 = MissionRunner.chatAnswer(xa, "o")
	local o2 = MissionRunner.chatAnswer(xb, " X ")
	local o3 = MissionRunner.chatAnswer(xc, "3")
	at(now + Config.OX_SECONDS + 0.2)
	local oxPicks = nil
	for _, m in screens(since2) do
		if m.payload.kind == "quizResult" and m.payload.picks and m.payload.answer == nil and not oxPicks then
			oxPicks = m.payload.picks
		end
	end
	check("17v O/X typed in chat: O / X (either case) count, a 3 does not", o1 == true and o2 == true and o3 == false
		and oxPicks ~= nil and oxPicks[tostring(xa.UserId)].text == "O" and oxPicks[tostring(xb.UserId)].text == "X"
		and oxPicks[tostring(xc.UserId)].text == "?")
	record2.cancel = true
	at(now + 2)

	local ea, eb, ec = table.unpack(newPlayers(3))
	local record3 = fakeCtx({ ea, eb, ec }, false, nil)
	local since3 = now
	start(Estimate, record3)
	at(now + Config.ESTIMATE_INTRO_SECONDS + 0.2)
	local e1 = MissionRunner.chatAnswer(ea, "1,500")
	local e2 = MissionRunner.chatAnswer(eb, "99999999") -- (out of range: hidden, not counted)
	local e3 = MissionRunner.chatAnswer(ec, "약 300")
	at(now + Config.ESTIMATE_SECONDS + 0.2)
	local numbers = nil
	for _, m in screens(since3) do
		if m.payload.kind == "estimate" and m.payload.picks and not numbers then
			numbers = m.payload.picks
		end
	end
	check("17w 숫자 근사 typed in chat: a whole number (commas fine) counts; too big is hidden but not counted",
		e1 == true and e2 == true and e3 == false and numbers ~= nil and numbers[tostring(ea.UserId)].text == "1,500"
		and numbers[tostring(eb.UserId)].text == "?" and numbers[tostring(ec.UserId)].text == "?")
	record3.cancel = true
	at(now + 3)
	QuizBank.main = realMain
end
do
	-- The right O/X answer of the statement on screen now.
	local function oxRight()
		local shown = nil
		for i = #NetStub.sent, 1, -1 do
			local m = NetStub.sent[i]
			if m.name == "Mission" and m.payload.kind == "quiz" and m.payload.id then
				shown = m.payload
				break
			end
		end
		for _, s in OXBank do
			if shown and string.find(shown.question, s.s, 1, true) then
				return if s.o then 1 else 2
			end
		end
		return 1
	end
	local a, b, c, d = table.unpack(newPlayers(4))
	local alive, fly = { a, b, c, d }, {}
	local since = now
	local record = fakeCtx(alive, false, fly)
	local run = start(OXQuiz, record)
	-- 1st: a and c right, b wrong, d silent. Then d leaves and c is launched for the 2nd (a right, b silent; c's try
	-- is ignored). Back for the 3rd: a and b wrong, c right. (Someone silent keeps a question open its full time.)
	at(now + Config.OX_INTRO_SECONDS + 0.2)
	local right = oxRight()
	answer(a, right)
	answer(b, 3 - right)
	answer(c, right)
	at(now + Config.OX_SECONDS + Config.PICKS_SECONDS + Config.OX_REVEAL_SECONDS)
	table.remove(alive, table.find(alive, d))
	fly[c] = true
	at(now + Config.OX_INTRO_SECONDS + 0.2)
	right = oxRight()
	answer(a, right)
	answer(c, 3 - right)
	at(now + Config.OX_SECONDS + Config.PICKS_SECONDS + Config.OX_REVEAL_SECONDS)
	fly[c] = nil
	at(now + Config.OX_INTRO_SECONDS + 0.2)
	right = oxRight()
	answer(a, 3 - right)
	answer(b, 3 - right)
	answer(c, right)
	at(now + Config.OX_SECONDS + Config.PICKS_SECONDS + Config.OX_REVEAL_SECONDS)
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	local result = lastScreenOf(since, "oxResult")
	local f = record.fails[1]
	check("17k O/X: a statement asked while launched does not count for them, who left is not shown; the most wrong"
		.. " still fly", run.done and result ~= nil and #result.ids == 3 and table.find(result.ids, d.UserId) == nil
		and result.wrong[1] == 1 and result.wrong[2] == 3 and result.wrong[3] == 0 and f ~= nil and #f.players == 1
		and f.players[1] == b)
end
do
	-- The number on screen now and its answer.
	local function target(since)
		local shown = lastScreenOf(since, "estimate")
		for _, item in EstimateBank do
			if shown and item.q == shown.question then
				return item.answer
			end
		end
		return 1
	end
	local a, b, c = table.unpack(newPlayers(3))
	local alive = { a, b, c }
	local since = now
	local record = fakeCtx(alive, false, nil)
	local run = start(Estimate, record)
	at(now + Config.ESTIMATE_INTRO_SECONDS + 0.2)
	local answerNow = target(since)
	answer(a, answerNow)
	answer(b, answerNow)
	table.remove(alive, table.find(alive, c)) -- (leaves without typing)
	at(now + Config.ESTIMATE_SECONDS + Config.MINIGAME_RESULT_SECONDS + 1)
	local result = lastScreenOf(since, "estimateResult")
	local nobody = #record.fails == 0 or #record.fails[1].players == 0
	check("17l 숫자 근사: everyone exact flies nobody; who left is neither judged nor shown",
		run.done and result ~= nil and #result.ids == 2 and #result.losers == 0 and nobody
		and table.find(record.shows, string.format(Config.TEXT.ESTIMATE_NOBODY, answerNow)) ~= nil)

	local d, e = table.unpack(newPlayers(2))
	local alive2 = { d, e }
	local since2 = now
	local record2 = fakeCtx(alive2, false, nil)
	local run2 = start(Estimate, record2)
	at(now + Config.ESTIMATE_INTRO_SECONDS + 0.2)
	answer(d, target(since2) + 5)
	table.remove(alive2, table.find(alive2, e)) -- (one left: too few to judge)
	at(now + Config.ESTIMATE_SECONDS + Config.MINIGAME_RESULT_SECONDS + 1)
	local solo = fakeCtx({ d }, false, nil)
	check("17m 숫자 근사 needs ESTIMATE_MIN_PLAYERS on the ground, at the start and at the end (alone the farthest is"
		.. " always you)", run2.done and #record2.fails == 0 and lastScreenOf(since2, "estimateResult") == nil
		and table.find(record2.shows, Config.TEXT.MINIGAME_TOO_FEW) ~= nil and Estimate.run(solo.ctx) == false
		and Estimate.minPlayers == Config.ESTIMATE_MIN_PLAYERS)
end
do
	-- 초성: the wrong choices are the closest (as many syllables when the category has them); a banned category is
	-- left out; with only a few words able to make a question, those keep coming.
	local rng = Random.new(4242)
	local closest = true
	for _ = 1, 60 do
		local q = Quiz.chosung.question(rng, {})
		if q then
			local category = string.match(q.q, "^(.-) · ")
			local right = q.choices[q.answer]
			local initials = Hangul.initials(right)
			local same = 0
			for _, entry in ChosungBank do
				if entry.category == category then
					for _, word in entry.words do
						if utf8.len(word) == utf8.len(right) and Hangul.initials(word) ~= initials then
							same += 1
						end
					end
				end
			end
			local shownSame = 0
			for i, choice in q.choices do
				if i ~= q.answer and utf8.len(choice) == utf8.len(right) then
					shownSame += 1
				end
			end
			closest = closest and shownSame == math.min(3, same)
		else
			closest = false
		end
	end
	local banned = { "동물", "음식", "나라", "직업", "운동", "탈것", "학교 물건" }
	for _, entry in ChosungBank do
		if entry.category == "과일" then
			for _, word in entry.words do
				if not table.find({ "사과", "포도", "딸기", "수박" }, word) then
					table.insert(banned, word)
				end
			end
		end
	end
	local few, asked = true, {}
	for _ = 1, 12 do
		local q = Quiz.chosung.question(rng, banned)
		few = few and q ~= nil and string.match(q.q, "^(.-) · ") == "과일"
		if q then
			asked[q.choices[q.answer]] = true
		end
	end
	check("17n 초성: the closest wrong choices (as many syllables first); banned words and categories left out; a few"
		.. " usable words keep making questions", closest and few and asked["사과"] and asked["포도"] and asked["딸기"]
		and asked["수박"])
end
do
	local everyBrief = true
	for _, mission in { Quiz.chosung, OXQuiz, Estimate } do
		everyBrief = everyBrief and typeof(mission.brief) == "string" and mission.brief ~= ""
			and string.find(mission.brief, "%%") == nil
	end
	check("17j the new quiz kinds have their one-line rules (formatted)", everyBrief)
	local Practice = require(node("TestMission"))
	local off = Practice.available(false)
	workspaceAttributes.BW_TestMission = true
	local on = Practice.available(false)
	workspaceAttributes.BW_TestMission = nil
	check("17o the Studio practice mission plays only with BW_TestMission (an owner's playtest never meets it)",
		not off and on)
end

---------------------------------------------------------------- 18. 머리 위 스무고개 (bundle 9c, owner 2026-10-25)
local Twenty = require(node("Twenty"))
local Judge = require(node("Judge"))
-- The latest "twenty" screen of `stage` since `since`, and who asks in it.
local function twentyScreen(since, stage)
	for i = #NetStub.sent, 1, -1 do
		local m = NetStub.sent[i]
		if m.at < since then
			break
		end
		if m.name == "Mission" and m.to == nil and m.payload.kind == "twenty" and m.payload.stage == stage then
			return m.payload
		end
	end
	return nil
end
local function askerOf(screen, players)
	local userId = screen and screen.ids[screen.asker]
	for _, player in players do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end
local function lastHeads(record)
	return record.heads[#record.heads]
end
do
	-- The words: as many as asked, all of one topic, two letters or more, none inside another; the right count.
	local rng = Random.new(99)
	local good = true
	for _ = 1, 200 do
		local count = rng:NextInteger(2, Config.MAX_PLAYERS)
		local topic, words = Twenty.draw(rng, count)
		local entry = nil
		for _, e in ChosungBank do
			if e.category == topic then
				entry = e
			end
		end
		good = good and entry ~= nil and #words == count
		for i, word in words do
			good = good and table.find(entry and entry.words or {}, word) ~= nil
				and (utf8.len(Judge.normalizeChat(word)) or 0) >= Config.TWENTY_MIN_LETTERS
			for j = i + 1, #words do
				good = good and not Judge.overlaps(word, words[j])
			end
		end
	end
	local none = select(1, Twenty.draw(rng, 40)) == nil
	check("18a 스무고개 words: one topic, all different, two letters or more, none inside another (연필 / 색연필); too many"
		.. " for any topic: none", good and none)
	check("18b the end: 30% of those who began, rounded up (2-3: 1, 4-6: 2, 7-10: 3)", Twenty.needed(2) == 1
		and Twenty.needed(3) == 1 and Twenty.needed(4) == 2 and Twenty.needed(6) == 2 and Twenty.needed(7) == 3
		and Twenty.needed(10) == 3)
	check("18c an answer is right with the same letters (spaces and marks aside), nothing else counts",
		Twenty.isRight("택배기사", "택배 기사") and Twenty.isRight(" 사과! ", "사과") and not Twenty.isRight("사", "사과")
		and not Twenty.isRight("", "사과") and not Twenty.isRight("사과나무", "사과"))
	local a, b = table.unpack(newPlayers(2))
	check("18d writing a hidden word of someone else is a leak; one's own, a known one or none is not",
		Twenty.leaks("이거 사과 아님?", a, { [b] = "사과" }) and not Twenty.leaks("사과?", a, { [a] = "사과" })
		and not Twenty.leaks("사과", a, {}) and not Twenty.leaks("동물이에요?", a, { [b] = "사과" }))
	check("18q a word counts written as a word of its own, maybe with a particle, never inside a longer word (review"
		.. " 2026-10-25: 나라면, 배우고, 나의 자리)", Twenty.writes("사과가 맞아", "사과") and Twenty.writes("그거 사과야?", "사과")
		and Twenty.writes("힌트: 사과!", "사과") and Twenty.writes("택배 기사는", "택배 기사")
		and Twenty.writes("택배기사", "택배 기사") and Twenty.writes("ㅋㅋ 라면", "라면") and not Twenty.writes("나라면 먹어", "라면")
		and not Twenty.writes("이거 배우고 싶다", "배우") and not Twenty.writes("나의 자리", "의자")
		and not Twenty.writes("사과나무", "사과") and not Twenty.writes("사 과", "사과") and not Twenty.writes("", "사과"))
	local skipped = true
	local rng2 = Random.new(5)
	for _ = 1, 300 do
		local _, drawn = Twenty.draw(rng2, Config.MAX_PLAYERS)
		for _, word in drawn do
			skipped = skipped and not table.find(Config.TWENTY_SKIP_WORDS, word)
		end
	end
	check("18r words with an everyday double (사자, 판다, 화가 ...) never play", skipped)
end
do
	-- A game of three: a wrong answer, a right one, the third one's turn still comes (the round ends first, owner rule);
	-- then one right (30% of three) ends it: the result shows first, then the ones never right fly.
	local ps = newPlayers(3)
	local since = now
	local record = fakeCtx(ps, false, nil)
	local run = start(Twenty, record)
	local first = lastHeads(record)
	local intro = twentyScreen(since, "intro")
	local own = first and first.words or {}
	local hidden = first ~= nil and first.known ~= nil and next(first.known) == nil
	at(now + Config.TWENTY_INTRO_SECONDS + 0.2)
	local ask1 = twentyScreen(since, "ask")
	local p1 = askerOf(ask1, ps)
	answer(p1, "틀린 답")
	at(now + 0.3)
	local wrong = twentyScreen(since, "verdict")
	at(now + Config.TWENTY_VERDICT_SECONDS + 0.2)
	local ask2 = twentyScreen(now - 0.5, "ask")
	local p2 = askerOf(ask2, ps)
	answer(p2, own[p2])
	at(now + 0.3)
	local right = twentyScreen(now - 0.5, "verdict")
	at(now + Config.TWENTY_VERDICT_SECONDS + 0.2)
	local ask3 = twentyScreen(now - 0.5, "ask")
	local p3turn = askerOf(ask3, ps)
	answer(p3turn, "또 틀림")
	at(now + 0.3 + Config.TWENTY_VERDICT_SECONDS + 0.3)
	local result = lastScreenOf(since, "twentyResult")
	local shownAt = now
	local beforeReveal = #record.fails
	local mine = {}
	for _, m in NetStub.sent do
		if m.at >= since and m.name == "Mission" and m.to and m.payload.kind == "twentyResult" then
			mine[m.to] = m.payload.myWord
		end
	end
	local p3 = nil
	for _, p in ps do
		if p ~= p1 and p ~= p2 then
			p3 = p
		end
	end
	local fail = record.fails[1]
	check("18e each one a different word, hidden from them; the topic and the order on screen; the asker's turn takes text",
		intro ~= nil and intro.topic ~= nil and #intro.ids == 3 and hidden and own[ps[1]] ~= own[ps[2]]
		and own[ps[2]] ~= own[ps[3]] and ask1 ~= nil and ask1.id ~= nil and ask1.need == 1 and p1 ~= nil)
	check("18f a wrong answer: ❌ on the card (no toast) and the next one asks (the typed text never shows)",
		wrong ~= nil and wrong.verdict == "wrong" and wrong.word == nil and p2 ~= nil and p2 ~= p1
		and table.find(record.shows, string.format(Config.TEXT.TWENTY_WRONG, p1.DisplayName)) == nil)
	at(now + Config.MINIGAME_RESULT_SECONDS + 0.5) -- (the result stays, then the launches and the words go)
	fail = record.fails[1]
	local after = record.heads[#record.heads - 1] -- (the last call takes the words down)
	check("18g a right answer: ⭕ with the word, its owner sees it; the round's last turn still comes; then the result"
		.. " shows and only after it the rest flies once", right ~= nil and right.verdict == "right" and right.word == own[p2]
		and p3turn == p3 and result ~= nil and #result.right == 1 and result.right[1] == p2.UserId and #result.losers == 2
		and beforeReveal == 0 and fail ~= nil and fail.key == "twenty" and fail.at >= shownAt + Config.MINIGAME_RESULT_SECONDS - 0.5
		and #fail.players == 2 and has(fail.players, p1) and has(fail.players, p3) and #record.fails == 1)
	check("18h at the end everyone sees their own word (on their own result too); then the words and the watcher go",
		run.done and after ~= nil and after.known ~= nil and after.known[ps[1]] and after.known[ps[2]] and after.known[ps[3]]
		and mine[ps[1]] == own[ps[1]] and mine[p3] == own[p3] and lastHeads(record).words == nil
		and record.chatHandler == nil and has(record.answered, p1) and has(record.answered, p2)
		and has(record.answered, p3) and #record.missed == 0)
end
do
	-- A leak: writing someone else's word flies the writer at once (also one already right), the owner's word stays
	-- hidden from its owner; one's own word, a flying writer or a known word is nothing. Nobody right: TWENTY_TRIES
	-- rounds of turns, then everyone not right flies (the writer not again).
	local ps = newPlayers(3)
	local flying = {}
	local record = fakeCtx(ps, false, flying)
	local since = now
	local run = start(Twenty, record)
	local own = lastHeads(record).words
	local chat = record.chatHandler
	chat(ps[1], "내 단어 " .. own[ps[1]] .. "?") -- (their own: they do not know it)
	flying[ps[2]] = true
	chat(ps[2], own[ps[3]]) -- (flying: takes no penalty)
	flying[ps[2]] = nil
	local quiet = #record.fails == 0
	chat(ps[1], "힌트 " .. own[ps[2]])
	chat(ps[1], own[ps[3]]) -- (out of this game already, even before the launch)
	at(now + 0.01) -- (the launch comes right after the line)
	local leak = record.fails[1]
	local heads = lastHeads(record)
	check("18i writing another's hidden word flies the writer at once and they see their own word; their own word, a"
		.. " flying writer, or a second line after it costs nothing", quiet and leak ~= nil and #leak.players == 1
		and leak.players[1] == ps[1] and leak.key == "twenty" and heads.known[ps[1]] == true and not heads.known[ps[2]]
		and #record.fails == 1 and table.find(record.shows, string.format(Config.TEXT.TWENTY_LEAK, ps[1].DisplayName)) ~= nil)
	-- nobody answers: the writer's turns are skipped, the others' run out
	local turns = 0
	local skipped = true
	local seen = {}
	at(now + Config.TWENTY_INTRO_SECONDS + 0.1)
	for _ = 1, 2 * Config.TWENTY_TRIES do
		local ask = twentyScreen(now - 0.2, "ask")
		if ask and not seen[ask.id] then
			seen[ask.id] = true
			turns += 1
			skipped = skipped and askerOf(ask, ps) ~= ps[1]
		end
		at(now + Config.TWENTY_TURN_SECONDS + Config.TWENTY_VERDICT_SECONDS)
	end
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	local final = record.fails[2]
	local shown = lastScreenOf(since, "twentyResult")
	check("18j nobody right: TWENTY_TRIES turns each (none for the writer), then everyone not right flies, the writer not"
		.. " again (shown apart)", run.done and turns == 2 * Config.TWENTY_TRIES and skipped and final ~= nil
		and #final.players == 2 and not has(final.players, ps[1]) and has(final.players, ps[2]) and has(final.players, ps[3])
		and shown ~= nil and #shown.leaked == 1 and shown.leaked[1] == ps[1].UserId and #shown.losers == 2)
	local alone = fakeCtx({ ps[1] }, false, nil)
	check("18k too few on the ground: nothing to play", Twenty.run(alone.ctx) == false and #alone.heads == 0)
end
do
	-- Text answers through the answer remote: only on a text question, one to TWENTY_ANSWER_MAX letters, the first
	-- counts; a choice question takes no text.
	local ps = newPlayers(2)
	local record = fakeCtx(ps, false, nil)
	local since = now
	start(Twenty, record)
	at(now + Config.TWENTY_INTRO_SECONDS + 0.2)
	local ask = twentyScreen(since, "ask")
	local asker = askerOf(ask, ps)
	local other = if asker == ps[1] then ps[2] else ps[1]
	answer(other, "남의 차례") -- (not theirs to answer)
	answer(asker, 7) -- (a number on a text question)
	answer(asker, string.rep("가", Config.TWENTY_ANSWER_MAX + 1)) -- (too long)
	at(now + 0.3)
	local stillOpen = twentyScreen(since, "verdict") == nil
	answer(asker, string.rep("가", Config.TWENTY_ANSWER_MAX))
	answer(asker, lastHeads(record).words[asker]) -- (a second answer: not counted)
	at(now + 0.3)
	local verdict = twentyScreen(since, "verdict")
	check("18l a text question takes one text (1 to TWENTY_ANSWER_MAX letters) from the one asked, the first one counts",
		stillOpen and verdict ~= nil and verdict.verdict == "wrong")
	at(now + 200)
	local quiz = fakeCtx(newPlayers(2), false, nil)
	QuizBank.main = { q("글자 답", "가", "나", "다", "라") }
	local qsince = now
	start(Quiz, quiz)
	at(now + Config.QUIZ_INTRO_SECONDS + 0.2)
	for _, p in quiz.ctx.players() do
		answer(p, "가")
	end
	at(now + Config.QUIZ_SECONDS + Config.QUIZ_REVEAL_SECONDS + 1)
	QuizBank.main = realMain
	local wrongAll = quiz.fails[1] ~= nil and #quiz.fails[1].players == 2
	check("18m a choice question takes no text (both count as no answer)", wrongAll and qsince < now)
	-- The time budget counts the players there are: two fit where ten do not.
	MissionRunner.beginRound()
	local function listed(seconds, alive)
		for _, m in MissionRunner.candidates(seconds, alive, false) do
			if m.id == "twenty" then
				return true
			end
		end
		return false
	end
	local two = Twenty.expectedFor and Twenty.expectedFor(2) or 0
	check("18n the time budget counts the players: fits with two, not with ten in the same time",
		listed(two + Config.FLING_RETURN_SECONDS, 2) and not listed(two + Config.FLING_RETURN_SECONDS, 10)
		and not listed(two + Config.FLING_RETURN_SECONDS - 1, 2))
end

do
	-- Four players need two right: the first right one does not end it and gets no more turns; it ends after the
	-- round in which the second one got it.
	local ps = newPlayers(4)
	local record = fakeCtx(ps, false, nil)
	local since = now
	local run = start(Twenty, record)
	local own = lastHeads(record).words
	at(now + Config.TWENTY_INTRO_SECONDS + 0.2)
	local askers, rounds, seenIds = {}, {}, {}
	local firstRight, secondRight = nil, nil
	for _ = 1, 8 do
		local ask = twentyScreen(since, "ask")
		if not ask or seenIds[ask.id] then
			break
		end
		seenIds[ask.id] = true
		local who = askerOf(ask, ps)
		table.insert(askers, who)
		table.insert(rounds, ask.round)
		if ask.round == 1 and not firstRight then
			firstRight = who
			answer(who, own[who])
		elseif ask.round == 2 and not secondRight then
			secondRight = who
			answer(who, own[who])
		else
			answer(who, "모름")
		end
		at(now + 0.3 + Config.TWENTY_VERDICT_SECONDS + 0.3)
	end
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	local rightAgain = false
	for i, who in askers do
		rightAgain = rightAgain or (rounds[i] == 2 and who == firstRight)
	end
	local result = lastScreenOf(since, "twentyResult")
	local fail = record.fails[1]
	check("18o four need two: the first right gets no more turns, the game ends after the round of the second one",
		run.done and #askers == 7 and rounds[4] == 1 and rounds[5] == 2 and rounds[7] == 2 and not rightAgain
		and result ~= nil and #result.right == 2 and fail ~= nil and #fail.players == 2 and not has(fail.players, firstRight)
		and not has(fail.players, secondRight))
end
do
	-- Two lines writing each other's word, arriving together: both count as they arrived (review 2026-10-25), and with
	-- nobody left guessing the game ends.
	local ps = newPlayers(3)
	local record = fakeCtx(ps, false, nil)
	start(Twenty, record)
	local own = lastHeads(record).words
	local chat = record.chatHandler
	chat(ps[1], own[ps[2]])
	chat(ps[2], own[ps[1]])
	at(now + 0.01)
	local first = record.fails[1]
	local second = record.fails[2]
	local told = {}
	for _, m in NetStub.sent do
		if m.name == "Notice" and m.to and own[m.to] and m.payload.text == string.format(Config.TEXT.TWENTY_LEAK_MINE, own[m.to]) then
			told[m.to] = true
		end
	end
	check("18p two leaks arriving together both count (each judged as it arrived) and fly in one launch (one deciding the"
		.. " round cannot drop the other); each writer is told their own word", first ~= nil and second == nil
		and #first.players == 2 and has(first.players, ps[1]) and has(first.players, ps[2]) and told[ps[1]] and told[ps[2]]
		and not told[ps[3]])
	at(now + 200)
end

---------------------------------------------------------------- 19. launch review (bundle 10)
local BalanceBank = require(node("BalanceBank"))
local LiarBank = require(node("LiarBank"))
do
	-- 머리 위 스무고개 only with TWENTY_MAX_PLAYERS alive or fewer (owner 2026-10-26).
	MissionRunner.beginRound()
	local function listed(alive)
		for _, m in MissionRunner.candidates(100000, alive, false) do
			if m.id == "twenty" then
				return true
			end
		end
		return false
	end
	check("19a 스무고개 is offered with TWENTY_MAX_PLAYERS alive, not with one more",
		listed(Config.TWENTY_MAX_PLAYERS) and not listed(Config.TWENTY_MAX_PLAYERS + 1))
	-- Other forms of a word (content/WordAliases): a right answer, a leak; never drawn next to a word one sits in.
	local a, b = newPlayers(2)[1], newPlayers(1)[1]
	check("19b another form of the word is a right answer (돈까스 for 돈가스, 경찰 for 경찰관); a longer word is not",
		Twenty.isRight("돈까스", "돈가스") and Twenty.isRight("경찰", "경찰관") and Twenty.isRight("돈 가스", "돈가스")
		and not Twenty.isRight("경찰차", "경찰관") and not Twenty.isRight("", "돈가스"))
	check("19c writing another form of someone's word in chat is a leak too", Twenty.leaks("이거 돈까스야?", a, { [b] = "돈가스" })
		and Twenty.leaks("헬기 맞지", a, { [b] = "헬리콥터" }) and not Twenty.leaks("헬기 맞지", a, { [a] = "헬리콥터" }))
	local apart = true
	local rng = Random.new(11)
	for _ = 1, 300 do
		local _, drawn = Twenty.draw(rng, Config.TWENTY_MAX_PLAYERS)
		for i, w1 in drawn do
			for j, w2 in drawn do
				if i ~= j then
					for _, f1 in Twenty.forms(w1) do
						for _, f2 in Twenty.forms(w2) do
							apart = apart and string.find(f1, f2, 1, true) == nil
						end
					end
				end
			end
		end
	end
	check("19d no drawn word (or its other forms) sits inside another's", apart)
	-- The quiz's choices come in a new order (the right one moves with them); numbers keep their order.
	Config.QUIZ_SHUFFLE = true
	local moved, kept, rightShown = false, true, true
	for k = 1, 6 do
		QuizBank.main = { q("섞기 " .. k, "정답", "오답1", "오답2", "오답3"), q("숫자 " .. k, "1개", "2개", "3개", "4개") }
		for _ = 1, 2 do
			local ps = newPlayers(1)
			local record = fakeCtx(ps, false, nil)
			record.ctx.rng = Random.new(k * 31)
			local since = now
			start(Quiz, record)
			at(now + Config.QUIZ_INTRO_SECONDS + Config.QUIZ_SECONDS + Config.PICKS_SECONDS + 0.5)
			local result = lastScreenOf(since, "quizResult")
			if result then
				local right = result.choices[result.answer]
				rightShown = rightShown and (right == "정답" or right == "1개")
				if right == "정답" then
					moved = moved or result.answer ~= 1
				else
					kept = kept and result.choices[1] == "1개" and result.choices[4] == "4개"
				end
			end
			at(now + Config.QUIZ_REVEAL_SECONDS + 1)
		end
	end
	Config.QUIZ_SHUFFLE = false
	QuizBank.main = realMain
	check("19e the quiz's choices move (the right one with them); number choices keep their order", moved and kept
		and rightShown)
	-- No balance question or liar word again until every one was played on this server.
	Balance.forgetAsked()
	Liar.forgetPlayed()
	local seenQ, againQ = {}, false
	local rngB = Random.new(3)
	for _ = 1, #BalanceBank do
		local question = Balance.pickQuestion(rngB)
		againQ = againQ or seenQ[question] == true
		seenQ[question] = true
	end
	local seenW, againW, total = {}, false, 0
	for _, entry in LiarBank do
		total += #entry.words
	end
	local rngL = Random.new(4)
	for _ = 1, total do
		local entry, word = Liar.pickWord(rngL)
		local key = entry.category .. "/" .. word
		againW = againW or seenW[key] == true
		seenW[key] = true
	end
	check("19f no balance question or liar word comes again before every one was played", not againQ and not againW)
end
do
	-- The result names who the server counted right (their "correct" sound): not an answer that came after the end.
	QuizBank.main = { q("맞힌 사람", "가", "나", "다", "라") }
	local ps = newPlayers(3)
	local record = fakeCtx(ps, false, nil)
	local since = now
	start(Quiz, record)
	at(now + Config.QUIZ_INTRO_SECONDS + 0.1)
	answer(ps[1], 1)
	answer(ps[2], 2)
	at(now + Config.QUIZ_SECONDS + 0.2)
	answer(ps[3], 1) -- (after the end: not counted)
	at(now + Config.PICKS_SECONDS + 0.2)
	local result = lastScreenOf(since, "quizResult")
	local right = result and result.right or {}
	check("19g the quiz result lists who was counted right (the late answer is not)", #right == 1 and right[1] == ps[1].UserId)
	at(now + Config.QUIZ_REVEAL_SECONDS + 1)
	QuizBank.main = realMain
end

---------------------------------------------------------------- 20. difficulty modes (bundle 11b, owner 2026-10-27)
local Modes = require(node("Modes"))
local OXBankEasy = require(node("OXBankEasy"))
local OXBankHard = require(node("OXBankHard"))
do
	local rng = Random.new(3)
	local tiedOthers = {}
	for _ = 1, 30 do
		tiedOthers[Modes.decide({ easy = 2, hard = 2 }, rng)] = true
	end
	check("20a the mode vote: the most votes win; a tie with the normal mode is normal, another tie is drawn; no votes:"
		.. " normal", Modes.decide({ easy = 2, normal = 1 }, rng) == "easy"
		and Modes.decide({ easy = 1, normal = 1, hard = 1 }, rng) == "normal" and Modes.decide({}, rng) == "normal"
		and tiedOthers.easy == true and tiedOthers.hard == true and tiedOthers.normal == nil)
	check("20b a mode's numbers come from MODE_TUNING, any other (and no mode) from Config",
		Modes.value("easy", "QUIZ_SECONDS") == 15 and Modes.value("hard", "QUIZ_SECONDS") == 7
		and Modes.value("normal", "QUIZ_SECONDS") == Config.QUIZ_SECONDS and Modes.value(nil, "QUIZ_SECONDS") == Config.QUIZ_SECONDS
		and Modes.value("easy", "LIVES") == Config.LIVES and Modes.title("hard") == Config.TEXT.MODE_HARD)
	-- (with the answers over the heads, bundle 12: PICKS_SECONDS a question)
	local quizBase = Config.QUIZ_INTRO_SECONDS + Config.PICKS_SECONDS + Config.QUIZ_REVEAL_SECONDS
	local oxBase = Config.OX_QUESTIONS * (Config.OX_INTRO_SECONDS + Config.PICKS_SECONDS + Config.OX_REVEAL_SECONDS)
		+ Config.MINIGAME_RESULT_SECONDS
	check("20c the time budget counts the mode: a quiz's answer time 15/10/7 s, the O/X quiz's 7/5/4 s a statement, 초성"
		.. " like the quiz", Quiz.expectedFor(5, "easy") == quizBase + 15 and Quiz.expectedFor(5, "normal") == quizBase + 10
		and Quiz.expectedFor(5, "hard") == quizBase + 7 and OXQuiz.expectedFor(5, "easy") == oxBase + 3 * 7
		and OXQuiz.expectedFor(5, "normal") == oxBase + 3 * 5 and OXQuiz.expectedFor(5, "hard") == oxBase + 3 * 4
		and Quiz.chosung.expectedFor(5, "hard") == quizBase + 7)
end
-- One question of `mission` in `mode`: its text and how long its buttons were open.
local function askedIn(mode, final, mission)
	Match.mode = mode
	local ps = newPlayers(2)
	local record = fakeCtx(ps, final, nil)
	local since = now
	local run = start(mission or Quiz, record)
	at(now + Config.QUIZ_INTRO_SECONDS + 0.1)
	local opened = now - 0.1
	local screen = nil
	for _, m in screens(since) do
		if m.payload.kind == "quiz" and m.payload.endsAt then
			screen = m.payload
		end
	end
	at(now + 30)
	record.cancel = true
	at(now + 30)
	Match.mode = nil
	return screen and screen.question, screen and (screen.endsAt - opened), run.done
end
local function inBank(text, bank)
	for _, question in bank do
		if question.q == text then
			return question
		end
	end
	return nil
end
do
	local okEasy, okEasyFinal, okHard, okHardFinal, okBell = true, true, true, true, true
	for _ = 1, 6 do
		okEasy = okEasy and inBank(askedIn("easy", false), QuizBank.easy) ~= nil
		okEasyFinal = okEasyFinal and inBank(askedIn("easy", true), QuizBank.easy) ~= nil
		local hard = askedIn("hard", false)
		okHard = okHard and (inBank(hard, QuizBank.final) ~= nil or inBank(hard, QuizBank.hardMain) ~= nil)
		okHardFinal = okHardFinal and inBank(askedIn("hard", true), QuizBank.hardFinal) ~= nil
		-- (no presenter: the bell quiz asks everyone with four choices — from the same bank it would ring for)
		local bell = inBank(askedIn("easy", false, Quiz.bell), QuizBank.easy)
		okBell = okBell and bell ~= nil and not bell.nonsense
	end
	check("20d the easy mode asks its own bank (the final too), the bell quiz no 넌센스 of it; the hard mode's main game"
		.. " asks the normal final's and hardMain's questions, its final hardFinal's", okEasy and okEasyFinal and okHard
		and okHardFinal and okBell)
	local _, easySeconds = askedIn("easy", false)
	local _, normalSeconds = askedIn(nil, false)
	local _, hardSeconds = askedIn("hard", false)
	check("20e the answer time by mode: 15 / 10 / 7 s", easySeconds ~= nil and math.abs(easySeconds - 15) < 0.3
		and math.abs(normalSeconds - Config.QUIZ_SECONDS) < 0.3 and math.abs(hardSeconds - 7) < 0.3,
		tostring(easySeconds) .. " " .. tostring(normalSeconds) .. " " .. tostring(hardSeconds))
end
do
	-- 20f: a question asked in this round is not asked again in it, even when the server's history starts over.
	local saved = QuizBank.main
	QuizBank.main = { q("하나", "1", "2", "3", "4"), q("둘", "1", "2", "3", "4"), q("셋", "1", "2", "3", "4") }
	Match.roundId = 900
	local first = { askedIn(nil, false), askedIn(nil, false) }
	Match.roundId = 901
	local third = askedIn(nil, false)
	local fourth = askedIn(nil, false)
	local fifth = askedIn(nil, false)
	QuizBank.main = saved
	check("20f a round never asks a question twice: the bank's last fresh one, then (history over) the other two, each"
		.. " once", third ~= nil and not table.find(first, third) and fourth ~= nil and fifth ~= nil and fourth ~= third
		and fifth ~= third and fifth ~= fourth)
	-- 20l: the time budget sees the mode: a quiz fits a normal round's last seconds, not an easy one's; a little less
	-- only a hard one's.
	local quizCore = Config.QUIZ_INTRO_SECONDS + Config.PICKS_SECONDS + Config.QUIZ_REVEAL_SECONDS
	local budget = quizCore + Config.QUIZ_SECONDS + Config.FLING_RETURN_SECONDS
	local function offered(mode)
		Match.mode = mode
		local found = false
		for _, mission in MissionRunner.candidates(budget, 3, false) do
			found = found or mission.id == "quiz"
		end
		Match.mode = nil
		return found
	end
	local normalFits, easyFits = offered(nil), offered("easy")
	budget = quizCore + 7 + Config.FLING_RETURN_SECONDS
	check("20l the time budget counts the mode: the quiz fits a normal round's last seconds, not an easy one's; a little"
		.. " less only a hard one's", normalFits and not easyFits and offered("hard") and not offered(nil))
end
do
	-- 20g: the O/X banks by mode.
	local inEasy, inHard = true, true
	local rng = Random.new(5)
	for _ = 1, 20 do
		Match.mode = "easy"
		for _, statement in OXQuiz.draw(Config.OX_QUESTIONS, rng) do
			inEasy = inEasy and table.find(OXBankEasy, statement) ~= nil
		end
		Match.mode = "hard"
		for _, statement in OXQuiz.draw(Config.OX_QUESTIONS, rng) do
			inHard = inHard and (table.find(OXBankHard, statement) ~= nil or statement.hard == true)
		end
	end
	Match.mode = nil
	check("20g the O/X quiz: the easy mode asks OXBankEasy, the hard mode OXBankHard and the normal statements marked hard",
		inEasy and inHard)
end
do
	-- 20h: 초성 in the easy mode: wrong choices of as many syllables with fewer initials in the same places.
	local function sameSpots(word, other)
		local a, b = {}, {}
		for _, code in utf8.codes(Hangul.initials(word)) do
			table.insert(a, code)
		end
		for _, code in utf8.codes(Hangul.initials(other)) do
			table.insert(b, code)
		end
		local n = 0
		for i = 1, math.min(#a, #b) do
			if a[i] == b[i] then
				n += 1
			end
		end
		return n, #a == #b
	end
	local function measure(mode)
		Match.mode = mode
		local rng = Random.new(11)
		local spots, sameLength, total = 0, 0, 0
		for _ = 1, 150 do
			local question = Quiz.chosung.question(rng, {})
			if question then
				local right = question.choices[question.answer]
				for i, choice in question.choices do
					if i ~= question.answer then
						local n, same = sameSpots(right, choice)
						spots += n
						sameLength += if same then 1 else 0
						total += 1
					end
				end
			end
		end
		Match.mode = nil
		return spots / total, sameLength / total
	end
	local easySpots, easySame = measure("easy")
	local normalSpots, normalSame = measure(nil)
	check("20h 초성 in the easy mode: wrong choices share fewer initials with the answer, mostly of as many syllables",
		easySpots < normalSpots and easySame > 0.6, string.format("%.2f %.2f / %.2f %.2f", easySpots, easySame,
			normalSpots, normalSame))
end
do
	-- 20i: the timing games' numbers by mode, on their screens.
	local function firstScreen(mission, kind, mode)
		Match.mode = mode
		local ps = newPlayers(3)
		local record = fakeCtx(ps, false, nil)
		local since = now
		local run = start(mission, record)
		at(now + 0.5)
		local screen = lastScreenOf(since, kind)
		record.cancel = true
		at(now + 60)
		Match.mode = nil
		return screen, run.done
	end
	local timeEasy = firstScreen(TimeGuess, "timeGuess", "easy")
	local timeHard = firstScreen(TimeGuess, "timeGuess", "hard")
	local redEasy = firstScreen(RedLight, "redLight", "easy")
	local redHard = firstScreen(RedLight, "redLight", "hard")
	local bottleEasy = firstScreen(Bottle, "bottle", "easy")
	local bottleHard = firstScreen(Bottle, "bottle", "hard")
	check("20i the timing games by mode: 숫자 맞추기's clock 4 / 2 s (and its brief), 무궁화's goal 20 / 30, 물병's first"
		.. " zone 0.28 / 0.17 with the easy bar slower", timeEasy ~= nil and timeEasy.visibleFor == 4
		and timeHard ~= nil and timeHard.visibleFor == 2 and string.find(TimeGuess.briefFor("easy"), "4", 1, true) ~= nil
		and redEasy ~= nil and redEasy.goal == 20 and redHard ~= nil and redHard.goal == 30 and bottleEasy ~= nil
		and bottleEasy.width == 0.28 and bottleEasy.period == 1.4 and bottleHard ~= nil and bottleHard.width == 0.17
		and bottleHard.period == Config.BOTTLE_PERIOD)
	local a, b = table.unpack(newPlayers(2))
	local times = { [a] = 10, [b] = 10.45 }
	Match.mode = "easy"
	local easyClash = Nunchi.clash({ a, b }, times)
	Match.mode = nil
	local normalClash = Nunchi.clash({ a, b }, times)
	Match.mode = "hard"
	local hardClash = Nunchi.clash({ a, b }, { [a] = 10, [b] = 10.55 })
	Match.mode = nil
	check("20j 눈치 게임's clash window by mode: 0.45 s apart clash in the normal mode, not in the easy one; 0.55 s in the"
		.. " hard one", easyClash == nil and normalClash ~= nil and hardClash ~= nil)
end
do
	-- 20k: the new banks are well formed: four different choices, the answer among them, no question twice in any bank;
	-- the easy bank mostly 넌센스 with enough plain ones for the bell quiz; the O/X banks balanced.
	local seen, okForm, dup = {}, true, nil
	local nonsense, plain = 0, 0
	for _, bank in { QuizBank.main, QuizBank.final, QuizBank.easy, QuizBank.hardMain, QuizBank.hardFinal } do
		for _, question in bank do
			local distinct = {}
			for _, choice in question.choices do
				distinct[choice] = true
			end
			local count = 0
			for _ in distinct do
				count += 1
			end
			okForm = okForm and #question.choices == 4 and count == 4 and question.answer >= 1 and question.answer <= 4
			if seen[question.q] then
				dup = dup or question.q
			end
			seen[question.q] = true
		end
	end
	for _, question in QuizBank.easy do
		if question.nonsense then
			nonsense += 1
		else
			plain += 1
		end
	end
	local function balanced(list)
		local o, x = 0, 0
		for _, statement in list do
			if statement.o then
				o += 1
			else
				x += 1
			end
		end
		return o, x
	end
	local hardAll = table.clone(OXBankHard)
	for _, statement in OXBank do
		if statement.hard then
			table.insert(hardAll, statement)
		end
	end
	local eo, ex = balanced(OXBankEasy)
	local ho, hx = balanced(hardAll)
	local seenS, dupS = {}, nil
	for _, list in { OXBank, OXBankEasy, OXBankHard } do
		for _, statement in list do
			if seenS[statement.s] then
				dupS = dupS or statement.s
			end
			seenS[statement.s] = true
		end
	end
	check("20k the mode banks: well formed, no question or statement twice; easy = mostly 넌센스 (50+) with 20+ plain; the"
		.. " hard main game 70+, its final 40, O/X easy 45 and hard 45, both answers 12+ each", okForm and dup == nil
		and dupS == nil and nonsense >= 50 and plain >= 20 and #QuizBank.final + #QuizBank.hardMain >= 70
		and #QuizBank.hardFinal >= 40 and #OXBankEasy >= 45 and #hardAll >= 45 and eo >= 12 and ex >= 12 and ho >= 12
		and hx >= 12, tostring(dup) .. " " .. tostring(dupS) .. string.format(" %d/%d %d/%d %d/%d", nonsense, plain, eo, ex, ho, hx))
end

print(if fails == 0 then "ALL PASS" else fails .. " FAILED")
