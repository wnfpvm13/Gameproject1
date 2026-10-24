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

-- 1. Trains and cars.
do
	local x1 = ArenaLayout.trainX(1, 2, 10, 12)
	local x2 = ArenaLayout.trainX(2, 2, 10, 12)
	check("two trains sit either side of the middle", near(x1, -11) and near(x2, 11))
	check("one train sits on the middle", near(ArenaLayout.trainX(1, 1, 10, 12), 0))
	local places = ArenaLayout.carPlaces(A.Cars, A.CarGap)
	check("every car is placed", #places == #A.Cars)
	check("the train is centred along the track", near(places[1].front, -places[#places].back))
	local spaced = true
	for i = 2, #places do
		spaced = spaced and near(places[i].front - places[i - 1].back, A.CarGap)
	end
	check("cars follow one another a car gap apart", spaced)
	check("a car's middle is halfway along it", near(places[2].middle, (places[2].front + places[2].back) / 2))
end

-- 2. Planks, spawn spots and the fall line.
do
	local places = ArenaLayout.carPlaces(A.Cars, A.CarGap)
	local planks = ArenaLayout.planks(places, A.PlankCars, A.Trains, A.RoofWidth, A.Gap, A.PlankOverlap)
	check("a plank across each gap at each plank car", #planks == (A.Trains - 1) * #A.PlankCars)
	local plank = planks[1]
	local between = (ArenaLayout.trainX(1, A.Trains, A.RoofWidth, A.Gap) + ArenaLayout.trainX(2, A.Trains, A.RoofWidth, A.Gap)) / 2
	check("the plank spans the gap and lies on both roofs", near(plank.length, A.Gap + 2 * A.PlankOverlap) and near(plank.x, between))
	check("the plank sits at its car's roof", near(plank.top, places[A.PlankCars[1]].roof) and near(plank.z, places[A.PlankCars[1]].middle))
	local spots = ArenaLayout.spawnSpots(places, A.Trains, A.RoofWidth, A.Gap, 2)
	check("two spawn spots per car per train", #spots == A.Trains * #A.Cars * 2)
	local onRoofs = true
	for _, spot in spots do
		local onAny = false
		for _, place in places do
			if spot.z > place.front and spot.z < place.back and near(spot.y, place.roof) then
				onAny = true
			end
		end
		onRoofs = onRoofs and onAny
	end
	check("every spawn spot is on a roof", onRoofs)
	local lowest = math.huge
	for _, car in A.Cars do
		lowest = math.min(lowest, car.roof)
	end
	check("the fall line is the margin under the lowest roof", near(ArenaLayout.fallLine(places, Config.Fall.Margin), lowest - Config.Fall.Margin))
	check("the sand is under the fall line (whoever lands on it is out)", A.GroundY < ArenaLayout.fallLine(places, Config.Fall.Margin))
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
	local jumpTime = 2 * math.sqrt(2 * JUMP_HEIGHT / GRAVITY)
	local jump = WALK_SPEED * jumpTime
	check("the gap between trains is wider than a jump (a plank or a hit is needed)", A.Gap > jump + 1, string.format("gap %.1f, jump %.1f", A.Gap, jump))
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
