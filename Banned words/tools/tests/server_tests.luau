-- Server tests on the real modules: judge range rule, settle, banned words (JudgeService and WordService are
-- kept for the speech judging of phase 2; WordService holds the V3 banned words; the V3 round rules are in
-- round_tests.luau).
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
local hits = {}
JudgeService.start(function(player, word)
	table.insert(hits, { p = player.Name, w = word, at = now })
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
check("1d may have begun before the talk -> ignored", not say(1115, p1, "고양이", 990, 1001))
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

---------------------------------------------------------------- 3. banned words (V3: one each, per-player habit draw)
local HABITS = {}
for _, w in { "진짜", "대박", "완전", "솔직히", "아무튼", "약간", "그러니까", "근데", "혹시", "제발", "미안", "엄청", "웃겨" } do
	HABITS[w] = true
end
local mixed, total, habitCount, oneEach, noOverlap = 0, 0, 0, true, true
local JudgeForWords = require(node("Judge"))
for seed = 1, 20 do
	Match.resetRound()
	local list = {}
	for i = 1, 10 do
		local p = fakePlayer(100 + i)
		table.insert(list, p)
		Match.participants[p] = { player = p, alive = true, words = {} }
	end
	playerList = list
	WordService.assign(Random.new(seed * 7919))
	local habits = 0
	local texts = {}
	for _, p in Match.participants do
		oneEach = oneEach and #p.words == 1
		if p.words[1] then
			table.insert(texts, p.words[1].text)
			if HABITS[p.words[1].text] then
				habits += 1
			end
		end
	end
	for i = 1, #texts do
		for j = i + 1, #texts do
			noOverlap = noOverlap and not JudgeForWords.overlaps(texts[i], texts[j])
		end
	end
	total += 10
	habitCount += habits
	if habits > 0 and habits < 10 then
		mixed += 1
	end
end
check("3a every player gets exactly one word, none overlapping another", oneEach and noOverlap)
check("3b kinds are mixed within rounds (drawn per player, not one kind for all)", mixed >= 15, mixed .. "/20 rounds mixed")
check("3c about HABIT_WORD_CHANCE of the words are habits", habitCount >= total * (Config.HABIT_WORD_CHANCE - 0.12)
	and habitCount <= total * (Config.HABIT_WORD_CHANCE + 0.12), habitCount .. "/" .. total)
do
	local someone = playerList[1]
	local before = Match.participants[someone].words[1].text
	local okReplace = true
	for k = 1, 30 do
		WordService.replace(someone, { "오늘의 문제: 사과와 바나나와 치킨" }, Random.new(k))
		local word = Match.participants[someone].words[1].text
		okReplace = okReplace and #Match.participants[someone].words == 1 and word ~= before
			and not string.find("오늘의문제:사과와바나나와치킨", word, 1, true)
		for other, p in Match.participants do
			if other ~= someone then
				okReplace = okReplace and not JudgeForWords.overlaps(word, p.words[1].text)
			end
		end
		before = word
	end
	check("3d a new word: one word, never the old one, nowhere in the screen texts, overlapping nobody", okReplace)
	Match.phase = "Play"
	local seen = WordService.payloadFor(someone)
	local other = playerList[2]
	check("3e an alive player sees everyone's word but their own", seen[tostring(someone.UserId)].words == nil
		and seen[tostring(other.UserId)].words[1] == Match.participants[other].words[1].text)
	Match.participants[someone].alive = false
	local outView = WordService.payloadFor(someone)
	Match.participants[someone].alive = true
	local spectator = fakePlayer(999)
	local specView = WordService.payloadFor(spectator)
	Match.phase = "Result"
	local resultView = WordService.payloadFor(someone)
	check("3f out players and spectators (and the presenter) see every word; the result shows your own",
		outView[tostring(someone.UserId)].words ~= nil and specView[tostring(someone.UserId)].words ~= nil
		and resultView[tostring(someone.UserId)].words ~= nil)
	Match.phase = "Play"
	Config.SHOW_OWN_WORD = true -- (the solo speech test build)
	local soloView = WordService.payloadFor(someone)
	Config.SHOW_OWN_WORD = false
	check("3f2 the solo speech test build shows a player their own word", soloView[tostring(someone.UserId)].words ~= nil
		and soloView[tostring(someone.UserId)].words[1] == Match.participants[someone].words[1].text)
	WordService.clear()
	check("3g clear drops every word", #Match.participants[someone].words == 0)
	Match.phase = "Lobby"
end

---------------------------------------------------------------- 3b. chat judging (bundle 5b)
do
	local J = require(node("Judge"))
	check("3h chat: spaces, punctuation and invisible characters do not hide a word", J.chatHit("사과", "사 과 먹을래")
		and J.chatHit("사과", "사.과!") and J.chatHit("사과", "사\u{200B}과") and J.chatHit("사과", "사\u{3000}과")
		and J.chatHit("사과", "청사과나무"))
	check("3k chat: Unicode spaces, middle dots, emoji and direction marks do not hide a word either",
		J.chatHit("사과", "사\u{00A0}과") and J.chatHit("사과", "사\u{00B7}과") and J.chatHit("사과", "사\u{318D}과")
		and J.chatHit("사과", "사\u{2002}과") and J.chatHit("사과", "사🍎과") and J.chatHit("사과", "사\u{200E}과")
		and J.chatHit("사과", "사\u{FE0F}과") and J.chatHit("사과", "사…과"))
	check("3l chat: Hangul fillers (blank-looking letters) do not hide a word", J.chatHit("사과", "사\u{3164}과")
		and J.chatHit("사과", "사\u{115F}과") and J.chatHit("사과", "사\u{1160}과"))
	check("3i chat: a word across two words is a hit too (the rescue covers it); jamo spelling is not (owner)",
		J.chatHit("사과", "의사 과학자") and not J.chatHit("사과", "ㅅㅏㄱㅘ") and not J.chatHit("사과", "애플"))
	check("3j chat: aliases count, other words do not", J.chatHit("핸드폰", "휴대폰 줘", { "휴대폰" })
		and not J.chatHit("핸드폰", "전화기 줘", { "휴대폰" }))
end

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

---------------------------------------------------------------- 5. a mission's words bring their other forms (bundle 10)
do
	local a, b = fakePlayer(51), fakePlayer(52)
	table.clear(Match.participants)
	Match.participants[a] = { player = a, alive = true, words = {} }
	Match.participants[b] = { player = b, alive = true, words = {} }
	Match.phase = "Play"
	WordService.place({ [a] = "경찰관", [b] = "사과" }, {})
	check("5a a line with another form of my hidden word (경찰 for 경찰관) never reaches me; other lines and others do",
		WordService.hides(a, "너 경찰이야?") and WordService.hides(a, "경찰관?") and not WordService.hides(a, "동물이야?")
		and not WordService.hides(b, "너 경찰이야?"))
	WordService.clear()
	table.clear(Match.participants)
end

print(if fails == 0 then "ALL PASS" else fails .. " FAILED")
