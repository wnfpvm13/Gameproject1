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
	local apart = true
	for a = 1, #L.spots do
		for b = a + 1, #L.spots do
			local p, q = L.spots[a], L.spots[b]
			if math.abs(p.x - q.x) < 3 and math.abs(p.z - q.z) < 3 then
				apart = false
			end
		end
	end
	check("spawn spots are at least 3 apart (nobody appears inside someone else)", apart)
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
	local rules = { max = 100, damage = 12, window = 1.5, launchOn = 3, immune = 0.9 }
	local s = HitRules.new(100)
	check("a fighter starts at full health", s.health == 100)
	local k1 = HitRules.hit(s, rules, 0)
	local k2 = HitRules.hit(s, rules, 0.6)
	local k3 = HitRules.hit(s, rules, 1.2)
	check("the first two hits of a combo are light, the third launches", k1 == "light" and k2 == "light" and k3 == "launch", k1 .. "," .. k2 .. "," .. k3)
	check("each hit takes its damage", s.health == 64)
	check("right after a launch the fighter cannot be hit", HitRules.hit(s, rules, 1.5) == "none" and s.health == 64)
	check("after the moment passes a new combo starts light", HitRules.hit(s, rules, 2.2) == "light")
	local t = HitRules.new(100)
	HitRules.hit(t, rules, 0)
	check("hits too far apart do not make a combo", HitRules.hit(t, rules, 2) == "light" and HitRules.hit(t, rules, 4) == "light")
	local u = HitRules.new(100)
	local kinds, now = {}, 0
	for _ = 1, 9 do
		table.insert(kinds, HitRules.hit(u, rules, now))
		now += 1 -- past the immune moment, and two hits a combo at most
	end
	check("the hit that empties health is a smash (the 9th from full)", kinds[9] == "smash" and kinds[8] ~= "smash" and u.health == 0, table.concat(kinds, ","))
	check("an emptied fighter takes no more hits", HitRules.hit(u, rules, now + 5) == "none")
	check("push scales from full to empty", HitRules.scale(100, 100, 9, 29) == 9 and HitRules.scale(0, 100, 9, 29) == 29 and HitRules.scale(50, 100, 9, 29) == 19)
	check("push stays in range outside the health range", HitRules.scale(-5, 100, 9, 29) == 29 and HitRules.scale(150, 100, 9, 29) == 9)
	check("the real numbers empty health on the 9th hit", math.ceil(Config.Health.Max / Config.Health.HitDamage) == 9)
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
	local max, damage = Config.Health.Max, Config.Health.HitDamage
	local function launchAt(health: number): number
		local push, lift = HitRules.force("launch", health, max, h)
		return BatMath.flightDistance(push, lift, GRAVITY)
	end
	local first, second = launchAt(max - h.LaunchOn * damage), launchAt(max - 2 * h.LaunchOn * damage)
	check("the first combo's launch lands on the roof from its middle", first < A.RoofWidth / 2, string.format("%.1f", first))
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
	check("a home run from the lowest deck is still higher than the highest top when it twinkles out", heightAt(lowestTop + 3, t) - 3 > highestTop, string.format("%.1f", heightAt(lowestTop + 3, t)))
	-- It would reach the sand (its middle about 3 above it) a good moment after the twinkle, so a late network word
	-- does not show it lying on the sand first.
	local sandY = A.GroundY + 3
	local land = (h.SmashLift + math.sqrt(h.SmashLift * h.SmashLift + 2 * GRAVITY * (lowestTop + 3 - sandY))) / GRAVITY
	-- The flight starts after the hold, so it has flown (t - hold) when the server takes it away.
	check("a home run reaches the sand at least 0.2 s after it twinkles out", land > t - Config.Feedback.HitStopSeconds + 0.2, string.format("%.2f", land))
	local top = highestTop + 3 + h.SmashLift * h.SmashLift / (2 * GRAVITY)
	check("a home run's top stays under the stands, even from the highest top", top < A.WaitingRoomHeight - 5, string.format("%.1f", top))
	check("a light hit's stun ends before the swinger can swing again (the one hit can answer)", h.LightStun + 0.1 < Config.Bat.Cooldown)
	check("a launched fighter stays unhittable past lying down", h.LaunchImmune > Config.Knock.MinSeconds + 0.2)
	check("a combo has time for its hits at the swing rate", h.ComboWindow > (h.LaunchOn - 1) * Config.Bat.Cooldown)
	check("a plank is wider than a character and narrower than a roof", A.PlankWidth > 2.5 and A.PlankWidth < A.RoofWidth)
	check("the car gap is well under a character's thickness (about 1: nobody slips through)", A.CarGap <= 0.5)
	check("the bat lands within the drawn swing", Config.Bat.HitAt < Config.Bat.SwingSeconds)
	check("a swing pressed before the hit showed is taken, a swing while flying is not", Config.Knock.SwingGrace > 0 and Config.Knock.SwingGrace < Config.Knock.MinSeconds)
	check("the server's slack keeps its reach above the client's", Config.Bat.ReachSlack > 0 and Config.Bat.CooldownSlack < Config.Bat.Cooldown)
	check("the server's network slack stays small (it shows as hits from too far)", Config.Bat.ReachSlack <= 2)
	check("the waiting room's walls are higher than a jump off someone's head", A.WaitingRoomWall > JUMP_HEIGHT + 5.5)
	check("the fall plays while the waiting room is far above", Config.Arena.WaitingRoomHeight > 40)
end

print(string.format("%d passed, %d failed", passed, failed))
if failed == 0 then
	print("ALL PASS")
end
