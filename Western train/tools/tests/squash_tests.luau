-- Squash math tests (run by tools/tests/run_tests.py, which puts Config, SquashSpring, SquashPose and CrankMotion
-- above this).
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

print(string.format("%d passed, %d failed", passed, failed))
if failed == 0 then
	print("ALL PASS")
end
