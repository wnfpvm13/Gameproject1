-- Speech.luau segment / range tests (times are virtual seconds; the module sees them as server time).
local out = {}
Speech.onText(function(text, earliest, latest, ended, id)
	table.insert(out, { text = text, e = earliest, l = latest, ended = ended, id = id })
end)
local unstable = 0
Speech.onUnstable(function() unstable += 1 end)
Speech.start(makeInstance("Folder"))
local rec = created.AudioSpeechToText
local fails = 0
local function check(name, cond, detail)
	print((if cond then "PASS " else "FAIL ") .. name .. (if detail then "  " .. detail else ""))
	if not cond then fails += 1 end
end
local function reset(t)
	at(t)
	rec.VoiceDetected = false -- the fake mic only fires on a change
	Speech.setEnabled(false)
	Speech.setEnabled(true)
	table.clear(out)
	unstable = 0
end
local function on(t) at(t); rec.VoiceDetected = true end
local function off(t) at(t); rec.VoiceDetected = false end
local function say(t, text) at(t); rec.Text = text end
local function last() return out[#out] end
local function range(r) return string.format("[%.2f, %.2f]", r.e, r.l) end
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- A. normal sentence: exact start, end = when the voice stopped
reset(999); on(1000); off(1002); say(1002.5, "a")
check("A normal", near(last().e, 1000) and near(last().l, 1000) and near(last().ended, 1002), range(last()) .. " ended " .. last().ended)

-- B. late text (3.5 s) while talking again: must keep the OLD start, not borrow the new one (the Codex bug)
reset(1009); on(1010); off(1012); on(1014); say(1015.5, "b")
check("B late text keeps old start", near(last().e, 1010) and near(last().l, 1010), range(last()))
off(1016); say(1016.4, "b2")
check("B next sentence gets its own start", near(last().e, 1014) and near(last().l, 1014), range(last()))

-- C. ~10 s cut of a monologue, then the rest
reset(1019); on(1020); say(1030, "c1")
check("C cut: first piece (ended by now)", near(last().e, 1020) and near(last().l, 1020) and near(last().ended, 1030), range(last()))
off(1033); say(1033.4, "c2")
check("C cut: rest keeps the monologue's start", near(last().e, 1020) and near(last().l, 1030), range(last()))

-- D. an empty segment (a laugh) just before: range widens to its start (lenient for a new word)
reset(1039); on(1040); off(1041); at(1044.2); on(1045); off(1046); say(1046.4, "d")
check("D widened by recent empty segment", near(last().e, 1040) and near(last().l, 1045), range(last()))

-- E. text with no segment at all
reset(1059); say(1060, "e")
check("E unknown: last 12 s", near(last().e, 1048) and near(last().l, 1060) and near(last().ended, 1060), range(last()))

-- F. two short segments waiting: oldest first, range covers both
reset(1069); on(1070); off(1071); on(1071.1); off(1071.3); say(1071.5, "f1")
check("F two waiting: first", near(last().e, 1070) and near(last().l, 1071.1), range(last()))
say(1071.8, "f2")
check("F two waiting: second", near(last().e, 1071.1) and near(last().l, 1071.1), range(last()))
check("F ids differ", out[1].id ~= out[2].id)

-- I. open segment old enough to be cut vs expired late text
reset(1119); on(1120); off(1121); on(1122); say(1128, "i1")
check("I young open -> late text of expired", near(last().e, 1120) and near(last().l, 1120), range(last()))
reset(1139); on(1140); off(1141); on(1142); say(1150.5, "i2") -- open 8.5 s old, the expired one merged into lost at 1149
check("I old open + lost one -> covers both", near(last().e, 1140) and near(last().l, 1142), range(last()))
reset(1159); on(1160); off(1161); on(1161); say(1169, "i3") -- open 8 s old (may be cut), expired kept until 1169
check("I ambiguous -> covers both", near(last().e, 1160) and near(last().l, 1161), range(last()))

-- J. Codex's case: a late text of an old sentence arrives while a newer one is waiting. Answer the oldest first,
--    so the newer sentence's own text keeps its own (after-the-end) start instead of the old one's.
reset(1299); on(1300); off(1301); on(1304.2); off(1304.4); say(1304.5, "j1 (late text of the 1300 sentence)")
check("J late old text covers both", near(last().e, 1300) and near(last().l, 1304.2) and near(last().ended, 1304.4), range(last()))
say(1304.6, "j2 (the 1304.2 sentence)")
check("J newer sentence keeps its own start", near(last().e, 1304.2) and near(last().l, 1304.2) and near(last().ended, 1304.4), range(last()))

-- K. Codex's case 2: the old sentence's text is 8.5 s late (its segment already merged into `lost`) while a newer
--    sentence is waiting: the late text must still get the old start, not the newer one's.
reset(1399); on(1400); off(1401); on(1409.2); off(1409.4); say(1409.5, "k1 (8.5 s late text of the 1400 sentence)")
check("K very late text keeps the old start", near(last().e, 1400) and near(last().l, 1409.2), range(last()))
say(1409.6, "k2 (the 1409.2 sentence)")
check("K newer sentence keeps its own start", near(last().e, 1409.2) and near(last().l, 1409.2), range(last()))

-- L. Codex's case 3: a cut whose text comes 4 s late; the rest of the monologue keeps the monologue's start.
reset(1499); on(1500); say(1514, "l1")
check("L late cut: first piece", near(last().e, 1500) and near(last().l, 1500) and near(last().ended, 1514), range(last()))
off(1516); say(1516.3, "l2")
check("L late cut: rest covers back to the start", near(last().e, 1500) and near(last().l, 1514) and near(last().ended, 1516), range(last()))

-- M. `lost` is dropped LOST_KEEP after its end (no result comes a minute late)
reset(1599); on(1600); off(1601); say(1670, "m")
check("M lost dropped after LOST_KEEP -> unknown range", near(last().e, 1658) and near(last().l, 1670), range(last()))

-- G. waitSettled(cutoff, endBy, maxWait): waits only for speech the server may still judge
local function settleAt(t, cutoff, endBy, maxWait)
	at(t)
	local result = { done = nil }
	task.spawn(function()
		Speech.waitSettled(cutoff, endBy, maxWait)
		result.done = now
	end)
	return result
end
reset(1179); on(1180)
local g1 = settleAt(1181, 1181, 1182.5, 5); off(1182); say(1182.5, "g1"); at(1183)
check("G1 waits for the text of a sentence ended in time", g1.done ~= nil and g1.done >= 1182.5 and g1.done <= 1182.65, tostring(g1.done))
reset(1189); on(1190)
local g2 = settleAt(1191, 1191, 1192.5, 5); off(1192); at(1197)
check("G2 no text -> returns after expiry", g2.done ~= nil and g2.done > 1195 and g2.done <= 1195.25, tostring(g2.done))
reset(1199); on(1201)
local g3 = settleAt(1201.5, 1200, 1201.5, 5); at(1202)
check("G3 speech began after cutoff -> no wait", g3.done == 1201.5, tostring(g3.done))
reset(1209); on(1210)
local g4 = settleAt(1211, 1211, 1212.5, 5); at(1220)
check("G4 still talking past endBy -> stops waiting there", g4.done ~= nil and g4.done >= 1212.5 and g4.done <= 1212.65, tostring(g4.done))
reset(1219); on(1220); off(1221)
local g6 = settleAt(1221.1, 1221, 1222.5, 2); at(1226)
check("G6 cap (maxWait) before the expiry", g6.done ~= nil and g6.done >= 1223.1 and g6.done <= 1223.25, tostring(g6.done))
Speech.setEnabled(false)
local g5 = settleAt(1226, 1226, 1227.5, 5)
check("G5 recognizer off -> no wait", g5.done == 1226, tostring(g5.done))
Speech.setEnabled(true)

-- H. three empty segments in a row -> one unstable notice; a text resets the streak
reset(1229)
for i = 0, 2 do on(1230 + i * 5); off(1231 + i * 5) end
at(1250)
check("H unstable once after 3 misses", unstable == 1, tostring(unstable))
on(1251); off(1252); at(1256)
check("H no repeat on the 4th", unstable == 1, tostring(unstable))

print(if fails == 0 then "ALL PASS" else fails .. " FAILED")
