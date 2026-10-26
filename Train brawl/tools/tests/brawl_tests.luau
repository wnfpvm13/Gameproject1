-- Arena and bat math tests (run by tools/tests/run_tests.py, which puts Config, ArenaLayout and BatMath above this).
-- Uses the real Config numbers, so a tuning change that breaks a promise fails.
local passed, failed = 0, 0
local function check(name: string, ok: boolean, detail: string?)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (if detail then ": " .. detail else ""))
	end
end
local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-9)
end

local A = Config.Arena
local GRAVITY = 196.2 -- Roblox default
local JUMP_HEIGHT = 7.2 -- Roblox default
local WALK_SPEED = 16 -- Roblox default
-- How much farther a real running jump crosses than ArenaLayout.jumpReach's plain flight. Measured in Studio
-- (2026-10-25, default R15 dummy, jump pressed as late as 1.9 past the edge, where it still stands; from about 1.95
-- it mostly falls first): crossed 12.75 / 13.75 / 14.25 for drops 0 / 5 / 8 (never 13 / 14 / 14.5) against the
-- formula's 8.67 / 9.98 / 10.63, 3.6 to 4.1 more; 4.25 keeps a little margin.
local JUMP_EXTRA = 4.25

local SERVER_SIZE = 8 -- planned players per server (docs/DESIGN.md)
local L = ArenaLayout.layout(A, Config.Fall.Margin)

-- The walkable tops of train i.
local function topsOf(i: number): { any }
	local list = {}
	for _, surface in L.surfaces do
		if surface.train == i then
			table.insert(list, surface)
		end
	end
	return list
end

-- 1. Trains and cars.
do
	local x1 = ArenaLayout.trainX(1, 2, 10, 12)
	local x2 = ArenaLayout.trainX(2, 2, 10, 12)
	check("two trains sit either side of the middle", near(x1, -11) and near(x2, 11))
	check("one train sits on the middle", near(ArenaLayout.trainX(1, 1, 10, 12), 0))
	check("three trains: one on the middle, one either side", near(ArenaLayout.trainX(1, 3, 10, 12), -22) and near(ArenaLayout.trainX(2, 3, 10, 12), 0) and near(ArenaLayout.trainX(3, 3, 10, 12), 22))
	check("every train in Config is laid out", #L.trains == #A.Trains)
	local placed, centred, spaced, halves, kinds, engines = true, true, true, true, true, true
	local shifts = {}
	for i, train in L.trains do
		local spec = A.Trains[i]
		placed = placed and #train.cars == #spec.cars
		centred = centred and near((train.cars[1].front + train.cars[#train.cars].back) / 2, spec.shift)
		for k, place in train.cars do
			kinds = kinds and A.CarKinds[place.kind] ~= nil and place.kind == spec.cars[k]
			halves = halves and near(place.middle, (place.front + place.back) / 2)
			if k > 1 then
				spaced = spaced and near(place.front - train.cars[k - 1].back, A.CarGap)
			end
		end
		engines = engines and train.cars[1].kind == "Locomotive"
		shifts[spec.shift] = true
	end
	local differentShifts = 0
	for _ in shifts do
		differentShifts += 1
	end
	check("every car of every train is placed, of its own kind", placed and kinds)
	check("each train is centred on its own shift along the track", centred)
	check("cars follow one another a car gap apart", spaced)
	check("a car's middle is halfway along it", halves)
	check("every train has its locomotive in front", engines)
	check("the trains stand at different shifts (different cars face each other)", differentShifts == #A.Trains)
	-- Along one train everyone can get from any car to the next: a step down, or up by less than a jump.
	local climbable = true
	for _, train in L.trains do
		for k = 2, #train.cars do
			if math.abs(train.cars[k].roof - train.cars[k - 1].roof) > JUMP_HEIGHT - 1.5 then
				climbable = false
			end
		end
	end
	check("along a train every car's top is within a jump of the next (flatcars can be climbed out of)", climbable)
	local stepUp = true
	for _, kind in A.CarKinds do
		local crates: { any } = kind.crates or {}
		for _, crate in crates do
			stepUp = stepUp and crate.height < JUMP_HEIGHT - 1.5
		end
		if kind.cupola then
			stepUp = stepUp and kind.cupola.height < JUMP_HEIGHT - 1.5
		end
		if kind.boiler then
			stepUp = stepUp and math.abs(kind.roof - kind.boiler.top) < JUMP_HEIGHT - 1.5
		end
	end
	check("every top standing on a car (crates, lookout, boiler) is within a jump of the one below", stepUp)
end

-- 2. Planks, spawn spots, jumps and the fall line.
do
	local perGap: { [number]: { any } } = {}
	local across, resting, clear = true, true, true
	for _, plank in L.planks do
		local gap = 0
		for i = 1, #L.trains - 1 do
			if near(plank.x, (L.trains[i].x + L.trains[i + 1].x) / 2) then
				gap = i
			end
		end
		across = across and gap > 0 and near(plank.length, A.Gap + 2 * A.PlankOverlap)
		if gap > 0 then
			perGap[gap] = perGap[gap] or {}
			table.insert(perGap[gap], plank)
			-- Both ends rest on a plank top of the plank's height that runs past it along the track.
			for _, i in { gap, gap + 1 } do
				local held = false
				for _, surface in topsOf(i) do
					if surface.plank and near(surface.top, plank.top)
						and plank.z - A.PlankWidth / 2 >= surface.z - surface.length / 2
						and plank.z + A.PlankWidth / 2 <= surface.z + surface.length / 2 then
						held = true
					end
					-- Nothing higher stands on the plank's end (the part lying on the roof) or a character's width (1) past it.
					local inward = if i == gap then -1 else 1
					local edgeX = L.trains[i].x - inward * A.RoofWidth / 2
					local stepX = edgeX + inward * (A.PlankOverlap + 1)
					local endFrom, endTo = math.min(edgeX, stepX), math.max(edgeX, stepX)
					local overlapX = math.min(endTo, surface.x + surface.width / 2) - math.max(endFrom, surface.x - surface.width / 2)
					local overlapZ = math.min(plank.z + A.PlankWidth / 2, surface.z + surface.length / 2) - math.max(plank.z - A.PlankWidth / 2, surface.z - surface.length / 2)
					if surface.top > plank.top + 1e-6 and overlapX > 0 and overlapZ > 0 then
						clear = false
					end
				end
				resting = resting and held
			end
		end
	end
	check("every plank spans a gap between neighbouring trains", across)
	check("every plank's ends rest on flat tops of its own height", resting)
	check("nothing higher stands on a plank's ends or where one steps off them", clear)
	local everyGap, fewSpread = true, true
	for i = 1, #L.trains - 1 do
		local list = perGap[i] or {}
		everyGap = everyGap and #list >= 1
		fewSpread = fewSpread and #list <= A.PlanksPerGap
		for a = 1, #list do
			for b = a + 1, #list do
				fewSpread = fewSpread and math.abs(list[a].z - list[b].z) >= A.PlankSpacing
			end
		end
	end
	check("every gap has a plank (every train can be reached)", everyGap)
	check("at most PlanksPerGap planks per gap, PlankSpacing apart", fewSpread)
	-- No jump crosses a gap, even one from the highest top dropping onto the lowest across from it (a top narrower than
	-- the roof starts further from the edge).
	local worst, worstWhere = -math.huge, ""
	for i = 1, #L.trains - 1 do
		for _, a in topsOf(i) do
			for _, b in topsOf(i + 1) do
				local facing = math.min(a.z + a.length / 2, b.z + b.length / 2) - math.max(a.z - a.length / 2, b.z - b.length / 2)
				if facing > 0 then
					local distance = A.Gap + (A.RoofWidth - a.width) / 2 + (A.RoofWidth - b.width) / 2
					local reach = ArenaLayout.jumpReach(WALK_SPEED, JUMP_HEIGHT, GRAVITY, math.abs(a.top - b.top)) + JUMP_EXTRA
					if reach - distance > worst then
						worst, worstWhere = reach - distance, string.format("%s %.1f -> %s %.1f: reach %.1f, gap %.1f", a.kind, a.top, b.kind, b.top, reach, distance)
					end
				end
			end
		end
	end
	check("no jump crosses a gap, even dropping from the highest top to the lowest", worst < 0, worstWhere)
	check("the plain jump flight on the flat is about 8.7 (Roblox's default jump)", near(ArenaLayout.jumpReach(16, 7.2, 196.2, 0), 8.67, 0.05))
	check("JUMP_EXTRA covers every measured jump (it must not be lowered below them)", ArenaLayout.jumpReach(16, 7.2, 196.2, 0) + JUMP_EXTRA > 12.75
		and ArenaLayout.jumpReach(16, 7.2, 196.2, 5) + JUMP_EXTRA > 13.75 and ArenaLayout.jumpReach(16, 7.2, 196.2, 8) + JUMP_EXTRA > 14.25)
	-- Spawn spots: on their train's own flat top, clear of anything higher, enough for a full server and the sandbags.
	check("enough spawn spots for a full server and the practice sandbags", #L.spots >= SERVER_SIZE + Config.Sandbag.Count, tostring(#L.spots))
	local onTop, roomy = true, true
	for _, spot in L.spots do
		local stands = false
		for _, surface in topsOf(spot.train) do
			local dx, dz = math.abs(spot.x - surface.x), math.abs(spot.z - surface.z)
			if near(surface.top, spot.y) and dx <= surface.width / 2 - 1.5 and dz <= surface.length / 2 - 1.5 then
				stands = true
			end
			if surface.top > spot.y + 1e-6 and dx < surface.width / 2 + 1.5 and dz < surface.length / 2 + 1.5 then
				roomy = false
			end
		end
		onTop = onTop and stands
	end
	check("every spawn spot is on its train's flat top, away from its ends", onTop)
	check("no spawn spot is in or against something higher", roomy)
	-- The farthest any weapon reaches at once (a cone's reach, or a slam's spot ahead plus its radius), with the slack.
	local farthest = 0
	for _, w in Config.Weapons do
		if w.reach then
			farthest = math.max(farthest, w.reach)
		end
		if w.style == "slam" and w.ahead and w.radius then
			farthest = math.max(farthest, w.ahead + w.radius)
		end
	end
	local SPAWN_APART = farthest + Config.Attack.ReachSlack
	local apart = true
	for a = 1, #L.spots do
		for b = a + 1, #L.spots do
			local p, q = L.spots[a], L.spots[b]
			if math.sqrt((p.x - q.x) ^ 2 + (p.z - q.z) ^ 2) <= SPAWN_APART then
				apart = false
			end
		end
	end
	check("spawn spots are farther apart than a swing reaches on the server (nobody starts within a hit)", apart)
	-- preferMiddle with a shuffle that reverses (to see it is used): every spot once, never farther from the middle than a
	-- later one, and the two trains beside the middle taking turns.
	local calls = 0
	local function reverse<T>(list: { T }): { T }
		calls += 1
		local copy = {}
		for k = #list, 1, -1 do
			table.insert(copy, list[k])
		end
		return copy
	end
	local mixed = ArenaLayout.preferMiddle(L.spots, #L.trains, reverse)
	local middle = (#L.trains + 1) / 2
	local seen, once, outward = {}, #mixed == #L.spots, true
	for k, spot in mixed do
		once = once and not seen[spot]
		seen[spot] = true
		if k > 1 and math.abs(spot.train - middle) < math.abs(mixed[k - 1].train - middle) - 1e-9 then
			outward = false
		end
	end
	check("preferMiddle hands out every spot once, the middle train first, then outward", once and outward and mixed[1].train == middle)
	local outside = {}
	for _, spot in mixed do
		if spot.train ~= middle then
			table.insert(outside, spot.train)
		end
	end
	local alternate = #outside >= 2
	for k = 2, #outside do
		alternate = alternate and outside[k] ~= outside[k - 1] -- both sides have the same number of spots here
	end
	check("the trains beside the middle take turns all the way", alternate)
	-- The middle train's spots come out in the reversed order the shuffle returned.
	local middleSpots = {}
	for _, spot in L.spots do
		if spot.train == middle then
			table.insert(middleSpots, spot)
		end
	end
	local usesShuffle = calls > 0 and #middleSpots > 1
	for k, spot in middleSpots do
		usesShuffle = usesShuffle and mixed[#middleSpots - k + 1] == spot
	end
	check("preferMiddle hands out what the shuffle returned", usesShuffle)
	local four = ArenaLayout.preferMiddle({ { x = 0, y = 0, z = 0, train = 1 }, { x = 0, y = 0, z = 0, train = 2 }, { x = 0, y = 0, z = 0, train = 3 }, { x = 0, y = 0, z = 0, train = 4 } }, 4, reverse)
	local two = (four[1].train == 2 or four[1].train == 3) and (four[2].train == 2 or four[2].train == 3) and four[1].train ~= four[2].train
	check("with an even number of trains the two middle ones come first", two and #four == 4)
	local lowest = math.huge
	for _, surface in L.surfaces do
		lowest = math.min(lowest, surface.top)
	end
	check("the fall line is the margin under the lowest top", near(L.fallLine, lowest - Config.Fall.Margin))
	check("the fall line lies between the sand and the lowest deck", A.GroundY < L.fallLine and L.fallLine < lowest)
	check("the outer edge is the outermost train's roof edge", near(L.outerEdge, math.abs(L.trains[1].x) + A.RoofWidth / 2))
	check("the roadside props stand beyond the outer edge and before the far line", L.outerEdge + Config.Run.RoadsideClearance < Config.Run.RoadsideFar)
end

-- 3. The bat's cone and knock.
do
	check("a target straight ahead in reach is hit", BatMath.inCone(0, 0, 0, 0, -1, 0, 0, -5, 7, 5, 70))
	check("a target behind is not hit", not BatMath.inCone(0, 0, 0, 0, -1, 0, 0, 5, 7, 5, 70))
	check("a target out of reach is not hit", not BatMath.inCone(0, 0, 0, 0, -1, 0, 0, -8, 7, 5, 70))
	check("a target too high is not hit", not BatMath.inCone(0, 0, 0, 0, -1, 0, 6, -3, 7, 5, 70))
	check("a target at the edge of the cone is hit, just past it not", BatMath.inCone(0, 0, 0, 0, -1, math.sin(math.rad(69)) * 5, 0, -math.cos(math.rad(69)) * 5, 7, 5, 70)
		and not BatMath.inCone(0, 0, 0, 0, -1, math.sin(math.rad(72)) * 5, 0, -math.cos(math.rad(72)) * 5, 7, 5, 70))
	local vx, vy, vz = BatMath.knock(0, 0, 0, -1, 3, 0, 28, 20)
	check("the knock pushes away from the swinger and lifts", near(vx, 28) and near(vy, 20) and near(vz, 0))
	local fx, _, fz = BatMath.knock(0, 0, 0, -1, 0, 0, 28, 20)
	check("standing on top of each other, the knock goes the way the swinger faces", near(fx, 0) and near(fz, -28))
end

-- 4. Hit rules.
do
	local rules = { max = 100, window = 1.5, gang = 3, immune = 0.9 }
	local s = HitRules.new(100)
	check("a fighter starts at full health", s.health == 100)
	local k1 = HitRules.hit(s, rules, 0, 12, false, "A")
	local k2 = HitRules.hit(s, rules, 0.5, 12, false, "A")
	local k3 = HitRules.hit(s, rules, 1.0, 12, false, "A")
	check("one attacker's hits stay light however many land (the attacker's string decides the launch)", k1 == "light" and k2 == "light" and k3 == "light", k1 .. "," .. k2 .. "," .. k3)
	check("the attacker's launching hit launches", HitRules.hit(s, rules, 1.4, 12, true, "A") == "launch")
	check("each hit takes its damage", s.health == 52)
	check("right after a launch the fighter cannot be hit", HitRules.hit(s, rules, 1.8, 12, false, "B") == "none" and s.health == 52)
	check("after the moment passes hits are light again", HitRules.hit(s, rules, 2.4, 12, false, "A") == "light")
	local g = HitRules.new(100)
	local g1, g2 = HitRules.hit(g, rules, 0, 8, false, "A"), HitRules.hit(g, rules, 0.3, 8, false, "B")
	check("ganged up on: the third hit within the window from two attackers launches", g1 == "light" and g2 == "light" and HitRules.hit(g, rules, 0.6, 8, false, "A") == "launch")
	local h = HitRules.new(100)
	HitRules.hit(h, rules, 0, 8, false, "A")
	HitRules.hit(h, rules, 1.0, 8, false, "B")
	check("hits further apart than the window do not count together", HitRules.hit(h, rules, 2.0, 8, false, "A") == "light")
	local u = HitRules.new(100)
	local kinds, now = {}, 0
	for _ = 1, 9 do
		table.insert(kinds, (HitRules.hit(u, rules, now, 12, false, "A")))
		now += 1
	end
	check("the hit that empties health is a smash (the 9th from full)", kinds[9] == "smash" and kinds[8] ~= "smash" and u.health == 0, table.concat(kinds, ","))
	check("an emptied fighter takes no more hits", HitRules.hit(u, rules, now + 5, 12) == "none")
	local v = HitRules.new(100)
	check("a weapon that always launches launches on the first hit", HitRules.hit(v, rules, 0, 16, true) == "launch" and v.health == 84)
	check("and leaves its fighter unhittable for a moment", HitRules.hit(v, rules, 0.5, 8) == "none")
	check("each hit takes its own weapon's damage", HitRules.hit(v, rules, 1, 8) == "light" and v.health == 76)
	check("push scales from full to empty", HitRules.scale(100, 100, 9, 29) == 9 and HitRules.scale(0, 100, 9, 29) == 29 and HitRules.scale(50, 100, 9, 29) == 19)
	check("push stays in range outside the health range", HitRules.scale(-5, 100, 9, 29) == 29 and HitRules.scale(150, 100, 9, 29) == 9)
	check("the real numbers: a bat empties health on the 9th hit, fists on the 13th", math.ceil(Config.Health.Max / Config.Weapons.Bat.damage) == 9 and math.ceil(Config.Health.Max / Config.Weapons.Fist.damage) == 13)
	local forces = { LightFull = 5, LightEmpty = 15, LaunchFull = 1, LaunchEmpty = 27, LaunchLift = 28, SmashPush = 70, SmashLift = 60 }
	local sp, sl = HitRules.force("smash", 0, 100, forces)
	local lp, ll = HitRules.force("launch", 50, 100, forces)
	local gp, gl = HitRules.force("light", 50, 100, forces)
	check("a smash pushes and lifts at its own fixed force", sp == 70 and sl == 60)
	check("a launch pushes by health and lifts", lp == 14 and ll == 28)
	check("a light hit pushes by health along the ground only", gp == 10 and gl == 0)
end

-- 5. Tuning promises.
do
	-- Knock reach (the plain flight formula; a lying landing and a short slide add about a fifth, measured in Studio).
	local h = Config.Hit
	-- (The launches were measured with the bat: its damage makes the combos' health.)
	local max, damage = Config.Health.Max, Config.Weapons.Bat.damage
	local function launchAt(health: number): number
		local push, lift = HitRules.force("launch", health, max, h)
		return BatMath.flightDistance(push, lift, GRAVITY)
	end
	local strikes = Config.Attack.StringCount -- a string's last hit launches: the first launch comes after its hits
	local first, second = launchAt(max - strikes * damage), launchAt(max - 2 * strikes * damage)
	check("the first combo's launch lands on the roof from its middle", first < A.RoofWidth / 2, string.format("%.1f", first))
	-- The launches as measured in Studio (2026-10-25, a server-physics sandbag on a 15-wide roof): the travel includes
	-- landing and sliding, so it is longer than the formula's. A tuning change to these pushes must be measured again.
	local MEASURED = { { health = 64, push = 15.4, lift = 28, travel = 5.38 }, { health = 28, push = 29.2, lift = 28, travel = 11.02 } }
	local same = true
	for _, m in MEASURED do
		local push, lift = HitRules.force("launch", m.health, max, h)
		same = same and near(push, m.push, 0.05) and near(lift, m.lift)
	end
	check("the launch pushes are the ones measured in Studio (measure again after a change)", same)
	check("measured: the first combo's launch stays on the roof from its middle", MEASURED[1].travel < A.RoofWidth / 2)
	check("measured: the second combo's launch goes off the roof from its middle", MEASURED[2].travel > A.RoofWidth / 2)
	check("the second combo's launch goes off the roof from its middle", second > A.RoofWidth / 2, string.format("%.1f", second))
	check("a light hit never pushes off the roof from its middle", h.LightEmpty * h.SlideSeconds < A.RoofWidth / 2)
	check("a smash flies past the other train", BatMath.flightDistance(h.SmashPush, h.SmashLift, GRAVITY) > A.RoofWidth + A.Gap + A.RoofWidth)
	-- The home run: from a body on any top (its middle about 3 above), still flying over the highest top when it
	-- twinkles out, and never up into the stands.
	local lowestTop, highestTop = math.huge, -math.huge
	for _, surface in L.surfaces do
		lowestTop = math.min(lowestTop, surface.top)
		highestTop = math.max(highestTop, surface.top)
	end
	local t = Config.Fall.HomeRunSeconds
	local function heightAt(startY: number, after: number): number
		return startY + h.SmashLift * after - GRAVITY / 2 * after * after
	end
	local hold = Config.Feedback.HitStop.smash -- the flight starts after the hold
	check("a home run from the lowest deck is still higher than the highest top when it twinkles out", heightAt(lowestTop + 3, t - hold) - 3 > highestTop, string.format("%.1f", heightAt(lowestTop + 3, t - hold)))
	-- It would reach the sand (its middle about 3 above it) a good moment after the twinkle, so a late network word
	-- does not show it lying on the sand first.
	local sandY = A.GroundY + 3
	local land = (h.SmashLift + math.sqrt(h.SmashLift * h.SmashLift + 2 * GRAVITY * (lowestTop + 3 - sandY))) / GRAVITY
	-- The flight starts after the hold, so it has flown (t - hold) when the server takes it away.
	check("a home run reaches the sand at least 0.2 s after it twinkles out", land > t - hold + 0.2, string.format("%.2f", land))
	check("a heavier hit holds longer, and every hold is short", Config.Feedback.HitStop.light < Config.Feedback.HitStop.launch and Config.Feedback.HitStop.launch < Config.Feedback.HitStop.smash and Config.Feedback.HitStop.smash <= 0.2)
	local top = highestTop + 3 + h.SmashLift * h.SmashLift / (2 * GRAVITY)
	check("a home run's top stays under where the stands begin, even from the highest top", top < A.WaitingRoomHeight - A.StandsMargin - 2, string.format("%.1f", top))
	local quickest = math.huge
	for _, w in Config.Weapons do
		quickest = math.min(quickest, w.cooldown)
	end
	local a = Config.Attack
	check("a light hit's stun ends before any weapon can attack again (the one hit can answer)", h.LightStun + 0.1 < quickest)
	check("a launched fighter stays unhittable past lying down", h.LaunchImmune > Config.Knock.MinSeconds + 0.2)
	check("a string waits a moment for the next press, then starts again", a.StringGap >= 0.2 and a.StringGap <= 0.6 and a.StringSlack < a.StringGap and a.StringCount == 3)
	check("a crowd's hits launch within the same window the old combo had", h.GangWindow >= 1 and h.GangHits == 3)
	check("a plank is wider than a character and narrower than a roof", A.PlankWidth > 2.5 and A.PlankWidth < A.RoofWidth)
	check("the car gap is well under a character's thickness (about 1: nobody slips through)", A.CarGap <= 0.5)
	local within = true
	for _, w in Config.Weapons do
		within = within and w.hitAt < w.seconds and w.seconds <= w.cooldown + 0.3
	end
	check("every attack lands within its drawn move, and the move ends about when the next may start", within)
	check("a swing pressed before the hit showed is taken, a swing while flying is not", Config.Knock.SwingGrace > 0 and Config.Knock.SwingGrace < Config.Knock.MinSeconds)
	check("the server's slack keeps its reach above the client's", Config.Attack.ReachSlack > 0 and Config.Attack.CooldownSlack < quickest)
	check("the server's network slack stays small (it shows as hits from too far)", Config.Attack.ReachSlack <= 2)
	check("the waiting room's walls are higher than a jump off someone's head", A.WaitingRoomWall > JUMP_HEIGHT + 5.5)
	check("the fall plays while the waiting room is far above", Config.Arena.WaitingRoomHeight > 40)
end

-- 6. Decoration promises (stage 3): the chimney is a perch on its boiler, the drawn wheels fit, the canyon stays clear
-- of a home run's flight and reaches past the trackside.
do
	local engine = A.CarKinds.Locomotive
	local boiler, stack = engine.boiler, engine.stack
	check("the locomotive has a boiler and a chimney on it", boiler ~= nil and stack ~= nil)
	if boiler and stack then
		local found, onBoiler = 0, true
		for _, train in L.trains do
			for _, place in train.cars do
				if place.kind == "Locomotive" then
					local z = place.front + place.length * stack.along
					local boilerEnd = place.front + place.length * boiler.to
					onBoiler = onBoiler and z - stack.width / 2 >= place.front and z + stack.width / 2 <= boilerEnd
					for _, surface in L.surfaces do
						if surface.train == place.train and near(surface.z, z) and near(surface.top, boiler.top + stack.height) then
							found += 1
						end
					end
				end
			end
		end
		check("every chimney top is a walkable top of its own train", found == #L.trains, tostring(found))
		check("every chimney stands on its boiler", onBoiler)
		check("a chimney top is within a jump of the boiler (a perch, not a wall)", stack.height < JUMP_HEIGHT - 1.5)
		-- The drawn driving wheels' tyres, at their inner face, stay under the round boiler.
		local tyreInner = A.Gauge - 0.15 * Config.Decor.DetailScale
		local overTyre = boiler.top - boiler.width / 2 - math.sqrt((boiler.width / 2) ^ 2 - tyreInner ^ 2)
		check("the drawn driving wheels' tyres stay under the boiler", Config.Decor.DriverRadius * 2 < overTyre, string.format("%.2f", overTyre))
		check("the chimney is narrower than the boiler's ridge", stack.width < boiler.width)
		-- The drawn driving wheels stand on the rails, under the round boiler where it is at the rails.
		local boilerMiddle = boiler.top - boiler.width / 2
		local underBoiler = boilerMiddle - math.sqrt((boiler.width / 2) ^ 2 - A.Gauge ^ 2)
		check("the drawn driving wheels fit under the boiler", Config.Decor.DriverRadius * 2 < underBoiler, string.format("%.2f", underBoiler))
	end
	check("the rails are inside a car body (the wheels under it)", A.Gauge + 0.5 < A.RoofWidth / 2 - A.BodyInset)
	check("the trucks' wheels fit under a car body", A.BodyBottom >= 2 * Config.Decor.TruckWheelRadius)
	-- The locomotive's solid frame: all of it under the boiler (nothing sticks out beside it to land on above the fall
	-- line) and inside the drawn driving wheels (their tyres 0.3 thick on the rails), so they show.
	if boiler then
		check("the locomotive frame stays under the boiler", A.LocomotiveFrame / 2 < boiler.width / 2)
	end
	check("the locomotive frame stays inside the driving wheels", A.LocomotiveFrame / 2 < A.Gauge - 0.15)
	check("a chimney's pipe is narrower than its top", A.StackPipe > 0 and A.StackPipe < 1)
	local c, h = Config.Canyon, Config.Hit
	-- A home run's sideways flight until it twinkles out, from the outermost roof edge, against every piece the clients
	-- draw (CanyonLayout, turned spires by their corners).
	local reach = L.outerEdge + h.SmashPush * Config.Fall.HomeRunSeconds
	local pieces = CanyonLayout.pieces(c, A.GroundY)
	local nearest, farthest, overhang, kinds = math.huge, 0, 0, {}
	for _, piece in pieces do
		local near, far = CanyonLayout.span(piece)
		nearest = math.min(nearest, near)
		farthest = math.max(farthest, far)
		overhang = math.max(overhang, CanyonLayout.overhang(piece))
		kinds[piece.kind] = true
	end
	check("the canyon has walls, slopes, ribs and spires", kinds.Wall and kinds.Talus and kinds.Rib and kinds.Spire or false)
	check("a home run never flies into the canyon (every piece)", reach + 5 < nearest, string.format("%.1f vs %.1f", reach, nearest))
	check("no canyon piece comes nearer than its Config limits say", nearest >= c.Inner - math.max(c.TalusWidth, c.RibOut, c.SpireOut) - 1e-6, string.format("%.1f", nearest))
	local half, ahead, behind = CanyonLayout.ground(c)
	check("the sand reaches under the canyon across the track", farthest < half, string.format("%.1f vs %.1f", farthest, half))
	check("the sand reaches past a canyon stretch wrapped at either end", overhang < ahead - c.Ahead and overhang < behind - c.Behind, string.format("%.1f", overhang))
	check("the sand is one part (2048 at most each way)", half * 2 <= 2048 and ahead + behind <= 2048)
	check("the canyon reaches past the trackside scenery both ways", c.Ahead > Config.Run.ViewAhead and c.Behind > Config.Run.ViewBehind)
	check("the canyon is beyond the roadside props and poles", nearest > Config.Run.RoadsideFar and nearest > L.outerEdge + Config.Run.PoleDistance)
	check("a canyon stretch is long enough to show and shorter than the loop", c.SegmentMin > 10 and c.SegmentMax < c.Ahead + c.Behind)
	check("the floor window is smaller than the waiting room", A.WaitingRoomWindow < A.WaitingRoomSize - 4)
end

-- 7. Weapons (stage 4b): fists by default, weapons from crates, every hit pushed by health.
do
	local W, h = Config.Weapons, Config.Hit
	local styles = { punch = true, swing = true, slam = true, throw = true }
	local shaped, lasting = true, true
	for name, w in W do
		shaped = shaped and styles[w.style] == true and w.damage > 0 and w.push > 0 and (Words.Weapons[name] or "") ~= ""
		if w.style == "punch" or w.style == "swing" then
			shaped = shaped and w.reach ~= nil and w.halfAngle ~= nil
		elseif w.style == "slam" then
			shaped = shaped and w.radius ~= nil and w.ahead ~= nil
		else
			shaped = shaped and w.radius ~= nil and w.throwSpeed ~= nil and w.throwLift ~= nil and w.fuse ~= nil
		end
		if name ~= "Fist" then
			lasting = lasting and (w.weight or 0) > 0 and (w.uses ~= nil or w.heldSeconds ~= nil)
		end
	end
	check("every weapon has what its style needs", shaped)
	check("every weapon but the fists comes in crates and runs out", lasting)
	check("bare fists never come in a crate and never run out", W.Fist and (W.Fist.weight or 0) == 0 and W.Fist.uses == nil and W.Fist.heldSeconds == nil)
	check("fists reach less than the bat", W.Fist.reach ~= nil and W.Bat.reach ~= nil and W.Fist.reach < W.Bat.reach)
	-- No single hit of any weapon carries a full-health fighter off a roof from its middle (the owner's choice: weapons
	-- push by health too). A launch travelled up to 1.32 times the plain flight (measured: 11.02 against 8.33), so the
	-- check takes 1.5 times.
	local safe, worst = true, ""
	for name, w in W do
		local health = Config.Health.Max - w.damage
		local travel
		if w.launch then
			local push, lift = HitRules.force("launch", health, Config.Health.Max, h)
			travel = BatMath.flightDistance(push * w.push * 1.5, lift, GRAVITY)
		else
			local push = HitRules.force("light", health, Config.Health.Max, h)
			travel = push * w.push * h.SlideSeconds * 1.5 -- a light push carries on a little (measured 1.2 to 2)
		end
		if travel >= A.RoofWidth / 2 then
			safe, worst = false, string.format("%s %.1f", name, travel)
		end
	end
	check("no single hit of any weapon throws a full-health fighter off from a roof's middle", safe, worst)
	check("a held gold bar is pushed less and walks slower", W.GoldBar.resist ~= nil and W.GoldBar.resist < 1 and W.GoldBar.slow ~= nil and W.GoldBar.slow > 0 and W.GoldBar.slow < 1)
	local stick = W.Dynamite
	check("a thrown stick lands beyond its own blast", BatMath.flightDistance(stick.throwSpeed or 0, stick.throwLift or 0, GRAVITY) > (stick.radius or 0))
	check("a stick's fuse outlasts its flight across a gap (time to run)", (stick.fuse or 0) > 2 * (stick.throwLift or 0) / GRAVITY + 0.8)
	-- Picking a crate's weapon.
	check("a crate never holds bare fists", WeaponRules.pick(W, 0) ~= "Fist" and WeaponRules.pick(W, 0.999) ~= "Fist")
	local counts: { [string]: number } = {}
	for k = 0, 999 do
		local picked = WeaponRules.pick(W, k / 1000)
		if picked then
			counts[picked] = (counts[picked] or 0) + 1
		end
	end
	local total = 0
	for name, w in W do
		total += w.weight or 0
	end
	local fair = true
	for name, w in W do
		local expected = 1000 * (w.weight or 0) / total
		fair = fair and math.abs((counts[name] or 0) - expected) <= 2
	end
	check("crates hold each weapon as often as its weight says", fair)
	check("with no weights nothing is picked", WeaponRules.pick({ Fist = W.Fist }, 0.5) == nil)
	check("a weapon name is read back, anything else is bare fists", WeaponRules.named(W, "Hammer") == "Hammer" and WeaponRules.named(W, "Nope") == "Fist" and WeaponRules.named(W, nil) == "Fist")
	check("an area hit reaches within its radius and height only", WeaponRules.inArea(0, 0, 0, 3, 1, 4, 5, 5) and not WeaponRules.inArea(0, 0, 0, 4, 0, 4, 5, 5) and not WeaponRules.inArea(0, 0, 0, 1, 6, 0, 5, 5))
	local ax, ay, az = WeaponRules.arc(1, 2, 3, 1, 0, 10, 20, GRAVITY, 0)
	local bx, by, _ = WeaponRules.arc(0, 0, 0, 1, 0, 10, 20, GRAVITY, 20 / GRAVITY)
	check("a throw starts at the hand and tops out where the lift runs out", ax == 1 and ay == 2 and az == 3 and near(bx, 10 * 20 / GRAVITY) and near(by, 20 * 20 / GRAVITY / 2))
	local d = Config.Drops
	check("crates: one for every three fighters, at least one, at most MaxOnMap", WeaponRules.cratesFor(1, d.MaxOnMap) == 1 and WeaponRules.cratesFor(3, d.MaxOnMap) == 1 and WeaponRules.cratesFor(4, d.MaxOnMap) == math.min(2, d.MaxOnMap) and WeaponRules.cratesFor(30, d.MaxOnMap) == d.MaxOnMap)
	check("a crate lands before the next is due and lies a while", d.FallSeconds < d.Every and d.LifeSeconds > d.FallSeconds and d.FirstAfter < Config.Round.MaxSeconds)
end

-- 8. Words on screen (stage 5a): one place, every weapon named, every control has its card, no line left empty.
do
	local named = true
	for name in Config.Weapons do
		named = named and type(Words.Weapons[name]) == "string" and Words.Weapons[name] ~= ""
	end
	check("every weapon has a name on screen", named)
	local cards = true
	for _, control in { "mouse", "touch", "gamepad" } do
		local rows = Words.cardRows(control)
		cards = cards and #rows >= 4 and #rows <= 6
		for _, row in rows do
			cards = cards and #row == 2 and row[1] ~= "" and row[2] ~= ""
		end
	end
	check("every kind of control has a first-ride card of 4 to 6 rows", cards)
	check("the mouse card names Alt, the touch card does not", Words.cardRows("mouse")[6][1] == "왼쪽 Alt" and #Words.cardRows("touch") == 5)
	check("the clock reads minutes and seconds", Words.clock(113) == "1:53" and Words.clock(5) == "0:05" and Words.clock(0) == "0:00")
	check("the feed credits who knocked who off, and a fall with nobody to credit", Words.feed("B", "A", "homerun") == "A → B 홈런!" and Words.feed("B", "A", "fall") == "A → B 하차" and Words.feed("B", nil, "fall") == "B 하차")
	check("what the player holds reads its name and what is left", Words.uses("Hammer", 3) == "망치 ×3" and Words.secondsLeft("GoldBar", 12) == "금괴 12초")
end

-- 9. The attacker's 1-2-3 string (stage 5b).
do
	local r = { count = 3, gap = 0.35, slack = 0.15, windup = 0.08 }
	-- An attack that lands, then takes the next (each at `at`).
	local function hits(s: any, at: number, claim: number?): number
		local step = AttackString.take(s, r, at, 0.45, "punch", claim)
		AttackString.landed(s)
		return step
	end
	local s = AttackString.new()
	local steps = { hits(s, 0), hits(s, 0.5), hits(s, 1.0), hits(s, 1.5) }
	check("landed attacks in a row go 1, 2, 3 and start again after the third", steps[1] == 1 and steps[2] == 2 and steps[3] == 3 and steps[4] == 1, table.concat(steps, ","))
	local m = AttackString.new()
	AttackString.take(m, r, 0, 0.45, "punch") -- a miss
	check("a miss starts the string again (swinging at the air on the way in banks nothing)", AttackString.take(m, r, 0.5, 0.45, "punch") == 1)
	local p = AttackString.new()
	hits(p, 0)
	check("a pause longer than the gap starts the string again", AttackString.take(p, r, 0.45 + 0.36, 0.45, "punch") == 1)
	local c = AttackString.new()
	hits(c, 0)
	check("the client's next step is taken a little past the gap (jitter)", AttackString.take(c, r, 0.45 + 0.4, 0.45, "punch", 2) == 2)
	local late = AttackString.new()
	hits(late, 0)
	check("but not past the gap and its slack", AttackString.take(late, r, 0.45 + 0.51, 0.45, "punch", 2) == 1)
	local k = AttackString.new()
	hits(k, 0)
	check("a client cannot skip to the launching step", AttackString.take(k, r, 0.5, 0.45, "punch", 3) == 2)
	local four = AttackString.new()
	hits(four, 0)
	hits(four, 0.5)
	hits(four, 1.0)
	check("nor claim a step past the last", AttackString.take(four, r, 1.5, 0.45, "punch", 4) == 1)
	local miss = AttackString.new()
	AttackString.take(miss, r, 0, 0.45, "punch")
	check("nor keep a string going on a miss", AttackString.take(miss, r, 0.5, 0.45, "punch", 2) == 1)
	local o = AttackString.new()
	hits(o, 0)
	check("a client may always start a new string", AttackString.take(o, r, 0.5, 0.45, "punch", 1) == 1)
	local b = AttackString.new()
	hits(b, 0)
	AttackString.reset(b)
	check("being hit breaks the string, even against the client's word", AttackString.take(b, r, 0.5, 0.45, "punch", 2) == 1)
	local w = AttackString.new()
	hits(w, 0)
	hits(w, 0.5)
	check("a slam or a throw is no step and starts the string over", AttackString.take(w, r, 1.0, 0.9, "throw") == 1 and AttackString.take(w, r, 1.5, 0.45, "punch") == 1)
	check("the third step of a punch or swing launches, not the others, and not a slam or a throw", AttackString.launches(r, 3, "punch") and AttackString.launches(r, 3, "swing") and not AttackString.launches(r, 2, "punch") and not AttackString.launches(r, 3, "slam") and not AttackString.launches(r, 3, "throw"))
	check("the launching step lands a moment later than the others", AttackString.hitAt(r, 0.1, 3, "punch") == 0.1 + r.windup and AttackString.hitAt(r, 0.1, 2, "punch") == 0.1 and AttackString.hitAt(r, 0.45, 3, "slam") == 0.45)
	local real = Config.Attack
	local rr = AttackString.rules(real)
	check("the real rules come from Config.Attack", rr.count == real.StringCount and rr.gap == real.StringGap and rr.slack == real.StringSlack and rr.windup == real.FinisherWindup)
	check("with the real numbers a fist string keeps going for presses up to 0.8 s apart", near(Config.Weapons.Fist.cooldown + real.StringGap, 0.8))
	local fits = true
	for name, wpn in Config.Weapons do
		if AttackString.uses(wpn.style) then
			local length = wpn.seconds * real.FinisherStretch
			-- The finisher is drawn longer, still lands inside its drawn move, and is done by the time the next may start.
			fits = fits and wpn.hitAt + real.FinisherWindup < length * 0.9 and length <= wpn.cooldown
		end
	end
	check("every finisher lands inside its longer move and ends by the weapon's cooldown", fits)
end

-- 10. The guard against being ganged up on (stage 5b), beyond section 4.
do
	local rules = { max = 100, window = 1.5, gang = 3, immune = 0.9 }
	local a = HitRules.new(100)
	HitRules.hit(a, rules, 0, 8, false, "A")
	HitRules.hit(a, rules, 0.4, 8, false, "B")
	local crowdKind, crowd = HitRules.hit(a, rules, 0.8, 8, false, "C")
	check("three attackers' hits together launch too, marked as a crowd's launch", crowdKind == "launch" and crowd == true)
	local own = HitRules.new(100)
	local ownKind, ownCrowd = HitRules.hit(own, rules, 0, 8, true, "A")
	check("an attacker's own launch is not marked as a crowd's", ownKind == "launch" and ownCrowd == false)
	local e = HitRules.new(100)
	HitRules.hit(e, rules, 0, 8, false, "A")
	HitRules.hit(e, rules, 0.75, 8, false, "B")
	check("the window includes its very edge", HitRules.hit(e, rules, 1.5, 8, false, "A") == "launch")
	local f = HitRules.new(100)
	HitRules.hit(f, rules, 0, 8, false, "A")
	HitRules.hit(f, rules, 0.3, 8, false, "B")
	HitRules.hit(f, rules, 0.6, 8, false, "A") -- launched: the list is cleared
	local after1, after2 = HitRules.hit(f, rules, 1.6, 8, false, "B"), HitRules.hit(f, rules, 1.9, 8, false, "A")
	check("after a crowd launch the count starts again", after1 == "light" and after2 == "light")
end

print(string.format("%d passed, %d failed", passed, failed))
if failed == 0 then
	print("ALL PASS")
end
