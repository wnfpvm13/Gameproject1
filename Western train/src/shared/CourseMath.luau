--!strict
-- The run toward the low bridges: how far the world has moved past the locomotive, where each bridge is and when it
-- is over the locomotive, and the server's check of a pass. Pure math on plain numbers (no Roblox API), so the luau
-- CLI tests run it unchanged. Requires nothing.
-- The locomotive stands still; the run distance grows as the world moves back past it. A bridge at course distance b
-- is (b - distance) studs ahead of the locomotive's base (ahead = -Z in locomotive space).

local CourseMath = {}

-- start: server time the run (re)started moving; from: the distance at that time; speed: studs per second (0 = held).
export type Run = { start: number, from: number, speed: number }
-- The squash state as the server received it, oldest first.
export type Change = { time: number, squashed: boolean }

-- Run distance at server time `now` (before `start` the run waits at `from`).
function CourseMath.distance(run: Run, now: number): number
	return run.from + math.max(0, now - run.start) * run.speed
end

-- Server time the run reaches `distance` (math.huge when it is held).
function CourseMath.timeAt(run: Run, distance: number): number
	if run.speed <= 0 then
		return math.huge
	end
	return run.start + (distance - run.from) / run.speed
end

-- Course distance of bridge i (1, 2, ...): the first at firstAt, then the gaps between bridges, repeating.
function CourseMath.bridgeAt(i: number, firstAt: number, gaps: { number }): number
	local cycle = 0
	for _, gap in gaps do
		cycle += gap
	end
	local steps = i - 1
	local d = firstAt + math.floor(steps / #gaps) * cycle
	for k = 1, steps % #gaps do
		d += gaps[k]
	end
	return d
end

-- Mail crane i: halfway between bridge i and the next one, on the right (1) for odd i and the left (-1) for even i.
-- Returns its course distance and side.
function CourseMath.mailAt(i: number, firstAt: number, gaps: { number }): (number, number)
	local here = CourseMath.bridgeAt(i, firstAt, gaps)
	local after = CourseMath.bridgeAt(i + 1, firstAt, gaps)
	return (here + after) / 2, if i % 2 == 1 then 1 else -1
end

-- Barrel i: dropped at `share` of the way from bridge i to the next, after crane i and in the lane on its side (right,
-- 1, for odd i): a cowboy who has just picked up that bag at the roof's edge must get out of the way. Returns its drop
-- distance and lane.
function CourseMath.barrelAt(i: number, firstAt: number, gaps: { number }, share: number): (number, number)
	local here = CourseMath.bridgeAt(i, firstAt, gaps)
	local after = CourseMath.bridgeAt(i + 1, firstAt, gaps)
	return here + (after - here) * share, if i % 2 == 1 then 1 else -1
end

-- Where a barrel dropped at run distance `drop` is along the train at run distance `distance` (train space Z, back is
-- +): it lands at `startZ` and rolls back `ratio` studs per stud of run. nil before it drops.
function CourseMath.barrelZ(drop: number, distance: number, startZ: number, ratio: number): number?
	if distance < drop then
		return nil
	end
	return startZ + (distance - drop) * ratio
end

export type Barrel = { index: number, lane: number, drop: number, z: number }

-- The barrels on the roofs at run distance `distance`: dropped already and not yet rolled past `endZ` (the train's
-- back). `startZ`, `ratio` and `share` as for barrelZ/barrelAt.
function CourseMath.activeBarrels(distance: number, firstAt: number, gaps: { number }, share: number, startZ: number, endZ: number, ratio: number): { Barrel }
	local rolling = (endZ - startZ) / ratio -- run distance a barrel stays on the roofs
	local found = {}
	local i = math.max(1, CourseMath.nextBridge(distance - rolling, firstAt, gaps, 0, 0) - 1)
	while true do
		local drop, lane = CourseMath.barrelAt(i, firstAt, gaps, share)
		if drop > distance then
			break
		end
		local z = CourseMath.barrelZ(drop, distance, startZ, ratio)
		if z and z <= endZ then
			table.insert(found, { index = i, lane = lane, drop = drop, z = z })
		end
		i += 1
	end
	return found
end

-- The run distances while bridge b covers any part of the locomotive: from when the bridge's near face meets the
-- locomotive's front until its far face passes the locomotive's back. front and back are the locomotive's ends in
-- its own Z (front < 0 < back), depth is the bridge's length along the track.
function CourseMath.under(b: number, depth: number, front: number, back: number): (number, number)
	return b - depth / 2 + front, b + depth / 2 + back
end

-- The first bridge that has not yet fully passed a locomotive at this distance. Whole cycles of gaps are skipped at
-- once, so the cost stays small however long the run gets.
function CourseMath.nextBridge(distance: number, firstAt: number, gaps: { number }, depth: number, back: number): number
	local passedBefore = distance - depth / 2 - back -- a bridge has fully passed once it is before this
	local cycle = 0
	for _, gap in gaps do
		cycle += gap
	end
	local i = math.max(0, math.floor((passedBefore - firstAt) / cycle)) * #gaps + 1
	while CourseMath.bridgeAt(i, firstAt, gaps) < passedBefore do
		i += 1
	end
	return i
end

-- True when the history says squashed from `from` up to just before `to` (a change exactly at `to` does not count;
-- an empty window counts as true).
function CourseMath.squashedThroughout(history: { Change }, from: number, to: number): boolean
	if to <= from then
		return true
	end
	local squashed = false
	local i = 1
	while history[i] and history[i].time <= from do
		squashed = history[i].squashed
		i += 1
	end
	if not squashed then
		return false
	end
	while history[i] and history[i].time < to do
		if not history[i].squashed then
			return false
		end
		i += 1
	end
	return true
end

return CourseMath
