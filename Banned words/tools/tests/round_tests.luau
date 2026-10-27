-- V3 round rules on the real modules (docs/DESIGN_V3.md §2, §4, §15): LifeService (one penalty per event, none while
-- flying, simultaneous fails, everyone at once -> final, subjective limits, AFK), Timeline (time up, early final),
-- and whole rounds of the real RoundService with stub chairs/stands/voice/scores and a scripted mission in place
-- of the Studio test mission: games back to back (no free talk, bundle 6a), the time budget -> the final once nothing
-- fits, final cap -> joint winners, 3 left of 4+ -> final at once, everyone at once -> final among them, one left ->
-- winner, leaving is out, the Studio fail key; joining by chat (ChatService: privacy of the check, retries, voice
-- accounts, the round lock), the real VoiceService routing, the presenter, and the real banned-word talk (words in
-- its prep stage only, chat judging, rescues, the presenter's ear and re-draws, public limits, the settle stage).
local Config = require(node("Config"))
-- The shipped Config has speech judging on (the friend beta, owner 2026-10-24); these rounds start without it and
-- turn it on the Studio way (workspace attribute BW_VoiceJudging) for the banned-word talk (section 13).
Config.VOICE_JUDGING = false
-- Since bundle 9c the shipped game plays 머리 위 스무고개 instead of the talk (Config.TALK_GAME_ON off); its code stays and
-- is still tested here (section 13); 스무고개 itself is switched on only in section 17.
Config.TALK_GAME_ON = true
local Match = require(node("Match"))
local LifeService = require(node("LifeService"))
local Timeline = require(node("Timeline"))

local fails = 0
local function check(name, cond, detail)
	print((if cond then "PASS " else "FAIL ") .. name .. (if detail then "  " .. detail else ""))
	if not cond then fails += 1 end
end

local function fakeCharacter()
	local humanoid = { Health = 100 }
	local character = { Parent = workspace, ChildAdded = signal() }
	function character:GetChildren()
		return {}
	end
	function character:FindFirstChildOfClass(className)
		return if className == "Humanoid" then humanoid else nil
	end
	function character:FindFirstChild(name)
		return if name == "HumanoidRootPart" then {} else nil
	end
	function character:WaitForChild(_name)
		return {}
	end
	return character
end
local friendPairs = {} -- ["a-b"] = true: those two users are Roblox friends
local friendsBroken = false
local friendsDelay = 0 -- each friend check yields this long
local function fakePlayer(i)
	local attributes = {}
	return {
		IsFriendsWithAsync = function(self, otherId)
			if friendsBroken then
				error("friends API unavailable")
			end
			if friendsDelay > 0 then
				task.wait(friendsDelay)
			end
			return friendPairs[self.UserId .. "-" .. otherId] == true or friendPairs[otherId .. "-" .. self.UserId] == true
		end,
		Name = "P" .. i,
		UserId = i,
		DisplayName = "P" .. i,
		Parent = Players,
		Character = fakeCharacter(),
		CharacterAdded = signal(),
		ChildAdded = signal(), -- (the real VoiceService of section 9 watches every player)
		FindFirstChildOfClass = function(_, _className) return nil end,
		SetAttribute = function(_, name, value) attributes[name] = value end,
		GetAttribute = function(_, name) return attributes[name] end,
	}
end

---------------------------------------------------------------- 5. LifeService
local flyingNow = {}
LifeService.start(function(p) return flyingNow[p] == true end)
local function setup(n, lives)
	Match.resetRound()
	local list = {}
	for i = 1, n do
		local p = fakePlayer(i)
		list[i] = p
		Match.participants[p] = { player = p, words = {}, alive = true, lives = lives or Config.LIVES, afkMisses = 0 }
	end
	LifeService.beginRound()
	return list
end
local function livesOf(p) return Match.participants[p].lives end
local function alive(p) return Match.participants[p].alive end

local a = setup(3)
local first = LifeService.fail({ a[1] }, "e1", "objective")
local again = LifeService.fail({ a[1] }, "e1", "objective")
check("5a the same event never costs a player twice", #first == 1 and #again == 0 and livesOf(a[1]) == 2)
local twice = LifeService.fail({ a[2], a[2] }, "e2", "objective")
check("5b listed twice in one event -> one life", #twice == 1 and livesOf(a[2]) == 2)
flyingNow[a[3]] = true
local flying = LifeService.fail({ a[3] }, "e3", "objective")
flyingNow[a[3]] = nil
check("5c no penalty while flying", #flying == 0 and livesOf(a[3]) == 3)

local b = setup(2, 1)
local last = LifeService.fail({ b[1] }, "e4", "objective")
check("5d the last life lost -> out", #last == 1 and last[1].out and last[1].livesLeft == 0 and not alive(b[1]) and alive(b[2]))

local c = setup(3, 1)
local all, toFinal = LifeService.fail({ c[1], c[2], c[3] }, "e5", "objective")
check("5e everyone alive falls at once -> nobody out, they play the final", toFinal and #all == 3 and not all[1].out
	and alive(c[1]) and alive(c[2]) and alive(c[3]) and livesOf(c[1]) == 0)

local d = setup(3, 1)
Match.participants[d[3]].lives = 2
local together, toFinal2 = LifeService.fail({ d[1], d[2], d[3] }, "e6", "objective")
check("5f simultaneous fails are taken together; someone with lives left survives -> no final", not toFinal2
	and #together == 3 and not alive(d[1]) and not alive(d[2]) and alive(d[3]) and livesOf(d[3]) == 1)

local e = setup(2, 1)
flyingNow[e[2]] = true
local hit, toFinal3 = LifeService.fail({ e[1], e[2] }, "e7", "objective")
flyingNow[e[2]] = nil
check("5g a flying player is skipped and still counts as a survivor", not toFinal3 and #hit == 1 and hit[1].player == e[1] and hit[1].out)

Match.serverKind = "public"
local f = setup(2)
local s1 = LifeService.fail({ f[1] }, "s1", "subjective")
local s2 = LifeService.fail({ f[1] }, "s2", "subjective")
check("5h public: one subjective launch per player per round", #s1 == 1 and #s2 == 0 and livesOf(f[1]) == 2)
Match.participants[f[2]].lives = 1
local s3 = LifeService.fail({ f[2] }, "s3", "subjective")
check("5i public: a subjective launch never takes the last life", #s3 == 0 and livesOf(f[2]) == 1
	and not LifeService.canFail(f[2], "subjective") and LifeService.canFail(f[2], "objective"))
local o1 = LifeService.fail({ f[2] }, "o1", "objective")
check("5j ...an objective fail still does", #o1 == 1 and o1[1].out)
LifeService.beginRound()
Match.participants[f[1]].lives = 3
local s4 = LifeService.fail({ f[1] }, "s1", "subjective")
check("5k a new round resets the subjective quota and the event memory", #s4 == 1)
Match.serverKind = "private"
local g = setup(1)
local p1 = LifeService.fail({ g[1] }, "s5", "subjective")
local p2 = LifeService.fail({ g[1] }, "s6", "subjective")
check("5l private: no subjective limit", #p1 == 1 and #p2 == 1 and livesOf(g[1]) == 1)
Match.serverKind = "public"

local h = setup(3)
local gone = LifeService.eliminate({ h[1], h[1], h[2] })
local goneAgain = LifeService.eliminate({ h[1] })
check("5m eliminate: out at once, players already out are skipped", #gone == 2 and #goneAgain == 0 and not alive(h[1])
	and livesOf(h[1]) == 0 and alive(h[3]))
check("5n AFK: the first miss keeps the player in", LifeService.noteAnswer(h[3], false) == false and alive(h[3]))
LifeService.noteAnswer(h[3], true)
check("5o AFK: an answer resets the run", LifeService.noteAnswer(h[3], false) == false and alive(h[3]))
check("5p AFK: AFK_MISSES misses in a row -> out", LifeService.noteAnswer(h[3], false) == true and not alive(h[3]))

local k = setup(1)
flyingNow[k[1]] = true
local whileFlying = LifeService.fail({ k[1] }, "e9", "objective")
flyingNow[k[1]] = nil
local sameEventLater = LifeService.fail({ k[1] }, "e9", "objective")
local nextEvent = LifeService.fail({ k[1] }, "e10", "objective")
check("5q an event that came while flying is used up (it never costs that player later)", #whileFlying == 0
	and #sameEventLater == 0 and #nextEvent == 1)
flyingNow[k[1]] = true
LifeService.noteAnswer(k[1], false)
LifeService.noteAnswer(k[1], false)
flyingNow[k[1]] = nil
check("5r AFK: missions missed while flying do not count", alive(k[1]) and Match.participants[k[1]].afkMisses == 0)

---------------------------------------------------------------- 6. Timeline
Timeline.begin(5)
check("6a the whole main game is left at the start", math.abs(Timeline.left() - Config.ROUND_MAX_SECONDS) < 1e-6
	and Timeline.gamesLeft() == Config.ROUND_GAMES)
check("6b begun with 4+: the final is due as soon as FINAL_AT_ALIVE are left", not Timeline.finalDue(Config.FINAL_AT_ALIVE + 1)
	and Timeline.finalDue(Config.FINAL_AT_ALIVE))
Timeline.begin(Config.FINAL_AT_ALIVE)
check("6c begun with FINAL_AT_ALIVE or fewer: no early final", not Timeline.finalDue(2) and not Timeline.finalDue(1))
at(now + Config.ROUND_MAX_SECONDS)
check("6d time up -> the final is due", Timeline.left() == 0 and Timeline.finalDue(Config.FINAL_AT_ALIVE))
Timeline.begin(Config.FINAL_AT_ALIVE + 2)
local fewWithMany = Timeline.fewLeft(Config.FINAL_AT_ALIVE) and not Timeline.fewLeft(Config.FINAL_AT_ALIVE + 1)
Timeline.begin(Config.FINAL_AT_ALIVE)
check("6e fewLeft: only the head count rule (begun with 4+), never the clock", fewWithMany and not Timeline.fewLeft(1))
Timeline.begin(Config.FINAL_AT_ALIVE)
local numbers = {}
for _ = 1, Config.ROUND_GAMES - 1 do
	table.insert(numbers, Timeline.gameStarted())
end
local dueBefore = Timeline.finalDue(Config.FINAL_AT_ALIVE)
table.insert(numbers, Timeline.gameStarted())
check("6f ROUND_GAMES games: numbered 1.., the final is due once the last one started (owner 2026-10-24)",
	not dueBefore and Timeline.finalDue(Config.FINAL_AT_ALIVE) and Timeline.gamesLeft() == 0
	and numbers[1] == 1 and numbers[#numbers] == Config.ROUND_GAMES)

---------------------------------------------------------------- 7. whole rounds (RoundService + stubs)
local Seat = { flying = {}, flings = {}, reseats = {}, noChair = {}, index = {}, onLanded = nil }
local returnDue = nil
function Seat.init(callback, onLanded)
	returnDue = callback
	Seat.onLanded = onLanded
end
function Seat.seatPlayers(players)
	local seated = {}
	for i, p in players do
		seated[p] = true
		Seat.index[p] = i
	end
	return seated
end
function Seat.seatIndexOf(player) return Seat.index[player] end
function Seat.fling(player, tag, delay, size)
	if Seat.flying[player] or Seat.noChair[player] then
		return false
	end
	Seat.flying[player] = true
	table.insert(Seat.flings, { player = player, at = now, delay = delay or 0, size = size or 1 })
	local character = player.Character
	task.delay(Config.FLING_RETURN_SECONDS, function()
		if Seat.flying[player] then
			returnDue(player, tag, character)
		end
	end)
	return true
end
function Seat.endFling(player) Seat.flying[player] = nil end
function Seat.reseat(player)
	if Seat.flying[player] then
		return false
	end
	table.insert(Seat.reseats, { player = player, at = now })
	return true
end
function Seat.isFlying(player) return Seat.flying[player] == true end
function Seat.anyFlying() return next(Seat.flying) ~= nil end
function Seat.releaseAll() table.clear(Seat.flying) end
loaders.SeatService = function() return Seat end

local Spectator = { stands = {} }
function Spectator.start() end
function Spectator.beginRound() end
function Spectator.endRound() end
function Spectator.toStands(player) table.insert(Spectator.stands, { player = player, at = now }) end
loaders.SpectatorService = function() return Spectator end

local Voice = { speakers = nil, silenced = nil, silencedCalls = 0, floor = nil, floors = {} }
function Voice.start() end
function Voice.setSpeakers(ids) Voice.speakers = ids end
function Voice.setFloor(ids)
	Voice.floor = ids
	table.insert(Voice.floors, ids or false)
end
function Voice.setSilenced(ids)
	Voice.silenced = ids
	Voice.silencedCalls += 1
end
loaders.VoiceService = function() return Voice end

local Score = { added = {} }
function Score.start() end
function Score.resetRound() end
function Score.add(player, amount) Score.added[player] = (Score.added[player] or 0) + amount end
loaders.Scores = function() return Score end

-- The mission: waits expectedSeconds (ctx.wait, so a cancel stops it), then fails whoever pick(run number, alive
-- players) names; secondPick, if set, is a second event of the same main-game run right after the first.
local Scripted = { id = "scripted", title = "scripted", expectedSeconds = 10, runs = {}, finalRuns = {}, pick = nil, finalPick = nil, secondPick = nil,
	off = false, noPlay = 0 } -- off: not offered in the main game (the banned-word talk sections), still the final's
-- questions; noPlay: this many next runs end at once with "nothing to play" (too few players)
function Scripted.available(final) return final or not Scripted.off end
function Scripted.run(ctx)
	if not ctx.final and Scripted.noPlay > 0 then
		Scripted.noPlay -= 1
		Scripted.skipped = (Scripted.skipped or 0) + 1
		return false
	end
	local list = if ctx.final then Scripted.finalRuns else Scripted.runs
	table.insert(list, now)
	if not ctx.wait(Scripted.expectedSeconds) then
		return
	end
	if Scripted.missed and not ctx.final then -- an answer mission: these players did not answer (the AFK rule)
		ctx.answers({}, Scripted.missed(ctx.players()))
	end
	if Scripted.judge and not ctx.final then -- the one-word mission's ending: the presenter picks, a subjective launch
		local options = {}
		for _, player in ctx.players() do
			table.insert(options, { id = tostring(player.UserId), title = player.Name, recommended = false })
		end
		local picked = ctx.presenterPick(options, Config.PRESENTER_JUDGE_SECONDS)
		table.insert(Scripted.judged, picked or "none")
		for _, player in ctx.players() do
			if tostring(player.UserId) == picked then
				ctx.fail({ player }, "judge", true)
			end
		end
		return
	end
	if Scripted.extra and not ctx.final then -- a test drives the ctx itself (bells, the floor, a verdict)
		Scripted.extra(ctx)
		return
	end
	local pick = if ctx.final then Scripted.finalPick else Scripted.pick
	ctx.fail(if pick then pick(#list, ctx.players()) else {}, "result")
	local second = if ctx.final then nil else Scripted.secondPick
	if second then
		ctx.fail(second(#list, ctx.players()), "second")
	end
end
loaders.TestMission = function() return Scripted end
-- The real quiz and roulette have their own suite (mission_tests.luau); here they never run, so every round plays
-- the scripted mission.
local function never(id)
	return { id = id, title = id, expectedSeconds = 1, available = function(_final) return false end, run = function(_ctx) end }
end
loaders.Quiz = function()
	local quiz = never("quiz")
	quiz.bell = never("bellQuiz")
	quiz.chosung = never("chosung")
	return quiz
end
-- (one test switches the roulette stand-in on, so a vote between two games happens)
local rouletteStub = never("roulette")
loaders.Roulette = function() return rouletteStub end
loaders.OneWord = function() return never("oneWord") end
loaders.Crocodile = function() return never("croc") end
local bombStub = never("bomb")
loaders.BombPass = function() return bombStub end
loaders.Nunchi = function() return never("nunchi") end
loaders.Balance = function() return never("balance") end
loaders.RedLight = function() return never("redLight") end
loaders.Liar = function() return never("liar") end
loaders.TimeGuess = function() return never("timeGuess") end
loaders.Duel = function() return never("duel") end
loaders.Bottle = function() return never("bottle") end
loaders.OXQuiz = function() return never("oxQuiz") end
loaders.Estimate = function() return never("estimate") end
-- The real 머리 위 스무고개, offered only while `twentyOn` (section 17).
local twentyOn = false
local realTwenty = loaders.Twenty
loaders.Twenty = function()
	local twenty = realTwenty()
	local available = twenty.available
	twenty.available = function(final)
		return twentyOn and available(final)
	end
	return twenty
end

local function advanceUntil(cond, limit)
	local deadline = now + limit
	while not cond() and now < deadline do
		at(now + 0.25)
	end
	return cond()
end
local function sent(name, since)
	local list = {}
	for _, m in NetStub.sent do
		if m.name == name and m.at >= since then
			table.insert(list, m)
		end
	end
	return list
end
-- Phase changes since `since`: { phase, at, message }.
local function phases(since)
	local list = {}
	for _, m in sent("RoundState", since) do
		local last = list[#list]
		if not last or last.phase ~= m.payload.phase then
			table.insert(list, { phase = m.payload.phase, at = m.at, message = m.payload.message })
		end
	end
	return list
end
local function phaseAt(list, name)
	for _, entry in list do
		if entry.phase == name then
			return entry
		end
	end
	return nil
end
local function noticesWith(text, since)
	local count = 0
	for _, n in NetStub.notices do
		if n.text == text and n.at >= since then
			count += 1
		end
	end
	return count
end
local function find(list, player)
	for _, entry in list do
		if entry.player == player then
			return entry
		end
	end
	return nil
end
local function count(list, player)
	local n = 0
	for _, entry in list do
		if entry.player == player then
			n += 1
		end
	end
	return n
end

local nextId = 1000
local function newPlayers(n)
	local list = {}
	for _ = 1, n do
		nextId += 1
		local p = fakePlayer(nextId)
		table.insert(list, p)
		task.spawn(Players.PlayerAdded.fire, p)
	end
	return list
end
-- Starts a round with `players`; returns once the main game began (the time it began).
local function begin(players, expectedSeconds, pick, finalPick, secondPick)
	table.clear(Seat.flings)
	table.clear(Seat.reseats)
	table.clear(Seat.noChair)
	table.clear(Spectator.stands)
	table.clear(Scripted.runs)
	table.clear(Scripted.finalRuns)
	Score.added = {}
	Scripted.expectedSeconds = expectedSeconds
	Scripted.pick = pick
	Scripted.finalPick = finalPick
	Scripted.secondPick = secondPick
	Scripted.missed = nil
	Scripted.judge = nil
	Scripted.judged = {}
	playerList = players
	local since = now
	advanceUntil(function() return Match.phase == "Play" end, 60)
	local play = phaseAt(phases(since), "Play")
	return if play then play.at else now
end
-- Plays the round to its result, then empties the server so the next scenario starts from the lobby.
local function finish(since)
	advanceUntil(function() return Match.phase == "Result" end, 2000)
	local list = phases(since)
	playerList = {}
	advanceUntil(function() return Match.phase == "Lobby" end, 60)
	return list
end
local function lifeLost(since, reason)
	local list = {}
	for _, m in sent("LifeLost", since) do
		if m.payload.reason == reason then
			table.insert(list, m)
		end
	end
	return list
end
local function leave(player, stays)
	playerList = stays
	task.spawn(Players.PlayerRemoving.fire, player)
end
-- Each game is briefed for BRIEF_SECONDS before it starts (owner 2026-10-24). Here only the scripted mission can
-- run, so there is never a vote (a ballot of one), but without a presenter its seconds are counted for the fit.
local CARD = Config.BRIEF_SECONDS
-- How many main-game missions of `seconds` start without a presenter: ROUND_GAMES, or fewer if the time cap comes
-- first (one starts only if it fits with its launches once the vote and the briefing are over).
local function expectedRuns(seconds)
	local count, t = 0, 0
	while count < Config.ROUND_GAMES
		and Config.ROUND_MAX_SECONDS - t - Config.NEXT_VOTE_SECONDS - CARD >= seconds + Config.FLING_RETURN_SECONDS do
		count += 1
		t += CARD + seconds
	end
	return count
end
-- Run 1-3 fail both players: everyone falls at once on the last life -> the two play the final.
local function bothFall(ps)
	return function(run)
		return if run <= 3 then { ps[1], ps[2] } else {}
	end
end

local RoundService = require(node("RoundService"))
playerList = {}
RoundService.start()
at(now + 2)
-- Presses name the menu / bell window they answer (bundle 6b); the tests press on the latest one unless told otherwise.
local function latestId(name)
	for i = #NetStub.sent, 1, -1 do
		local m = NetStub.sent[i]
		if m.name == name and m.payload.id then
			return m.payload.id
		end
	end
	return nil
end
local rawPick, rawBell = NetStub.listeners.PresenterPick, NetStub.listeners.Bell
NetStub.listeners.PresenterPick = function(player, id, menuId)
	return rawPick(player, id, menuId or latestId("PresenterMenu"))
end
NetStub.listeners.Bell = function(player, windowId)
	return rawBell(player, windowId or latestId("BellOpen"))
end

-- 7A: three players, nobody fails: games back to back until the next would not fit, then the final at once, then the
-- cap (the last question begins before the cap and is played to its end).
do
	local ps = newPlayers(3)
	local since = now
	Match.serverKind = "private" -- the round start must set it again
	local seconds = 40
	local play = begin(ps, seconds, nil, nil)
	at(play + 10)
	local respawned = fakeCharacter()
	ps[1].Character = respawned
	task.spawn(ps[1].CharacterAdded.fire, respawned)
	at(play + 11)
	local reseat = find(Seat.reseats, ps[1])
	check("7a a participant's new character goes back on the chair", reseat ~= nil and reseat.at >= play + 10.4 and reseat.at <= play + 10.7)
	check("7a the round start sets the server kind (Studio default)", Match.serverKind == Config.STUDIO_SERVER_KIND)
	check("7a no free talk: the first game starts once its card is over; the status board names it while it runs",
		#Scripted.runs == 1 and math.abs(Scripted.runs[1] - (play + CARD)) < 0.3 and Match.message == Scripted.title,
		Scripted.runs[1] and string.format("+%.1f", Scripted.runs[1] - play))
	local list = finish(since)
	local final, result = phaseAt(list, "Final"), phaseAt(list, "Result")
	local runs = Scripted.runs
	check("7b ROUND_GAMES missions run (none would miss the time cap)", #runs == expectedRuns(seconds)
		and #runs == Config.ROUND_GAMES,
		string.format("%d runs (expected %d)", #runs, expectedRuns(seconds)))
	local lastEnd = (runs[#runs] or play) + seconds - play -- (each start drifts by a scheduler tick, so measure the last one)
	check("7c the final starts as soon as the last game is over", final ~= nil
		and math.abs(final.at - play - lastEnd) < 0.5 and final.at - play <= Config.ROUND_MAX_SECONDS,
		final and string.format("final at +%.1f (last game over at +%.1f)", final.at - play, lastEnd))
	local questions = math.ceil(Config.FINAL_MAX_SECONDS / seconds)
	check("7d final cap -> the survivors share the win; a question begun before the cap is finished", result ~= nil and final ~= nil
		and #Scripted.finalRuns == questions and result.at - final.at > Config.FINAL_MAX_SECONDS
		and math.abs(result.at - final.at - questions * seconds) < 1
		and string.find(result.message, "공동 우승") ~= nil and string.find(result.message, ps[1].DisplayName) ~= nil
		and string.find(result.message, ps[3].DisplayName) ~= nil, result and final and string.format("%s, %.1f s", result.message, result.at - final.at))
	check("7e each winner scores SCORE_WIN", Score.added[ps[1]] == Config.SCORE_WIN and Score.added[ps[2]] == Config.SCORE_WIN
		and Score.added[ps[3]] == Config.SCORE_WIN)
	check("7f everyone hears everyone again after the round", Voice.speakers == nil)
end

-- 7B: five players on a private server: two lose all lives -> three left -> the final at once (after the flights).
do
	workspaceAttributes.BW_ServerKind = "private"
	local ps = newPlayers(5)
	local since = now
	local play = begin(ps, 10, function(run)
		return if run <= 3 then { ps[1], ps[2] } else {}
	end, function(question, alivePlayers)
		if question == 1 then
			return { ps[3] }
		elseif question == 2 then
			return alivePlayers -- everyone left is wrong
		end
		return { ps[4] }
	end)
	check("7g Studio server kind setting -> private rules", Match.serverKind == "private")
	local list = finish(since)
	workspaceAttributes.BW_ServerKind = nil
	local failEvents = lifeLost(since, "fail")
	local third = failEvents[3]
	check("7h each mission fail costs a life; the third puts both out", #failEvents == 3 and #failEvents[1].payload.players == 2
		and failEvents[1].payload.players[1].lives == 2 and third ~= nil and third.payload.players[1].out and third.payload.players[2].out)
	check("7i flights back on the chair while lives are left", count(Seat.reseats, ps[1]) == 2 and count(Seat.reseats, ps[2]) == 2)
	local stand = find(Spectator.stands, ps[1])
	check("7j out -> the stands when the flight is over", stand ~= nil and third ~= nil
		and math.abs(stand.at - (third.at + Config.FLING_RETURN_SECONDS)) < 0.01)
	local final = phaseAt(list, "Final")
	check("7k 3 left of 5 -> the final at once, after the flights", final ~= nil and third ~= nil
		and final.at >= third.at + Config.FLING_RETURN_SECONDS and final.at - play < 200,
		final and string.format("final at +%.1f", final.at - play))
	local finals = lifeLost(since, "final")
	check("7l a wrong final answer is out; all wrong -> nobody out", #finals == 2 and finals[1].payload.players[1].userId == ps[3].UserId
		and finals[2].payload.players[1].userId == ps[4].UserId and noticesWith(Config.TEXT.ALL_WRONG, since) == 1
		and #Scripted.finalRuns == 3)
	local result = phaseAt(list, "Result")
	check("7m the last finalist wins", result ~= nil and result.message == string.format(Config.TEXT.WINNER, ps[5].DisplayName)
		and Score.added[ps[5]] == Config.SCORE_WIN and Score.added[ps[4]] == nil, result and result.message)
end

-- 7C: two players fall together on their last life -> nobody out, the two play the final. A second event of that same
-- mission comes after the outcome is fixed and is dropped.
do
	local ps = newPlayers(2)
	local since = now
	local finalists = -1
	local play = begin(ps, 10, bothFall(ps), function(_question, alivePlayers)
		finalists = #alivePlayers
		return { ps[1] }
	end, function(run)
		return if run == 3 then { ps[1] } else {}
	end)
	local list = finish(since)
	local failEvents = lifeLost(since, "fail")
	local third = failEvents[3]
	check("7n everyone at once on the last life -> nobody out, the final among them (said in the same message)", third ~= nil
		and not third.payload.players[1].out and not third.payload.players[2].out and third.payload.players[1].lives == 0
		and third.payload.final == true and failEvents[1].payload.final == false and noticesWith(Config.TEXT.TO_FINAL, since) == 0)
	check("7o a later event of that mission is dropped (both play the final)", #failEvents == 3 and finalists == 2)
	local final = phaseAt(list, "Final")
	check("7p that final starts right after the flights", final ~= nil and third ~= nil and final.at >= third.at + Config.FLING_RETURN_SECONDS
		and final.at - third.at < Config.FLING_RETURN_SECONDS + 1 and final.at - play < 200)
	local result = phaseAt(list, "Result")
	check("7q ...and its winner wins the round", result ~= nil and result.message == string.format(Config.TEXT.WINNER, ps[2].DisplayName))
	local byRun = {}
	for _, f in Seat.flings do
		if f.at >= since then
			table.insert(byRun, f)
		end
	end
	-- (runs 1-3 both fall: two launches each, the chairs in seating order, the second CHAIN_DELAY later)
	local chained, sized = #byRun >= 6, #byRun >= 6
	for i = 1, 6, 2 do
		local a, b = byRun[i], byRun[i + 1]
		chained = chained and a ~= nil and b ~= nil and a.delay == 0 and math.abs(b.delay - Config.CHAIN_DELAY) < 1e-9
			and (Seat.index[a.player] or 0) < (Seat.index[b.player] or 0)
	end
	sized = sized and byRun[1].size == 1 and byRun[3].size == 1 + Config.BLAST_GROWTH
		and byRun[5].size == 1 + 2 * Config.BLAST_GROWTH
	check("7q5 chain explosions (owner 2026-10-24): launched together go off CHAIN_DELAY apart from the left chair; the"
		.. " blast grows as lives run out (1, 1.5, 2)", chained and sized)
	local briefs = {}
	for _, m in sent("Mission", since) do
		if m.payload.kind == "brief" then
			table.insert(briefs, m.payload)
		end
	end
	local names = { ps[1].DisplayName, ps[2].DisplayName }
	table.sort(names)
	check("7q2 the briefings (owner 2026-10-24): each game's number and name; with no vote (one game to choose from) the"
		.. " briefing tells what the last game did", briefs[1] ~= nil and briefs[1].game == 1 and briefs[1].recap == ""
		and briefs[1].title == Scripted.title and briefs[1].games == Config.ROUND_GAMES and briefs[2] ~= nil
		and briefs[2].game == 2 and briefs[2].recap == string.format(Config.TEXT.RECAP_LOST, table.concat(names, ", ")))
end

-- 7Q6: the round awards on the result screen (owner 2026-10-24): the longest flight, the most games without losing a
-- life.
do
	local ps = newPlayers(3)
	local since = now
	local play = begin(ps, 10, function(run)
		return if run == 1 then { ps[1] } else {}
	end, nil)
	at(play + 1)
	Seat.onLanded(ps[2], 50, 1)
	Seat.onLanded(ps[1], 100, 1.5)
	Seat.onLanded(ps[3], 80, 1.2)
	finish(since)
	local shown = nil
	for _, m in sent("Mission", since) do
		if m.payload.kind == "roundResult" then
			shown = m.payload
		end
	end
	local names = { ps[2].DisplayName, ps[3].DisplayName }
	table.sort(names)
	local lines = shown and shown.lines or {}
	check("7q6 the result screen: who won, the longest flight (in metres) and the most games without losing a life",
		shown ~= nil and string.find(shown.title, "우승") ~= nil
		and lines[1] == string.format(Config.TEXT.AWARD_FLIGHT, ps[1].DisplayName, 100 * Config.STUDS_TO_METERS)
		and lines[2] == string.format(Config.TEXT.AWARD_SURVIVOR, table.concat(names, ", "), Config.ROUND_GAMES),
		table.concat(lines, " / "))
	local winners = shown and shown.winners or {}
	local matches = true
	for _, p in ps do
		matches = matches and (table.find(winners, p.UserId) ~= nil) == (string.find(shown.title, p.DisplayName, 1, true) ~= nil)
	end
	check("7q7 the result screen names the winners by id (their confetti and fanfare, 2026-10-26)", #winners > 0 and matches)
end

-- 7C1: a game with too few players to start (it says "nothing to play") is not one of the round's games.
do
	local ps = newPlayers(3)
	local since = now
	Scripted.noPlay = 2
	Scripted.skipped = 0
	begin(ps, 10, nil, nil)
	finish(since)
	check("7q4 a game that had nothing to play does not count: ROUND_GAMES games are played anyway",
		Scripted.skipped == 2 and #Scripted.runs == Config.ROUND_GAMES, string.format("%d skipped, %d runs", Scripted.skipped, #Scripted.runs))
	Scripted.noPlay = 0
end

-- 7C2: alone (Studio): the last life lost -> no "to the final" (there is none: one player), they win with no lives left.
do
	local ps = newPlayers(1)
	local since = now
	begin(ps, 10, function(run)
		return if run <= 3 then { ps[1] } else {}
	end, nil)
	local list = finish(since)
	local events = lifeLost(since, "fail")
	local result = phaseAt(list, "Result")
	check("7q3 alone: the third life lost does not say 'to the final'; no final, the player wins with no lives left",
		#events == 3 and events[3].payload.final == false and events[3].payload.players[1].lives == 0
		and phaseAt(list, "Final") == nil and result ~= nil
		and result.message == string.format(Config.TEXT.WINNER, ps[1].DisplayName))
end

-- 7D: one of two loses all lives -> the other wins without a final, once the flight is over.
do
	local ps = newPlayers(2)
	local since = now
	begin(ps, 10, function(run)
		return if run <= 3 then { ps[1] } else {}
	end, nil)
	local list = finish(since)
	local result = phaseAt(list, "Result")
	local lastFling = Seat.flings[#Seat.flings]
	check("7r one left -> the winner, no final", phaseAt(list, "Final") == nil and result ~= nil
		and result.message == string.format(Config.TEXT.WINNER, ps[2].DisplayName))
	check("7s the result waits for the last flight", result ~= nil and lastFling ~= nil and result.at >= lastFling.at + Config.FLING_RETURN_SECONDS)
end

-- 7E: leaving is out.
do
	local ps = newPlayers(2)
	local since = now
	local play = begin(ps, 10, nil, nil)
	at(play + 20)
	leave(ps[2], { ps[1] })
	local list = finish(since)
	local left = lifeLost(since, "left")
	local result = phaseAt(list, "Result")
	check("7t leaving is out (told to everyone)", #left == 1 and left[1].payload.players[1].userId == ps[2].UserId and left[1].payload.players[1].out)
	check("7u the one left wins at once", result ~= nil and result.at - (play + 20) < 1 and phaseAt(list, "Final") == nil
		and result.message == string.format(Config.TEXT.WINNER, ps[1].DisplayName))
end

-- 7F: the other player leaves in the middle of a mission -> the mission stops at once and its result is dropped.
do
	local ps = newPlayers(2)
	local since = now
	local play = begin(ps, 10, function()
		return { ps[1] } -- would cost the winner a life if it were still applied
	end, nil)
	local missionAt = play + CARD
	at(missionAt + 5)
	leave(ps[2], { ps[1] })
	local list = finish(since)
	local result = phaseAt(list, "Result")
	check("7v decided in the middle of a mission -> it stops, its result is dropped", #Scripted.runs == 1
		and #lifeLost(since, "fail") == 0 and #Seat.flings == 0 and result ~= nil and result.at - (missionAt + 5) < 1
		and result.message == string.format(Config.TEXT.WINNER, ps[1].DisplayName), result and string.format("result %.1f s after the leave", result.at - (missionAt + 5)))
end

-- 7F2: five players, two leave in the middle of a mission -> three left -> the final starts at once and the mission's
-- result is dropped (it would have cost the finalists a life).
do
	local ps = newPlayers(5)
	local since = now
	local play = begin(ps, 10, function(_run, alivePlayers)
		return alivePlayers
	end, nil)
	local missionAt = play + CARD
	at(missionAt + 4)
	leave(ps[4], { ps[1], ps[2], ps[3], ps[5] })
	leave(ps[5], { ps[1], ps[2], ps[3] })
	advanceUntil(function() return Match.phase == "Final" end, 60)
	local final = phaseAt(phases(since), "Final")
	check("7v2 3 left of 5 in the middle of a mission -> the final at once, the mission's result dropped", final ~= nil
		and final.at - (missionAt + 4) < 1 and #lifeLost(since, "fail") == 0 and Match.participants[ps[1]].lives == Config.LIVES,
		final and string.format("final %.1f s after the leaves", final.at - (missionAt + 4)))
	finish(since)
end

-- 7G: the last opponent leaves during a final question -> the final ends at once, no "all wrong".
do
	local ps = newPlayers(2)
	local since = now
	local finalAt = nil
	begin(ps, 10, bothFall(ps), function()
		return { ps[1] }
	end)
	advanceUntil(function() return Match.phase == "Final" end, 400)
	finalAt = now
	at(finalAt + 5)
	leave(ps[2], { ps[1] })
	local list = finish(since)
	local result = phaseAt(list, "Result")
	check("7w the other finalist leaves mid-question -> the last one wins at once", result ~= nil and result.at - (finalAt + 5) < 1
		and noticesWith(Config.TEXT.ALL_WRONG, since) == 0 and #lifeLost(since, "final") == 0
		and result.message == string.format(Config.TEXT.WINNER, ps[1].DisplayName))
end

-- 7H: a final question that breaks ends the final; the survivors share the win.
do
	local warned = #warnings
	local ps = newPlayers(2)
	local since = now
	begin(ps, 10, bothFall(ps), function()
		error("broken question")
	end)
	local list = finish(since)
	local final, result = phaseAt(list, "Final"), phaseAt(list, "Result")
	-- (the question breaks when it is scored, after its wait)
	check("7x a broken final question ends the final (reported once)", final ~= nil and result ~= nil and #Scripted.finalRuns == 1
		and math.abs(result.at - final.at - Scripted.expectedSeconds) < 1 and #warnings == warned + 1
		and string.find(warnings[#warnings], "broken question", 1, true) ~= nil
		and string.find(result.message, "공동 우승") ~= nil, result and result.message)
end

-- 7I: the Studio fail key: F costs a life, "show" only launches (not while flying), "out" with no chair -> the stands;
-- a return signal of an older round or of a replaced character changes nothing.
do
	local ps = newPlayers(2)
	local since = now
	local play = begin(ps, 10, nil, nil)
	local devFling = NetStub.listeners.DevFling
	at(play + 2)
	devFling(ps[1])
	check("7y F: a life lost and a launch", Match.participants[ps[1]].lives == 2 and count(Seat.flings, ps[1]) == 1)
	at(play + 3)
	devFling(ps[1], "show")
	check("7z show while flying: nothing", count(Seat.flings, ps[1]) == 1)
	at(play + 8)
	devFling(ps[1], "show")
	check("7za show: a launch, no life lost", count(Seat.flings, ps[1]) == 2 and Match.participants[ps[1]].lives == 2)
	at(play + 14)
	local oldCharacter = ps[1].Character
	local reseats, stands = #Seat.reseats, #Spectator.stands
	returnDue(ps[1], Match.roundId - 1, oldCharacter)
	ps[1].Character = fakeCharacter()
	returnDue(ps[1], Match.roundId, oldCharacter)
	check("7zb a return signal of an older round or a replaced character changes nothing", #Seat.reseats == reseats
		and #Spectator.stands == stands)
	Seat.noChair[ps[1]] = true
	devFling(ps[1], "out")
	local stand = find(Spectator.stands, ps[1])
	check("7zc out with nothing to launch -> the stands at once", stand ~= nil and stand.at == play + 14)
	devFling(ps[2])
	check("7zd the fail key does nothing once the round is decided", Match.participants[ps[2]].lives == Config.LIVES)
	local list = finish(since)
	local result = phaseAt(list, "Result")
	check("7ze ...and the other player wins", result ~= nil and result.message == string.format(Config.TEXT.WINNER, ps[2].DisplayName))
end

local crashed = 0
for _, line in warnings do
	if string.find(line, "round crashed", 1, true) then
		crashed += 1
	end
end
check("7zf no round crashed; the only mission error is 7H's", crashed == 0 and #warnings == 1, table.concat(warnings, " | "))

-- 7V: no presenter and two games that may run -> between games the alive players vote (owner 2026-10-24): the vote
-- screen with the recap, the most votes win, then that game's briefing and the game.
do
	local rouletteRuns = 0
	rouletteStub.available = function(final) return not final end
	local ps = nil :: any
	rouletteStub.run = function(ctx)
		rouletteRuns += 1
		ctx.wait(1)
		if rouletteRuns == 1 then
			ctx.fail({ ps[1] }, "result")
		end
	end
	bombStub.available = function(final) return not final end
	bombStub.run = function(ctx) ctx.wait(1) end
	ps = newPlayers(3)
	local since = now
	local play = begin(ps, 10, nil, nil)
	at(play + 0.5)
	local vote = nil
	for _, m in sent("Mission", since) do
		if m.payload.kind == "nextVote" then
			vote = m.payload
		end
	end
	local rouletteAt = vote and table.find(vote.choices, "roulette")
	if vote and rouletteAt then
		for _, p in ps do
			NetStub.listeners.MissionAnswer(p, vote.id, rouletteAt)
		end
	end
	at(now + 0.5)
	local brief = nil
	for _, m in sent("Mission", since) do
		if m.payload.kind == "brief" then
			brief = m.payload
		end
	end
	at(now + Config.BRIEF_SECONDS + 0.5)
	check("7va a vote among three games: the choices (no recap before the first); once all voted the winner is briefed"
		.. " and played", vote ~= nil and vote.recap == "" and #vote.choices == 3 and rouletteAt ~= nil
		and brief ~= nil and brief.title == "roulette" and rouletteRuns == 1 and #Scripted.runs == 0
		and Match.message ~= Config.TEXT.NEXT_VOTE)
	at(now + 1 + Config.FLING_RETURN_SECONDS + 1)
	local second = nil
	for _, m in sent("Mission", since) do
		if m.payload.kind == "nextVote" then
			second = m.payload
		end
	end
	check("7vb the next vote tells what the last game did (who lost a life), and the game just played is not offered",
		second ~= nil and second ~= vote and second.recap == string.format(Config.TEXT.RECAP_LOST, ps[1].DisplayName)
		and table.find(second.choices, "roulette") == nil and #second.choices == 2)
	bombStub.available = function(_final) return false end
	rouletteStub.available = function(_final) return false end
	NetStub.listeners.DevFling(ps[2], "out")
	NetStub.listeners.DevFling(ps[3], "out")
	finish(since)
end

---------------------------------------------------------------- 8. joining by chat (ChatService through RoundService)
do
	local chatJoin = NetStub.listeners.ChatJoin
	local ready = NetStub.listeners.Ready
	local function join(player, on) -- one request, after the per-player cooldown has passed
		at(now + Config.CHAT_JOIN_COOLDOWN)
		chatJoin(player, on)
	end
	local function accessOf(player) -- the last ChatAccess state sent to that player
		for i = #NetStub.sent, 1, -1 do
			local m = NetStub.sent[i]
			if m.name == "ChatAccess" and m.to == player then
				return m.payload.state
			end
		end
		return nil
	end
	local function arrive(player)
		task.spawn(Players.PlayerAdded.fire, player)
	end
	local function lastState()
		for i = #NetStub.sent, 1, -1 do
			if NetStub.sent[i].name == "RoundState" then
				return NetStub.sent[i].payload
			end
		end
		return nil
	end

	-- (Owner 2026-10-25: voice is a must; a voice account may play by chat and still hears everyone; no voice: watch.)
	local p1, p2, p3, pn = fakePlayer(3001), fakePlayer(3002), fakePlayer(3003), fakePlayer(3005)
	for _, id in { 3001, 3002, 3003 } do
		voiceEnabled[id] = true
	end
	chatAllowed[3002] = false
	RunService.IsStudio = function() return false end
	arrive(p1)
	arrive(p2)
	arrive(p3)
	arrive(pn)
	RunService.IsStudio = function() return true end
	local private = true
	for _, m in NetStub.sent do
		if m.name == "ChatAccess" and m.to == nil then
			private = false
		end
	end
	check("8a each account is checked once and told privately: voice (chat too) / voice only / no voice (watch)",
		accessOf(p1) == "voice" and accessOf(p2) == "voiceOnly" and accessOf(pn) == "noVoice" and chatCalls[3001] == 1
		and chatCalls[3005] == nil and private and p1:GetAttribute("BW_CanChat") == nil)

	local warned = #warnings
	chatBroken = true
	local p4 = fakePlayer(3004)
	voiceEnabled[3004] = true
	RunService.IsStudio = function() return false end
	arrive(p4)
	local during = accessOf(p4)
	at(now + Config.CHAT_CHECK_RETRIES[1] + Config.CHAT_CHECK_RETRIES[2] + 1)
	RunService.IsStudio = function() return true end
	check("8b a chat check that keeps failing is retried, then voice only on a live server (each failure reported)",
		during == "checking" and accessOf(p4) == "voiceOnly" and chatCalls[3004] == 1 + #Config.CHAT_CHECK_RETRIES
		and #warnings == warned + chatCalls[3004])
	local p6 = fakePlayer(3006)
	voiceEnabled[3006] = true
	arrive(p6)
	chatBroken = false
	at(now + Config.CHAT_CHECK_RETRIES[1] + 0.5)
	check("8c a retry that works gives the answer", accessOf(p6) == "voice" and chatCalls[3006] == 2)
	voiceBroken = true
	local p7 = fakePlayer(3007)
	voiceEnabled[3007] = true
	RunService.IsStudio = function() return false end
	arrive(p7)
	at(now + Config.CHAT_CHECK_RETRIES[1] + Config.CHAT_CHECK_RETRIES[2] + 1)
	RunService.IsStudio = function() return true end
	voiceBroken = false
	check("8d a voice check that keeps failing (retried) counts as no voice on a live server (owner 2026-10-23)",
		accessOf(p7) == "noVoice")

	chatDelay = 3
	local p8, p9 = fakePlayer(3008), fakePlayer(3009)
	voiceEnabled[3008] = true
	voiceEnabled[3009] = true
	arrive(p8)
	arrive(p9)
	join(p8, true) -- 1 s in: the 3 s check is still running
	local refused = Match.chatJoin[p8] == nil and accessOf(p8) == "checking"
	p9.Parent = nil
	task.spawn(Players.PlayerRemoving.fire, p9)
	at(now + 3)
	chatDelay = 0
	check("8e a request while the check runs is refused", refused and accessOf(p8) == "voice")
	check("8f a player who leaves during the check is told nothing afterwards", accessOf(p9) == "checking")
	join(p8, true)
	check("8g once checked, that player can play by chat", Match.chatJoin[p8] == true and p8:GetAttribute("BW_ChatMode") == true)

	join(p1, true)
	check("8h a voice account plays by chat if it wants (it still hears everyone)", Match.chatJoin[p1] == true
		and p1:GetAttribute("BW_ChatMode") == true)
	chatJoin(p1, false)
	check("8i requests closer than CHAT_JOIN_COOLDOWN are ignored (each one broadcasts)", Match.chatJoin[p1] == true)
	at(now + Config.CHAT_JOIN_COOLDOWN)
	chatJoin(p1, "no")
	chatJoin(p1, nil)
	check("8j a request that is not true/false is ignored (it does not cancel)", Match.chatJoin[p1] == true)
	join(p2, true)
	join(pn, true)
	check("8k no chat mode for a voice account that may not chat, nor for an account without voice (it watches)",
		Match.chatJoin[p2] == nil and Match.chatJoin[pn] == nil)
	ready(p3, true)
	join(p3, true)
	check("8l a player whose voice is ready may still choose chat", Match.chatJoin[p3] == true)
	join(p3, false)
	ready(p1, true)
	check("8m a voice that gets ready does not undo the choice of chat", Match.chatJoin[p1] == true
		and p1:GetAttribute("BW_ChatMode") == true)
	ready(p1, false)
	join(p1, false)
	local left = Match.chatJoin[p1] == nil and p1:GetAttribute("BW_ChatMode") == false
	join(p1, true)
	check("8n leaving chat mode (and coming back)", left and Match.chatJoin[p1] == true)

	Config.REQUIRE_VOICE_READY = true
	playerList = { p1, p2, p3, pn }
	ready(pn, true, true) -- (a client says ready for an account without voice: it is not believed)
	local unlinked = Match.eligiblePlayers() -- p1 plays by chat, but its voice is not connected yet
	ready(p1, false, true)
	local refusedOff = Match.chatJoin[p2] == nil
	local eligible = Match.eligiblePlayers()
	Players.PlayerRemoving.fire(p1) -- (still listed while it runs, as in Roblox)
	local state = lastState()
	playerList = {}
	Config.REQUIRE_VOICE_READY = false
	check("8o live servers seat voice-ready and chat players only (no voice: nobody seats them)", #eligible == 2
		and table.find(eligible, p1) ~= nil and table.find(eligible, p3) ~= nil and table.find(eligible, p2) == nil
		and table.find(eligible, pn) == nil and refusedOff)
	check("8o2 a client cannot make an account without voice ready, and a chat player needs its voice connected to sit",
		table.find(unlinked, pn) == nil and table.find(unlinked, p1) == nil and table.find(unlinked, p3) ~= nil)
	ready(pn, false, false)
	check("8p a chat player who leaves is no longer counted in the state sent then", state ~= nil and state.readyCount == 1
		and Match.chatJoin[p1] == nil)
	ready(p3, false)

	local sentBefore = #NetStub.sent
	NetStub.listeners.Sync(p2)
	local resent = false
	for i = sentBefore + 1, #NetStub.sent do
		local m = NetStub.sent[i]
		resent = resent or (m.name == "ChatAccess" and m.to == p2 and m.payload.state == "voiceOnly")
	end
	check("8v Sync sends the player's chat access again (a late client missed it)", resent)
	voiceDelay = 2
	local p10 = fakePlayer(3010)
	arrive(p10)
	p10.Parent = nil
	task.spawn(Players.PlayerRemoving.fire, p10)
	at(now + 2.5)
	voiceDelay = 0
	check("8w a player who leaves during the voice check is not checked further", chatCalls[3010] == nil
		and accessOf(p10) == "checking")
	chatBroken = true
	local p11 = fakePlayer(3011)
	arrive(p11) -- (no voice: Studio has none, it goes on as a voice account)
	at(now + Config.CHAT_CHECK_RETRIES[1] + Config.CHAT_CHECK_RETRIES[2] + 1)
	chatBroken = false
	check("8x in Studio an account without voice and a chat check that keeps failing still let the tester try chat mode",
		accessOf(p11) == "voice")
	Config.REQUIRE_VOICE_READY = true
	local p14 = fakePlayer(3014)
	voiceEnabled[3014] = true
	arrive(p14)
	join(p14, true)
	local withoutLink = Match.chatJoin[p14] == nil
	ready(p14, false, true)
	join(p14, true)
	Config.REQUIRE_VOICE_READY = false
	check("8z on live servers playing by chat needs the voice connected first (to hear everyone)", withoutLink
		and Match.chatJoin[p14] == true)
	join(p14, false)
	voiceBroken = true
	local p15 = fakePlayer(3015)
	voiceEnabled[3015] = true
	RunService.IsStudio = function() return false end
	arrive(p15)
	local during15 = accessOf(p15)
	voiceBroken = false
	at(now + Config.CHAT_CHECK_RETRIES[1] + 0.5)
	RunService.IsStudio = function() return true end
	check("8z2 a failing voice check is retried before it counts as no voice", during15 == "checking"
		and accessOf(p15) == "voice")
	workspaceAttributes.BW_ChatAccess = "noVoice"
	local p12, p13 = fakePlayer(3012), fakePlayer(3013)
	voiceEnabled[3012] = true
	voiceEnabled[3013] = true
	arrive(p12)
	RunService.IsStudio = function() return false end
	arrive(p13)
	RunService.IsStudio = function() return true end
	workspaceAttributes.BW_ChatAccess = nil
	check("8y the Studio setting BW_ChatAccess forces the result (live servers ignore it)", accessOf(p12) == "noVoice"
		and accessOf(p13) == "voice")

	-- A round with two chat participants (one connects voice mid-round) and a voice player.
	local ps = newPlayers(3)
	join(ps[1], true)
	join(ps[2], true)
	local since = now
	local play = begin(ps, 10, nil, nil)
	local silenced = Voice.silenced or {}
	check("8q chat participants play by chat and nobody hears their voice", #silenced == 2
		and table.find(silenced, ps[1].UserId) ~= nil and table.find(silenced, ps[2].UserId) ~= nil
		and Match.participants[ps[1]].chat == true and Match.participants[ps[3]].chat == false)
	local calls = Voice.silencedCalls
	join(ps[1], false)
	ready(ps[1], true) -- their voice connects mid-round
	check("8r the choice holds for the round (also when their voice connects)", Match.chatJoin[ps[1]] == true
		and Match.participants[ps[1]].chat == true and Voice.silencedCalls == calls)
	at(play + 2)
	local devFling = NetStub.listeners.DevFling
	devFling(ps[3], "out")
	devFling(ps[2], "out")
	advanceUntil(function() return Match.phase == "Result" end, 60)
	check("8s at the result everyone is heard again", Voice.silenced ~= nil and #Voice.silenced == 0 and Voice.speakers == nil)
	join(ps[2], false)
	check("8t at the result the choice can change again", Match.chatJoin[ps[2]] == nil)
	finish(since)
	check("8u after the round the choice of chat stays until they change it (their voice got ready meanwhile)",
		Match.chatJoin[ps[1]] == true and ps[1]:GetAttribute("BW_ChatMode") == true)
	join(ps[1], false)
end

---------------------------------------------------------------- 9. VoiceService (the real module): who hears whom
do
	local RealVoice = require(node("VoiceServiceReal"))
	local function newInput()
		local input = { AccessType = nil, list = nil }
		function input:IsA(className) return className == "AudioDeviceInput" end
		function input:SetUserIdAccessList(list) self.list = list end
		return input
	end
	local function voicePlayer(id)
		local p = { UserId = id, Name = "V" .. id, Parent = Players, Character = nil, CharacterAdded = signal(), ChildAdded = signal() }
		p.input = newInput()
		function p:FindFirstChildOfClass(className) return if className == "AudioDeviceInput" then self.input else nil end
		return p
	end
	local alive, chatter, spectator, late = voicePlayer(4001), voicePlayer(4002), voicePlayer(4003), voicePlayer(4004)
	late.input = nil -- connects voice later
	playerList = { alive, chatter, spectator, late }
	RealVoice.start()
	RealVoice.setSpeakers({ alive.UserId, chatter.UserId })
	RealVoice.setSilenced({ chatter.UserId })
	local Allow, Deny = Enum.AccessModifierType.Allow, Enum.AccessModifierType.Deny
	check("9a an alive participant is heard by everyone", alive.input.AccessType == Deny and #alive.input.list == 0)
	check("9b a chat participant is heard by nobody, even while alive", chatter.input.AccessType == Allow and #chatter.input.list == 0)
	check("9c spectators are heard by spectators only", spectator.input.AccessType == Allow
		and table.find(spectator.input.list, spectator.UserId) ~= nil and table.find(spectator.input.list, late.UserId) ~= nil
		and table.find(spectator.input.list, alive.UserId) == nil and table.find(spectator.input.list, chatter.UserId) == nil)
	RealVoice.setSilenced({ chatter.UserId, late.UserId })
	late.input = newInput()
	late.ChildAdded.fire(late.input) -- their voice connects mid-round
	check("9d a voice that connects mid-round gets the current setting (silenced)", late.input.AccessType == Allow
		and #late.input.list == 0)
	RealVoice.setSpeakers(nil)
	RealVoice.setSilenced({})
	local open = true
	for _, p in playerList do
		open = open and p.input.AccessType == Deny and #p.input.list == 0
	end
	check("9e round over: everyone is heard by everyone", open)
	-- The floor (bundle 6b): the speaker and the presenter heard by everyone, the other alive players by nobody.
	local holder, other, host = voicePlayer(4005), voicePlayer(4006), voicePlayer(4007)
	playerList = { holder, other, host, spectator }
	RealVoice.setSpeakers({ holder.UserId, other.UserId, host.UserId })
	RealVoice.setFloor({ holder.UserId, host.UserId })
	check("9f the floor: the speaker and the presenter are heard by everyone, the other players by nobody; spectators as before",
		holder.input.AccessType == Deny and #holder.input.list == 0 and host.input.AccessType == Deny
		and other.input.AccessType == Allow and #other.input.list == 0 and spectator.input.AccessType == Allow
		and table.find(spectator.input.list, spectator.UserId) ~= nil)
	RealVoice.setFloor(nil)
	check("9g the floor given back: every player heard again", other.input.AccessType == Deny and #other.input.list == 0)
	RealVoice.setSpeakers(nil)
	playerList = {}
end

---------------------------------------------------------------- 10. the presenter (PresenterService through RoundService)
do
	local Presenter = require(node("PresenterService"))
	local volunteer = NetStub.listeners.Volunteer
	local pickMission = NetStub.listeners.PresenterPick
	local pressSound = NetStub.listeners.PresenterSound
	local function offer(player, on) -- one request, after the per-player cooldown has passed
		at(now + Config.VOLUNTEER_COOLDOWN)
		volunteer(player, on)
	end
	local function lastState()
		for i = #NetStub.sent, 1, -1 do
			if NetStub.sent[i].name == "RoundState" then
				return NetStub.sent[i].payload
			end
		end
		return nil
	end
	local function menus(since) -- menus that opened since `since`: { to, payload }
		local list = {}
		for _, m in NetStub.sent do
			if m.name == "PresenterMenu" and m.at >= since and m.payload.options then
				table.insert(list, m)
			end
		end
		return list
	end

	-- 10A: three players, one volunteers: they present, the menu, a pick, sounds, then missed picks.
	local ps = newPlayers(3)
	offer(ps[1], true)
	local since = now
	local play = begin(ps, 10, nil, nil)
	local state = lastState()
	check("10a a volunteer presents the round and takes no chair", Match.presenter == ps[1] and Match.participants[ps[1]] == nil
		and Match.participants[ps[2]] ~= nil and state ~= nil and state.presenter == ps[1].UserId)
	check("10b the presenter is heard by everyone", Voice.speakers ~= nil and table.find(Voice.speakers, ps[1].UserId) ~= nil)
	local menuAt = play -- (no free talk: the presenter picks the first game at once)
	at(menuAt + 0.5)
	local opened = menus(since)
	check("10c the menu opens to the presenter alone between games (the first right away)", #opened == 1
		and opened[1].to == ps[1] and math.abs(opened[1].at - menuAt) < 0.3 and opened[1].payload.options[1].id == "scripted"
		and opened[1].payload.options[1].recommended == true and Match.message == Config.TEXT.PICKING)
	local function closes()
		local n = 0
		for _, m in NetStub.sent do
			if m.name == "PresenterMenu" and m.at >= since and not m.payload.options then
				n += 1
			end
		end
		return n
	end
	pickMission(ps[2], "scripted") -- not the presenter
	pickMission(ps[1], "nope") -- not on the menu
	at(now + 0.5)
	local stillOpen = menus(since)
	local closedEarly = closes()
	local pickedAt = now
	pickMission(ps[1], "scripted")
	at(now + 1 + CARD)
	check("10d a pick by anyone else or of something not offered is ignored; the presenter's pick starts after its briefing",
		#stillOpen == 1 and closedEarly == 0 and #Scripted.runs == 1 and math.abs(Scripted.runs[1] - pickedAt - CARD) < 0.3
		and noticesWith(Config.TEXT.PICK_AUTO, since) == 0)
	local before = #sent("Sound", since)
	pressSound(ps[1], 1)
	pressSound(ps[1], 1) -- the same button again at once
	pressSound(ps[1], 2)
	pressSound(ps[2], 3) -- not the presenter
	pressSound(ps[1], 99) -- no such button
	local sounds = sent("Sound", since)
	check("10e sound buttons: the presenter only, each button once per PRESENTER_SOUND_COOLDOWN", #sounds == before + 2
		and sounds[#sounds - 1].payload.index == 1 and sounds[#sounds].payload.index == 2)
	-- No more picks: the system picks; PRESENTER_MISSES misses in a row and nobody else volunteers -> the system.
	local cycle = Config.PRESENTER_PICK_SECONDS + CARD + Scripted.expectedSeconds
	advanceUntil(function() return Match.presenter == nil end, cycle * (Config.PRESENTER_MISSES + 1))
	check("10f a missed pick is made by the system (notice); PRESENTER_MISSES in a row end the presenting",
		noticesWith(Config.TEXT.PICK_AUTO, since) == Config.PRESENTER_MISSES and Match.presenter == nil
		and #Scripted.runs >= Config.PRESENTER_MISSES and lastState().presenter == nil)
	check("10g ...and the presenter is no longer heard by the table", table.find(Voice.speakers, ps[1].UserId) == nil)
	at(now + 1)
	leave(ps[3], { ps[1], ps[2] })
	finish(since)

	-- 10B: the presenter leaves mid-round -> a volunteer who is not playing takes over; then steps down -> the system.
	local qs = newPlayers(3)
	offer(qs[1], true)
	local since2 = now
	local play2 = begin(qs, 10, nil, nil)
	local late = fakePlayer(nextId + 50)
	playerList = { qs[1], qs[2], qs[3], late }
	task.spawn(Players.PlayerAdded.fire, late)
	offer(late, true)
	leave(qs[1], { qs[2], qs[3], late })
	at(now + 0.5)
	check("10h a presenter who leaves is replaced by a volunteer who is not playing", Match.presenter == late
		and lastState().presenter == late.UserId and Match.participants[late] == nil)
	offer(late, false)
	at(now + 0.5)
	check("10i a presenter who stops volunteering steps down (the system runs the round, they watch from the stands)",
		Match.presenter == nil and find(Spectator.stands, late) ~= nil)
	at(play2 + 3)
	NetStub.listeners.DevFling(qs[3], "out")
	finish(since2)

	-- 10C: presenting to the end scores and is credited; the presenter may move again afterwards.
	local rs = newPlayers(2)
	offer(rs[1], true)
	local since3 = now
	local play3 = begin(rs, 10, nil, nil)
	local humanoid = rs[1].Character:FindFirstChildOfClass("Humanoid")
	local lockedWalk = humanoid.WalkSpeed
	at(play3 + 2)
	NetStub.listeners.DevFling(rs[2], "out")
	local list3 = finish(since3)
	local result3 = phaseAt(list3, "Result")
	check("10j the presenter at the end scores SCORE_PRESENTER and is named in the result", Score.added[rs[1]] == Config.SCORE_PRESENTER
		and result3 ~= nil and string.find(result3.message, string.format(Config.TEXT.PRESENTER_CREDIT, rs[1].DisplayName), 1, true) ~= nil)
	check("10k the presenter stays at the podium in the round and may move again after it", lockedWalk == Config.PRESENTER_WALK_SPEED
		and humanoid.WalkSpeed == 16)

	-- 10E: an out player who volunteers may take over the round (docs/DESIGN_V3.md §8).
	local ts = newPlayers(4)
	offer(ts[1], true)
	local since5 = now
	local play5 = begin(ts, 10, nil, nil)
	at(play5 + 2)
	NetStub.listeners.DevFling(ts[4], "out")
	at(now + Config.FLING_RETURN_SECONDS + 1)
	offer(ts[4], true)
	offer(ts[1], false)
	at(now + 0.5)
	check("10t an out player who volunteers may take over the round", Match.presenter == ts[4]
		and lastState().presenter == ts[4].UserId and not Match.isAlive(ts[4]))
	NetStub.listeners.DevFling(ts[3], "out")
	finish(since5)

	-- 10F: a flying out player cannot take over; a replaced presenter is not chosen again in that round.
	local fs = newPlayers(4)
	offer(fs[1], true)
	local since6 = now
	local play6 = begin(fs, 10, nil, nil)
	at(play6 + 2)
	NetStub.listeners.DevFling(fs[4], "out")
	at(now + 0.2)
	volunteer(fs[4], true) -- (first request of this player: no cooldown to wait for)
	volunteer(fs[1], false)
	at(now + 0.5)
	check("10w a flying player cannot take over (the system runs the round)", Match.presenter == nil)
	finish(since6)

	local us = newPlayers(5)
	offer(us[1], true)
	local since7 = now
	local play7 = begin(us, 10, nil, nil)
	at(play7 + 2)
	NetStub.listeners.DevFling(us[5], "out")
	at(now + Config.FLING_RETURN_SECONDS + 1)
	offer(us[5], true)
	offer(us[1], false)
	at(now + 0.5)
	local tookOver = Match.presenter == us[5]
	offer(us[1], true) -- the stepped-down presenter volunteers again
	offer(us[5], false)
	at(now + 0.5)
	check("10v a replaced presenter is not chosen again in that round", tookOver and Match.presenter == nil)
	NetStub.listeners.DevFling(us[3], "out")
	NetStub.listeners.DevFling(us[4], "out")
	finish(since7)

	-- 10G: the round ends while the checks for a replacement still run -> nobody presents, nothing is locked.
	workspaceAttributes.BW_ServerKind = "public" -- friend checks run
	local vs = newPlayers(3)
	offer(vs[1], true)
	local since8 = now
	local play8 = begin(vs, 10, nil, nil)
	local spare = fakePlayer(nextId + 60)
	playerList = { vs[1], vs[2], vs[3], spare }
	task.spawn(Players.PlayerAdded.fire, spare)
	offer(spare, true)
	at(play8 + 3)
	friendsDelay = 4
	offer(vs[1], false) -- steps down: the two friend checks for `spare` take 8 s
	local steppedDown = now
	at(now + 0.5)
	local pendingWhileChecking = Match.presenterPending -- (sent with the next broadcast; none comes before the checks end here)
	NetStub.listeners.DevFling(vs[3], "out") -- the round is over once the flight ends (about 5 s)
	at(steppedDown + 10) -- the checks are done; the result shows for RESULT_TIME
	friendsDelay = 0
	local spareHumanoid = spare.Character:FindFirstChildOfClass("Humanoid")
	check("10u a round that ends during the checks gets no new presenter", Match.phase == "Result"
		and Match.presenter == nil and (spareHumanoid == nil or spareHumanoid.WalkSpeed ~= Config.PRESENTER_WALK_SPEED))
	check("10y clients are told a replacement is being looked for, and when it is over", pendingWhileChecking
		and Match.presenterPending == false)
	workspaceAttributes.BW_ServerKind = nil
	finish(since8)

	-- 10Z: someone leaves while the presenter checks of a new round run (review 2026-10-25): they get no chair, and the
	-- round waits for enough players instead of starting with one (here: the volunteer then plays as the second).
	workspaceAttributes.BW_ServerKind = "public" -- friend checks run
	local studioMin = Config.MIN_PLAYERS
	Config.MIN_PLAYERS = 2 -- (live servers; Studio plays rounds of one)
	local zs = newPlayers(3)
	offer(zs[1], true)
	playerList = zs
	advanceUntil(function() return Match.phase == "Countdown" end, 60)
	friendsDelay = 3
	at(Match.endsAt + 1.5) -- (the countdown is over and the checks run: two friend checks of 3 s, still "Countdown")
	friendsDelay = 0
	local checking = Match.phase == "Countdown"
	leave(zs[3], { zs[1], zs[2] })
	local startedAlone, sinceZ = false, now
	advanceUntil(function()
		if Match.phase == "Play" and Match.startedWith < 2 then
			startedAlone = true
		end
		return Match.phase == "Play"
	end, 120)
	check("10z a player who left during the presenter checks gets no chair, and no round starts with one",
		checking and not startedAlone and Match.participants[zs[3]] == nil and Match.startedWith == 2
		and Match.participants[zs[1]] ~= nil and Match.participants[zs[2]] ~= nil,
		string.format("checking=%s alone=%s z3=%s started=%s z1=%s z2=%s phase=%s", tostring(checking),
			tostring(startedAlone), tostring(Match.participants[zs[3]] ~= nil), tostring(Match.startedWith),
			tostring(Match.participants[zs[1]] ~= nil), tostring(Match.participants[zs[2]] ~= nil), tostring(Match.phase)))
	workspaceAttributes.BW_ServerKind = nil
	finish(sinceZ)
	Config.MIN_PLAYERS = studioMin

	-- 10D: who may present (PresenterService.choose directly, between rounds).
	local function pool(n)
		local list = newPlayers(n)
		for _, p in list do
			offer(p, true)
		end
		return list
	end
	local function choose(candidates)
		local chosen = Presenter.choose(candidates)
		Match.presenter = nil
		return chosen
	end
	Match.serverKind = "public"
	local a = pool(1)
	check("10l a presenter needs MIN_PLAYERS others to play", choose({ a[1] }) == nil)
	local b = newPlayers(2)
	offer(b[1], true)
	Match.chatJoin[b[1]] = true
	check("10m a chat participant cannot present", choose(b) == nil)
	Match.chatJoin[b[1]] = nil
	Config.REQUIRE_VOICE_READY = true
	local notReady = choose(b)
	Match.ready[b[1]] = true
	local readyNow = choose(b)
	Config.REQUIRE_VOICE_READY = false
	Match.ready[b[1]] = nil
	check("10n on live servers a presenter needs their voice ready", notReady == nil and readyNow == b[1])
	friendPairs[b[1].UserId .. "-" .. b[2].UserId] = true
	local publicFriend = choose(b)
	Match.serverKind = "private"
	local privateFriend = choose(b)
	Match.serverKind = "public"
	friendPairs[b[1].UserId .. "-" .. b[2].UserId] = nil
	check("10o public servers: nobody's friend may present; private servers: friends may", publicFriend == nil and privateFriend == b[1])
	voiceGroups[b[1].UserId] = { "x" }
	local apart = choose(b)
	voiceGroups[b[1].UserId] = nil
	check("10p the presenter must share a voice chat group with every voice participant", apart == nil)
	Match.chatJoin[b[2]] = true
	voiceGroups[b[2].UserId] = { "y" }
	local apartChat = choose(b)
	voiceGroups[b[2].UserId] = nil
	Match.chatJoin[b[2]] = nil
	check("10p2 and with every chat participant too (they hear the presenter, owner 2026-10-25)", apartChat == nil)
	Match.chatJoin[b[2]] = true
	chatBlocked[b[2].UserId .. ">" .. b[1].UserId] = true
	local blocked = choose(b)
	chatBlocked[b[2].UserId .. ">" .. b[1].UserId] = nil
	Match.chatJoin[b[2]] = nil
	check("10q the presenter must receive every chat participant's messages", blocked == nil)
	friendsDelay = 2
	local switched = "pending"
	task.spawn(function()
		switched = choose(b)
	end)
	Match.chatJoin[b[1]] = true -- while the friend check runs
	at(now + 5)
	Match.chatJoin[b[1]] = nil
	friendsDelay = 0
	check("10x a volunteer who switches to chat during the checks is not chosen", switched == nil)
	groupsBroken = true
	local studio = choose(b)
	RunService.IsStudio = function() return false end
	local live = choose(b)
	RunService.IsStudio = function() return true end
	groupsBroken = false
	check("10r a check that cannot run: Studio allows, live servers do not", studio == b[1] and live == nil)
	local c = pool(2)
	local others = newPlayers(1)
	local first = choose({ c[1], c[2], others[1] })
	local second = choose({ c[1], c[2], others[1] })
	check("10s volunteers take turns (who presented least goes first)", first ~= nil and second ~= nil and first ~= second)
end

---------------------------------------------------------------- 11. answer missions missed in a row (the AFK rule)
do
	local ps = newPlayers(3)
	local since = now
	local play = begin(ps, 10, nil, nil)
	Scripted.missed = function(_alive) return { ps[3] } end
	local secondEnd = play + 2 * (CARD + Scripted.expectedSeconds) + 1
	at(play + CARD + Scripted.expectedSeconds + 1)
	local afterOne = Match.isAlive(ps[3])
	at(secondEnd)
	local afk = lifeLost(since, "afk")
	check("11a two answer missions missed in a row make a player a spectator (one toast, reason afk)", afterOne
		and not Match.isAlive(ps[3]) and #afk == 1 and afk[1].payload.players[1].userId == ps[3].UserId
		and Match.isAlive(ps[1]) and Match.isAlive(ps[2]))
	NetStub.listeners.DevFling(ps[2], "out")
	finish(since)

	-- The AFK player's going out and the same question's wrong answers are one event: with four at the start, an
	-- AFK out leaving three decides the final, but the wrong answer still costs its life.
	local qs = newPlayers(4)
	local since2 = now
	local play2 = begin(qs, 10, function(run, _alive) return if run == 2 then { qs[3] } else {} end, nil)
	Scripted.missed = function(_alive) return { qs[4] } end
	at(play2 + 2 * (CARD + Scripted.expectedSeconds) + 1)
	check("11b an AFK out that decides the final does not drop the same question's wrong answers",
		not Match.isAlive(qs[4]) and Match.participants[qs[3]].lives == Config.LIVES - 1)
	finish(since2)
end

---------------------------------------------------------------- 12. the presenter judges (the one-word mission's launch)
do
	local volunteer = NetStub.listeners.Volunteer
	local pickMission = NetStub.listeners.PresenterPick
	local ps = newPlayers(4) -- ps[1] presents, three play
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(ps[1], true)
	workspaceAttributes.BW_ServerKind = "public"
	local since = now
	local play = begin(ps, 10, nil, nil)
	Scripted.judge = true
	local function judgeMenu(after)
		for i = #NetStub.sent, 1, -1 do
			local m = NetStub.sent[i]
			if m.at < after then
				break
			end
			if m.name == "PresenterMenu" and m.payload.kind == "judge" and m.payload.options then
				return m
			end
		end
		return nil
	end
	local missionAt = play + Config.PRESENTER_PICK_SECONDS + CARD + Scripted.expectedSeconds -- (the pick menu runs out first)
	at(missionAt + 0.5)
	local menu = judgeMenu(since)
	local target = ps[3]
	if menu then
		pickMission(ps[1], tostring(target.UserId))
	end
	at(now + 1)
	check("12a the judge menu goes to the presenter alone; their pick launches that player (subjective)", menu ~= nil
		and menu.to == ps[1] and Match.participants[target].lives == Config.LIVES - 1 and Scripted.judged[1] == tostring(target.UserId))
	-- The next mission: the same player again -> public servers allow SUBJECTIVE_FLINGS per player per round.
	local since2 = now
	at(missionAt + 0.5 + Config.FLING_RETURN_SECONDS + Config.PRESENTER_PICK_SECONDS + CARD + Scripted.expectedSeconds + 1)
	local menu2 = judgeMenu(since2)
	if menu2 then
		pickMission(ps[1], tostring(target.UserId))
	end
	at(now + 1)
	check("12b public servers: a second subjective launch of the same player in a round costs nothing", menu2 ~= nil
		and Match.participants[target].lives == Config.LIVES - 1)
	workspaceAttributes.BW_ServerKind = nil
	Scripted.judge = nil
	NetStub.listeners.DevFling(ps[2], "out")
	NetStub.listeners.DevFling(ps[4], "out")
	finish(since)
end

---------------------------------------------------------------- 13. the banned-word talk (bundle 6a)
-- The real BannedTalk mission (the scripted one is switched off for the main game here, so the talk is the only game).
local ChatGate = require(node("ChatGate"))
local general = { Name = "RBXGeneral" }
local whisper = { Name = "RBXWhisper:1_2" }
local function wordOf(player)
	local p = Match.participants[player]
	return p and p.words[1] and p.words[1].text
end
-- The latest message `name` (to `to`, of payload kind `kind`, when given) sent since `since`.
local function lastSent(name, since, to, kind)
	for i = #NetStub.sent, 1, -1 do
		local m = NetStub.sent[i]
		if m.at < since then
			break
		end
		if m.name == name and (to == nil or m.to == to) and (kind == nil or m.payload.kind == kind) then
			return m
		end
	end
	return nil
end
local function lastWordsTo(player, since)
	local m = lastSent("Words", since, player)
	return m and m.payload
end
local function lastRescueTo(player, since)
	local m = lastSent("Rescue", since, player)
	return m and m.payload
end
local function beepsSince(since)
	local n = 0
	for _, m in sent("Sound", since) do
		if m.payload.index == Config.HIT_SOUND then
			n += 1
		end
	end
	return n
end
local messages = 0
local function say(player, text)
	messages += 1
	local id = "msg" .. messages
	ChatGate.received(id, player, text) -- (the delivery callback calls this once per receiver)
	ChatGate.received(id, player, text)
	at(now + 0.05)
end
-- The presenter picks the banned-word talk from the menu (waits for the menu to open). Returns the menu.
local function pickTalk(presenter, since)
	local menu = nil
	advanceUntil(function()
		local m = lastSent("PresenterMenu", since, presenter)
		if m and m.payload.options and m.payload.kind == "pick" then
			menu = m
		end
		return menu ~= nil
	end, 30)
	if menu then
		NetStub.listeners.PresenterPick(presenter, "bannedTalk")
	end
	at(now + 0.3 + CARD) -- (its briefing first)
	return menu
end
local function noticesTo(player, since)
	local list = {}
	for _, m in sent("Notice", since) do
		if m.to == player then
			table.insert(list, m.payload.text)
		end
	end
	return list
end

-- 13A: without speech judging the talk is never played (nothing else is offered here: the final comes at once).
do
	workspaceAttributes.BW_ServerKind = "private"
	Scripted.off = true
	local ps = newPlayers(2)
	local since = now
	local play = begin(ps, 10, nil, nil)
	advanceUntil(function() return Match.phase == "Final" end, 30)
	local final = phaseAt(phases(since), "Final")
	check("13a without speech judging the banned-word talk is never played (no game fits: the final at once)", final ~= nil
		and final.at - play < 1 and lastSent("Mission", since, nil, "talk") == nil and wordOf(ps[1]) == nil)
	finish(since)
end

workspaceAttributes.BW_VoiceJudging = true

-- 13B: a private server with a presenter: the prep stage, re-draws, "start now", the ear, chat hits, the settle stage.
do
	local volunteer = NetStub.listeners.Volunteer
	local ear = NetStub.listeners.EarJudge
	local reroll = NetStub.listeners.Reroll
	local talkStart = NetStub.listeners.TalkStart
	local rescue = NetStub.listeners.Rescue
	local ps = newPlayers(4) -- ps[1] presents
	local spectator = newPlayers(1)[1]
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(ps[1], true)
	local since = now
	begin(ps, 10, nil, nil)
	playerList = { ps[1], ps[2], ps[3], ps[4], spectator }
	local menu = pickTalk(ps[1], since)
	local prepAt = now
	local view = lastWordsTo(ps[2], since)
	local screen = lastSent("Mission", since, nil, "talk")
	local topic = if screen then screen.payload.topic else ""
	local clean = true
	for i = 2, 4 do
		local word = wordOf(ps[i])
		clean = clean and word ~= nil and string.find(topic, word, 1, true) == nil
	end
	check("13b the talk's prep stage: a word for each player (none for the presenter, none inside the topic), own word hidden",
		menu ~= nil and #menu.payload.options == 1 and menu.payload.options[1].id == "bannedTalk" and Match.talk == "prep"
		and clean and Match.participants[ps[1]] == nil and view ~= nil and view[tostring(ps[2].UserId)].words == nil
		and view[tostring(ps[3].UserId)].words ~= nil and screen ~= nil and screen.payload.stage == "prep" and topic ~= "")
	check("13c chat rules come with the talk: spectators and the presenter do not reach players; whispers are off",
		ChatGate.shouldDeliver(general, spectator, ps[2]) == false and ChatGate.shouldDeliver(general, ps[1], ps[2]) == false
		and ChatGate.shouldDeliver(general, ps[2], spectator) == true and ChatGate.shouldDeliver(whisper, ps[2], ps[3]) == false
		and fakeWhisperCommand.Enabled == false)
	local quietAt = now
	say(ps[2], wordOf(ps[2]))
	ear(ps[1], ps[3].UserId)
	at(now + Config.LEVER_SECONDS + 0.2)
	check("13d the prep stage judges nothing (a player's own word in chat, the presenter's ear)", beepsSince(quietAt) == 0
		and #sent("Lever", quietAt) == 0 and Match.participants[ps[2]].lives == Config.LIVES
		and Match.participants[ps[3]].lives == Config.LIVES)
	at(now + Config.EAR_COOLDOWN)
	local before = wordOf(ps[2])
	reroll(ps[3], ps[2].UserId) -- not the presenter
	local afterStranger = wordOf(ps[2])
	reroll(ps[1], "all") -- a private server has no "everyone"
	local afterAll = wordOf(ps[2])
	at(now + Config.EAR_COOLDOWN)
	reroll(ps[1], ps[2].UserId)
	local afterPresenter = wordOf(ps[2])
	check("13e the presenter (only) re-draws one player's word in the prep stage (private: no \"everyone\")",
		afterStranger == before and afterAll == before and afterPresenter ~= nil and afterPresenter ~= before
		and string.find(topic, afterPresenter, 1, true) == nil)
	talkStart(ps[2]) -- not the presenter
	at(now + 0.3)
	local stillPrep = Match.talk == "prep"
	talkStart(ps[1])
	at(now + 0.3)
	local talkAt = now
	local screen2 = lastSent("Mission", prepAt, nil, "talk")
	check("13f \"start now\" (the presenter only) ends the prep stage early", stillPrep and Match.talk == "talk"
		and talkAt - prepAt < Config.TALK_REROLL_SECONDS and screen2 ~= nil and screen2.payload.stage == "talk")
	-- The presenter's ear: what the system missed.
	at(now + Config.EAR_COOLDOWN)
	local word3 = wordOf(ps[3])
	local earAt = now
	ear(ps[2], ps[3].UserId) -- not the presenter
	ear(ps[1], ps[3].UserId)
	ear(ps[1], ps[4].UserId) -- within EAR_COOLDOWN: ignored
	local levers = #sent("Lever", earAt)
	at(now + Config.LEVER_SECONDS + 0.2)
	check("13g the presenter's ear in the talk: the lever, then a life and a new word (no rescue); others' presses are ignored",
		levers == 1 and Match.participants[ps[3]].lives == Config.LIVES - 1 and wordOf(ps[3]) ~= word3
		and Match.participants[ps[4]].lives == Config.LIVES)
	-- Chat: a hit waits for the presenter's rescue; none -> a life and a new word (a second hit is merged).
	local word2 = wordOf(ps[2])
	local hitAt = now
	say(ps[2], "음 " .. word2 .. " 맞지?")
	local banner = lastRescueTo(ps[1], hitAt)
	check("13h a banned word in chat: one beep and the presenter's rescue banner (once per message)", beepsSince(hitAt) == 1
		and banner ~= nil and #banner.hits == 1 and banner.hits[1].userId == ps[2].UserId and banner.hits[1].word == word2)
	say(ps[2], word2 .. " 또") -- while the hit waits: merged
	at(hitAt + Config.RESCUE_SECONDS + 0.3)
	check("13i no rescue in time: a life and a new word (a second hit while waiting is merged)",
		Match.participants[ps[2]].lives == Config.LIVES - 1 and wordOf(ps[2]) ~= word2)
	local word4 = wordOf(ps[4])
	local hit4 = now
	say(ps[4], word4)
	rescue(ps[2], ps[4].UserId) -- not the presenter: nothing happens
	local stillWaiting = lastRescueTo(ps[1], hit4)
	rescue(ps[1], ps[4].UserId)
	local afterRescue = lastRescueTo(ps[1], hit4)
	at(hit4 + Config.RESCUE_SECONDS + 0.3)
	check("13j only the presenter rescues: no life lost, but a new word", stillWaiting ~= nil and #stillWaiting.hits == 1
		and afterRescue ~= nil and #afterRescue.hits == 0 and Match.participants[ps[4]].lives == Config.LIVES
		and wordOf(ps[4]) ~= word4 and noticesWith(string.format(Config.TEXT.RESCUED, ps[4].DisplayName), hit4) == 1)
	NetStub.listeners.DevFling(ps[3], "out")
	at(now + Config.FLING_RETURN_SECONDS + 1)
	local outAt = now
	say(ps[3], wordOf(ps[3]) or "?") -- out now: their word no longer counts
	check("13k only alive players are judged; out players do not reach players", not Match.isAlive(ps[3])
		and wordOf(ps[3]) ~= nil and beepsSince(outAt) == 0 and ChatGate.shouldDeliver(general, ps[3], ps[2]) == false)
	-- The talk ends: the settle stage tells everyone their word, then the words and the chat rules go.
	local endAt = talkAt + Config.TALK_SECONDS
	at(endAt - 0.5)
	local final2, final4 = wordOf(ps[2]), wordOf(ps[4])
	advanceUntil(function() return Match.talk == nil end, 10)
	local told2 = noticesTo(ps[2], endAt - 0.5)
	local view2 = lastWordsTo(ps[2], endAt - 0.5)
	local entry4 = view2 and view2[tostring(ps[4].UserId)]
	check("13l the settle stage: everyone is told their word, then the words, the chat rules and the whisper block go",
		Match.talk == nil and wordOf(ps[2]) == nil and #told2 == 1 and told2[1] == string.format(Config.TEXT.MY_WORD_WAS, final2)
		and entry4 ~= nil and entry4.count == 0 and ChatGate.shouldDeliver(general, spectator, ps[2]) == true
		and fakeWhisperCommand.Enabled == true)
	local lateAt = now
	say(ps[4], final4)
	check("13m after the talk nothing is judged", beepsSince(lateAt) == 0 and Match.participants[ps[4]].lives == Config.LIVES)
	NetStub.listeners.DevFling(ps[4], "out")
	finish(since)
end

-- 13C: a public server with a presenter: re-draws of everyone (REROLLS_PUBLIC), rescues (RESCUES_PUBLIC), the ear is
-- a subjective launch.
do
	workspaceAttributes.BW_ServerKind = "public"
	local volunteer = NetStub.listeners.Volunteer
	local ear = NetStub.listeners.EarJudge
	local reroll = NetStub.listeners.Reroll
	local rescue = NetStub.listeners.Rescue
	local ps = newPlayers(4) -- ps[1] presents
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(ps[1], true)
	local since = now
	begin(ps, 10, nil, nil)
	pickTalk(ps[1], since)
	local before = { wordOf(ps[2]), wordOf(ps[3]), wordOf(ps[4]) }
	reroll(ps[1], ps[2].UserId) -- public: no single re-draws
	local afterOne = wordOf(ps[2])
	at(now + Config.EAR_COOLDOWN)
	reroll(ps[1], "all")
	local afterAll = { wordOf(ps[2]), wordOf(ps[3]), wordOf(ps[4]) }
	at(now + Config.EAR_COOLDOWN)
	reroll(ps[1], "all") -- past REROLLS_PUBLIC
	local afterSecond = { wordOf(ps[2]), wordOf(ps[3]), wordOf(ps[4]) }
	check("13n public servers: the presenter re-draws everyone at once, REROLLS_PUBLIC times a round (no single re-draws)",
		afterOne == before[1] and (afterAll[1] ~= before[1] or afterAll[2] ~= before[2] or afterAll[3] ~= before[3])
		and afterSecond[1] == afterAll[1] and afterSecond[2] == afterAll[2] and afterSecond[3] == afterAll[3])
	NetStub.listeners.TalkStart(ps[1])
	at(now + 0.3)
	local hitAt = now
	say(ps[2], wordOf(ps[2]))
	say(ps[3], wordOf(ps[3]))
	rescue(ps[1], ps[2].UserId)
	rescue(ps[1], ps[3].UserId) -- the second rescue of the round
	at(hitAt + Config.RESCUE_SECONDS + 0.3)
	check("13o public servers: RESCUES_PUBLIC rescues a round (the second hit is not rescued)", Match.talk == "talk"
		and Match.participants[ps[2]].lives == Config.LIVES and Match.participants[ps[3]].lives == Config.LIVES - 1)
	at(now + Config.EAR_COOLDOWN)
	ear(ps[1], ps[4].UserId)
	at(now + Config.LEVER_SECONDS + 0.2)
	local afterFirst = Match.participants[ps[4]].lives
	at(now + Config.FLING_RETURN_SECONDS + 1)
	local secondAt = now
	ear(ps[1], ps[4].UserId)
	at(now + Config.LEVER_SECONDS + 0.2)
	check("13p public servers: the presenter's ear is a subjective launch (once per player a round, no lever beyond it)",
		afterFirst == Config.LIVES - 1 and Match.participants[ps[4]].lives == Config.LIVES - 1 and #sent("Lever", secondAt) == 0)
	NetStub.listeners.DevFling(ps[3], "out")
	NetStub.listeners.DevFling(ps[4], "out")
	finish(since)
	workspaceAttributes.BW_ServerKind = "private"
end

-- 13D: no presenter: TALK_PREP_SECONDS of prep, a chat hit flies at once; a talk cut short still settles.
do
	local ps = newPlayers(3)
	local since = now
	begin(ps, 10, nil, nil)
	advanceUntil(function() return Match.talk == "prep" end, 10)
	local prepAt = now
	advanceUntil(function() return Match.talk == "talk" end, Config.TALK_PREP_SECONDS + 2)
	local talkSeen = now
	local word2 = wordOf(ps[2])
	local hitAt = now
	say(ps[2], word2)
	check("13q without a presenter: TALK_PREP_SECONDS of prep, and a chat hit flies at once (no rescue wait)",
		math.abs(talkSeen - prepAt - Config.TALK_PREP_SECONDS) < 0.6 and Match.participants[ps[2]].lives == Config.LIVES - 1
		and wordOf(ps[2]) ~= word2 and beepsSince(hitAt) == 1 and count(Seat.flings, ps[2]) == 1,
		string.format("prep %.1f s", talkSeen - prepAt))
	NetStub.listeners.DevFling(ps[3], "out")
	NetStub.listeners.DevFling(ps[2], "out") -- ps[1] is the last one: decided in the middle of the talk
	advanceUntil(function() return Match.phase == "Result" end, 30)
	check("13r a talk cut short by the round's end still settles (words and chat rules gone by the result)",
		Match.phase == "Result" and wordOf(ps[1]) == nil and Match.talk == nil
		and ChatGate.shouldDeliver(general, ps[3], ps[1]) == true)
	finish(since)
end

-- 13E: two players on their last life both wait for a rescue and get none: judged together (everyone at once -> the
-- final among them), not one after the other (the first out, the second protected and the winner).
do
	local volunteer = NetStub.listeners.Volunteer
	local ps = newPlayers(3) -- ps[1] presents
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(ps[1], true)
	local since = now
	begin(ps, 10, nil, nil)
	pickTalk(ps[1], since)
	NetStub.listeners.TalkStart(ps[1])
	at(now + 0.3)
	Match.participants[ps[2]].lives = 1
	Match.participants[ps[3]].lives = 1
	local hitAt = now
	say(ps[2], wordOf(ps[2]))
	at(now + 1)
	say(ps[3], wordOf(ps[3]))
	at(hitAt + Config.RESCUE_SECONDS + 0.3) -- ps[2]'s wait is over (not rescued), ps[3]'s still runs
	local heldAt = now
	NetStub.listeners.EarJudge(ps[1], ps[2].UserId)
	at(hitAt + 1 + Config.RESCUE_SECONDS + 0.3)
	local events = lifeLost(hitAt, "fail")
	check("13s two last-life hits waiting for rescues are judged together: both play the final (one event, final = true)",
		#events == 1 and #events[1].payload.players == 2 and events[1].payload.final == true
		and Match.isAlive(ps[2]) and Match.isAlive(ps[3]) and #sent("Lever", heldAt) == 0)
	finish(since)
end

-- 13F: the presenter's ear and the talk's end: not while a hit of theirs waits for a rescue; a lever pulled in the last
-- moment lands in the settle stage; a hit caught near the end costs its life there, and the word told is the one said.
do
	local volunteer = NetStub.listeners.Volunteer
	local ear = NetStub.listeners.EarJudge
	local ps = newPlayers(4) -- ps[1] presents
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(ps[1], true)
	local since = now
	begin(ps, 10, nil, nil)
	pickTalk(ps[1], since)
	NetStub.listeners.TalkStart(ps[1])
	at(now + 0.3)
	local talkAt = now
	local waitAt = now
	say(ps[2], wordOf(ps[2]))
	ear(ps[1], ps[2].UserId) -- their chat hit waits for a rescue
	at(now + Config.LEVER_SECONDS + 0.2)
	check("13t no ear judgment against a player whose hit waits for a rescue (no lever)", #sent("Lever", waitAt) == 0)
	at(talkAt + Config.TALK_SECONDS - 0.55) -- (the talk began up to 0.3 s before talkAt; no rescue waits at its end)
	local pressed = Match.talk
	ear(ps[1], ps[4].UserId) -- its lever lands after the talk's end
	at(now + Config.LEVER_SECONDS)
	local landedIn = Match.talk
	advanceUntil(function() return Match.talk == nil end, 10)
	check("13u a lever pulled in the talk's last moment still counts (it lands in the settle stage)",
		pressed == "talk" and landedIn == "settle" and Match.participants[ps[4]].lives == Config.LIVES - 1,
		tostring(pressed) .. " -> " .. tostring(landedIn))
	NetStub.listeners.DevFling(ps[3], "out")
	NetStub.listeners.DevFling(ps[4], "out")
	finish(since)

	-- A hit caught near the end: its life is taken in the settle stage, and the word told is the one said.
	local qs = newPlayers(3) -- qs[1] presents
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(qs[1], true)
	local since2 = now
	begin(qs, 10, nil, nil)
	pickTalk(qs[1], since2)
	NetStub.listeners.TalkStart(qs[1])
	at(now + 0.3)
	local talk2 = now
	at(talk2 + Config.TALK_SECONDS - 1)
	local said = wordOf(qs[2])
	say(qs[2], said) -- resolves after the talk's end
	advanceUntil(function() return Match.talk == nil end, 10)
	local told = noticesTo(qs[2], talk2 + Config.TALK_SECONDS - 1)
	check("13v a hit caught near the end costs its life in the settle stage, and the word told is the one said",
		Match.participants[qs[2]].lives == Config.LIVES - 1 and #told == 1 and told[1] == string.format(Config.TEXT.MY_WORD_WAS, said))
	NetStub.listeners.DevFling(qs[3], "out")
	finish(since2)
end

---------------------------------------------------------------- 14. chat judging at the edges (bundles 5b/6a)
do
	local volunteer = NetStub.listeners.Volunteer

	-- 14A: the real delivery callback on a TextChannel (as TextChatService would call it).
	local channel = {
		Name = "RBXGeneral",
		IsA = function(_, className) return className == "TextChannel" end,
	}
	fakeChannels.ChildAdded.fire(channel)
	local ps = newPlayers(6) -- ps[1] presents; ps[2..6] play (five: the final starts at three or fewer)
	local spectator = newPlayers(1)[1]
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(ps[1], true)
	local since = now
	begin(ps, 10, nil, nil)
	playerList = { ps[1], ps[2], ps[3], ps[4], ps[5], ps[6], spectator }
	pickTalk(ps[1], since)
	NetStub.listeners.TalkStart(ps[1])
	at(now + 0.3)
	local function message(id, from, text)
		return { MessageId = id, TextSource = { UserId = from.UserId }, Text = text }
	end
	local cb = channel.ShouldDeliverCallback
	local word2 = wordOf(ps[2])
	local cbAt = now
	local toPlayer = cb and cb(message("real1", spectator, "hi"), { UserId = ps[3].UserId })
	local toPresenter = cb and cb(message("real1", spectator, "hi"), { UserId = ps[1].UserId })
	if cb then
		cb(message("real2", ps[2], word2), { UserId = ps[3].UserId })
		cb(message("real2", ps[2], word2), { UserId = ps[4].UserId })
	end
	at(now + 0.1)
	check("14a the channel callback: a spectator's message does not reach a player, does reach the presenter; a player's word is caught once",
		cb ~= nil and toPlayer == false and toPresenter == true and beepsSince(cbAt) == 1)

	-- 14B: a rescue still waiting when the final becomes due (three left) is judged first, by the main game's rule.
	-- (Two leave rather than fly: no flight to wait for, so only the waiting rescue can hold the final back.)
	leave(ps[5], { ps[1], ps[2], ps[3], ps[4], ps[6], spectator })
	leave(ps[6], { ps[1], ps[2], ps[3], ps[4], spectator })
	at(now + 0.5)
	local phaseWhileWaiting = Match.phase
	-- (speech judging is on here: once decided, late results fall together after the settle stage's wait, bundle 6e)
	advanceUntil(function() return Match.talk == nil end, Config.RESCUE_SECONDS + Config.SETTLE_MAX + 4)
	check("14b the final waits for a rescue still waiting; the hit costs a main-game life (not a final out)",
		phaseWhileWaiting == "Play" and Match.participants[ps[2]].lives == Config.LIVES - 1 and Match.isAlive(ps[2])
		and Match.phase ~= "Final")
	finish(since)

	-- 14C: once the main game is decided, a new message is not judged (even while an older rescue still waits).
	local qs = newPlayers(4) -- qs[1] presents
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(qs[1], true)
	local since2 = now
	begin(qs, 10, nil, nil)
	pickTalk(qs[1], since2)
	NetStub.listeners.TalkStart(qs[1])
	at(now + 0.3)
	ChatGate.received("edge1", qs[2], wordOf(qs[2])) -- waits for a rescue
	at(now + 0.1)
	NetStub.listeners.DevFling(qs[2], "out")
	NetStub.listeners.DevFling(qs[3], "out") -- qs[4] is the last one: decided
	at(now + 0.1)
	local lateAt = now
	ChatGate.received("edge2", qs[4], wordOf(qs[4]))
	at(now + 0.1)
	check("14c after the decision a new message is not judged", beepsSince(lateAt) == 0)
	finish(since2)

	-- 14D (bundle 6e): speech judging in the talk (JudgeService through RoundService; no presenter: a hit flies at once).
	local transcript = NetStub.listeners.Transcript
	local vs = newPlayers(3)
	local since3 = now
	begin(vs, 10, nil, nil)
	advanceUntil(function() return Match.talk == "talk" end, Config.TALK_PREP_SECONDS + 12)
	local talkAt = now
	at(now + 1)
	local early = wordOf(vs[3])
	if transcript and early then
		transcript(vs[3], "음 " .. early, talkAt - 2, talkAt - 1, now, 1) -- may have begun before the talk
	end
	at(now + 0.1)
	local w2 = wordOf(vs[2])
	local hitAt = now
	if transcript and w2 then
		transcript(vs[2], "그건 " .. w2 .. " 같아", now - 1, now - 0.5, now, 1)
	end
	at(now + 0.1)
	check("14d speech judging: a transcript from inside the talk with the banned word flies at once (no presenter); one that may have begun before the talk does not count",
		transcript ~= nil and Match.participants[vs[2]].lives == Config.LIVES - 1 and wordOf(vs[2]) ~= w2
		and beepsSince(hitAt) == 1 and Match.participants[vs[3]].lives == Config.LIVES and wordOf(vs[3]) == early)
	advanceUntil(function() return Match.talk == "settle" end, Config.TALK_SECONDS + 2)
	local settle = lastSent("Settle", since3)
	local cutoff = if settle then settle.payload.cutoff else now
	local w3, w1 = wordOf(vs[3]), wordOf(vs[1])
	if transcript and w3 and w1 then
		transcript(vs[3], w3, cutoff - 2, cutoff - 1, cutoff, 2) -- began in the talk, arrives in the settle stage
		transcript(vs[1], w1, cutoff + 0.5, cutoff + 0.6, cutoff + 1, 2) -- began after the talk ended
	end
	at(now + 0.1)
	local heldMeanwhile = Match.participants[vs[3]].lives == Config.LIVES
	local stillSettling = Match.talk == "settle"
	local settledAt = now
	for _, v in vs do
		if settle then
			NetStub.listeners.Settled(v, settle.payload.key)
		end
	end
	advanceUntil(function() return Match.talk == nil end, Config.SETTLE_MAX + Config.RESCUE_SECONDS + 3)
	local lateLanded = Match.participants[vs[3]].lives == Config.LIVES - 1
	local afterIgnored = Match.participants[vs[1]].lives == Config.LIVES
	check("14e the settle stage sends Settle with the talk's end and waits: a late transcript of speech from inside the talk lands (held until the wait is over), one begun after it does not; every voice player settled -> it goes on before SETTLE_MAX",
		settle ~= nil and stillSettling and heldMeanwhile and lateLanded and afterIgnored and Match.talk == nil
		and now - settledAt < Config.SETTLE_MAX - 1, string.format("%.1f s after Settled", now - settledAt))
	local talkOver = now
	if transcript then
		transcript(vs[1], wordOf(vs[1]) or "x", talkOver - 0.5, talkOver - 0.2, talkOver, 3)
	end
	at(now + 0.1)
	check("14f after the talk the speech judging is closed", beepsSince(talkOver) == 0)
	finish(since3)

	-- 14G: decided in the middle of the talk while a rescue still waits (so the talk goes on): speech begun after that
	-- moment is not judged, even when its transcript comes in the settle stage.
	local gs = newPlayers(4) -- gs[1] presents
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(gs[1], true)
	local since4 = now
	begin(gs, 10, nil, nil)
	pickTalk(gs[1], since4)
	NetStub.listeners.TalkStart(gs[1])
	at(now + 0.3)
	ChatGate.received("g1", gs[2], wordOf(gs[2])) -- waits for a rescue
	at(now + 0.1)
	NetStub.listeners.DevFling(gs[3], "out")
	NetStub.listeners.DevFling(gs[2], "out") -- gs[4] is the last one: decided while the rescue waits
	local decidedAt = now
	local stillTalk = Match.talk == "talk"
	advanceUntil(function() return Match.talk == "settle" end, Config.RESCUE_SECONDS + 3)
	local inSettle = Match.talk == "settle"
	local gw = wordOf(gs[4])
	local sendAt = now
	if transcript and gw then
		transcript(gs[4], gw, decidedAt + 0.5, decidedAt + 0.6, decidedAt + 0.8, 7)
	end
	at(now + 0.1)
	check("14g decided in the middle of the talk (a rescue waiting): speech begun after that moment is not judged in the settle stage",
		stillTalk and inSettle and gw ~= nil and beepsSince(sendAt) == 0 and Match.participants[gs[4]].lives == Config.LIVES)
	finish(since4)

	-- 14I: the same, but speech from before that moment, its transcript arriving while the talk still goes on: it counts
	-- (held, it falls in the settle stage), as it would in the settle stage.
	local is = newPlayers(4) -- is[1] presents
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(is[1], true)
	local since6 = now
	begin(is, 10, nil, nil)
	pickTalk(is[1], since6)
	NetStub.listeners.TalkStart(is[1])
	at(now + 0.3)
	ChatGate.received("i1", is[2], wordOf(is[2])) -- waits for a rescue
	at(now + 0.5)
	local beforeAt = now
	at(now + 0.5)
	NetStub.listeners.DevFling(is[3], "out")
	NetStub.listeners.DevFling(is[2], "out") -- is[4] is the last one: decided while the rescue waits
	local decided6 = now
	at(now + 0.2)
	local talkStill = Match.talk == "talk"
	local iw = wordOf(is[4])
	local sendAt6 = now
	if transcript and iw then
		transcript(is[4], iw, beforeAt - 0.2, beforeAt, decided6 - 0.1, 9) -- spoken before the decision
	end
	at(now + 0.1)
	local beeped = beepsSince(sendAt6) == 1
	advanceUntil(function() return Match.talk == nil end, Config.RESCUE_SECONDS + Config.SETTLE_MAX + 6)
	check("14i decided while the talk goes on: speech from before that moment still counts when its transcript comes before the settle stage",
		talkStill and beeped and Match.participants[is[4]].lives == Config.LIVES - 1)
	finish(since6)

	-- 14H: late hits in the settle stage fall together once the wait is over (one event, whatever order they came in).
	local hs = newPlayers(4)
	local since5 = now
	begin(hs, 10, nil, nil)
	advanceUntil(function() return Match.talk == "talk" end, Config.TALK_PREP_SECONDS + 12)
	advanceUntil(function() return Match.talk == "settle" end, Config.TALK_SECONDS + 2)
	local settle5 = lastSent("Settle", since5)
	local cut5 = if settle5 then settle5.payload.cutoff else now
	if transcript then
		transcript(hs[1], wordOf(hs[1]) or "x", cut5 - 3, cut5 - 2.5, cut5 - 2, 11)
	end
	at(now + 0.5)
	if transcript then
		transcript(hs[2], wordOf(hs[2]) or "x", cut5 - 2, cut5 - 1.5, cut5 - 1, 11)
	end
	at(now + 0.1)
	local noneYet = Match.participants[hs[1]].lives == Config.LIVES and Match.participants[hs[2]].lives == Config.LIVES
	local releaseAt = now
	for _, h in hs do
		if settle5 then
			NetStub.listeners.Settled(h, settle5.payload.key)
		end
	end
	at(now + 0.5)
	local lost = lastSent("LifeLost", releaseAt)
	check("14h late hits are held until the settle wait is over, then fall together in one event",
		noneYet and lost ~= nil and #lost.payload.players == 2 and Match.participants[hs[1]].lives == Config.LIVES - 1
		and Match.participants[hs[2]].lives == Config.LIVES - 1)
	finish(since5)
	workspaceAttributes.BW_ServerKind = nil
	workspaceAttributes.BW_VoiceJudging = nil
	Scripted.off = false
end

---------------------------------------------------------------- 15. the seat bells, the floor, the presenter's verdict (bundle 6b)
do
	local ring = NetStub.listeners.Bell
	local volunteer = NetStub.listeners.Volunteer
	local ps = newPlayers(4) -- ps[1] presents
	at(now + Config.VOLUNTEER_COOLDOWN)
	volunteer(ps[1], true)
	local since = now
	local seen = {}
	Scripted.extra = function(ctx)
		seen.rung = ctx.bell({ ps[2], ps[3] }, 3, false)
		ctx.floor(ps[2])
		seen.floor = Voice.floor and table.clone(Voice.floor)
		seen.chatOther = ChatGate.shouldDeliver(general, ps[3], ps[4])
		seen.chatHolder = ChatGate.shouldDeliver(general, ps[2], ps[4])
		seen.chatToPresenter = ChatGate.shouldDeliver(general, ps[3], ps[1])
		seen.verdict = ctx.presenterVerdict("캔버라", 5)
		-- (the floor is left on here: RoundService gives it back after the mission)
	end
	local play = begin(ps, 10, nil, nil)
	local pickMission = NetStub.listeners.PresenterPick
	at(play + 0.3)
	pickMission(ps[1], "scripted")
	local missionAt = now + CARD -- (after its briefing)
	at(missionAt + Scripted.expectedSeconds + 0.5) -- the bells of ps[2] and ps[3] are open now
	local openMsg = lastSent("BellOpen", missionAt)
	ring(ps[4]) -- not open to them
	rawBell(ps[2], (openMsg and openMsg.payload.id or 0) - 1) -- an older window's number: does not count
	Seat.flying[ps[2]] = true
	ring(ps[2]) -- flying: does not count
	Seat.flying[ps[2]] = nil
	ring(ps[3])
	at(now + 0.3)
	ring(ps[2])
	ring(ps[3]) -- a second ring: one each time the bells open
	local rangs = sent("BellRang", missionAt)
	at(missionAt + Scripted.expectedSeconds + 3.5) -- the bells closed, the floor is on, the verdict menu open
	local closeMsg = lastSent("BellOpen", missionAt)
	local verdictMenu = lastSent("PresenterMenu", missionAt, ps[1], "verdict")
	check("15a the bells: only those they open to, one ring each, not while flying, in the order they came (everyone hears it)",
		seen.rung ~= nil and #seen.rung == 2 and seen.rung[1] == ps[3] and seen.rung[2] == ps[2] and #rangs == 2
		and rangs[1].payload.userId == ps[3].UserId and openMsg ~= nil and openMsg.payload.open == true
		and #openMsg.payload.ids == 2 and closeMsg ~= nil and closeMsg.payload.open == false)
	check("15b the floor: the speaker and the presenter are heard by everyone; alive players receive only the speaker's chat",
		seen.floor ~= nil and #seen.floor == 2 and table.find(seen.floor, ps[2].UserId) ~= nil
		and table.find(seen.floor, ps[1].UserId) ~= nil and seen.chatOther == false and seen.chatHolder == true
		and seen.chatToPresenter == true)
	rawPick(ps[1], "wrong", verdictMenu and verdictMenu.payload.id - 1 or 0) -- an older menu's number: does not count
	pickMission(ps[1], "right")
	at(now + 0.5)
	check("15c the presenter's verdict: a right / wrong menu to the presenter with the right answer, their press comes back",
		verdictMenu ~= nil and verdictMenu.payload.note == "캔버라" and #verdictMenu.payload.options == 2 and seen.verdict == "right")
	at(now + 0.5)
	check("15d after the mission the floor is given back (voice and chat) and the bells are closed", Voice.floor == nil
		and ChatGate.shouldDeliver(general, ps[3], ps[4]) == true)
	-- The floor outlives a presenter change (the new routing has no old presenter in it); the one answering leaving
	-- ends the verdict at once.
	local floorSeen = {}
	Scripted.extra = function(ctx)
		ctx.floor(ps[2])
		local asked = now
		floorSeen.verdict = ctx.presenterVerdict("x", 10)
		floorSeen.waited = now - asked
	end
	at(now + Config.FLING_RETURN_SECONDS + 1)
	local menuSeen = lastSent("PresenterMenu", now - 30, ps[1], "pick")
	pickMission(ps[1], "scripted")
	local started = now + CARD -- (after its briefing)
	at(started + Scripted.expectedSeconds + 0.5)
	leave(ps[2], { ps[1], ps[3], ps[4] })
	at(now + 1)
	check("15f the one answering leaves: the verdict ends at once (no judging, the floor goes back)", menuSeen ~= nil
		and floorSeen.verdict == nil and floorSeen.waited ~= nil and floorSeen.waited < 1.5 and Voice.floor == nil)
	Scripted.extra = nil
	local outside = now
	ring(ps[2]) -- no bells open: nothing
	check("15e a ring with no bells open does nothing", #sent("BellRang", outside) == 0)
	NetStub.listeners.DevFling(ps[3], "out")
	NetStub.listeners.DevFling(ps[4], "out")
	finish(since)
end

---------------------------------------------------------------- 16. a client flipping "ready" fast
do
	local ready = NetStub.listeners.Ready
	local rs = newPlayers(1)
	playerList = rs
	at(now + 1)
	local since = now
	for i = 1, 20 do
		ready(rs[1], i % 2 == 1) -- true, false, true ... (ends false), all within one moment
	end
	ready(rs[1], true)
	local burst = #sent("RoundState", since)
	at(now + Config.READY_BROADCAST_DELAY + 0.1)
	local after = #sent("RoundState", since)
	check("16a fast ready flips: the last value counts at once, and they cause one state broadcast", Match.ready[rs[1]] == true
		and burst == 0 and after == 1)
	playerList = {}
	at(now + 1)
end

---------------------------------------------------------------- 17. 머리 위 스무고개 (bundle 9c): its words and chat rules
do
	Config.TALK_GAME_ON = false
	twentyOn = true
	Scripted.off = true
	local ps = newPlayers(3)
	local spectator = newPlayers(1)[1]
	local since = now
	begin(ps, 10, nil, nil)
	playerList = { ps[1], ps[2], ps[3], spectator }
	advanceUntil(function() return lastSent("Mission", since, nil, "twenty") ~= nil end, 30)
	local view = lastWordsTo(ps[1], since)
	local screen = lastSent("Mission", since, nil, "twenty")
	local w1, w2, w3 = wordOf(ps[1]), wordOf(ps[2]), wordOf(ps[3])
	check("17a 스무고개 (the only game here): a different word for each, their own hidden, the topic on screen",
		screen ~= nil and screen.payload.topic ~= nil and w1 ~= nil and w2 ~= nil and w3 ~= nil and w1 ~= w2 and w2 ~= w3
		and view ~= nil and view[tostring(ps[1].UserId)].words == nil and view[tostring(ps[2].UserId)].words[1] == w2)
	check("17b while its words are up: chat guarded, whispers off, and a line holding a player's word never reaches them",
		ChatGate.shouldDeliver(general, spectator, ps[2]) == false and ChatGate.shouldDeliver(whisper, ps[2], ps[3]) == false
		and ChatGate.shouldDeliver(general, ps[1], ps[2], "이거 " .. w2 .. " 맞지?") == false
		and ChatGate.shouldDeliver(general, ps[1], ps[3], "이거 " .. w2 .. " 맞지?") == true
		and ChatGate.shouldDeliver(general, ps[1], ps[2], "동물이야?") == true)
	local leakAt = now
	say(ps[1], "힌트: " .. w2)
	at(now + 0.2)
	local seesOwn = lastWordsTo(ps[1], leakAt)
	check("17c writing another player's word in chat flies the writer at once (a life); they see their own word then",
		Match.participants[ps[1]].lives == Config.LIVES - 1 and #lifeLost(leakAt, "fail") == 1 and seesOwn ~= nil
		and seesOwn[tostring(ps[1].UserId)].words ~= nil)
	-- A right answer ends it (one of three is 30% rounded up).
	local asker, askId = nil, nil
	advanceUntil(function()
		local m = lastSent("Mission", leakAt, nil, "twenty")
		if m and m.payload.stage == "ask" and m.payload.id then
			local userId = m.payload.ids[m.payload.asker]
			for _, p in ps do
				if p.UserId == userId then
					asker, askId = p, m.payload.id
				end
			end
		end
		return asker ~= nil
	end, 60)
	local answerAt = now
	if asker then
		NetStub.listeners.MissionAnswer(asker, askId, wordOf(asker))
	end
	advanceUntil(function() return lastSent("Mission", answerAt, nil, "twentyResult") ~= nil end, 40)
	twentyOn = false -- (no second game of it: the final comes next)
	local third = if asker == ps[2] then ps[3] else ps[2]
	advanceUntil(function() return Match.participants[third].lives < Config.LIVES end, 10)
	at(now + Config.MINIGAME_RESULT_SECONDS + 1)
	check("17d a right answer ends it: the one not right flies, the writer not again; then no words and no chat rules",
		asker ~= nil and asker ~= ps[1] and Match.participants[third].lives == Config.LIVES - 1
		and Match.participants[asker].lives == Config.LIVES and Match.participants[ps[1]].lives == Config.LIVES - 1
		and wordOf(ps[2]) == nil and ChatGate.shouldDeliver(general, spectator, ps[2]) == true
		and fakeWhisperCommand.Enabled == true)
	local afterAt = now
	say(ps[2], w3)
	at(now + 0.2)
	check("17e after it a chat line judges nothing", #lifeLost(afterAt, "fail") == 0)
	Scripted.off = false
	Config.TALK_GAME_ON = true
	finish(since)
end
-- 17F: a leak that takes the last life of one of two decides the round in the middle of the game: the words and the
-- chat rules go all the same.
do
	Config.TALK_GAME_ON = false
	twentyOn = true
	Scripted.off = true
	local ps = newPlayers(2)
	local spectator = newPlayers(1)[1]
	local since = now
	begin(ps, 10, nil, nil)
	playerList = { ps[1], ps[2], spectator }
	advanceUntil(function() return lastSent("Mission", since, nil, "twenty") ~= nil end, 30)
	local up = wordOf(ps[2]) ~= nil
	Match.participants[ps[1]].lives = 1
	local leakAt = now
	say(ps[1], wordOf(ps[2]))
	advanceUntil(function() return Match.phase == "Result" end, 30)
	twentyOn = false
	check("17f a leak deciding the round mid-game: the game stops at once (no result of it), the words and the chat rules"
		.. " go", up and Match.phase == "Result" and lastSent("Mission", leakAt, nil, "twentyResult") == nil
		and now - leakAt < Config.FLING_RETURN_SECONDS + 5 and wordOf(ps[2]) == nil
		and ChatGate.shouldDeliver(general, spectator, ps[2]) == true and fakeWhisperCommand.Enabled == true)
	Scripted.off = false
	Config.TALK_GAME_ON = true
	finish(since)
end

---------------------------------------------------------------- 18. Sound settings (SettingsService, bundle 11a)
-- The real SettingsService (RoundService started it) on the prelude's in-memory DataStore: loads, checks, the delayed
-- save, its retries, a failed load (never saved), a change made before the load ended, leaving, and Sync.
do
	local Settings = require(node("SettingsService"))
	local function sentTo(p, since)
		local found = nil
		for _, item in NetStub.sent do
			if item.name == "Settings" and item.to == p and item.at >= since then
				found = item.payload
			end
		end
		return found
	end
	local function settingsPlayer(id)
		local p = fakePlayer(id)
		return p
	end
	-- 18a: a saved player gets their settings once the load is over.
	local p1 = settingsPlayer(901)
	settingsData["901"] = { music = 0.3, effects = 0.8 }
	local since = now
	Settings.join(p1)
	at(now + 0.1)
	local got = sentTo(p1, since)
	check("18a a saved player's settings are loaded and sent", got ~= nil and got.music == 0.3 and got.effects == 0.8)
	-- 18b: a new player gets the defaults; a change is kept on the steps and saved SETTINGS_SAVE_DELAY after it.
	local p2 = settingsPlayer(902)
	since = now
	Settings.join(p2)
	at(now + 0.1)
	got = sentTo(p2, since)
	local writes = settingsWrites
	Settings.change(p2, { music = 0.73, effects = 1 })
	at(now + Config.SETTINGS_SAVE_DELAY - 0.5)
	local early = settingsWrites
	at(now + 1)
	check("18b a new player gets the defaults; a change is kept on the steps (0.73 -> 0.7) and saved once,"
		.. " SETTINGS_SAVE_DELAY later", got ~= nil and got.music == Config.SETTINGS_DEFAULT.music
		and got.effects == Config.SETTINGS_DEFAULT.effects and early == writes and settingsWrites == writes + 1
		and settingsData["902"].music == 0.7 and settingsData["902"].effects == 1)
	-- 18c: anything not a volume is ignored (NaN, out of range, not a number, not a table).
	at(now + 1.1)
	Settings.change(p2, { music = 0 / 0 })
	Settings.change(p2, { music = 2 })
	Settings.change(p2, { effects = "x" })
	Settings.change(p2, "loud")
	local kept = Settings.get(p2)
	check("18c NaN, out of range, not a number or not a table changes nothing", kept ~= nil and kept.music == 0.7
		and kept.effects == 1)
	-- 18d: at most SETTINGS_RATE changes a second are taken.
	at(now + 1.1)
	for i = 1, 10 do
		Settings.change(p2, { music = i / 10 })
	end
	local limited = Settings.get(p2)
	at(now + 1.1)
	Settings.change(p2, { music = 0.2 })
	local after = Settings.get(p2)
	check("18d at most SETTINGS_RATE changes a second; the next second takes changes again", limited ~= nil
		and limited.music == Config.SETTINGS_RATE / 10 and after ~= nil and after.music == 0.2)
	at(now + Config.SETTINGS_SAVE_DELAY + 1)
	-- 18e: a load that fails twice: the defaults go after the retry, and nothing of this visit is ever saved.
	settingsGetBroken = true
	local p3 = settingsPlayer(903)
	settingsData["903"] = { music = 0.1, effects = 0.1 }
	since = now
	local warned = #warnings
	Settings.join(p3)
	at(now + Config.SETTINGS_LOAD_RETRY - 0.5)
	local beforeRetry = sentTo(p3, since)
	at(now + 1)
	got = sentTo(p3, since)
	settingsGetBroken = false
	writes = settingsWrites
	Settings.change(p3, { music = 0.9, effects = 0.9 })
	at(now + Config.SETTINGS_SAVE_DELAY + 1)
	Settings.leave(p3)
	at(now + 1)
	check("18e a failed load: the defaults go after one retry, and the visit's changes are never saved", beforeRetry == nil
		and got ~= nil and got.music == Config.SETTINGS_DEFAULT.music and settingsWrites == writes
		and settingsData["903"].music == 0.1)
	-- (the two failed loads warned; nothing else did)
	for i = #warnings, warned + 1, -1 do
		table.remove(warnings, i)
	end
	-- 18f: a change made while the load is still out wins over the loaded values (and is saved).
	settingsGetDelay = 1
	local p4 = settingsPlayer(904)
	settingsData["904"] = { music = 0.2, effects = 0.2 }
	since = now
	Settings.join(p4)
	at(now + 0.2)
	Settings.change(p4, { music = 0.9, effects = 1 })
	at(now + 1.5)
	got = sentTo(p4, since)
	settingsGetDelay = 0
	at(now + Config.SETTINGS_SAVE_DELAY + 1)
	check("18f a change made before the load ended is kept (the load's values are dropped) and saved", got ~= nil
		and got.music == 0.9 and got.effects == 1 and settingsData["904"].music == 0.9)
	-- 18g: a failed save is retried after SETTINGS_SAVE_RETRIES[1].
	settingsSetBroken = true
	writes = settingsWrites
	warned = #warnings
	Settings.change(p4, { music = 0.4, effects = 1 })
	at(now + Config.SETTINGS_SAVE_DELAY + 0.5)
	local failedOnce = settingsWrites == writes and settingsData["904"].music == 0.9
	settingsSetBroken = false
	at(now + Config.SETTINGS_SAVE_RETRIES[1] + 0.5)
	check("18g a failed save is retried SETTINGS_SAVE_RETRIES[1] later", failedOnce and settingsWrites == writes + 1
		and settingsData["904"].music == 0.4)
	for i = #warnings, warned + 1, -1 do
		table.remove(warnings, i)
	end
	-- 18h: leaving saves what was not saved yet, once; the waiting save does not run after.
	writes = settingsWrites
	Settings.change(p4, { music = 0.6, effects = 1 })
	Settings.leave(p4)
	at(now + Config.SETTINGS_SAVE_DELAY + 1)
	check("18h leaving saves the unsaved change at once, once", settingsWrites == writes + 1
		and settingsData["904"].music == 0.6 and Settings.get(p4) == nil)
	-- 18i: Sync sends the settings again.
	at(now + Config.SYNC_COOLDOWN + 0.1)
	since = now
	NetStub.listeners.Sync(p1)
	got = sentTo(p1, since)
	check("18i Sync sends the settings again", got ~= nil and got.music == 0.3 and got.effects == 0.8)
	-- 18j: a slow save with a change made during it: the change is saved after it (one save at a time), last value wins.
	settingsSetDelay = 2
	local p5 = settingsPlayer(905)
	Settings.join(p5)
	at(now + 0.1)
	writes = settingsWrites
	Settings.change(p5, { music = 0.1, effects = 1 })
	at(now + Config.SETTINGS_SAVE_DELAY + 0.5) -- (the first save is under way)
	Settings.change(p5, { music = 0.8, effects = 1 })
	at(now + 2)
	local firstDone = settingsWrites == writes + 1 and settingsData["905"].music == 0.1
	at(now + Config.SETTINGS_SAVE_DELAY + 3)
	check("18j a change made during a slow save is saved after it (saves one at a time, the last value stays)", firstDone
		and settingsWrites == writes + 2 and settingsData["905"].music == 0.8)
	-- 18k: the server's closing waits for the save of a player who just left (live servers only).
	Settings.change(p5, { music = 0.3, effects = 1 })
	Settings.leave(p5)
	RunService.IsStudio = function() return false end
	local closed = false
	task.spawn(function()
		Settings.closeAll()
		closed = true
	end)
	at(now + 1)
	local waiting = not closed
	at(now + 2)
	RunService.IsStudio = function() return true end
	settingsSetDelay = 0
	check("18k the server's closing waits for a leaving player's save still running", waiting and closed
		and settingsData["905"].music == 0.3)
	Settings.leave(p1)
	Settings.leave(p2)
end

print(if fails == 0 then "ALL PASS" else fails .. " FAILED")
