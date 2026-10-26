--!strict
-- The weapons as pure rules (numbers from Config.Weapons and Config.Drops): which weapon a crate holds (by weight),
-- who an area hit reaches (a hammer's slam, a dynamite's blast), where a thrown stick is along its arc, how many crates
-- a round keeps on the map. Requires nothing.

local WeaponRules = {}

WeaponRules.FIST = "Fist" -- bare fists: what everyone has when holding nothing

-- A weapon (Config.Weapons): how it attacks (style), what a hit does (damage, push: a multiplier on the health-based
-- push; launch: even a first hit launches), its reach (a cone: reach and halfAngle; an area: radius around a point
-- `ahead` of the attacker or where a thrown stick lands), its timing, and how long it lasts once picked up (uses,
-- or seconds held). weight: how often a crate holds it (0 or nil = never: the fists).
export type Weapon = {
	style: string, -- "punch" | "swing" | "slam" | "throw"
	damage: number,
	push: number,
	launch: boolean?,
	reach: number?,
	halfAngle: number?,
	radius: number?,
	ahead: number?,
	throwSpeed: number?,
	throwLift: number?,
	fuse: number?,
	cooldown: number,
	hitAt: number,
	seconds: number,
	uses: number?,
	heldSeconds: number?,
	resist: number?, -- while held, knocks taken are multiplied by this
	slow: number?, -- while held, walking speed is multiplied by this
	weight: number?,
}

-- The weapon named by `value` (a character's Names.Weapon attribute), or "Fist" when it names none.
function WeaponRules.named(weapons: { [string]: Weapon }, value: unknown): string
	return if typeof(value) == "string" and weapons[value] ~= nil then value else WeaponRules.FIST
end

-- The weapon a crate holds: `roll` in [0, 1) picks among the weapons with a weight, in name order (so the same roll
-- always picks the same weapon). nil when no weapon has a weight.
function WeaponRules.pick(weapons: { [string]: Weapon }, roll: number): string?
	local names = {}
	local total = 0
	for name, weapon in weapons do
		if (weapon.weight or 0) > 0 then
			table.insert(names, name)
			total += weapon.weight or 0
		end
	end
	if total <= 0 then
		return nil
	end
	table.sort(names)
	local at = math.clamp(roll, 0, 0.999999) * total
	for _, name in names do
		at -= weapons[name].weight or 0
		if at < 0 then
			return name
		end
	end
	return names[#names]
end

-- Whether a fighter at (tx, ty, tz) is in an area hit centred on (cx, cy, cz): within `radius` along the ground and
-- `heightReach` up or down.
function WeaponRules.inArea(cx: number, cy: number, cz: number, tx: number, ty: number, tz: number, radius: number, heightReach: number): boolean
	local dx, dz = tx - cx, tz - cz
	return dx * dx + dz * dz <= radius * radius and math.abs(ty - cy) <= heightReach
end

-- Where a stick thrown from (x, y, z) along the flat direction (fx, fz) (length 1) at `speed` with `lift` upward is
-- after `t` seconds under `gravity`.
function WeaponRules.arc(x: number, y: number, z: number, fx: number, fz: number, speed: number, lift: number, gravity: number, t: number): (number, number, number)
	return x + fx * speed * t, y + lift * t - gravity / 2 * t * t, z + fz * speed * t
end

-- How many crates may be on the map with `alive` fighters left: one for every three, at least one, at most `most`.
function WeaponRules.cratesFor(alive: number, most: number): number
	return math.clamp(math.ceil(alive / 3), 1, most)
end

return WeaponRules
