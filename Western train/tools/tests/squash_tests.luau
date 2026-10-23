-- Squash and run math tests (run by tools/tests/run_tests.py, which puts Config, SquashSpring, SquashPose,
-- CrankMotion, CourseMath, JumpArc, PaperPath and CrewBook above this).
-- Uses the real Config numbers, so a tuning change that breaks the feel (too slow, no bounce, flying parts) fails.
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

local c = Config.Squash

-- Runs the spring toward target at a frame rate; records the range, crossings of the target and the settle time.
local function run(state, target: number, seconds: number, fps: number?)
	local dt = 1 / (fps or 60)
	local frames = math.floor(seconds / dt + 0.5)
	local pressing = target == 1
	local frequency = if pressing then c.PressFrequency else c.ReleaseFrequency
	local damping = if pressing then c.PressDamping else c.ReleaseDamping
	local low, high, crossings, lastSide, settledAt = math.huge, -math.huge, 0, nil, nil
	for i = 1, frames do
		SquashSpring.step(state, target, dt, frequency, damping, c.MinValue, c.MaxValue)
		low = math.min(low, state.value)
		high = math.max(high, state.value)
		local side = if state.value > target then 1 else -1
		if lastSide and side ~= lastSide and not settledAt then
			crossings += 1
		end
		lastSide = side
		if not settledAt and SquashSpring.settle(state, target, c.RestEpsilon) then
			settledAt = i * dt
		end
	end
	return { low = low, high = high, crossings = crossings, settledAt = settledAt }
end

-- 1. Pressing folds fast, overshoots a little (extra squish) and settles.
do
	local s = SquashSpring.new()
	run(s, 1, 0.15)
	check("press is nearly flat after 0.15 s", s.value >= 0.85, tostring(s.value))
	local r = run(SquashSpring.new(), 1, 1.5)
	check("press overshoots a little", r.high > 1.0 and r.high < 1.2, tostring(r.high))
	check("press settles within 1 s", r.settledAt ~= nil and r.settledAt <= 1.0, tostring(r.settledAt))
end

-- 2. Letting go springs past normal (taller: the bounce), wobbles 2-3 times and settles.
do
	local s = SquashSpring.new()
	s.value = 1
	local r = run(s, 0, 3)
	check("release bounces taller than normal", r.low <= -0.15, tostring(r.low))
	check("release bounce stays inside the limit", r.low >= c.MinValue, tostring(r.low))
	check("release wobbles a few times", r.crossings >= 3, tostring(r.crossings))
	check("release settles within 2.5 s", r.settledAt ~= nil and r.settledAt <= 2.5, tostring(r.settledAt))
	check("settled exactly at normal", s.value == 0 and s.velocity == 0)
end

-- 3. The same feel at any frame rate, and a hitch or a bad dt can never fling the shape.
do
	local slow, fast = SquashSpring.new(), SquashSpring.new()
	run(slow, 1, 0.3, 30)
	run(fast, 1, 0.3, 240)
	check("30 fps and 240 fps agree", near(slow.value, fast.value, 0.02), slow.value .. " vs " .. fast.value)
	local hitch = SquashSpring.new()
	SquashSpring.step(hitch, 1, 5, c.PressFrequency, c.PressDamping, c.MinValue, c.MaxValue)
	check("a 5 s hitch stays in range", hitch.value >= c.MinValue and hitch.value <= c.MaxValue and hitch.value == hitch.value)
	local back = SquashSpring.new()
	SquashSpring.step(back, 1, -1, c.PressFrequency, c.PressDamping, c.MinValue, c.MaxValue)
	check("a negative dt changes nothing", back.value == 0 and back.velocity == 0)
end

-- 4. Body scale: normal, flat and the tall bounce.
do
	local normal = SquashPose.bodyScale(0, c.HeightAtFull, c.WidthAtFull, c.LengthAtFull)
	check("value 0 is the normal shape", normal.x == 1 and normal.y == 1 and normal.z == 1)
	local flat = SquashPose.bodyScale(1, c.HeightAtFull, c.WidthAtFull, c.LengthAtFull)
	check("value 1 is flat and wide", near(flat.x, c.WidthAtFull) and near(flat.y, c.HeightAtFull) and near(flat.z, c.LengthAtFull))
	local tall = SquashPose.bodyScale(-0.3, c.HeightAtFull, c.WidthAtFull, c.LengthAtFull)
	check("negative value is tall and thin", tall.y > 1 and tall.x < 1)
	local crushed = SquashPose.bodyScale(50, c.HeightAtFull, c.WidthAtFull, c.LengthAtFull)
	check("no axis ever reaches zero", crushed.y >= 0.05 and crushed.x > 0 and crushed.z > 0)
end

local IDENTITY = { { x = 1, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }, { x = 0, y = 0, z = 1 } }
local SUPINE = { { x = -1, y = 0, z = 0 }, { x = 0, y = 0, z = -1 }, { x = 0, y = -1, z = 0 } }
local UPRIGHT = { { x = 0, y = 1, z = 0 }, { x = -1, y = 0, z = 0 }, { x = 0, y = 0, z = 1 } }
local FLAT = { x = 1.3, y = 0.4, z = 1.08 }
local function v(x, y, z)
	return { x = x, y = y, z = z }
end

-- 5. Part poses.
do
	local pos, size = SquashPose.pose({ position = v(1, 2, 3), anchor = v(1, 2, 3), size = v(2, 4, 6), axes = IDENTITY, exponent = 1 }, FLAT)
	check("centre part moves with the body", near(pos.x, 1.3) and near(pos.y, 0.8) and near(pos.z, 3.24))
	check("centre part resizes with the body", near(size.x, 2.6) and near(size.y, 1.6) and near(size.z, 6.48))

	local _, torso = SquashPose.pose({ position = v(0, 3, 5), anchor = v(0, 3, 5), size = v(4, 10, 3), axes = SUPINE, exponent = 1 }, FLAT)
	check("lying torso: own Y (length) follows the track, own Z (thickness) the height",
		near(torso.x, 5.2) and near(torso.y, 10.8) and near(torso.z, 1.2), torso.x .. "," .. torso.y .. "," .. torso.z)

	local r = 1.3
	local wheelPos, wheelSize = SquashPose.pose({ position = v(2.3, r, 4), anchor = v(2.3, r, 4), size = v(0.6, 2 * r, 2 * r), axes = IDENTITY, exponent = 1 }, FLAT)
	check("wheel bottom stays on the rails", near(wheelPos.y - wheelSize.y / 2, 0))

	-- chimney: foot on the boiler top (y 5), 2.6 tall, folding harder than the body
	local e = c.ChimneyExponent
	local foot = v(0, 5, 2)
	local chimneyPos, chimneySize = SquashPose.pose({ position = v(0, 6.3, 2), anchor = foot, size = v(2.6, 1.3, 1.3), axes = UPRIGHT, exponent = e }, FLAT)
	check("chimney foot rides on the squashed boiler top", near(chimneyPos.y - chimneySize.x / 2, 5 * 0.4))
	check("chimney folds harder than the body", chimneySize.x < 2.6 * 0.4 and near(chimneySize.x, 2.6 * 0.4 ^ e))
	local capPos, capSize = SquashPose.pose({ position = v(0, 5 + 2.6 + 0.35, 2), anchor = foot, size = v(0.7, 2.3, 2.3), axes = UPRIGHT, exponent = e }, FLAT)
	check("cap sits on the folded chimney", near(capPos.y - capSize.x / 2, chimneyPos.y + chimneySize.x / 2))

	local restPos, restSize = SquashPose.pose({ position = v(0, 6.3, 2), anchor = foot, size = v(2.6, 1.3, 1.3), axes = UPRIGHT, exponent = e }, v(1, 1, 1))
	check("value 0 puts a part exactly back", near(restPos.y, 6.3) and near(restSize.x, 2.6) and near(restSize.y, 1.3))

	-- The FileMesh cylinders of the dressed locomotive: a boiler along the track and a wheel across it squash into
	-- ellipses (the narrow axis is the height, the wide one the width or length).
	local ALONG_TRACK = { { x = 1, y = 0, z = 0 }, { x = 0, y = 0, z = 1 }, { x = 0, y = -1, z = 0 } }
	local ACROSS = { { x = 0, y = -1, z = 0 }, { x = 1, y = 0, z = 0 }, { x = 0, y = 0, z = 1 } }
	local _, boiler = SquashPose.pose({ position = v(0, 4, 3.75), anchor = v(0, 4, 3.75), size = v(4, 7.5, 4), axes = ALONG_TRACK, exponent = 1 }, FLAT)
	check("boiler: width x1.3, length x1.08, height x0.4", near(boiler.x, 5.2) and near(boiler.y, 8.1) and near(boiler.z, 1.6),
		boiler.x .. "," .. boiler.y .. "," .. boiler.z)
	local driver = 1.5
	local dPos, dSize = SquashPose.pose({ position = v(2, driver, 4.4), anchor = v(2, driver, 4.4), size = v(3, 0.5, 3), axes = ACROSS, exponent = 1 }, FLAT)
	check("driving wheel: an oval 0.4 tall and 1.08 long, still on the rails", near(dSize.x, 1.2) and near(dSize.z, 3.24) and near(dPos.y - dSize.x / 2, 0))
end

-- 6. Rods and crank pins circle with the driving wheels.
do
	local L = Config.Locomotive
	local r = L.CrankRadius
	local y0, z0 = CrankMotion.offset(0, 0, r, 1, 1)
	check("angle 0 is the top of the circle", near(y0, r) and near(z0, 0))
	local angle = CrankMotion.advance(0, 0.01, L.CrankTurnsPerSecond)
	local _, z1 = CrankMotion.offset(angle, 0, r, 1, 1)
	check("running forward moves the top forward (-Z)", angle > 0 and z1 < 0, tostring(z1))
	local right, left = CrankMotion.forSide(1, r), CrankMotion.forSide(-1, r)
	local yq, zq = CrankMotion.offset(0, left.phase, r, 1, 1)
	check("the left side is a quarter turn ahead (at the front when the right is on top)",
		right.phase == 0 and right.radius == r and near(yq, 0, 1e-9) and near(zq, -r))
	local ys, zs = CrankMotion.offset(0.7, 0, r, 0.4, 1.08)
	local yn, zn = CrankMotion.offset(0.7, 0, r, 1, 1)
	check("the circle squashes with the wheels", near(ys, yn * 0.4) and near(zs, zn * 1.08))
	check("one second turns the wheels the configured times", near(CrankMotion.advance(0, 1 / L.CrankTurnsPerSecond, L.CrankTurnsPerSecond), 0, 1e-6)
		or near(CrankMotion.advance(0, 1 / L.CrankTurnsPerSecond, L.CrankTurnsPerSecond), 2 * math.pi, 1e-6))
	local wrapped = 0
	for _ = 1, 10000 do
		wrapped = CrankMotion.advance(wrapped, 1 / 60, L.CrankTurnsPerSecond)
	end
	check("the angle stays within one turn", wrapped >= 0 and wrapped < 2 * math.pi)
	check("a negative dt does not turn backward", CrankMotion.advance(1, -0.5, L.CrankTurnsPerSecond) == 1)
end

-- 7. The legs swing about the hip while the spring moves (they lag behind the body).
do
	local L = Config.Locomotive
	local limits = { gain = c.LegKickGain, up = c.LegKickUp, down = c.LegKickDown, flatHeight = c.HeightAtFull }
	check("still spring, still legs", SquashPose.kickAngle(0, 1, 1, limits) == 0 and SquashPose.kickAngle(0, -1, 1, limits) == 0)
	check("the two legs swing opposite ways", near(SquashPose.kickAngle(3, 1, 1, limits), -SquashPose.kickAngle(3, -1, 1, limits)))
	check("the swing never passes its limits", near(SquashPose.kickAngle(1e6, 1, 1, limits), c.LegKickDown)
		and near(SquashPose.kickAngle(-1e6, 1, 1, limits), -c.LegKickUp))
	check("no downward swing once fully flat", SquashPose.kickAngle(1e6, 1, c.HeightAtFull, limits) == 0
		and near(SquashPose.kickAngle(-1e6, 1, c.HeightAtFull, limits), -c.LegKickUp))
	-- With the real spring numbers: a press kicks clearly, the release flaps both ways, and the lowest shoe corner
	-- never goes below the rail tops (y = 0). The leg reach adds about 0.4 for the shoe (avatar foot size, not in
	-- Config); the shoe stands FootLength tall (toes up) and folds with the body.
	local hipY = L.DeckHeight + L.CabWaist / 2
	local reach = L.LegLength + 0.4
	local function swings(target: number, from: number)
		local state = SquashSpring.new()
		state.value = from
		local pressing = target == 1
		local frequency = if pressing then c.PressFrequency else c.ReleaseFrequency
		local damping = if pressing then c.PressDamping else c.ReleaseDamping
		local low, high, lowest = 0, 0, math.huge
		for _ = 1, 120 do
			SquashSpring.step(state, target, 1 / 60, frequency, damping, c.MinValue, c.MaxValue)
			local body = SquashPose.bodyScale(state.value, c.HeightAtFull, c.WidthAtFull, c.LengthAtFull)
			for _, side in { 1, -1 } do
				local a = SquashPose.kickAngle(state.velocity, side, body.y, limits)
				low, high = math.min(low, a), math.max(high, a) -- up (negative) and down over both legs
				local down = math.max(0, a)
				local shoeBottom = hipY * body.y - reach * body.z * math.sin(down) - L.FootLength / 2 * body.y * math.cos(down)
				lowest = math.min(lowest, shoeBottom)
			end
		end
		return low, high, lowest
	end
	local pressLow, pressHigh, pressLowest = swings(1, 0)
	check("a press kicks a leg up at least 30 degrees", -pressLow >= math.rad(30),
		tostring(math.deg(pressLow)) .. " / " .. tostring(math.deg(pressHigh)))
	local releaseLow, releaseHigh, releaseLowest = swings(0, 1)
	check("the release flaps the legs up and down", releaseLow <= -math.rad(20) and releaseHigh >= math.rad(10),
		tostring(math.deg(releaseLow)) .. " / " .. tostring(math.deg(releaseHigh)))
	check("the shoes never dig into the rails", pressLowest >= 0 and releaseLowest >= 0,
		tostring(pressLowest) .. " / " .. tostring(releaseLowest))
end

-- 8. The run toward the low bridges.
do
	local B, R, L = Config.Bridge, Config.Run, Config.Locomotive
	local run = { start = 100, from = 0, speed = 24 }
	check("the run waits before its start", CourseMath.distance(run, 90) == 0)
	check("the run moves at its speed", near(CourseMath.distance(run, 102), 48))
	check("timeAt is the inverse of distance", near(CourseMath.timeAt(run, 48), 102))
	check("a held run never reaches anything", CourseMath.timeAt({ start = 0, from = 5, speed = 0 }, 10) == math.huge)
	local gaps = B.Gaps
	local cycle = 0
	for _, gap in gaps do
		cycle += gap
	end
	check("the first bridge is at FirstAt", CourseMath.bridgeAt(1, B.FirstAt, gaps) == B.FirstAt)
	check("then the gaps in order", CourseMath.bridgeAt(3, B.FirstAt, gaps) == B.FirstAt + gaps[1] + gaps[2])
	check("the gaps repeat", CourseMath.bridgeAt(1 + #gaps * 2, B.FirstAt, gaps) == B.FirstAt + cycle * 2)
	local enter, exit = CourseMath.under(200, 6, -8, 8)
	check("a bridge is over the locomotive from its front to its back", enter == 200 - 3 - 8 and exit == 200 + 3 + 8)
	check("the next bridge is the first not fully passed", CourseMath.nextBridge(0, B.FirstAt, gaps, B.Depth, 8) == 1
		and CourseMath.nextBridge(B.FirstAt + B.Depth / 2 + 8 + 0.01, B.FirstAt, gaps, B.Depth, 8) == 2)
	-- The server's pass check against the squash states it received.
	local history = { { time = 0, squashed = false }, { time = 10, squashed = true }, { time = 12, squashed = false } }
	check("flat for the whole window passes", CourseMath.squashedThroughout(history, 10.5, 11.9))
	check("let go inside the window fails", not CourseMath.squashedThroughout(history, 10.5, 12.5))
	check("pressed too late fails", not CourseMath.squashedThroughout(history, 9.5, 11))
	check("an empty window passes", CourseMath.squashedThroughout(history, 5, 5))
	-- A release in the last moment (inside ReleaseGrace) still passes; an earlier one does not.
	local exitAt = 20
	local late = { { time = 0, squashed = true }, { time = exitAt - R.ReleaseGrace / 2, squashed = false } }
	local early = { { time = 0, squashed = true }, { time = exitAt - R.ReleaseGrace * 2, squashed = false } }
	check("a release in the last moment still passes", CourseMath.squashedThroughout(late, 10, exitAt - R.ReleaseGrace))
	check("an earlier release fails", not CourseMath.squashedThroughout(early, 10, exitAt - R.ReleaseGrace))
	-- nextBridge skips whole cycles: the same answer as counting from the first bridge, also far along the run.
	local function slowNext(distance)
		local i = 1
		while CourseMath.bridgeAt(i, B.FirstAt, gaps) + B.Depth / 2 + 8 < distance do
			i += 1
		end
		return i
	end
	local same = true
	for _, distance in { 0, 100, B.FirstAt + 11, 1234.5, 5000, 20000, 20000 + cycle * 3 + 0.25 } do
		same = same and CourseMath.nextBridge(distance, B.FirstAt, gaps, B.Depth, 8) == slowNext(distance)
	end
	check("nextBridge far along the run matches counting from the start", same)
	-- The numbers fit together: a standing locomotive cannot pass, a flat one can, a restart does not bring back the
	-- bridge before, and pressing just before the bridge is enough even with the allowed network delay.
	local roof = L.DeckHeight + L.CabHeight + L.RoofThickness
	check("the standing cab roof hits the girder", roof > B.Clearance)
	check("the flat cab roof passes under it", roof * c.HeightAtFull < B.Clearance)
	check("the car roofs are as high as the cab roof (walk across)", math.abs(Config.Cars.RoofTop - roof) < 0.01)
	check("a cowboy lying flat on a flat roof passes under the girder", roof * c.HeightAtFull + Config.Cowboy.FlatHeight < B.Clearance)
	local smallest = math.huge
	for _, gap in gaps do
		smallest = math.min(smallest, gap)
	end
	local cars = Config.Cars
	-- About the train's length: the locomotive (cowcatcher to soles, about 17) and its cars; the real value is a model attribute.
	local length = 17 + cars.Count * (cars.Length + cars.Gap)
	-- The run distance is measured at the train's middle: a restart RestartLead before a bridge puts the train's back
	-- past the bridge before (smallest gap), and leaves its front a fair way from the bridge (time to react).
	check("a restart starts after the bridge before", R.RestartLead < smallest - B.Depth / 2 - length / 2)
	check("a restart leaves over a second before the front meets the bridge", (R.RestartLead - B.Depth / 2 - length / 2) / R.Speed >= 1.2,
		tostring((R.RestartLead - B.Depth / 2 - length / 2) / R.Speed))
	check("the time under a bridge is longer than the delay allowance", (B.Depth + length) / R.Speed > R.PassTolerance * 2)
end

-- 9. Who drives and who rides.
do
	local book = CrewBook.new(2)
	local s1, r1 = book:join("A", false)
	local s2, r2 = book:join("B", false)
	local s3, r3 = book:join("C", false)
	check("the first player drives, the next rides that train", s1 == 1 and r1 == "driver" and s2 == 1 and r2 == "cowboy")
	check("the third drives the next train", s3 == 2 and r3 == "driver")
	local slot, change, promoted = book:leave("A")
	check("a driver leaving hands the train to the cowboy", slot == 1 and change == "promoted" and promoted == "B" and select(2, book:find("B")) == "driver")
	local _, gone = book:leave("C")
	check("a driver alone leaving frees the track", gone == "freed" and book:crew(2) == nil)
	local s4, r4 = book:join("D", false)
	check("a new player rides a train that has no cowboy", s4 == 1 and r4 == "cowboy")
	local _, left = book:leave("D")
	check("a cowboy leaving leaves the train without one", left == "nocowboy" and book:crew(1).cowboy == nil)
	local solo = CrewBook.new(1)
	local ss, sr = solo:join("E", true)
	check("a lone tester rides a train with the stand-in driver", ss == 1 and sr == "cowboy" and solo:crew(1).bot == true)
	local ts, tr, took = solo:join("F", false)
	check("the next player takes over from the stand-in driver", ts == 1 and tr == "driver" and took == true and solo:crew(1).bot == false)
	local again, againRole = solo:join("F", false)
	check("joining twice changes nothing", again == 1 and againRole == "driver" and solo:crew(1).cowboy == "E")
	local full = solo:join("G", false)
	check("no track left: no slot", full == nil)
	local botBook = CrewBook.new(1)
	botBook:join("H", true)
	local _, botGone = botBook:leave("H")
	check("the stand-in driver's train goes with its cowboy", botGone == "freed" and botBook:crew(1) == nil)
end

-- 10. The mail bags.
do
	local B, M, C = Config.Bridge, Config.Mail, Config.Cars
	local d1, s1 = CourseMath.mailAt(1, B.FirstAt, B.Gaps)
	local d2, s2 = CourseMath.mailAt(2, B.FirstAt, B.Gaps)
	check("a crane stands halfway between two bridges", d1 == (CourseMath.bridgeAt(1, B.FirstAt, B.Gaps) + CourseMath.bridgeAt(2, B.FirstAt, B.Gaps)) / 2)
	check("cranes take the right and left side in turn", s1 == 1 and s2 == -1 and d2 > d1)
	-- A standing cowboy's middle (upper torso) is about 3.3 above the roof floor; reach is measured from there.
	local floorTop = C.RoofTop + C.WalkThickness
	local torsoY = floorTop + 3.3
	local function reachFrom(x: number): number
		return math.sqrt((M.BagX - x) ^ 2 + (M.BagY - torsoY) ^ 2)
	end
	local roofEdge = C.Width / 2 + C.RoofOverhang
	check("from the middle of the roof the bag is out of reach", reachFrom(0) > M.Reach, tostring(reachFrom(0)))
	check("from the walkway's edge the bag is out of reach", reachFrom(C.WalkWidth / 2) > M.Reach, tostring(reachFrom(C.WalkWidth / 2)))
	check("near that edge of the roof the bag is in reach", reachFrom(roofEdge - 0.4) <= M.Reach, tostring(reachFrom(roofEdge - 0.4)))
	local lyingY = floorTop * c.HeightAtFull + 0.7
	check("lying flat on a flat roof the bag is out of reach", math.abs(M.BagY - lyingY) > M.Reach)
	-- The flattened locomotive is widest at the fists (about 3.6 out, x1.3 when flat).
	local flatFists = 3.6 * c.WidthAtFull
	check("the crane's post stands clear of the flattened train", M.PostX - M.PostThickness / 2 > flatFists + 0.2 and M.PostX > roofEdge * c.WidthAtFull + 1)
end

-- 11. The barrels.
do
	local B, K, C, M = Config.Bridge, Config.Barrels, Config.Cars, Config.Mail
	local drop1, lane1 = CourseMath.barrelAt(1, B.FirstAt, B.Gaps, K.At)
	local crane1, side1 = CourseMath.mailAt(1, B.FirstAt, B.Gaps)
	local _, lane2 = CourseMath.barrelAt(2, B.FirstAt, B.Gaps, K.At)
	check("a barrel drops after the crane and before the next bridge", drop1 > crane1 and drop1 < CourseMath.bridgeAt(2, B.FirstAt, B.Gaps))
	check("a barrel rolls in the lane on its gap's crane side, lanes alternate", lane1 == side1 and lane2 == -lane1)
	check("no barrel before its drop", CourseMath.barrelZ(100, 99, 0, 0.4) == nil and CourseMath.barrelZ(100, 110, 1, 0.5) == 6)
	local ratio = K.RollSpeed / Config.Run.Speed
	check("a barrel is on the roofs just after its drop", #CourseMath.activeBarrels(drop1 + 1, B.FirstAt, B.Gaps, K.At, -2, 20, ratio) == 1)
	check("and gone once it has rolled past the back", #CourseMath.activeBarrels(drop1 + 22 / ratio + 1, B.FirstAt, B.Gaps, K.At, -2, 20, ratio) == 0)
	check("no barrels before the first drop", #CourseMath.activeBarrels(drop1 - 1, B.FirstAt, B.Gaps, K.At, -2, 20, ratio) == 0)
	local roofHalf = C.Width / 2 + C.RoofOverhang
	check("a barrel stays on the roof", K.LaneX + K.Length / 2 <= roofHalf)
	check("the walkway's middle is clear of both lanes", K.LaneX - (K.Length / 2 + K.HitAcross) >= 0.15)
	local flatRoof = (C.RoofTop + C.WalkThickness) * c.HeightAtFull
	check("a barrel on a flat roof fits under a bridge", flatRoof + K.Radius * 2 < B.Clearance)
	check("the water tower stands outside the mail cranes", K.TowerX - 1.4 > M.PostX + M.PostThickness)
	check("the spout passes over a tall standing cowboy's head", K.SpoutHeight - 0.2 > C.RoofTop + C.WalkThickness + 6)
	-- the biggest rock reaches about 1.9 from its middle (size 2.1, turned)
	check("the roadside props stand outside the water towers", Config.Stage.RoadsideNear - 2 > K.TowerX + 1.6)
end

-- 12. The jump and the gold mail.
do
	local J, G, B, C, M, R = Config.Jump, Config.GoldMail, Config.Bridge, Config.Cars, Config.Mail, Config.Run
	check("no lift without a jump, before it or after it", JumpArc.lift(nil, 5, J.Seconds, J.Height) == 0
		and JumpArc.lift(10, 9.9, J.Seconds, J.Height) == 0 and JumpArc.lift(10, 10 + J.Seconds, J.Seconds, J.Height) == 0)
	check("the arc tops out at the jump height halfway", near(JumpArc.lift(10, 10 + J.Seconds / 2, J.Seconds, J.Height), J.Height))
	check("in the air only during the jump", JumpArc.airborne(10, 10, J.Seconds) and JumpArc.airborne(10, 10 + J.Seconds * 0.99, J.Seconds)
		and not JumpArc.airborne(10, 10 + J.Seconds, J.Seconds) and not JumpArc.airborne(nil, 10, J.Seconds))
	local gold1, side1 = CourseMath.goldAt(1, B.FirstAt, B.Gaps, G.At, G.Every)
	local gold2 = CourseMath.goldAt(2, B.FirstAt, B.Gaps, G.At, G.Every)
	local _, mailSide1 = CourseMath.mailAt(1, B.FirstAt, B.Gaps)
	local bridge1, bridge2 = CourseMath.bridgeAt(1, B.FirstAt, B.Gaps), CourseMath.bridgeAt(2, B.FirstAt, B.Gaps)
	check("gold 1 hangs in gap 1 before its mail crane", near(gold1, bridge1 + (bridge2 - bridge1) * G.At) and gold1 < (CourseMath.mailAt(1, B.FirstAt, B.Gaps)))
	check("the gold crane stands away from that gap's mail crane", side1 == -mailSide1)
	check("gold 2 hangs in gap 1 + Every", gold2 > CourseMath.bridgeAt(1 + G.Every, B.FirstAt, B.Gaps) and gold2 < CourseMath.bridgeAt(2 + G.Every, B.FirstAt, B.Gaps))
	check("the jump point brings the bag over the cars after the lead", CourseMath.jumpFrom(100, 8, 12) == 96)
	-- A train as built in Studio (2026-10-24): front -19.1, back 19.1, the first car's roof from -2.0.
	local front, back, roofFront = -19.1, 19.1, -2.0
	local leadStuds = (J.Seconds / 2 + G.RiseSeconds) * R.Speed
	local springStuds = 6 -- the body is back up this long after the stand-in driver lets go
	for k = 1, #B.Gaps do
		local gold = CourseMath.goldAt(k, B.FirstAt, B.Gaps, G.At, G.Every)
		local i = (k - 1) * G.Every + 1
		local from = CourseMath.jumpFrom(gold, (roofFront + back) / 2, leadStuds)
		local upAgain = CourseMath.bridgeAt(i, B.FirstAt, B.Gaps) + B.Depth / 2 + back + Config.Bot.TrailStuds + springStuds
		local flatAgain = CourseMath.bridgeAt(i + 1, B.FirstAt, B.Gaps) - B.Depth / 2 + front - Config.Bot.LeadStuds
		check("gold " .. k .. ": the jump starts once the train is up after the bridge", from >= upAgain, string.format("%.1f < %.1f", from, upAgain))
		check("gold " .. k .. ": and lands before the next bridge needs it flat", from + J.Seconds * R.Speed <= flatAgain)
	end
	-- Reaching the bag: a cowboy's upper torso is about 3.55 over the feet (R15) and a jump rises 7.2 (Roblox default).
	local roofTop = C.RoofTop + C.WalkThickness
	local topOfJump = roofTop + 7.2 + 3.55
	check("a jump from a standing roof falls short of the gold", topOfJump + G.Reach < G.BagY)
	check("a jump from the top of the arc reaches it", math.abs(topOfJump + J.Height - G.BagY) <= G.Reach * 0.6)
	check("the gold crane's arm is over a cowboy's head at the best jump", G.BagY + G.BagSize.Y / 2 + G.ArmAboveBag - G.ArmThickness / 2 > roofTop + J.Height + 7.2 + 5.3)
	check("the gold crane's post stands where the mail crane's would", G.PostX >= M.PostX)
	check("the rise time is a default jump's", math.abs(G.RiseSeconds - math.sqrt(2 * 7.2 / 196.2)) < 0.01)
end

-- 13. The paper gag after a bridge splat.
do
	local P, S = Config.Paper, Config.Cowboy.SplatSeconds
	local function thick(t: number): number
		return PaperPath.thickness(t, S, P)
	end
	check("as thick as ever before the splat and after the pop", thick(-0.1) == 1 and near(thick(S + P.PopSeconds), 1, 1e-6) and thick(S + 5) == 1)
	check("paper-thin right after the splat until back on the train", near(thick(P.InSeconds), P.Thickness) and near(thick(S - 0.01), P.Thickness))
	check("flattening and the pop start where the last part ended", near(thick(P.InSeconds - 1e-6), P.Thickness, 1e-4) and near(thick(S), P.Thickness))
	check("puffs past their own thickness in the pop", near(thick(S + P.PopSeconds / 2), P.PopThickness, 1e-6))
	local speed = Config.Run.Speed
	local x, y, z, yaw, tilt = PaperPath.at(P.StuckSeconds / 2, speed, P)
	check("stuck on the girder: carried back with it, not falling or turning", x == 0 and y == 0 and near(z, speed * P.StuckSeconds / 2) and yaw == 0 and tilt == 0)
	local x1, y1, z1, yaw1 = PaperPath.at(P.StuckSeconds + 1e-6, speed, P)
	check("peeling off where the girder left it", near(x1, 0, 1e-4) and near(y1, 0, 1e-4) and near(z1, speed * P.StuckSeconds, 1e-4) and near(yaw1, 0, 1e-4))
	local lowest, widest, lastZ, backward, turned = 0, 0, z1, true, 0
	for i = 1, 40 do
		local t = P.StuckSeconds + (S - P.StuckSeconds) * i / 40
		local px, py, pz, pyaw = PaperPath.at(t, speed, P)
		lowest = math.min(lowest, py)
		widest = math.max(widest, math.abs(px))
		backward = backward and pz >= lastZ and pz - lastZ < speed * (S - P.StuckSeconds) / 40
		lastZ = pz
		turned = pyaw
	end
	check("flutters down slowly, swaying within its sway", lowest < 0 and widest <= P.SwayStuds + 1e-9)
	check("drifts back slower than the bridges go", backward)
	check("turns enough to show its thin edge", turned >= math.pi / 2)
	local standingRoot = Config.Cars.RoofTop + Config.Cars.WalkThickness + 3
	check("does not fall into the sand before it goes back", standingRoot - P.FallSpeed * (S - P.StuckSeconds) > 1)
end

print(string.format("%d passed, %d failed", passed, failed))
if failed == 0 then
	print("ALL PASS")
end
