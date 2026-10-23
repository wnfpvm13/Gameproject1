--!strict
-- Where a coupling rod or crank pin is on its circle around the driving wheel centres. Pure math on plain numbers
-- (no Roblox API), so the luau CLI tests run it unchanged. Requires nothing.
-- Locomotive space: Y up, Z back (forward is -Z). Angle 0 is the top of the circle; growing angles turn the wheels so
-- their tops move forward, as when the train runs.

local CrankMotion = {}

-- A part that circles: its radius (studs at rest) and phase (radians, added to the shared crank angle).
export type Crank = { radius: number, phase: number }

local TURN = 2 * math.pi

-- The crank of one side of the engine (sign 1 = right, -1 = left): the left side runs a quarter turn ahead.
function CrankMotion.forSide(sign: number, radius: number): Crank
	return { radius = radius, phase = if sign == 1 then 0 else math.pi / 2 }
end

-- The crank angle after dt seconds, kept within one turn.
function CrankMotion.advance(angle: number, dt: number, turnsPerSecond: number): number
	return (angle + math.max(0, dt) * turnsPerSecond * TURN) % TURN
end

-- Offset (Y, Z) from the rest position for the crank angle plus this part's phase. bodyY and bodyZ are the squash
-- scale's height and length, so the circle squashes with the wheels.
function CrankMotion.offset(angle: number, phase: number, radius: number, bodyY: number, bodyZ: number): (number, number)
	local a = angle + phase
	return radius * math.cos(a) * bodyY, -radius * math.sin(a) * bodyZ
end

return CrankMotion
