--!strict
-- A back car coming off its train, as pure rules (persona fix 6; B's "칸 떨어져 나가기" brought forward, numbers from
-- Config.Uncouple): which car goes next, which planks it takes along, and where it is `t` seconds after it lets go -
-- easing back first (the gap to the car ahead opening slowly, time to jump across), then dropping away behind the
-- train fast and low. Requires nothing.

local Uncouple = {}

export type Rules = { DriftSeconds: number, DriftSpeed: number, FallSeconds: number, FallSpeed: number, Sink: number }

-- How far back (along +Z, the way the ground runs) and how far down the car is `t` seconds after it let go, and how
-- fast it moves back and down then.
function Uncouple.motion(t: number, rules: Rules): (number, number, number, number)
	local d, vd = rules.DriftSeconds, rules.DriftSpeed
	local f, vf = rules.FallSeconds, rules.FallSpeed
	if t <= 0 then
		return 0, 0, 0, 0
	elseif t <= d then
		local a = vd / d
		return 0.5 * a * t * t, 0, a * t, 0
	end
	local s = math.min(t - d, f)
	local back = 0.5 * vd * d + vd * s + 0.5 * (vf - vd) / f * s * s
	local down = rules.Sink * (s / f) ^ 2
	return back, down, vd + (vf - vd) * s / f, 2 * rules.Sink * s / (f * f)
end

-- Whether it has gone for good (past the drop).
function Uncouple.over(t: number, rules: Rules): boolean
	return t > rules.DriftSeconds + rules.FallSeconds
end

-- Which train's car goes next: of `left` (each train's count of cars still on), a train with more than `keep`, picked
-- with `random` (a number in [0, 1)); nil when none has. Its car to go is its last one on (number `left[train]`).
function Uncouple.pick(left: { number }, keep: number, random: () -> number): number?
	local able = {}
	for train, count in left do
		if count > keep then
			table.insert(able, train)
		end
	end
	if #able == 0 then
		return nil
	end
	return able[math.clamp(math.floor(random() * #able) + 1, 1, #able)]
end

-- The planks a car coming off takes along: of `numbers` (the planks resting on it), those no car took this fight yet,
-- marked taken in `taken`. A plank between two trains rests on a car of each: whichever comes off first takes it, and
-- the other leaves it be (it has gone, and a second taker would remember its sunk place as home and put it back there).
function Uncouple.claim(numbers: { number }, taken: { [number]: boolean }): { number }
	local mine = {}
	for _, number in numbers do
		if not taken[number] then
			taken[number] = true
			table.insert(mine, number)
		end
	end
	return mine
end

return Uncouple
