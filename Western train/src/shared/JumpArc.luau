--!strict
-- The locomotive's jump as pure math: the whole train rises and falls on a parabola. Times are server times; `at` is
-- the jump's start (nil = no jump yet). Requires nothing.

local JumpArc = {}

-- How high the train is lifted at time `now` by a jump started at `at` that lasts `seconds` and tops out at `height`
-- (0 before and after it).
function JumpArc.lift(at: number?, now: number, seconds: number, height: number): number
	if not at then
		return 0
	end
	local t = (now - at) / seconds
	if t <= 0 or t >= 1 then
		return 0
	end
	return 4 * height * t * (1 - t)
end

-- Whether a jump started at `at` that lasts `seconds` is still in the air at time `now`.
function JumpArc.airborne(at: number?, now: number, seconds: number): boolean
	return at ~= nil and now >= at and now < at + seconds
end

return JumpArc
