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
