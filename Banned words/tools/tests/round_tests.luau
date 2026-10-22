-- V3 round rules on the real modules (docs/DESIGN_V3.md §2, §4, §15): LifeService (one penalty per event, none while
-- flying, simultaneous fails, everyone at once -> final, subjective limits, AFK), Timeline (time up, early final),
-- and whole rounds of the real RoundService with stub chairs/stands/voice/scores and a scripted mission in place
-- of the Studio test mission: 8 min -> final, time budget, final cap -> joint winners, 3 left of 4+ -> final at once,
-- everyone at once -> final among them, one left -> winner, leaving is out, the Studio fail key; joining by chat
-- (ChatService: privacy of the check, retries, voice accounts, the round lock) and the real VoiceService routing.
local Config = require(node("Config"))
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
	local character = { Parent = workspace }
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
local function fakePlayer(i)
	local attributes = {}
	return {
		Name = "P" .. i,
		UserId = i,
		DisplayName = "P" .. i,
		Parent = Players,
		Character = fakeCharacter(),
		CharacterAdded = signal(),
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
check("6a the whole main game is left at the start", math.abs(Timeline.left() - Config.ROUND_SECONDS) < 1e-6)
check("6b begun with 4+: the final is due as soon as FINAL_AT_ALIVE are left", not Timeline.finalDue(Config.FINAL_AT_ALIVE + 1)
	and Timeline.finalDue(Config.FINAL_AT_ALIVE))
Timeline.begin(Config.FINAL_AT_ALIVE)
check("6c begun with FINAL_AT_ALIVE or fewer: no early final", not Timeline.finalDue(2) and not Timeline.finalDue(1))
at(now + Config.ROUND_SECONDS)
check("6d time up -> the final is due", Timeline.left() == 0 and Timeline.finalDue(Config.FINAL_AT_ALIVE))
Timeline.begin(Config.FINAL_AT_ALIVE + 2)
local fewWithMany = Timeline.fewLeft(Config.FINAL_AT_ALIVE) and not Timeline.fewLeft(Config.FINAL_AT_ALIVE + 1)
Timeline.begin(Config.FINAL_AT_ALIVE)
check("6e fewLeft: only the head count rule (begun with 4+), never the clock", fewWithMany and not Timeline.fewLeft(1))

---------------------------------------------------------------- 7. whole rounds (RoundService + stubs)
local Seat = { flying = {}, flings = {}, reseats = {}, noChair = {} }
local returnDue = nil
function Seat.init(callback) returnDue = callback end
function Seat.seatPlayers(players)
	local seated = {}
	for _, p in players do
		seated[p] = true
	end
	return seated
end
function Seat.fling(player, tag)
	if Seat.flying[player] or Seat.noChair[player] then
		return false
	end
	Seat.flying[player] = true
	table.insert(Seat.flings, { player = player, at = now })
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

local Voice = { speakers = nil, silenced = nil, silencedCalls = 0 }
function Voice.start() end
function Voice.setSpeakers(ids) Voice.speakers = ids end
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
local Scripted = { id = "scripted", expectedSeconds = 10, runs = {}, finalRuns = {}, pick = nil, finalPick = nil, secondPick = nil }
function Scripted.available(_final) return true end
function Scripted.run(ctx)
	local list = if ctx.final then Scripted.finalRuns else Scripted.runs
	table.insert(list, now)
	if not ctx.wait(Scripted.expectedSeconds) then
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
-- How many main-game missions of `seconds` start in ROUND_SECONDS (free talk before each; one starts only if it
-- fits with its launches).
local function expectedRuns(seconds)
	local count, t = 0, 0
	while true do
		t += Config.FREE_TALK_SECONDS
		if Config.ROUND_SECONDS - t < seconds + Config.FLING_RETURN_SECONDS then
			return count
		end
		count += 1
		t += seconds
	end
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

-- 7A: three players, nobody fails: missions until the next would not fit, the final at 8 min, then the cap (the last
-- question begins before the cap and is played to its end).
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
	at(play + Config.FREE_TALK_SECONDS + 5)
	NetStub.listeners.DevFling(ps[2])
	check("7a the Studio fail key is ignored while a mission runs", #Scripted.runs == 1 and Match.participants[ps[2]].lives == Config.LIVES
		and #Seat.flings == 0)
	local list = finish(since)
	local final, result = phaseAt(list, "Final"), phaseAt(list, "Result")
	local runs = Scripted.runs
	check("7b missions run until the next would not fit the time left", #runs == expectedRuns(seconds) and #runs >= 2,
		string.format("%d runs (expected %d)", #runs, expectedRuns(seconds)))
	check("7c the final starts when the 8 minutes are up", final ~= nil and final.at - play >= Config.ROUND_SECONDS
		and final.at - play <= Config.ROUND_SECONDS + 0.5, final and string.format("final at +%.1f", final.at - play))
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
	local missionAt = play + Config.FREE_TALK_SECONDS
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
	local missionAt = play + Config.FREE_TALK_SECONDS
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

	local p1, p2, p3, pv = fakePlayer(3001), fakePlayer(3002), fakePlayer(3003), fakePlayer(3005)
	chatAllowed[3002] = false
	voiceEnabled[3005] = true
	arrive(p1)
	arrive(p2)
	arrive(p3)
	arrive(pv)
	local private = true
	for _, m in NetStub.sent do
		if m.name == "ChatAccess" and m.to == nil then
			private = false
		end
	end
	check("8a each account is checked once and told privately: may chat / may not / a voice account", accessOf(p1) == "yes"
		and accessOf(p2) == "no" and accessOf(pv) == "voice" and chatCalls[3001] == 1 and chatCalls[3005] == nil and private
		and p1:GetAttribute("BW_CanChat") == nil)

	local warned = #warnings
	chatBroken = true
	local p4 = fakePlayer(3004)
	RunService.IsStudio = function() return false end
	arrive(p4)
	local during = accessOf(p4)
	at(now + Config.CHAT_CHECK_RETRIES[1] + Config.CHAT_CHECK_RETRIES[2] + 1)
	RunService.IsStudio = function() return true end
	check("8b a chat check that keeps failing is retried, then no chat on a live server (each failure reported)",
		during == "checking" and accessOf(p4) == "error" and chatCalls[3004] == 1 + #Config.CHAT_CHECK_RETRIES
		and #warnings == warned + chatCalls[3004])
	local p6 = fakePlayer(3006)
	arrive(p6)
	chatBroken = false
	at(now + Config.CHAT_CHECK_RETRIES[1] + 0.5)
	check("8c a retry that works gives the answer", accessOf(p6) == "yes" and chatCalls[3006] == 2)
	voiceBroken = true
	local p7 = fakePlayer(3007)
	voiceEnabled[3007] = true
	arrive(p7)
	voiceBroken = false
	check("8d a failing voice check counts as no voice (owner 2026-10-23)", accessOf(p7) == "yes")

	chatDelay = 3
	local p8, p9 = fakePlayer(3008), fakePlayer(3009)
	arrive(p8)
	arrive(p9)
	join(p8, true) -- 1 s in: the 3 s check is still running
	local refused = Match.chatJoin[p8] == nil and accessOf(p8) == "checking"
	p9.Parent = nil
	task.spawn(Players.PlayerRemoving.fire, p9)
	at(now + 3)
	chatDelay = 0
	check("8e a request while the check runs is refused", refused and accessOf(p8) == "yes")
	check("8f a player who leaves during the check is told nothing afterwards", accessOf(p9) == "checking")
	join(p8, true)
	check("8g once checked, that player can join by chat", Match.chatJoin[p8] == true and p8:GetAttribute("BW_ChatMode") == true)

	join(p1, true)
	check("8h a player who may chat joins by chat", Match.chatJoin[p1] == true and p1:GetAttribute("BW_ChatMode") == true)
	chatJoin(p1, false)
	check("8i requests closer than CHAT_JOIN_COOLDOWN are ignored (each one broadcasts)", Match.chatJoin[p1] == true)
	at(now + Config.CHAT_JOIN_COOLDOWN)
	chatJoin(p1, "no")
	chatJoin(p1, nil)
	check("8j a request that is not true/false is ignored (it does not cancel)", Match.chatJoin[p1] == true)
	join(p2, true)
	join(pv, true)
	check("8k no chat for an account that may not chat, nor for a voice account", Match.chatJoin[p2] == nil and Match.chatJoin[pv] == nil)
	ready(p3, true)
	join(p3, true)
	check("8l a player whose voice is ready cannot join by chat", Match.chatJoin[p3] == nil)
	ready(p1, true)
	check("8m voice ready -> joins by voice from now on", Match.chatJoin[p1] == nil and p1:GetAttribute("BW_ChatMode") == false)
	ready(p1, false)
	join(p1, true)
	local joined = Match.chatJoin[p1] == true
	join(p1, false)
	check("8n leaving chat mode", joined and Match.chatJoin[p1] == nil and p1:GetAttribute("BW_ChatMode") == false)

	join(p1, true)
	Config.REQUIRE_VOICE_READY = true
	playerList = { p1, p2, p3 }
	local eligible = Match.eligiblePlayers()
	Players.PlayerRemoving.fire(p1) -- (still listed while it runs, as in Roblox)
	local state = lastState()
	playerList = {}
	Config.REQUIRE_VOICE_READY = false
	check("8o live servers seat voice-ready and chat players only", #eligible == 2 and table.find(eligible, p1) ~= nil
		and table.find(eligible, p3) ~= nil and table.find(eligible, p2) == nil)
	check("8p a chat player who leaves is no longer counted in the state sent then", state ~= nil and state.readyCount == 1
		and Match.chatJoin[p1] == nil)
	ready(p3, false)

	local sentBefore = #NetStub.sent
	NetStub.listeners.Sync(p2)
	local resent = false
	for i = sentBefore + 1, #NetStub.sent do
		local m = NetStub.sent[i]
		resent = resent or (m.name == "ChatAccess" and m.to == p2 and m.payload.state == "no")
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
	arrive(p11)
	at(now + Config.CHAT_CHECK_RETRIES[1] + Config.CHAT_CHECK_RETRIES[2] + 1)
	chatBroken = false
	check("8x in Studio a chat check that keeps failing still lets the tester try chat mode", accessOf(p11) == "yes")
	workspaceAttributes.BW_ChatAccess = "yes"
	local p12, p13 = fakePlayer(3012), fakePlayer(3013)
	voiceEnabled[3012] = true
	voiceEnabled[3013] = true
	arrive(p12)
	RunService.IsStudio = function() return false end
	arrive(p13)
	RunService.IsStudio = function() return true end
	workspaceAttributes.BW_ChatAccess = nil
	check("8y the Studio setting BW_ChatAccess forces the result (live servers ignore it)", accessOf(p12) == "yes"
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
	check("8u after the round, a chat player whose voice got ready joins by voice", Match.chatJoin[ps[1]] == nil
		and ps[1]:GetAttribute("BW_ChatMode") == false)
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
	playerList = {}
end

print(if fails == 0 then "ALL PASS" else fails .. " FAILED")
