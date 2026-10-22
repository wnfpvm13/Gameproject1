-- Server tests on the real modules: judge range rule, settle, per-player habit draw (JudgeService and WordService are
-- kept for the speech judging of phase 2 and the banned words of bundle 5; the V3 round rules are in round_tests.luau).
local Config = require(node("Config"))
local Match = require(node("Match"))
local JudgeService = require(node("JudgeService"))
local WordService = require(node("WordService"))

local fails = 0
local function check(name, cond, detail)
	print((if cond then "PASS " else "FAIL ") .. name .. (if detail then "  " .. detail else ""))
	if not cond then fails += 1 end
end
local function fakePlayer(i)
	return { Name = "P" .. i, UserId = i, DisplayName = "P" .. i }
end

---------------------------------------------------------------- 1. judge range rule
local hits, speeches = {}, 0
JudgeService.start(function(player, word)
	table.insert(hits, { p = player.Name, w = word, at = now })
end, function()
	speeches += 1
end)
local p1, p2 = fakePlayer(1), fakePlayer(2)
playerList = { p1, p2 }
Match.participants[p1] = { player = p1, alive = true, words = {
	{ text = "고양이", aliases = {}, effectiveAt = 0 },
	{ text = "무지개", aliases = {}, effectiveAt = 1100 },
} }
Match.participants[p2] = { player = p2, alive = true, words = { { text = "강아지", aliases = {}, effectiveAt = 0 } } }
Match.talkStartedAt = 1000
JudgeService.setOpen(true)
local send = NetStub.listeners.Transcript
local function lastHit() return hits[#hits] end
local id = 0
local function say(t, player, text, earliest, latest, ended)
	at(t)
	id += 1
	local before = #hits
	send(player, text, earliest, latest, if ended == nil then (if type(latest) == "number" then latest else t) else ended, id)
	return #hits > before
end

check("1a exact range after the word -> launch", say(1050, p1, "우리 고양이 귀엽지", 1040, 1040) and lastHit().w == "고양이")
check("1b range straddles the new word's start -> no launch", not say(1110, p1, "무지개 봤어", 1095, 1105))
check("1c range wholly after the new word -> launch", say(1112, p1, "무지개 봤어", 1101, 1102) and lastHit().w == "무지개")
local s0 = speeches
check("1d may have begun before the talk -> ignored", not say(1115, p1, "고양이", 990, 1001) and speeches == s0)
Match.cutoffAt = 1200
check("1e may have begun after the cutoff -> ignored", not say(1203, p1, "고양이", 1195, 1201))
check("1f begun and ended before the cutoff -> launch", say(1203.5, p1, "고양이", 1195, 1199, 1199.8))
check("1n went on past the cutoff (END_TOLERANCE 0) -> ignored", not say(1204, p1, "고양이", 1195, 1199, 1200.3))
check("1o NaN end -> ignored", not say(1204.5, p1, "고양이", 1195, 1199, 0 / 0))
check("1p an end claimed in the future is not pulled back to now -> ignored", not say(1200.2, p1, "고양이", 1195, 1199, 1202.5))
-- RoundService presets cutoffAt to the talk's end, so the end counts before the round loop notices it
Match.cutoffAt = 1450
check("1q begun 0.05 s after the talk's end -> ignored", not say(1450.15, p1, "고양이", 1450.05, 1450.05, 1450.1))
check("1r begun and ended before the talk's end -> launch", say(1450.2, p1, "고양이", 1449.5, 1449.5, 1449.9))
Match.cutoffAt = math.huge
check("1g absurdly old start -> lenient (ignored, never clamped forward)", not say(1300, p1, "고양이", 0, 0))
check("1h NaN / missing values -> ignored", not say(1310, p1, "고양이", 0 / 0, nil))
check("1i wrong types -> ignored", not say(1320, p1, "고양이", "x", {}))
check("1m future start is clamped to now (judged)", say(1325, p1, "고양이", 1400, 1400))
at(1330)
send(p1, "고양이", 1325, 1325, 1325, 999)
local n = #hits
send(p1, "고양이", 1325, 1325, 1325, 999)
check("1j duplicate segment id -> ignored", #hits == n)
JudgeService.setOpen(false)
check("1k judging closed -> ignored", not say(1340, p1, "고양이", 1335, 1335))
-- a late text whose sentence began 2 s before a new word took effect
JudgeService.setOpen(true)
Match.participants[p1].words[2].effectiveAt = 1381
check("1l late text of a sentence begun before a new word -> no launch", not say(1400, p1, "무지개", 1379, 1379))

---------------------------------------------------------------- 2. settle
local function lastSettleKey()
	for i = #NetStub.sent, 1, -1 do
		if NetStub.sent[i].name == "Settle" then
			return NetStub.sent[i].payload.key, NetStub.sent[i].payload.cutoff
		end
	end
	return nil
end
local settled = NetStub.listeners.Settled
at(2000)
local done = nil
table.clear(NetStub.notices)
task.spawn(function()
	JudgeService.settle(1999.5)
	done = now
end)
local key, cutoff = lastSettleKey()
check("2a Settle sent with the cutoff", key ~= nil and cutoff == 1999.5)
at(2000.3); settled(p1, key)
at(2000.5); settled(p2, key - 1) -- stale key
check("2b still waiting for P2 (stale key ignored)", done == nil)
check("2c judging stays open during settle", say(2001, p2, "강아지", 1999, 1999))
at(2002); settled(p2, key)
at(2003)
check("2d returns once both answered", done ~= nil and done >= 2002 and done <= 2002.15, tostring(done))
check("2e notice after SETTLE_NOTICE_AFTER", #NetStub.notices == 1 and NetStub.notices[1].text == Config.TEXT.SETTLING
	and NetStub.notices[1].at >= 2001.2 and NetStub.notices[1].at <= 2001.35, tostring(NetStub.notices[1] and NetStub.notices[1].at))
done = nil
at(2010)
task.spawn(function()
	JudgeService.settle(2009)
	done = now
end)
at(2020)
check("2f nobody answers -> SETTLE_MAX cap", done ~= nil and done >= 2015 and done <= 2015.15, tostring(done))
done = nil
Match.participants[p2].alive = false
at(2030)
table.clear(NetStub.notices)
task.spawn(function()
	JudgeService.settle(2029)
	done = now
end)
key = lastSettleKey()
at(2030.2); settled(p1, key)
at(2031)
check("2g only alive players are waited for", done ~= nil and done <= 2030.35 and #NetStub.notices == 0, tostring(done))
JudgeService.setOpen(false)

---------------------------------------------------------------- 3. per-player habit draw
local HABITS = {}
for _, w in { "진짜", "대박", "완전", "솔직히", "아무튼", "약간", "그러니까", "근데", "혹시", "제발", "미안", "엄청", "게임", "웃겨" } do
	HABITS[w] = true
end
local mixed, total, habitCount, allThree = 0, 0, 0, true
for seed = 1, 20 do
	Match.resetRound()
	local list = {}
	for i = 1, 10 do
		local p = fakePlayer(100 + i)
		table.insert(list, p)
		Match.participants[p] = { player = p, alive = true, words = {} }
	end
	playerList = list
	local rng = Random.new(seed * 7919)
	WordService.assignFirst(rng)
	local start = now
	Match.phase = "Talk"
	Match.endsAt = start + 200
	task.spawn(WordService.runSchedule, 200, function() return now < Match.endsAt end, rng)
	at(start + 201)
	local habits = 0
	for _, p in Match.participants do
		allThree = allThree and #p.words == 3
		if p.words[3] and HABITS[p.words[3].text] then
			habits += 1
		end
	end
	total += 10
	habitCount += habits
	if habits > 0 and habits < 10 then
		mixed += 1
	end
end
check("3a every player got 3 words", allThree)
check("3b kinds are mixed within matches (not one kind for all)", mixed >= 18, mixed .. "/20 matches mixed")
check("3c about half the third words are habits", habitCount >= 70 and habitCount <= 130, habitCount .. "/" .. total)

---------------------------------------------------------------- 4. fixed texts never contain a word-bank word
-- Players may read them aloud, so the same rule as the judge applies (tools/check_content.luau does this in Studio).
local Judge = require(node("Judge"))
local WordBank = require(node("WordBank"))
local clashes = {}
for key, text in Config.TEXT do
	for _, entry in WordBank.allEntries() do
		if Judge.isConfirmed(entry.word, text, entry.aliases) then
			table.insert(clashes, key .. ":" .. entry.word)
		end
	end
end
check("4 no fixed UI text (Config.TEXT) contains a word-bank word", #clashes == 0, table.concat(clashes, ", "))

print(if fails == 0 then "ALL PASS" else fails .. " FAILED")
