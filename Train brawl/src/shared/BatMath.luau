--!strict
-- Attacks as pure math: whether a target stands in the cone a punch or swing covers, and the knock it gets. Positions and
-- directions are plain numbers (X and Z along the ground, Y up). Requires nothing.

local BatMath = {}

-- Whether a target at (tx, ty, tz) is hit by a swing from (sx, sy, sz) facing (fx, fz): within `reach` along the
-- ground, within `heightReach` up or down, and within `halfAngle` degrees of the facing.
function BatMath.inCone(sx: number, sy: number, sz: number, fx: number, fz: number, tx: number, ty: number, tz: number, reach: number, heightReach: number, halfAngle: number): boolean
	local dx, dz = tx - sx, tz - sz
	local along = math.sqrt(dx * dx + dz * dz)
	if along > reach or math.abs(ty - sy) > heightReach then
		return false
	end
	if along < 1e-3 then
		return true -- standing on top of each other: hit
	end
	local facing = math.sqrt(fx * fx + fz * fz)
	if facing < 1e-3 then
		return true
	end
	local cos = (dx * fx + dz * fz) / (along * facing)
	return cos >= math.cos(math.rad(halfAngle))
end

-- The knock a target gets: `push` along the ground away from the swinger (or along the facing when they stand on
-- top of each other) and `lift` upward. Returns the velocity x, y, z.
function BatMath.knock(sx: number, sz: number, fx: number, fz: number, tx: number, tz: number, push: number, lift: number): (number, number, number)
	local dx, dz = tx - sx, tz - sz
	local along = math.sqrt(dx * dx + dz * dz)
	if along < 1e-3 then
		dx, dz = fx, fz
		along = math.sqrt(dx * dx + dz * dz)
		if along < 1e-3 then
			return 0, lift, 0
		end
	end
	return dx / along * push, lift, dz / along * push
end

-- How far a knock carries along the ground before coming back down to the height it started at (under `gravity`).
function BatMath.flightDistance(push: number, lift: number, gravity: number): number
	return push * 2 * lift / gravity
end

return BatMath
