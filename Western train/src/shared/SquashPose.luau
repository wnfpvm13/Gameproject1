--!strict
-- Where a locomotive part goes and how big it gets for a squash value. Pure math on plain numbers (no CFrame or
-- Vector3), so the luau CLI tests run it unchanged; LocomotiveAnimator turns the numbers into CFrame/Vector3.
-- Locomotive space: X right, Y up, Z back (forward is -Z), origin on the rails under the middle. Requires nothing.

local SquashPose = {}

export type Vec = { x: number, y: number, z: number }

export type Rest = {
	position: Vec, -- part centre in locomotive space
	anchor: Vec, -- the point that rides on the body (usually the centre; the chimney uses its bottom)
	size: Vec, -- part size along its own axes
	axes: { Vec }, -- the part's own X, Y and Z axes written in locomotive space (unit vectors)
	exponent: number, -- extra height squash for this part between its anchor and its centre (1 = same as the body)
}

-- Body scale for a squash value: 1 is fully flat and wide, negative values (the bounce) are tall and thin.
function SquashPose.bodyScale(s: number, heightAtFull: number, widthAtFull: number, lengthAtFull: number): Vec
	return {
		x = math.max(0.05, 1 + (widthAtFull - 1) * s),
		y = math.max(0.05, 1 + (heightAtFull - 1) * s),
		z = math.max(0.05, 1 + (lengthAtFull - 1) * s),
	}
end

local function scaled(v: Vec, s: Vec): Vec
	return { x = v.x * s.x, y = v.y * s.y, z = v.z * s.z }
end

local function stretchOf(axis: Vec, s: Vec): number
	-- length of the part's own axis after the locomotive-space scale (exact for parts turned by right angles)
	return math.sqrt((axis.x * s.x) ^ 2 + (axis.y * s.y) ^ 2 + (axis.z * s.z) ^ 2)
end

-- New centre (locomotive space) and new size (own axes) of a part for the body scale.
function SquashPose.pose(rest: Rest, body: Vec): (Vec, Vec)
	local own = { x = body.x, y = body.y ^ rest.exponent, z = body.z }
	local anchor = scaled(rest.anchor, body)
	local offset = scaled({
		x = rest.position.x - rest.anchor.x,
		y = rest.position.y - rest.anchor.y,
		z = rest.position.z - rest.anchor.z,
	}, own)
	local position = { x = anchor.x + offset.x, y = anchor.y + offset.y, z = anchor.z + offset.z }
	local size = {
		x = rest.size.x * stretchOf(rest.axes[1], own),
		y = rest.size.y * stretchOf(rest.axes[2], own),
		z = rest.size.z * stretchOf(rest.axes[3], own),
	}
	return position, size
end

-- Limits for kickAngle: radians per unit of spring speed, the largest upward and downward swing, and the body height
-- scale at which the body is fully flat (no room left to swing down).
export type KickLimits = { gain: number, up: number, down: number, flatHeight: number }

-- Swing (radians about the locomotive's X axis; positive turns a leg pointing backward downward) of a leg that hangs
-- off the body, for the spring's speed and the body's height scale. The legs lag behind the body, so they kick when
-- it folds and flap while it bounces; side is 1 or -1, so the two legs go opposite ways. The downward limit shrinks
-- as the body folds, so a low hip never swings the shoes into the rails.
function SquashPose.kickAngle(velocity: number, side: number, bodyY: number, limits: KickLimits): number
	local room = math.clamp((bodyY - limits.flatHeight) / (1 - limits.flatHeight), 0, 1)
	return math.clamp(side * velocity * limits.gain, -limits.up, limits.down * room)
end

return SquashPose
