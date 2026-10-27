--!strict
-- Where a practice bot walks and whom it goes for, as pure math over the arena's walkable tops (ArenaLayout): the
-- nearest other fighter on the same top (no more than a few bots on one, so they do not all crowd one fighter), the
-- spot just short of that fighter to punch from, and a spot to wander to. Every spot stays a margin inside its top, so
-- a bot never walks off an edge by itself. Requires nothing.

local BotPlan = {}

-- A top's footprint (an ArenaLayout.Surface has these): its middle and its size across (x) and along (z).
export type Top = { x: number, z: number, width: number, length: number }
-- A fighter as the plan sees it: who (`key`), where it stands and the top under it (nil: none).
export type Seen = { key: any, x: number, z: number, top: Top? }

-- (x, z) kept `margin` inside `top`'s edges (its middle line when it is narrower than two margins).
local function inside(top: Top, x: number, z: number, margin: number): (number, number)
	local halfWidth = math.max(top.width / 2 - margin, 0)
	local halfLength = math.max(top.length / 2 - margin, 0)
	return math.clamp(x, top.x - halfWidth, top.x + halfWidth), math.clamp(z, top.z - halfLength, top.z + halfLength)
end

-- Of `others`, the nearest to (x, z) standing on `top` (the same top table), leaving out any that `most` bots already
-- go for (`taken[key]`); nil when there is none.
function BotPlan.nearest(x: number, z: number, top: Top, others: { Seen }, taken: { [any]: number }, most: number): Seen?
	local best: Seen? = nil
	local bestDistance = math.huge
	for _, other in others do
		if other.top == top and (taken[other.key] or 0) < most then
			local distance = (other.x - x) ^ 2 + (other.z - z) ^ 2
			if distance < bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

-- The spot `standOff` short of a target at (tx, tz), on the side of it the bot at (x, z) comes from, kept `margin`
-- inside `top`.
function BotPlan.standSpot(top: Top, x: number, z: number, tx: number, tz: number, standOff: number, margin: number): (number, number)
	local dx, dz = x - tx, z - tz
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-3 then
		dx, dz, length = 0, 1, 1 -- right on top of it: step back along the track
	end
	return inside(top, tx + dx / length * standOff, tz + dz / length * standOff, margin)
end

-- A spot to wander to on `top` from `z` along it: anywhere across it, up to `reach` along it, `margin` inside. `random`
-- gives numbers in [0, 1).
function BotPlan.wanderSpot(top: Top, z: number, reach: number, margin: number, random: () -> number): (number, number)
	local across = top.x + (random() * 2 - 1) * top.width / 2
	local along = z + (random() * 2 - 1) * reach
	return inside(top, across, along, margin)
end

return BotPlan
