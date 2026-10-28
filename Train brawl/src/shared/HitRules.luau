--!strict
-- What a hit does to a fighter, as pure rules (Smash Legends-style; the numbers come in from Config.Health and
-- Config.Hit). Health drops by the hit's damage (each weapon's own), and the hit that empties it is a smash (a certain
-- ring-out). Otherwise a hit launches (flying, lying down) when the attacker says so - the last step of the
-- attacker's string (AttackString) or a weapon that always launches (a hammer, a dynamite blast) - or when it makes
-- `gang` hits within the last `window` seconds and those hits came from two or more attackers (a crowd cannot keep
-- one fighter flinching); any other hit is light (a flinch). Right after a launch the fighter cannot be hit for `immune`
-- seconds. How hard a hit pushes grows as health drops (force, scale). Requires nothing.

local HitRules = {}

export type Kind = string -- "none" | "light" | "launch" | "smash"
-- recent: the hits of the last `window` seconds (when, and by whom: any value an attacker is told apart by).
export type State = { health: number, recent: { { at: number, by: unknown } }, immuneUntil: number }
export type Rules = { max: number, window: number, gang: number, immune: number }
-- The pushes (along the ground) and lifts of Config.Hit.
export type Forces = {
	LightFull: number,
	LightEmpty: number,
	LaunchFull: number,
	LaunchEmpty: number,
	LaunchLift: number,
	LaunchLiftEmpty: number,
	LaunchLiftCurve: number, -- more lift on top, growing with the square of the health lost (all of it at none)
	SmashPush: number,
	SmashLift: number,
}

function HitRules.new(max: number): State
	return { health = max, recent = {}, immuneUntil = -math.huge }
end

-- A hit of `damage` at time `now` by `by` (launch: the attacker's hit launches): updates `state` and says what kind
-- of hit it was ("none" while unhittable) and whether a crowd launched it (the guard, not the attacker's own launch).
function HitRules.hit(state: State, rules: Rules, now: number, damage: number, launch: boolean?, by: unknown?): (Kind, boolean)
	if now < state.immuneUntil or state.health <= 0 then
		return "none", false
	end
	state.health = math.max(0, state.health - damage)
	if state.health <= 0 then
		state.recent = {}
		return "smash", false
	end
	local kept = {}
	for _, hit in state.recent do
		if now - hit.at <= rules.window then
			table.insert(kept, hit)
		end
	end
	table.insert(kept, { at = now, by = by })
	state.recent = kept
	local ganged = false
	if #kept >= rules.gang then
		for _, hit in kept do
			if hit.by ~= kept[1].by then
				ganged = true
				break
			end
		end
	end
	if launch or ganged then
		state.recent = {}
		state.immuneUntil = now + rules.immune
		return "launch", ganged and not launch
	end
	return "light", false
end

-- A value that goes from `full` (health at max) to `empty` (health at 0) in a straight line.
function HitRules.scale(health: number, max: number, full: number, empty: number): number
	local left = math.clamp(health / max, 0, 1)
	return empty + (full - empty) * left
end

-- The push (along the ground) and lift a hit of `kind` gives a fighter left with `health` of `max` (a launch lifts more
-- as health drops, too: higher and longer flights, and much higher near the end - LaunchLiftCurve - while a launch at
-- high health stays as it was).
function HitRules.force(kind: Kind, health: number, max: number, forces: Forces): (number, number)
	if kind == "smash" then
		return forces.SmashPush, forces.SmashLift
	elseif kind == "launch" then
		local lost = 1 - math.clamp(health / max, 0, 1)
		local lift = HitRules.scale(health, max, forces.LaunchLift, forces.LaunchLiftEmpty) + forces.LaunchLiftCurve * lost * lost
		return HitRules.scale(health, max, forces.LaunchFull, forces.LaunchEmpty), lift
	end
	return HitRules.scale(health, max, forces.LightFull, forces.LightEmpty), 0
end

return HitRules
