--!strict
-- Hold-to-block as pure rules (decision 11's "누르고 버티는 막기", persona fix 4; the numbers come in from
-- Config.Block): whether an attack meets the block (from the front, and not a weapon that always launches), what it
-- does then - a light hit is softened, the string's launching third breaks the guard instead of launching - and why
-- one went through a block. Requires nothing.

local BlockRules = {}

export type Rules = { Arc: number, Damage: number, Push: number, BreakDamage: number }

-- Whether an attack from (fx, fz) meets a blocker standing at (x, z) and facing along (lx, lz) from the front: within
-- `arc` degrees either side of its facing (an attack from right on top of it counts as from the front).
function BlockRules.covers(x: number, z: number, lx: number, lz: number, fx: number, fz: number, arc: number): boolean
	local dx, dz = fx - x, fz - z
	local away = math.sqrt(dx * dx + dz * dz)
	local look = math.sqrt(lx * lx + lz * lz)
	if away < 1e-3 or look < 1e-3 then
		return true
	end
	local cosine = (dx * lx + dz * lz) / (away * look)
	return cosine >= math.cos(math.rad(arc)) - 1e-9
end

-- Whether a weapon's hit can be blocked at all: one that always launches (a hammer's slam, a dynamite blast, a wheel,
-- an oil slick) breaks through.
function BlockRules.blockable(alwaysLaunches: boolean?): boolean
	return alwaysLaunches ~= true
end

-- What a hit that meets the block does: the share of its damage and of its push that land, and whether it breaks the
-- guard (the string's launching third: no launch, a light hit's full push).
function BlockRules.outcome(launches: boolean, rules: Rules): (number, number, boolean)
	if launches then
		return rules.BreakDamage, 1, true
	end
	return rules.Damage, rules.Push, false
end

-- Why an attack from (fx, fz) went through the block of a fighter standing at (x, z) facing (lx, lz) (2026-10-31: a
-- tester could not tell a late block from one hit from the side): "weapon" (one that always launches), "back"
-- (from behind: more than 135 degrees off its facing), "side" (outside `arc`), or nil when the block covered it (it went
-- through as a crowd's launch or a hit that emptied health).
function BlockRules.through(blockable: boolean, x: number, z: number, lx: number, lz: number, fx: number, fz: number, arc: number): string?
	if not blockable then
		return "weapon"
	end
	if BlockRules.covers(x, z, lx, lz, fx, fz, arc) then
		return nil
	end
	return if BlockRules.covers(x, z, lx, lz, fx, fz, 135) then "side" else "back"
end

return BlockRules
