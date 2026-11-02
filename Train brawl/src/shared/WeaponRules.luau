--!strict
-- The weapons as pure rules (numbers from Config.Weapons and Config.Drops): which weapon a crate holds (by weight),
-- who an area hit reaches (a hammer's slam, a dynamite's blast, a burst of firecrackers), whom a thrown lump or a
-- rolling wheel passes, where a thrown stick is along its arc, which styles show their hits at once or hit from afar,
-- how many crates a round keeps on the map and whom and where the next one is for, and the golden crate's time, top
-- and weapon (decision 25). Requires nothing.

local WeaponRules = {}

WeaponRules.FIST = "Fist" -- bare fists: what everyone has when holding nothing

-- A weapon (Config.Weapons): how it attacks (style), what a hit does (damage, push: a multiplier on the health-based
-- push; launch: even a first hit launches), its reach (a cone: reach and halfAngle; an area: radius around a point
-- `ahead` of the attacker or where a thrown stick lands or a slick lies), its timing, and how long it lasts once picked
-- up (uses, or seconds held). weight: how often a crate holds it (0 or nil = never: the fists).
export type Weapon = {
	style: string, -- "punch" | "swing" | "spray" | "lasso" | "slam" | "burst" | "throw" | "toss" | "roll" | "pour"
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
	hitRadius: number?, -- a thrown lump or a rolling wheel hits a fighter whose middle passes this close
	flight: number?, -- a thrown lump flies at most this long
	rollSpeed: number?,
	rollSeconds: number?,
	lasts: number?, -- a slick lies this long
	pull: number?, -- a lasso pulls its catch in to this far in front of the attacker instead of pushing it away
	stun: number?, -- a light hit's own stun (no acting: a lasso's tie) instead of HitRules.stun's
	cooldown: number,
	hitAt: number,
	seconds: number,
	uses: number?,
	heldSeconds: number?,
	resist: number?, -- while held, knocks taken are multiplied by this
	slow: number?, -- while held, walking speed is multiplied by this
	weight: number?,
	offHand: Vector3?, -- held in both hands: where the free hand holds it (studs, in the grip's space: CharacterParts.grip)
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

-- How far an attack of `style` steps its attacker in (Config.Attack: LungeStuds for a punch or a swing, FinisherLunge
-- for a string's launching last step, SlamLunge for a slam; a throw stands still).
function WeaponRules.lunge(style: string, finisher: boolean, attack: { LungeStuds: number, FinisherLunge: number, SlamLunge: number }): number
	if style == "punch" or style == "swing" then
		return if finisher then attack.FinisherLunge else attack.LungeStuds
	elseif style == "slam" then
		return attack.SlamLunge
	end
	return 0
end

-- Whether the attacker's own client shows an attack of `style` hitting at once (a punch's or a swing's cone, the same
-- the server uses); the rest wait for the server's word (one victim of a lasso, the things sent out, the areas).
function WeaponRules.predicted(style: string): boolean
	return style == "punch" or style == "swing"
end

-- Whether an attack of `style` hits around a point (a slam: ahead of the attacker; a burst: around the attacker).
function WeaponRules.area(style: string): boolean
	return style == "slam" or style == "burst"
end

-- Whether an attack of `style` hits from away from its attacker (a thrown stick, a lump, a wheel, a slick): its hits
-- burst on the victim and do not hold the attacker's pose.
function WeaponRules.fromAfar(style: string): boolean
	return style == "throw" or style == "toss" or style == "roll" or style == "pour"
end

-- Whether a fighter at (px, py, pz) is passed by something moving from (ax, ay, az) to (bx, by, bz): its middle within
-- `radius` of the path along the ground and `heightReach` of the path's height there.
function WeaponRules.nearPath(ax: number, ay: number, az: number, bx: number, by: number, bz: number, px: number, py: number, pz: number, radius: number, heightReach: number): boolean
	local dx, dz = bx - ax, bz - az
	local long = dx * dx + dz * dz
	local s = if long > 1e-9 then math.clamp(((px - ax) * dx + (pz - az) * dz) / long, 0, 1) else 0
	local cx, cy, cz = ax + dx * s, ay + (by - ay) * s, az + dz * s
	local ox, oz = px - cx, pz - cz
	return ox * ox + oz * oz <= radius * radius and math.abs(py - cy) <= heightReach
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

-- How many crates may be on the map with `alive` fighters left: one for every `per`, at least one, at most `most`.
function WeaponRules.cratesFor(alive: number, most: number, per: number): number
	return math.clamp(math.ceil(alive / per), 1, most)
end

-- A fighter as the crates see it: where it stands, whether it holds bare fists (it can take a crate), and whether it
-- is a person (not a practice bot).
export type Seen = { x: number, z: number, fists: boolean, person: boolean? }

-- Whom the next crate is for (2026-10-31: the testers walked 47% of the time, mostly to crates bait had dropped far
-- away): nobody when the fight has gone `quiet` seconds without a hit landing (a stand-off: the crate is bait, dropped
-- far from everyone), else one of `fighters` picked with `random` (a number in [0, 1)) among the people holding bare
-- fists, then any holding bare fists, then all (weapons are the heart of the fight: owner 2026-10-31; practice bots
-- only fill in, and the persona testers kept chasing crates dropped by bots on other trains - 2026-11-02). Its index
-- in `fighters`, or nil.
function WeaponRules.crateFor(fighters: { Seen }, quiet: number, quietLimit: number, random: () -> number): number?
	if quiet >= quietLimit or #fighters == 0 then
		return nil
	end
	local pool = {}
	for i, seen in fighters do
		if seen.fists and seen.person then
			table.insert(pool, i)
		end
	end
	if #pool == 0 then
		for i, seen in fighters do
			if seen.fists then
				table.insert(pool, i)
			end
		end
	end
	if #pool == 0 then
		for i in fighters do
			table.insert(pool, i)
		end
	end
	return pool[math.clamp(math.floor(random() * #pool) + 1, 1, #pool)]
end

-- Of `spots`, where a crate for the fighter at (x, z) lands: the nearest at least `gap` away along the ground (it walks
-- a step or two to it, and it does not drop on its head), or the farthest when all are closer. Its index, or nil.
function WeaponRules.nearSpot(spots: { { x: number, z: number } }, x: number, z: number, gap: number): number?
	local best, bestDistance = nil, math.huge
	local far, farDistance = nil, -1
	for i, spot in spots do
		local distance = math.sqrt((spot.x - x) ^ 2 + (spot.z - z) ^ 2)
		if distance >= gap and distance < bestDistance then
			best, bestDistance = i, distance
		end
		if distance > farDistance then
			far, farDistance = i, distance
		end
	end
	return best or far
end

-- A walkable top as ArenaLayout has it (ArenaLayout.Surface, written out: this requires nothing).
export type Top = { train: number, car: number, kind: string, x: number, z: number, width: number, length: number, top: number, plank: boolean }

-- When the golden crate drops, in seconds into the fight: the first regular drop (`firstAfter`, then every `every`)
-- at or after `at` - it takes that drop's place.
function WeaponRules.goldenTime(firstAfter: number, every: number, at: number): number
	if at <= firstAfter then
		return firstAfter
	end
	return firstAfter + every * math.ceil((at - firstAfter) / every - 1e-9)
end

-- Where the golden crate lands: the middle of the biggest wide top (`wide` across, not a tender) of the middle train
-- (`middle`) whose car is not coming off (`away`) - the main stage everyone can reach - or of any train when none.
function WeaponRules.goldenTop(tops: { Top }, middle: number, wide: number, away: (number, number) -> boolean): Top?
	local best: Top? = nil
	local bestScore = -math.huge
	for _, top in tops do
		if top.width >= wide - 1e-6 and top.kind ~= "Tender" and not away(top.train, top.car) then
			local score = top.width * top.length - (if top.train == middle then 0 else 1e6)
			if score > bestScore then
				best, bestScore = top, score
			end
		end
	end
	return best
end

-- The golden crate's weapon: the next of `bag` (taken from its end), refilled from `pool` in a random order (`random`
-- in [0, 1)) when empty, never the same as `last` twice running across a refill. Changes `bag`.
function WeaponRules.goldenNext(bag: { string }, pool: { string }, last: string?, random: () -> number): string
	if #bag == 0 then
		for _, name in pool do
			table.insert(bag, name)
		end
		for i = #bag, 2, -1 do
			local j = math.floor(random() * i) + 1
			bag[i], bag[j] = bag[j], bag[i]
		end
		if #bag > 1 and bag[#bag] == last then
			bag[#bag], bag[1] = bag[1], bag[#bag]
		end
	end
	return table.remove(bag) :: string
end

return WeaponRules
