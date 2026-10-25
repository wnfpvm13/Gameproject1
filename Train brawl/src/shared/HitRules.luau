--!strict
-- What a hit does to a fighter, as pure rules (Smash Legends-style; the numbers come in from Config.Health and
-- Config.Hit). Health drops by the hit's damage (each weapon's own), and the hit that empties it is a smash (a certain
-- ring-out). Otherwise the hits on one fighter within `window` seconds of the first make a combo: the `launchOn`-th one
-- launches (flying, lying down) and ends the combo, the ones before are light (a flinch); a weapon that always launches
-- (a hammer, a dynamite blast) launches on any hit. Right after a launch the fighter
-- cannot be hit for `immune` seconds. How hard a hit pushes grows as health drops (force, scale). Requires nothing.

local HitRules = {}

export type Kind = string -- "none" | "light" | "launch" | "smash"
export type State = { health: number, combo: number, comboStart: number, immuneUntil: number }
export type Rules = { max: number, window: number, launchOn: number, immune: number }
-- The pushes (along the ground) and lifts of Config.Hit.
export type Forces = {
	LightFull: number,
	LightEmpty: number,
	LaunchFull: number,
	LaunchEmpty: number,
	LaunchLift: number,
	SmashPush: number,
	SmashLift: number,
}

function HitRules.new(max: number): State
	return { health = max, combo = 0, comboStart = -math.huge, immuneUntil = -math.huge }
end

-- A hit of `damage` at time `now` (launch: it launches whatever the combo): updates `state` and says what kind of hit
-- it was ("none" while unhittable).
function HitRules.hit(state: State, rules: Rules, now: number, damage: number, launch: boolean?): Kind
	if now < state.immuneUntil or state.health <= 0 then
		return "none"
	end
	state.health = math.max(0, state.health - damage)
	if state.health <= 0 then
		state.combo = 0
		return "smash"
	end
	if now - state.comboStart > rules.window then
		state.combo = 0
		state.comboStart = now
	end
	state.combo += 1
	if launch or state.combo >= rules.launchOn then
		state.combo = 0
		state.comboStart = -math.huge
		state.immuneUntil = now + rules.immune
		return "launch"
	end
	return "light"
end

-- A value that goes from `full` (health at max) to `empty` (health at 0) in a straight line.
function HitRules.scale(health: number, max: number, full: number, empty: number): number
	local left = math.clamp(health / max, 0, 1)
	return empty + (full - empty) * left
end

-- The push (along the ground) and lift a hit of `kind` gives a fighter left with `health` of `max`.
function HitRules.force(kind: Kind, health: number, max: number, forces: Forces): (number, number)
	if kind == "smash" then
		return forces.SmashPush, forces.SmashLift
	elseif kind == "launch" then
		return HitRules.scale(health, max, forces.LaunchFull, forces.LaunchEmpty), forces.LaunchLift
	end
	return HitRules.scale(health, max, forces.LightFull, forces.LightEmpty), 0
end

return HitRules
