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

-- 4. Tuning promises.
do
	local jumpTime = 2 * math.sqrt(2 * JUMP_HEIGHT / GRAVITY)
	local jump = WALK_SPEED * jumpTime
	check("the gap between trains is wider than a jump (a plank or a hit is needed)", A.Gap > jump + 1, string.format("gap %.1f, jump %.1f", A.Gap, jump))
	local carry = BatMath.flightDistance(Config.Bat.Push, Config.Bat.Lift, GRAVITY)
	-- Hit across the roof from the middle, the flight lands past the edge; from near one edge (1 in) toward the other,
	-- it lands on the roof (the slide after landing is not in this; it is measured in Studio).
	check("a knock across the roof from the middle lands off it", carry > A.RoofWidth / 2, string.format("%.1f", carry))
	check("a knock from near one edge toward the other lands on the roof", carry < A.RoofWidth - 2, string.format("%.1f", carry))
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
