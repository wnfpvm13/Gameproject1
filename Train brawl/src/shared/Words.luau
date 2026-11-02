--!strict
-- Every word the game shows on screen, in one place: Korean first (owner default 2026-10-26), so another language can
-- be added here later without touching the parts that show them. Train words where a Korean player reads them
-- naturally: the fighters still in are "탑승객", going out is "하차". Short lines, no lists of facts joined by dots.
-- Pure (no Roblox calls), so the tests can read it.

local Words = {}

-- Each weapon's name (Config.Weapons keys).
Words.Weapons = {
	Fist = "맨주먹",
	Bat = "방망이",
	Hammer = "망치",
	Dynamite = "다이너마이트",
	GoldBar = "금괴",
	Whip = "채찍",
	Shovel = "삽",
	Lasso = "올가미",
	Coal = "석탄 덩이",
	SteamHose = "증기 호스",
	OilCan = "기름통",
	Firecracker = "폭죽",
	Wheel = "열차 바퀴",
} :: { [string]: string }

-- The round line and the big centre text.
Words.WaitingFew = "다른 승객을 기다리는 중"
Words.WaitingSoon = "곧 다음 열차 출발"
Words.Go = "출발!"
Words.Out = "하차!"
Words.OutWatching = "관전 중"
Words.LateWatching = "다음 열차를 기다리는 중"
Words.Draw = "무승부"
Words.WinnerNote = "끝까지 버텼다!"
Words.HomeRun = "홈런!"
Words.SharedWin = "공동 우승!"
Words.Tickets = "승차권" -- over the player's own tickets
-- Coming back after a fall with a ticket left: landed, under the parachute, unhittable for a moment.
Words.Back = "다시 탑승!"
Words.Dropping = "낙하산으로 내려가는 중"
Words.Guarded = "보호 중, 때리면 풀린다"
Words.StringBroken = "끊김!" -- under the string marks when a hit breaks the player's 1-2-3 string
Words.GuardBroken = "막기 깨짐!" -- over a blocker whose guard a string's third broke
Words.ResultTitle = "이번 판"
-- Titles on the result card (persona fix 8): the most home runs, the most knock-offs, still aboard at the end.
Words.Titles = { homers = "홈런왕", kos = "KO왕", survived = "끝까지 버팀" } :: { [string]: string }

-- The big call when the player hits home runs in a row (two or more).
function Words.homerunStreak(count: number): string
	if count == 2 then
		return "더블 홈런!"
	elseif count == 3 then
		return "트리플 홈런!"
	end
	return string.format("%d연속 홈런!", count)
end

-- Under the winner's name when it has won rounds in a row (two or more).
function Words.winStreak(count: number): string
	return string.format("%d연승!", count)
end
Words.CarLeaving = "맨 뒤 칸이 떨어져 나간다! 앞 칸으로!" -- a back car is about to come off
-- A low bridge coming (decision 24): the seconds until it reaches the trains, then while it goes over.
function Words.bridgeComing(seconds: number): string
	return if seconds > 0 then string.format("낮은 다리! 낮은 칸으로 가거나 막기로 숙여! %d", seconds) else "낮은 다리 지나간다! 숙여!"
end
Words.BridgeSafe = "여기는 안전" -- over a low top while a bridge comes
-- The golden crate (decision 25): coming (seconds until it starts falling), lying there, and who took what.
function Words.goldenComing(seconds: number): string
	return string.format("황금 상자가 온다! 가운데 기차 %d", seconds)
end
Words.GoldenHere = "황금 상자! 옆에 잠깐 서 있으면 가져간다"
function Words.goldenTaken(name: string, weapon: string): string
	return string.format("%s, 황금 상자에서 %s!", name, Words.Weapons[weapon] or weapon)
end
Words.GoldenTag = "황금 " -- before the weapon's name over the golden crate

-- Under the big text when the player is knocked off: who did it and how, and how many hits it took since its last fall.
function Words.knockedOff(by: string?, how: string, hits: number): string
	local taken = if hits > 0 then string.format(", %d대 맞음", hits) else ""
	if how == "homerun" then
		return if by then string.format("%s의 홈런%s", by, taken) else string.format("홈런%s", taken)
	end
	return if by then string.format("%s에게 밀려 떨어짐%s", by, taken) else string.format("발을 헛디딤%s", taken)
end

-- On the result card when the player did not win: a fighter's tickets left and knock-offs (2026-10-31: a tester
-- still in at the end could not tell why another won).
function Words.standing(name: string, tickets: number, kos: number): string
	return string.format("%s  승차권 %d · KO %d", name, tickets, kos)
end
Words.Me = "나"

-- The player's round on the result card: its rows (a name, then the number).
function Words.resultRows(kos: number, homers: number, landed: number, seconds: number): { { string } }
	return {
		{ "떨어뜨린 수", tostring(kos) },
		{ "홈런", tostring(homers) },
		{ "맞힌 수", tostring(landed) },
		{ "버틴 시간", Words.clock(seconds) },
	}
end

function Words.ticketsLeft(count: number): string
	return string.format("승차권 %d장 남음", count)
end

-- While waiting in the stands for the parachute.
function Words.dropIn(seconds: number): string
	return string.format("%d초 뒤 낙하산 출발", seconds)
end

function Words.aboard(count: number): string
	return string.format("탑승객 %d", count)
end

function Words.knockOffs(count: number): string
	return string.format("KO %d", count)
end

function Words.clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Words.winner(name: string): string
	return string.format("%s 승리!", name)
end

-- A line in the knock-off feed: who fell, who gets the credit (nil = nobody: nobody hit them lately), how ("homerun"
-- or "fall"), whether it was their last ticket (out: "하차") or they come back (a fall: "떨어뜨림"), and the home runs
-- in a row it makes for who hit it (two or more are told).
function Words.feed(victim: string, by: string?, how: string, out: boolean, streak: number?): string
	if how == "homerun" then
		local row = if streak and streak >= 2 then string.format(" %d연속", streak) else ""
		return if by then string.format("%s → %s 홈런!%s", by, victim, row) else string.format("%s 홈런!", victim)
	elseif not out then
		return if by then string.format("%s → %s 떨어뜨림", by, victim) else string.format("%s 떨어짐", victim)
	end
	return if by then string.format("%s → %s 하차", by, victim) else string.format("%s 하차", victim)
end

-- What the player holds: its name and the attacks or seconds left.
function Words.uses(weapon: string, count: number): string
	return string.format("%s ×%d", Words.Weapons[weapon] or weapon, count)
end

function Words.secondsLeft(weapon: string, seconds: number): string
	return string.format("%s %d초", Words.Weapons[weapon] or weapon, seconds)
end

-- A Studio practice bot's name (number `n`).
function Words.bot(n: number): string
	return string.format("봇 %d", n)
end

-- The music button, the touch attack button.
Words.MusicOn = "음악 ON"
Words.MusicOff = "음악 OFF"
Words.AttackButton = "때리기"
Words.BlockButton = "막기"
Words.DodgeButton = "구르기"
Words.DodgeKey = "Q" -- the roll's key, shown with the cooldown on a keyboard (DodgeHud)
Words.DodgeKeyPad = "B" -- and its button on a gamepad
-- Over a blocker an attack went through (BlockRules.through): from the side, from behind, a weapon no block stops.
Words.BlockThrough = { side = "옆!", back = "뒤!", weapon = "못 막는 공격!" } :: { [string]: string }
Words.Counter = "반격!" -- over whoever the player hit back right after blocking

-- The first-ride card: its title and its rows (the control, then what it does) for the kind of control in use:
-- "mouse", "touch" or "gamepad".
Words.CardTitle = "탑승 안내"
function Words.cardRows(control: string): { { string } }
	local attack = if control == "touch" then "오른쪽 버튼" elseif control == "gamepad" then "RT / R2" else "클릭"
	local block = if control == "touch" then "막기 버튼 꾹" elseif control == "gamepad" then "LT / L2 꾹" else "오른쪽 클릭 꾹"
	local dodge = if control == "touch" then "구르기 버튼" elseif control == "gamepad" then "B" else "Q"
	local rows = {
		{ attack, "때리기" },
		{ block, "앞에서 오는 공격 막기" },
		{ dodge, "구르기 (잠깐 안 맞음)" },
		{ "3연타", "상대가 날아간다 (체력이 낮을수록 멀리)" },
		{ "낙하산 상자", "맨손으로 닿으면 무기" },
		{ "떨어지면", "승차권 1장 쓰고 복귀" },
	}
	if control == "mouse" then
		table.insert(rows, { "왼쪽 Alt", "커서 켜기·끄기" })
	end
	return rows
end

return Words
