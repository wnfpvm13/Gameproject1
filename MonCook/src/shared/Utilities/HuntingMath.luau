--!strict
-- No Roblox globals: geometry is shared by authoritative services and tests.
export type Point = { X: number, Y: number, Z: number }
local Math = {}
function Math.finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function Math.point(value: any): boolean
	return type(value) == "table" and Math.finite(value.X) and Math.finite(value.Y) and Math.finite(value.Z)
end
function Math.copy(p: Point): Point return { X = p.X, Y = p.Y, Z = p.Z } end
function Math.add(a: Point, b: Point): Point return { X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z } end
function Math.distance(a: Point, b: Point): number
	return math.sqrt((a.X - b.X)^2 + (a.Z - b.Z)^2)
end
function Math.direction(a: Point, b: Point, fallback: Point?): Point
	local x, z = b.X - a.X, b.Z - a.Z
	local length = math.sqrt(x*x + z*z)
	if length < 0.000001 then return Math.copy(fallback or { X = 0, Y = 0, Z = -1 }) end
	return { X = x/length, Y = 0, Z = z/length }
end
function Math.advance(p: Point, direction: Point, distance: number): Point
	return { X = p.X + direction.X*distance, Y = p.Y, Z = p.Z + direction.Z*distance }
end
function Math.dot(a: Point, b: Point): number return a.X*b.X + a.Z*b.Z end
function Math.correctFacing(original: Point, hint: Point?, degrees: number): Point
	local facing = Math.direction({ X = 0, Y = 0, Z = 0 }, original)
	if not hint or not Math.point(hint) or hint.X^2 + hint.Z^2 < 0.000001 then return facing end
	local candidate = Math.direction({ X = 0, Y = 0, Z = 0 }, hint)
	if Math.dot(facing, candidate) >= math.cos(math.rad(degrees)) then return candidate end
	return facing
end
function Math.inArc(origin: Point, facing: Point, target: Point, range: number, degrees: number, vertical: number): boolean
	if math.abs(origin.Y - target.Y) > vertical or Math.distance(origin, target) > range+0.000001 then return false end
	if Math.distance(origin, target) < 0.000001 then return true end
	-- Clipped sector-edge contacts can round one ulp outside the angle/radius.
	return Math.dot(facing, Math.direction(origin, target)) >= math.cos(math.rad(degrees/2))-0.000001
end
function Math.turnToward(original: Point, target: Point, maximum: number): Point
	local dot = math.clamp(Math.dot(original, target), -1, 1)
	local angle = math.acos(dot)
	if angle <= math.rad(maximum) then return Math.copy(target) end
	local sign = if original.X*target.Z-original.Z*target.X >= 0 then 1 else -1
	local turn = math.rad(maximum)*sign
	return { X = original.X*math.cos(turn)-original.Z*math.sin(turn), Y = 0,
		Z = original.X*math.sin(turn)+original.Z*math.cos(turn) }
end
function Math.segmentDistance(point: Point, start: Point, finish: Point): number
	local x, z = finish.X - start.X, finish.Z - start.Z
	local denominator = x*x + z*z
	local t = if denominator > 0 then math.clamp(((point.X-start.X)*x + (point.Z-start.Z)*z)/denominator, 0, 1) else 0
	return Math.distance(point, { X = start.X+x*t, Y = point.Y, Z = start.Z+z*t })
end
function Math.offset(origin: Point, facing: Point, localOffset: Point): Point
	-- Local -Z is forward; local +X is right, matching Roblox CFrame.
	return { X = origin.X - facing.Z*localOffset.X - facing.X*localOffset.Z,
		Y = origin.Y + localOffset.Y, Z = origin.Z + facing.X*localOffset.X - facing.Z*localOffset.Z }
end
return table.freeze(Math)
