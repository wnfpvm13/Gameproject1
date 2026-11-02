--!strict
-- The whole-body poses of every attack and hit reaction, as keyframes over the joints of an R15 body (no uploaded
-- animation): the hips and torso turn into a blow, the head keeps facing ahead. Each weapon (Config.Weapons) has its
-- own set: a stance (stance()), the pose a fighter holding it keeps while fighting, standing or walking, that its
-- attacks start from and come back to and a light hit's flinch settles back into; and a punch or swing has its own
-- pose for each step of the attacker's string (AttackString), the launching last step plainly bigger and starting with
-- a wind-up (it lands a moment later than the others: Config.Attack.FinisherWindup).
-- - bare fists: a boxing guard; 1 a left jab, 2 a right straight (then 1, 2 again), the last a dip into a rising
--   uppercut with a short step in. The hips turn first, the torso and shoulder follow and the elbow straightens last,
--   as the blow lands; the arm stays out only a moment and snaps back to the guard;
-- - the bat, the gold bar, the hammer, the dynamite stick, the whip, the lasso, the steam hose, the oil can, the
--   firecrackers and the spare wheel: see their sets below (the bat, the gold bar, the hammer, the hose and the wheel in
--   both hands); the shovel swings as the bat, coal is thrown as the stick;
-- - hit reactions: a light hit snaps the torso and head the way the hit pushed (back when hit from the front, forward
--   from behind, sideways from the side); a launch flails the arms while flying.
-- Each segment between keys has its own easing: a blow speeds into the hit and carries on through it (no stop at the
-- hit). A pose is each joint's turn (degrees, about the joint's own axes: x raises an arm forward
-- or leans the torso back, y turns left, z lifts an arm out to the right) and, for the root, a shift (studs, -z ahead).
-- SwingPose writes them on every client, blended in from the walking animation and back out (shared because client
-- parts do not require each other). Requires nothing.

local AttackPoses = {}

-- One joint's pose: turns in degrees and an optional shift (the root only).
export type Joint = { x: number?, y: number?, z: number?, shift: Vector3? }
export type Pose = { [string]: Joint }
-- A key: the pose at share `t` of the move; `ease` is how the segment that ends here moves ("in": speeding up into
-- this key, "out": slowing into it, "linear", or eased both ways when nil).
export type Key = { t: number, pose: Pose, ease: string? }

-- How long a light hit's flinch and a launch's flail are drawn (seconds).
AttackPoses.FlinchSeconds = 0.28
AttackPoses.FlailSeconds = 0.7
local TUMBLE = 0.55 -- a launch's tumble takes this share of the flail (about the flight)

local JOINTS = { "Root", "Waist", "Neck", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "RightHip", "LeftHip", "RightKnee", "LeftKnee" }

local function ease(kind: string?, s: number): number
	if kind == "in" then
		return s * s
	elseif kind == "out" then
		return 1 - (1 - s) * (1 - s)
	elseif kind == "linear" then
		return s
	end
	return s * s * (3 - 2 * s)
end

local function lerp(a: number, b: number, s: number): number
	return a + (b - a) * s
end

-- `a` and `b` blended by `s` (a joint missing from a pose is at rest), with every joint in `also` even when neither
-- names it (at rest then).
local function blend(a: Pose, b: Pose, s: number, also: { [string]: boolean }?): Pose
	local out: Pose = {}
	for _, name in JOINTS do
		local ja, jb = a[name], b[name]
		if ja or jb or (also and also[name]) then
			local pa: Joint = ja or {}
			local pb: Joint = jb or {}
			local shift: Vector3? = nil
			if pa.shift or pb.shift then
				shift = (pa.shift or Vector3.zero):Lerp(pb.shift or Vector3.zero, s)
			end
			out[name] = {
				x = lerp(pa.x or 0, pb.x or 0, s),
				y = lerp(pa.y or 0, pb.y or 0, s),
				z = lerp(pa.z or 0, pb.z or 0, s),
				shift = shift,
			}
		end
	end
	return out
end

-- The joints any of `keys` turns, found once per set of keys.
local used: { [{ Key }]: { [string]: boolean } } = setmetatable({}, { __mode = "k" }) :: any
local function turned(keys: { Key }): { [string]: boolean }
	local found = used[keys]
	if not found then
		local names: { [string]: boolean } = {}
		for _, key in keys do
			for name in key.pose do
				names[name] = true
			end
		end
		used[keys] = names
		found = names
	end
	return found
end

-- The pose at `u` (0..1) along keys (the first at 0, the last at 1). It names every joint any key turns, all through
-- the move (one the keys on both sides leave out is at rest), so no joint drops back to the walking animation part
-- way through.
function AttackPoses.sample(keys: { Key }, u: number): Pose
	u = math.clamp(u, 0, 1)
	local all = turned(keys)
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if u <= b.t then
			local span = b.t - a.t
			return blend(a.pose, b.pose, if span > 0 then ease(b.ease, (u - a.t) / span) else 1, all)
		end
	end
	return blend(keys[#keys].pose, keys[#keys].pose, 1, all)
end

-- Keys in order whatever the timing gives (a key that would come before the one ahead of it moves just after it, and
-- one that would come too late moves back to leave room for those after it; the last is at the end).
local function ordered(keys: { Key }): { Key }
	local n = #keys
	for i = 2, n do
		local latest = 1 - 0.01 * (n - i)
		keys[i].t = math.min(math.max(keys[i].t, keys[i - 1].t + 0.01), latest)
	end
	keys[n].t = 1
	return keys
end

local REST: Pose = {}

-- Bare fists' boxing guard: the torso turned a little so the left side leads (the head still facing ahead), the left
-- fist a little forward, the right one by the chin, elbows in.
local LEAD: Pose = { LeftShoulder = { x = 55, z = 10 }, LeftElbow = { x = 105 } }
local REAR: Pose = { RightShoulder = { x = 38, z = -12 }, RightElbow = { x = 128 } }
local GUARD: Pose = {
	Waist = { y = -10 },
	Neck = { y = 10 },
	LeftShoulder = LEAD.LeftShoulder,
	LeftElbow = LEAD.LeftElbow,
	RightShoulder = REAR.RightShoulder,
	RightElbow = REAR.RightElbow,
}

-- Blocking (decision 11, persona fix 4): both forearms up in front of the face, elbows forward, chin tucked, the body
-- leaning in and a little lower. Whatever is held stays in the right hand; the left lets go of a two-handed grip.
local BLOCK: Pose = {
	Root = { shift = Vector3.new(0, -0.25, 0) },
	Waist = { x = 10 },
	Neck = { x = -10 },
	LeftShoulder = { x = 88, z = 24 },
	LeftElbow = { x = 120 },
	RightShoulder = { x = 88, z = -24 },
	RightElbow = { x = 120 },
}

-- Joins pose tables (later ones win for a joint both name).
local function with(...: Pose): Pose
	local out: Pose = {}
	for _, pose in { ... } do
		for name, joint in pose do
			out[name] = joint
		end
	end
	return out
end

-- A punch from the guard landing at `k` (a share of the drawn attack): `load` a moment before, `drive` (the hips and
-- torso turning, the elbow still bent) speeding into `out` (the arm straight) as it lands, out only `hold` longer, then
-- snapped back through `back` to the guard.
local function fromGuard(load: Pose, drive: Pose, out: Pose, back: Pose, k: number, hold: number): { Key }
	return ordered({
		{ t = 0, pose = GUARD },
		{ t = k * 0.4, pose = load, ease = "out" },
		{ t = k * 0.75, pose = drive, ease = "in" },
		{ t = k, pose = out, ease = "linear" },
		{ t = k + hold, pose = out, ease = "linear" },
		{ t = k + hold + (1 - k - hold) * 0.5, pose = back, ease = "out" },
		{ t = 1, pose = GUARD },
	})
end

-- k: when the blow lands, as a share of the drawn attack.
local function punch(step: number, finisher: boolean, k: number): { Key }
	if not finisher then
		if step % 2 == 1 then -- a left jab: quick, the hips barely turning
			local load = with(GUARD, { Root = { y = 4 }, Waist = { y = -6 }, Neck = { y = 4 }, LeftShoulder = { x = 50, z = 12 }, LeftElbow = { x = 115 } })
			local drive = with(GUARD, { Root = { y = -6 }, Waist = { y = -18 }, Neck = { y = 20 }, LeftShoulder = { x = 80, z = 4 }, LeftElbow = { x = 60 } })
			local out = with(REAR, {
				Root = { y = -8, shift = Vector3.new(0, 0, -0.15) },
				Waist = { y = -24 },
				Neck = { y = 26 },
				LeftShoulder = { x = 92 },
				LeftElbow = { x = 2 },
			})
			local back = with(GUARD, { Waist = { y = -14 }, Neck = { y = 14 }, LeftShoulder = { x = 64, z = 8 }, LeftElbow = { x = 72 } })
			return fromGuard(load, drive, out, back, k, 0.06)
		end
		-- a right straight: coiled a little further, then the hips drive the rear hand through (the legs keep walking: a
		-- joint a punch names is held by it all through)
		local load = with(GUARD, { Root = { y = -6 }, Waist = { y = -18 }, Neck = { y = 22 }, RightShoulder = { x = 34, z = -14 }, RightElbow = { x = 135 } })
		local drive = with(GUARD, { Root = { y = 10 }, Waist = { y = 6 }, Neck = { y = -14 }, RightShoulder = { x = 74, z = -6 }, RightElbow = { x = 70 } })
		local out = with(LEAD, {
			Root = { y = 18, shift = Vector3.new(0, -0.05, -0.25) },
			Waist = { y = 22 },
			Neck = { y = -34 },
			RightShoulder = { x = 92, z = -4 },
			RightElbow = { x = 2 },
		})
		local back = with(GUARD, { Root = { y = 6 }, Waist = { y = 4 }, Neck = { y = -8 }, RightShoulder = { x = 58, z = -8 }, RightElbow = { x = 80 } })
		return fromGuard(load, drive, out, back, k, 0.06)
	end
	-- The finisher: down into a dip with the right fist low and back, then up through a rising uppercut with a short step
	-- in (a long one slides the feet).
	local dip = with(LEAD, {
		Root = { y = -10, shift = Vector3.new(0, -0.35, 0) },
		Waist = { x = -12, y = -20 },
		Neck = { x = 10, y = 26 },
		RightShoulder = { x = 8, z = 16 },
		RightElbow = { x = 80 },
		RightKnee = { x = -25 },
		LeftKnee = { x = -25 },
		RightHip = { x = 15 },
		LeftHip = { x = 15 },
	})
	local drive = with(LEAD, {
		Root = { y = 4, shift = Vector3.new(0, -0.15, -0.1) },
		Waist = { x = 2, y = 8 },
		Neck = { x = 4, y = -10 },
		RightShoulder = { x = 80, z = -4 },
		RightElbow = { x = 85 },
		RightKnee = { x = -12 },
		LeftKnee = { x = -12 },
		LeftHip = { x = 14 },
	})
	-- As it lands: the upper arm out ahead, the forearm up (a fist driven up under the chin, not a raised hand)...
	local rise = with(LEAD, {
		Root = { y = 14, shift = Vector3.new(0, 0.05, -0.2) },
		Waist = { x = 0, y = 24 },
		Neck = { x = 4, y = -36 },
		RightShoulder = { x = 112, z = -8 },
		RightElbow = { x = 72 },
		LeftHip = { x = 24 },
		RightHip = { x = -14 },
		LeftKnee = { x = -8 },
	})
	-- ...and carrying on up through it, leaning back.
	local through = with(rise, {
		Root = { y = 16, shift = Vector3.new(0, 0.1, -0.2) },
		Waist = { x = 12, y = 28 },
		Neck = { x = 8, y = -38 },
		RightShoulder = { x = 145, z = -10 },
		RightElbow = { x = 60 },
	})
	local back = with(GUARD, {
		Root = { y = 6, shift = Vector3.new(0, 0, -0.1) },
		Waist = { x = 4, y = 6 },
		Neck = { y = -8 },
		RightShoulder = { x = 70, z = -8 },
		RightElbow = { x = 95 },
	})
	return ordered({
		{ t = 0, pose = GUARD },
		{ t = k * 0.6, pose = dip, ease = "out" },
		{ t = k * 0.85, pose = drive, ease = "in" },
		{ t = k, pose = rise, ease = "linear" },
		{ t = k + 0.12, pose = through, ease = "out" },
		{ t = k + 0.12 + (1 - k - 0.12) * 0.55, pose = back, ease = "out" },
		{ t = 1, pose = GUARD },
	})
end

-- The weapons' own sets. Each pose was found in Studio (2026-10-27) from where the fist and the weapon should be at
-- that moment - the arm's turns that put them there - so the numbers are not meant to be read as angles. A two-handed
-- weapon's poses turn only the weapon arm and the body: SwingPose puts the free hand on the handle (Config.Weapons
-- offHand, ArmReach), and none of them names the left arm.

-- A strike from `stance` landing at `k`: wound up into `load`, speeding through `drive` (if any) into `hit` as it lands,
-- carried on into `follow` (`hold` later), then back through `back` to the stance.
local function strike(stance: Pose, load: Pose, drive: Pose?, hit: Pose, follow: Pose, back: Pose, k: number, hold: number): { Key }
	local keys: { Key } = { { t = 0, pose = stance }, { t = k * (if drive then 0.45 else 0.6), pose = load, ease = "out" } }
	if drive then
		table.insert(keys, { t = k * 0.8, pose = drive, ease = "in" })
	end
	table.insert(keys, { t = k, pose = hit, ease = if drive then "linear" else "in" })
	table.insert(keys, { t = k + hold, pose = follow, ease = "out" })
	table.insert(keys, { t = k + hold + (1 - k - hold) * 0.5, pose = back, ease = "out" })
	table.insert(keys, { t = 1, pose = stance })
	return ordered(keys)
end

-- The bat, in both hands, up by the right shoulder: 1 a level swing from the right that lands with the bat straight
-- ahead and carries on round to the left, 2 the swing back from the left, the last a big one from low with a step in,
-- ending wrapped round the left shoulder (held a moment, like a home run's).
local BAT_STANCE: Pose = { Root = { y = -10 }, Waist = { y = -15 }, Neck = { y = 25 }, RightShoulder = { x = 65, y = 42, z = -60 }, RightElbow = { x = 87 }, RightWrist = { x = 25, y = 3, z = -3 } }
local function bat(step: number, finisher: boolean, k: number): { Key }
	if not finisher then
		if step % 2 == 1 then
			return strike(
				BAT_STANCE,
				{ Root = { y = -25 }, Waist = { y = -30 }, Neck = { y = 45 }, RightShoulder = { x = 68, y = 41, z = -60 }, RightElbow = { x = 90 }, RightWrist = { x = 20, y = -14 } },
				{ Root = { y = 10 }, Waist = { y = -10 }, Neck = { y = 20 }, RightShoulder = { x = 33, y = 25, z = -59 }, RightElbow = { x = 106 }, RightWrist = { x = 36, y = -1, z = 1 } },
				{ Root = { y = 25 }, Waist = { y = 20 }, Neck = { y = -25 }, RightShoulder = { x = 16, y = 30, z = -43 }, RightElbow = { x = 123 }, RightWrist = { x = -17, y = -52, z = 10 } },
				{ Root = { y = 35 }, Waist = { y = 45 }, Neck = { y = -50 }, RightShoulder = { x = 21, y = 67, z = -19 }, RightElbow = { x = 135 }, RightWrist = { x = -80, y = -35, z = 3 } },
				{ Root = { y = 10 }, Waist = { y = 10 }, Neck = { y = -5 }, RightShoulder = { x = 39, y = 68, z = -5 }, RightElbow = { x = 131 }, RightWrist = { x = -42, y = -10 } },
				k,
				0.15
			)
		end
		return strike(
			BAT_STANCE,
			{ Root = { y = 10 }, Waist = { y = 30 }, Neck = { y = -30 }, RightShoulder = { x = 84, y = 60, z = -42 }, RightElbow = { x = 89 }, RightWrist = { x = -39, y = -7, z = -5 } },
			{ Root = { y = -5 }, Waist = { y = 10 }, Neck = { y = -10 }, RightShoulder = { x = 101, y = 70, z = -55 }, RightElbow = { x = 70 }, RightWrist = { x = -41, y = 15, z = -7 } },
			{ Root = { y = -20 }, Waist = { y = -20 }, Neck = { y = 25 }, RightShoulder = { x = 75, y = 26, z = -60 }, RightElbow = { x = 39 }, RightWrist = { x = -65, y = -33, z = -11 } },
			{ Root = { y = -30 }, Waist = { y = -40 }, Neck = { y = 45 }, RightShoulder = { x = 59, y = 17, z = -60 }, RightElbow = { x = 60 }, RightWrist = { x = -4, y = -47, z = -11 } },
			{ Root = { y = -10 }, Waist = { y = -15 }, Neck = { y = 15 }, RightShoulder = { x = 75, y = 33, z = -53 }, RightElbow = { x = 76 }, RightWrist = { x = 4, y = -15, z = -17 } },
			k,
			0.15
		)
	end
	local through: Pose = { Root = { y = 50, shift = Vector3.new(0, 0, -0.3) }, Waist = { x = 10, y = 70 }, Neck = { y = -70 }, RightShoulder = { x = 50, y = 87, z = -34 }, RightElbow = { x = 150 }, RightWrist = { x = -6, y = -90, z = 5 }, RightHip = { x = -14 }, LeftHip = { x = 20 } }
	return ordered({
		{ t = 0, pose = BAT_STANCE },
		{ t = k * 0.55, pose = { Root = { y = -30, shift = Vector3.new(0, -0.25, 0.15) }, Waist = { x = -8, y = -40 }, Neck = { y = 50 }, RightShoulder = { x = 90, y = 32, z = -60 }, RightElbow = { x = 87 }, RightWrist = { x = 20, y = -34, z = 4 }, RightHip = { x = 12 }, LeftHip = { x = 12 }, RightKnee = { x = -22 }, LeftKnee = { x = -22 } }, ease = "out" },
		{ t = k * 0.85, pose = { Root = { y = 15, shift = Vector3.new(0, -0.2, -0.25) }, Waist = { y = -10 }, Neck = { y = 15 }, RightShoulder = { x = 42, y = 34, z = -59 }, RightElbow = { x = 118 }, RightWrist = { x = 31, y = -3, z = -7 }, LeftHip = { x = 22 }, RightKnee = { x = -15 }, LeftKnee = { x = -10 } }, ease = "in" },
		{ t = k, pose = { Root = { y = 35, shift = Vector3.new(0, -0.1, -0.35) }, Waist = { y = 25 }, Neck = { y = -30 }, RightShoulder = { x = 20, y = 53, z = -60 }, RightElbow = { x = 150 }, RightWrist = { x = -2, y = -38, z = 1 }, RightHip = { x = -12 }, LeftHip = { x = 26 }, LeftKnee = { x = -6 } }, ease = "linear" },
		{ t = k + 0.18, pose = through, ease = "out" },
		{ t = k + 0.34, pose = through, ease = "linear" },
		{ t = 1, pose = BAT_STANCE, ease = "out" },
	})
end

-- The gold bar, carried by both ends in front: 1 heaved from the right side across the front to the left, 2 back from
-- the left, the last lifted overhead and brought down in front with the knees giving (it stays down a moment).
local GOLD_STANCE: Pose = { RightShoulder = { x = 27, y = 48, z = -7 }, RightElbow = { x = 59 }, RightWrist = { x = -37, y = 28, z = -15 } }
local function goldBar(step: number, finisher: boolean, k: number): { Key }
	if not finisher then
		if step % 2 == 1 then
			return strike(
				GOLD_STANCE,
				{ Root = { y = -20 }, Waist = { y = -35 }, Neck = { y = 40 }, RightShoulder = { x = 36, y = 66, z = -3 }, RightElbow = { x = 76 }, RightWrist = { x = -44, y = 18, z = -14 } },
				nil,
				{ Root = { y = 20 }, Waist = { y = 25 }, Neck = { y = -25 }, RightShoulder = { x = -13, y = -8, z = 27 }, RightElbow = { x = 124 }, RightWrist = { x = -67, y = 26, z = -27 } },
				{ Root = { y = 30 }, Waist = { y = 45 }, Neck = { y = -45 }, RightShoulder = { x = -22, y = -16, z = 26 }, RightElbow = { x = 149 }, RightWrist = { x = -53, y = 41, z = -45 } },
				{ Root = { y = 10 }, Waist = { y = 15 }, Neck = { y = -15 }, RightShoulder = { x = 5, y = 16, z = 10 }, RightElbow = { x = 104 }, RightWrist = { x = -45, y = 34, z = -30 } },
				k,
				0.15
			)
		end
		return strike(
			GOLD_STANCE,
			{ Root = { y = 20 }, Waist = { y = 35 }, Neck = { y = -40 }, RightShoulder = { x = 3, y = 38, z = 21 }, RightElbow = { x = 104 }, RightWrist = { x = -49, y = 29, z = -27 } },
			nil,
			{ Root = { y = -20 }, Waist = { y = -25 }, Neck = { y = 25 }, RightShoulder = { x = 19, y = 90, z = 37 }, RightElbow = { x = 74 }, RightWrist = { x = -14, y = 24, z = -8 } },
			{ Root = { y = -30 }, Waist = { y = -45 }, Neck = { y = 45 }, RightShoulder = { x = 19, y = 90, z = 37 }, RightElbow = { x = 70 }, RightWrist = { x = -30, y = 13, z = -2 } },
			{ Root = { y = -10 }, Waist = { y = -15 }, Neck = { y = 15 }, RightShoulder = { x = 23, y = 69, z = 15 }, RightElbow = { x = 65 }, RightWrist = { x = -34, y = 20, z = -9 } },
			k,
			0.15
		)
	end
	local down: Pose = { Root = { shift = Vector3.new(0, -0.45, -0.25) }, Waist = { x = -30 }, Neck = { x = 15 }, RightShoulder = { x = 25, y = 58, z = 33 }, RightElbow = { x = 107 }, RightWrist = { x = -65, y = 20, z = -27 }, RightHip = { x = 20 }, LeftHip = { x = 20 }, RightKnee = { x = -35 }, LeftKnee = { x = -35 } }
	return ordered({
		{ t = 0, pose = GOLD_STANCE },
		{ t = k * 0.6, pose = { Root = { shift = Vector3.new(0, -0.1, 0.1) }, Waist = { x = 15 }, Neck = { x = -8 }, RightShoulder = { x = 67, y = 63, z = 41 }, RightElbow = { x = 69 }, RightWrist = { x = -33, y = 19, z = -7 } }, ease = "out" },
		{ t = k, pose = down, ease = "in" },
		{ t = k + 0.15, pose = down, ease = "linear" },
		{ t = 1, pose = GOLD_STANCE },
	})
end

-- The hammer, in both hands with its head up in front: raised high overhead, leaning back (a long wind-up everyone
-- sees), slammed down into the roof ahead with the knees giving, kept down a moment, lifted back.
local HAMMER_STANCE: Pose = { Root = { y = -5 }, Waist = { y = -10 }, Neck = { y = 15 }, RightShoulder = { x = 42, y = 49, z = -42 }, RightElbow = { x = 88 }, RightWrist = { x = 29, y = 11, z = -5 } }
local function hammer(k: number): { Key }
	local down: Pose = { Root = { shift = Vector3.new(0, -0.45, -0.2) }, Waist = { x = -30 }, Neck = { x = 14 }, RightShoulder = { x = 67, y = 48, z = -60 }, RightElbow = { x = 98 }, RightWrist = { x = -11, y = -79, z = 11 }, RightHip = { x = 20 }, LeftHip = { x = 20 }, RightKnee = { x = -35 }, LeftKnee = { x = -35 } }
	return ordered({
		{ t = 0, pose = HAMMER_STANCE },
		{ t = k * 0.7, pose = { Waist = { x = 18 }, Neck = { x = -10 }, RightShoulder = { x = 106, y = 30, z = -32 }, RightElbow = { x = 59 }, RightWrist = { x = 3, z = 4 } }, ease = "out" },
		{ t = k, pose = down, ease = "in" },
		{ t = k + 0.15, pose = down, ease = "linear" },
		{ t = 1, pose = HAMMER_STANCE },
	})
end

-- The dynamite stick, held up by the right shoulder with the left hand out ahead to aim: wound back with the torso
-- turned away and the left arm pointing, whipped forward (it leaves the hand at `k`, high and on its way forward),
-- followed through low across the body.
local DYNAMITE_STANCE: Pose = { Root = { y = -5 }, Waist = { y = -10 }, Neck = { y = 15 }, RightShoulder = { x = 26, y = 42, z = 21 }, RightElbow = { x = 129 }, RightWrist = { x = -29, y = -32, z = -2 }, LeftShoulder = { x = 60, z = -10 }, LeftElbow = { x = 40 } }
local DYNAMITE_RELEASE: Pose = { Root = { y = 15 }, Waist = { x = -8, y = 20 }, Neck = { y = -20 }, RightShoulder = { x = 107, y = 13, z = -56 }, RightElbow = { x = 122 }, RightWrist = { x = -10, y = -79, z = 14 }, LeftShoulder = { x = 30, z = -20 }, LeftElbow = { x = 70 } }
local function dynamite(k: number): { Key }
	return ordered({
		{ t = 0, pose = DYNAMITE_STANCE },
		{ t = k * 0.6, pose = { Root = { y = -25 }, Waist = { x = 8, y = -35 }, Neck = { y = 40 }, RightShoulder = { x = 60, y = 38 }, RightElbow = { x = 121 }, RightWrist = { x = -10, y = -44, z = 9 }, LeftShoulder = { x = 85, z = -5 }, LeftElbow = { x = 10 } }, ease = "out" },
		{ t = k, pose = DYNAMITE_RELEASE, ease = "in" },
		{ t = math.min(k + 0.25, 0.9), pose = { Root = { y = 25 }, Waist = { x = -15, y = 35 }, Neck = { y = -30 }, RightShoulder = { x = 26, y = 43, z = -60 }, RightElbow = { x = 136 }, RightWrist = { x = -13, y = -74, z = 18 }, LeftShoulder = { x = 10, z = -25 }, LeftElbow = { x = 60 } }, ease = "out" },
		{ t = 1, pose = DYNAMITE_STANCE },
	})
end

-- The whip, in the right hand low ahead with the lash lying out ahead (the left fist up): 1 raised back over the
-- shoulder (the lash trailing behind) and cracked down ahead, 2 cracked across from the right with the hips turning,
-- the last a big overhead crack with a step in, leaning into it (held a moment). Where the lash points is about the sum
-- of the shoulder's, elbow's and wrist's x (0: straight ahead, 90: up, 180: back; Studio pose sheet 2026-10-28): it
-- trails behind the head on a wind-up and lies out level ahead as it lands, not up in the air.
local WHIP_STANCE: Pose = { Root = { y = -5 }, Waist = { y = -10 }, Neck = { y = 10 }, RightShoulder = { x = 20, z = -10 }, RightElbow = { x = 20 }, RightWrist = { x = -60, y = 0 }, LeftShoulder = { x = 40, z = 12 }, LeftElbow = { x = 95 } }
local WHIP_GUARD: Pose = { LeftShoulder = { x = 40, z = 12 }, LeftElbow = { x = 95 } }
local function whip(step: number, finisher: boolean, k: number): { Key }
	if not finisher then
		if step % 2 == 1 then
			return strike(
				WHIP_STANCE,
				with(WHIP_GUARD, { Root = { y = -12 }, Waist = { x = 12, y = -20 }, Neck = { x = -6, y = 20 }, RightShoulder = { x = 165, z = -20 }, RightElbow = { x = 40 }, RightWrist = { x = 0 } }),
				with(WHIP_GUARD, { Root = { y = -4 }, Waist = { x = 4, y = -6 }, Neck = { x = -2, y = 8 }, RightShoulder = { x = 130, z = -15 }, RightElbow = { x = 20 }, RightWrist = { x = -10 } }),
				with(WHIP_GUARD, { Root = { y = 8, shift = Vector3.new(0, -0.1, -0.2) }, Waist = { x = -12, y = 12 }, Neck = { x = 8, y = -12 }, RightShoulder = { x = 75, z = -5 }, RightElbow = { x = 0 }, RightWrist = { x = -80 } }),
				with(WHIP_GUARD, { Root = { y = 10, shift = Vector3.new(0, -0.1, -0.2) }, Waist = { x = -16, y = 16 }, Neck = { x = 10, y = -16 }, RightShoulder = { x = 50, z = 5 }, RightElbow = { x = 5 }, RightWrist = { x = -85 } }),
				with(WHIP_GUARD, { Root = { y = 2 }, Waist = { x = -4, y = 0 }, Neck = { y = 2 }, RightShoulder = { x = 30, z = -5 }, RightElbow = { x = 20 }, RightWrist = { x = -65 } }),
				k,
				0.12
			)
		end
		return strike(
			WHIP_STANCE,
			with(WHIP_GUARD, { Root = { y = -25 }, Waist = { y = -30 }, Neck = { y = 45 }, RightShoulder = { x = 60, z = 70 }, RightElbow = { x = 40 }, RightWrist = { x = -40 } }),
			with(WHIP_GUARD, { Root = { y = -5 }, Waist = { y = -5 }, Neck = { y = 10 }, RightShoulder = { x = 80, z = 45 }, RightElbow = { x = 20 }, RightWrist = { x = -60 } }),
			with(WHIP_GUARD, { Root = { y = 20, shift = Vector3.new(0, -0.05, -0.15) }, Waist = { y = 25 }, Neck = { y = -35 }, RightShoulder = { x = 85, z = 10 }, RightElbow = { x = 0 }, RightWrist = { x = -80 } }),
			with(WHIP_GUARD, { Root = { y = 30, shift = Vector3.new(0, -0.05, -0.15) }, Waist = { y = 40 }, Neck = { y = -45 }, RightShoulder = { x = 75, z = -30 }, RightElbow = { x = 10 }, RightWrist = { x = -80 } }),
			with(WHIP_GUARD, { Root = { y = 8 }, Waist = { y = 12 }, Neck = { y = -12 }, RightShoulder = { x = 40, z = -15 }, RightElbow = { x = 20 }, RightWrist = { x = -65 } }),
			k,
			0.12
		)
	end
	local through: Pose = with(WHIP_GUARD, { Root = { y = 10, shift = Vector3.new(0, -0.3, -0.4) }, Waist = { x = -22, y = 14 }, Neck = { x = 14, y = -14 }, RightShoulder = { x = 55, z = 0 }, RightElbow = { x = 5 }, RightWrist = { x = -95 }, LeftHip = { x = 28 }, RightHip = { x = -10 }, RightKnee = { x = -18 }, LeftKnee = { x = -10 } })
	return ordered({
		{ t = 0, pose = WHIP_STANCE },
		{ t = k * 0.6, pose = with(WHIP_GUARD, { Root = { y = -15, shift = Vector3.new(0, -0.15, 0.15) }, Waist = { x = 20, y = -22 }, Neck = { x = -10, y = 24 }, RightShoulder = { x = 175, z = -25 }, RightElbow = { x = 40 }, RightWrist = { x = 10 }, RightKnee = { x = -12 }, LeftKnee = { x = -12 }, RightHip = { x = 8 }, LeftHip = { x = 8 } }), ease = "out" },
		{ t = k * 0.85, pose = with(WHIP_GUARD, { Root = { y = -2, shift = Vector3.new(0, -0.2, -0.15) }, Waist = { x = 2, y = -4 }, Neck = { x = 0, y = 6 }, RightShoulder = { x = 145, z = -15 }, RightElbow = { x = 25 }, RightWrist = { x = -20 }, LeftHip = { x = 18 }, RightKnee = { x = -12 }, LeftKnee = { x = -8 } }), ease = "in" },
		{ t = k, pose = with(WHIP_GUARD, { Root = { y = 8, shift = Vector3.new(0, -0.25, -0.35) }, Waist = { x = -18, y = 12 }, Neck = { x = 12, y = -12 }, RightShoulder = { x = 80, z = -5 }, RightElbow = { x = 0 }, RightWrist = { x = -85 }, LeftHip = { x = 26 }, RightHip = { x = -8 }, RightKnee = { x = -16 }, LeftKnee = { x = -10 } }), ease = "linear" },
		{ t = k + 0.15, pose = through, ease = "out" },
		{ t = k + 0.3, pose = through, ease = "linear" },
		{ t = 1, pose = WHIP_STANCE, ease = "out" },
	})
end

-- The lasso, its coil held up by the right shoulder (the left hand out ahead): swung round overhead (the wrist
-- turning the loop), thrown out ahead as it leaves the hand at `k`, then the rope hauled back in with a lean.
local LASSO_STANCE: Pose = { Root = { y = -5 }, Waist = { y = -8 }, Neck = { y = 8 }, RightShoulder = { x = 40, z = 30 }, RightElbow = { x = 100 }, RightWrist = { y = 0 }, LeftShoulder = { x = 35, z = 8 }, LeftElbow = { x = 55 } }
local function lasso(k: number): { Key }
	local overhead: Pose = { Waist = { x = 8, y = -12 }, Neck = { x = -4, y = 12 }, LeftShoulder = { x = 50, z = 5 }, LeftElbow = { x = 30 } }
	return ordered({
		{ t = 0, pose = LASSO_STANCE },
		{ t = k * 0.3, pose = with(overhead, { Root = { y = -10 }, RightShoulder = { x = 165, z = 25 }, RightElbow = { x = 35 }, RightWrist = { y = 160 } }), ease = "out" },
		{ t = k * 0.65, pose = with(overhead, { Root = { y = -14 }, RightShoulder = { x = 170, z = 15 }, RightElbow = { x = 30 }, RightWrist = { y = 340 } }), ease = "linear" },
		{ t = k, pose = { Root = { y = 12, shift = Vector3.new(0, -0.05, -0.2) }, Waist = { x = -12, y = 14 }, Neck = { x = 8, y = -14 }, RightShoulder = { x = 100, z = 0 }, RightElbow = { x = 0 }, RightWrist = { y = 400 }, LeftShoulder = { x = 30, z = 10 }, LeftElbow = { x = 70 } }, ease = "in" },
		{ t = k + 0.12, pose = { Root = { y = 8, shift = Vector3.new(0, -0.05, -0.2) }, Waist = { x = -8, y = 10 }, Neck = { x = 6, y = -10 }, RightShoulder = { x = 75, z = 0 }, RightElbow = { x = 15 }, RightWrist = { y = 400 }, LeftShoulder = { x = 60, z = -5 }, LeftElbow = { x = 15 } }, ease = "out" },
		-- Hauling in: both hands pull back, leaning away.
		{ t = k + 0.12 + (1 - k - 0.12) * 0.5, pose = { Root = { y = -6, shift = Vector3.new(0, -0.1, 0.15) }, Waist = { x = 12, y = -6 }, Neck = { x = -6, y = 6 }, RightShoulder = { x = 45, z = 15 }, RightElbow = { x = 95 }, RightWrist = { y = 360 }, LeftShoulder = { x = 55, z = 0 }, LeftElbow = { x = 80 } }, ease = "out" },
		{ t = 1, pose = LASSO_STANCE },
	})
end

-- The steam hose, both hands on the pipe at the hip, its nozzle ahead: braced (knees giving) as the valve opens at `k`,
-- kicked back and up by the blast, held, and settled back.
local HOSE_STANCE: Pose = { Root = { y = -10 }, Waist = { y = -12 }, Neck = { y = 18 }, RightShoulder = { x = 20, z = 5 }, RightElbow = { x = 80 }, RightWrist = { x = -88, y = 0 } }
local function hose(k: number): { Key }
	local blast: Pose = { Root = { y = -10, shift = Vector3.new(0, -0.2, 0.3) }, Waist = { x = 8, y = -12 }, Neck = { x = -6, y = 18 }, RightShoulder = { x = 24, z = 5 }, RightElbow = { x = 72 }, RightWrist = { x = -86 }, RightHip = { x = 14 }, LeftHip = { x = 24 }, RightKnee = { x = -22 }, LeftKnee = { x = -14 } }
	return ordered({
		{ t = 0, pose = HOSE_STANCE },
		{ t = k * 0.7, pose = { Root = { y = -10, shift = Vector3.new(0, -0.2, -0.05) }, Waist = { x = -8, y = -12 }, Neck = { x = 6, y = 18 }, RightShoulder = { x = 18, z = 5 }, RightElbow = { x = 82 }, RightWrist = { x = -90 }, RightHip = { x = 14 }, LeftHip = { x = 24 }, RightKnee = { x = -22 }, LeftKnee = { x = -14 } }, ease = "out" },
		{ t = k, pose = blast, ease = "in" },
		{ t = k + 0.3, pose = blast, ease = "linear" },
		{ t = 1, pose = HOSE_STANCE, ease = "out" },
	})
end

-- The oil can, held by its handle at the right side (the left fist up): swung back, then up and out ahead and tipped
-- over as the oil leaves it at `k`, held pouring a moment, and brought back.
local CAN_STANCE: Pose = { Root = { y = -5 }, Waist = { y = -8 }, Neck = { y = 8 }, RightShoulder = { x = 20, z = 8 }, RightElbow = { x = 30 }, RightWrist = { x = 0, y = 0 }, LeftShoulder = { x = 40, z = 12 }, LeftElbow = { x = 95 } }
local function oilCan(k: number): { Key }
	local pour: Pose = { Root = { y = 10, shift = Vector3.new(0, -0.1, -0.15) }, Waist = { x = -14, y = 10 }, Neck = { x = 8, y = -10 }, RightShoulder = { x = 88, z = 0 }, RightElbow = { x = 10 }, RightWrist = { x = -70 }, LeftShoulder = { x = 40, z = 12 }, LeftElbow = { x = 95 } }
	return strike(
		CAN_STANCE,
		{ Root = { y = -15 }, Waist = { x = 6, y = -20 }, Neck = { y = 20 }, RightShoulder = { x = -25, z = 10 }, RightElbow = { x = 20 }, RightWrist = { x = 10 }, LeftShoulder = { x = 40, z = 12 }, LeftElbow = { x = 95 } },
		nil,
		pour,
		pour,
		{ Root = { y = 4 }, Waist = { x = -4, y = 2 }, Neck = { y = -2 }, RightShoulder = { x = 50, z = 4 }, RightElbow = { x = 25 }, RightWrist = { x = -30 }, LeftShoulder = { x = 40, z = 12 }, LeftElbow = { x = 95 } },
		k,
		0.22
	)
end

-- The firecrackers, held up at the chest (the left fist up): slapped down at the feet, then a hop back with both arms
-- up over the face as they pop at `k`, and back.
local CRACKER_STANCE: Pose = { Root = { y = -5 }, Waist = { y = -8 }, Neck = { y = 8 }, RightShoulder = { x = 45, z = 20 }, RightElbow = { x = 110 }, LeftShoulder = { x = 40, z = 12 }, LeftElbow = { x = 95 } }
local function firecracker(k: number): { Key }
	local cover: Pose = { Root = { shift = Vector3.new(0, 0.1, 0.35) }, Waist = { x = 12 }, Neck = { x = 10 }, RightShoulder = { x = 125, z = -15 }, RightElbow = { x = 115 }, LeftShoulder = { x = 125, z = 15 }, LeftElbow = { x = 115 }, RightHip = { x = -10 }, LeftHip = { x = -10 } }
	return ordered({
		{ t = 0, pose = CRACKER_STANCE },
		{ t = k * 0.35, pose = { Root = { y = -5, shift = Vector3.new(0, 0.05, 0) }, Waist = { x = 10, y = -8 }, Neck = { y = 8 }, RightShoulder = { x = 150, z = 15 }, RightElbow = { x = 60 }, LeftShoulder = { x = 40, z = 12 }, LeftElbow = { x = 95 } }, ease = "out" },
		{ t = k * 0.65, pose = { Root = { shift = Vector3.new(0, -0.45, -0.1) }, Waist = { x = -35 }, Neck = { x = 18 }, RightShoulder = { x = 40, z = 10 }, RightElbow = { x = 10 }, LeftShoulder = { x = 45, z = 12 }, LeftElbow = { x = 60 }, RightHip = { x = 25 }, LeftHip = { x = 25 }, RightKnee = { x = -40 }, LeftKnee = { x = -40 } }, ease = "in" },
		{ t = k, pose = cover, ease = "out" },
		{ t = k + 0.25, pose = cover, ease = "linear" },
		{ t = 1, pose = CRACKER_STANCE, ease = "out" },
	})
end

-- The spare wheel, carried by both ends of its axle in front (as the gold bar): swung back low at the right side with
-- the knees bent, then bowled out low ahead with a step in as it leaves the hands at `k`, and back up.
local function wheel(k: number): { Key }
	local release: Pose = { Root = { shift = Vector3.new(0, -0.45, -0.4) }, Waist = { x = -30 }, Neck = { x = 18 }, RightShoulder = { x = 40, y = 58, z = 30 }, RightElbow = { x = 80 }, RightWrist = { x = -55, y = 20, z = -27 }, RightHip = { x = 10 }, LeftHip = { x = 35 }, RightKnee = { x = -30 }, LeftKnee = { x = -25 } }
	return ordered({
		{ t = 0, pose = GOLD_STANCE },
		{ t = k * 0.6, pose = { Root = { y = -25, shift = Vector3.new(0, -0.5, 0.15) }, Waist = { x = -20, y = -30 }, Neck = { x = 10, y = 35 }, RightShoulder = { x = 10, y = 66, z = -3 }, RightElbow = { x = 76 }, RightWrist = { x = -44, y = 18, z = -14 }, RightHip = { x = 30 }, LeftHip = { x = 30 }, RightKnee = { x = -45 }, LeftKnee = { x = -45 } }, ease = "out" },
		{ t = k, pose = release, ease = "in" },
		{ t = k + 0.18, pose = release, ease = "linear" },
		{ t = 1, pose = GOLD_STANCE, ease = "out" },
	})
end

local function only(keys: (k: number) -> { Key }): (step: number, finisher: boolean, k: number) -> { Key }
	return function(_step: number, _finisher: boolean, k: number): { Key }
		return keys(k)
	end
end

-- Each weapon's stance and attack keys, by its name (Config.Weapons); a weapon without a set of its own is drawn with
-- its style's (the first weapon of that style: the shovel swings as the bat does, coal is thrown as the stick is).
type Set = { stance: Pose, keys: (step: number, finisher: boolean, k: number) -> { Key } }
local SETS: { [string]: Set } = {
	Fist = { stance = GUARD, keys = punch },
	Bat = { stance = BAT_STANCE, keys = bat },
	GoldBar = { stance = GOLD_STANCE, keys = goldBar },
	Hammer = {
		stance = HAMMER_STANCE,
		keys = function(_step: number, _finisher: boolean, k: number): { Key }
			return hammer(k)
		end,
	},
	Dynamite = {
		stance = DYNAMITE_STANCE,
		keys = function(_step: number, _finisher: boolean, k: number): { Key }
			return dynamite(k)
		end,
	},
	Whip = { stance = WHIP_STANCE, keys = whip },
	Lasso = { stance = LASSO_STANCE, keys = only(lasso) },
	SteamHose = { stance = HOSE_STANCE, keys = only(hose) },
	OilCan = { stance = CAN_STANCE, keys = only(oilCan) },
	Firecracker = { stance = CRACKER_STANCE, keys = only(firecracker) },
	Wheel = { stance = GOLD_STANCE, keys = only(wheel) },
}
local BY_STYLE: { [string]: string } = {
	punch = "Fist",
	swing = "Bat",
	slam = "Hammer",
	throw = "Dynamite",
	toss = "Dynamite",
	lasso = "Lasso",
	spray = "SteamHose",
	pour = "OilCan",
	burst = "Firecracker",
	roll = "Wheel",
}

local function setOf(weapon: string, style: string): Set
	return SETS[weapon] or SETS[BY_STYLE[style] or "Bat"]
end

-- `a` mixed `s` of the way into `b` (a joint one of them leaves out at rest there): what a fighter switching from one
-- stance to another shows part way.
function AttackPoses.mix(a: Pose, b: Pose, s: number): Pose
	return blend(a, b, math.clamp(s, 0, 1))
end

-- The stance a fighter holding `weapon` (of `style`) keeps while fighting: bare fists' guard, or the weapon held ready.
function AttackPoses.stance(weapon: string, style: string): Pose
	return setOf(weapon, style).stance
end

-- The blocking stance (the same for every weapon).
function AttackPoses.block(): Pose
	return BLOCK
end

-- The keys of an attack with `weapon` (of `style`) at `step` of the string (`finisher`: its launching last step), the
-- blow landing at `k` (a share of the drawn length). Made once per attack; sample() reads them each frame.
function AttackPoses.keys(weapon: string, style: string, step: number, finisher: boolean, k: number): { Key }
	return setOf(weapon, style).keys(step, finisher, k)
end

-- The hand a blow of `style` at `step` strikes with (`finisher`: the string's launching last step): bare fists jab with
-- the left and throw the rest with the right (punch above); every weapon is in the right hand.
function AttackPoses.hand(style: string, step: number, finisher: boolean): string
	return if style == "punch" and not finisher and step % 2 == 1 then "LeftHand" else "RightHand"
end

-- `pose` with the whole body shaken along a hit's push (`back`, `side` as for react) `t` seconds into a hit that holds
-- the body still `hold` seconds: `studs` each way at first, flipping every frame (1/60 s) and dying out by the end of
-- the hold, so the blow reads as landing (Sakurai's hitstop shake). Unchanged outside the hold.
function AttackPoses.shaken(pose: Pose, t: number, hold: number, studs: number, back: number, side: number): Pose
	if t < 0 or t >= hold or studs <= 0 then
		return pose
	end
	local flip = if math.floor(t * 60) % 2 == 0 then 1 else -1
	local amount = studs * (1 - t / hold) * flip
	local root: Joint = pose.Root or {}
	local out = table.clone(pose)
	out.Root = { x = root.x, y = root.y, z = root.z, shift = (root.shift or Vector3.zero) + Vector3.new(side, 0, back) * amount }
	return out
end

-- A hit reaction ("light" or a launch), `u` (0..1) through it. `back` and `side` say which way the hit pushed, in the
-- body's own frame (back: +1 straight backward, -1 forward; side: +1 to its right): a light hit snaps the torso and
-- head that way at once, knocks the arms open and eases back into `stance` (the fighter's stance; nil: none); a launch
-- throws the arms up and flails them while flying, the whole body tumbling `turns` times (default none) head over heels
-- the way it was pushed (a backflip when pushed back, a cartwheel when pushed sideways) over the first TUMBLE share
-- of it: whole turns, so the flail settles from upright.
function AttackPoses.react(kind: string, u: number, back: number, side: number, stance: Pose?, turns: number?): Pose
	if kind == "light" then
		local peak: Pose = {
			Waist = { x = 20 * back, y = -10 * side, z = -14 * side },
			Neck = { x = 16 * back, y = -16 * side, z = -10 * side },
			RightShoulder = { x = 30, z = 28 + 15 * math.max(side, 0) },
			LeftShoulder = { x = 30, z = -28 - 15 * math.max(-side, 0) },
			RightElbow = { x = 55 },
			LeftElbow = { x = 55 },
		}
		-- The stance's joints the flinch does not move (a weapon's hips, its wrist) stay as the stance has them.
		local held = if stance then with(stance, peak) else peak
		if u <= 0.25 then
			return held
		end
		return blend(held, stance or REST, ease(nil, (u - 0.25) / 0.75))
	end
	local wave = math.sin(u * math.pi * 6) * 30 * (1 - u) -- the arms flail, less as the flight ends
	local spin = 360 * math.floor(turns or 0) * ease("out", math.min(u / TUMBLE, 1))
	if u >= TUMBLE then
		spin = 0 -- a whole number of turns: the same as upright
	end
	local root: Joint = if math.abs(back) >= math.abs(side) then { x = spin * (if back >= 0 then 1 else -1) } else { z = -spin * (if side >= 0 then 1 else -1) }
	local flail: Pose = {
		Root = root,
		Waist = { x = 14 * back },
		Neck = { x = 18 },
		RightShoulder = { x = 150 + wave, z = 25 },
		LeftShoulder = { x = 150 - wave, z = -25 },
		RightHip = { x = 30 - wave * 0.5 },
		LeftHip = { x = -10 + wave * 0.5 },
	}
	if u <= 0.6 then
		return flail
	end
	return blend(flail, REST, ease(nil, (u - 0.6) / 0.4))
end

-- A dodge roll at share `u` of it (decision 22), rolling along `back` (the body's own +Z: backward) and `side` (+X: to
-- its right): tucked in - bent forward, knees up, arms in - over all but its first and last moments, turning once
-- head over heels the way it rolls (over a shoulder, sideways, when it rolls more to a side), a little lower at its
-- middle so the tucked body stays on the roof. A whole turn ends upright: no snap back.
function AttackPoses.roll(u: number, back: number, side: number): Pose
	local tuck = ease(nil, math.clamp(math.min(u, 1 - u) / 0.2, 0, 1))
	local spin = 360 * ease(nil, math.clamp((u - 0.05) / 0.85, 0, 1))
	local low = Vector3.new(0, -0.8 * math.sin(math.pi * math.clamp(u, 0, 1)), 0)
	local root: Joint = if math.abs(back) >= math.abs(side)
		then { x = spin * (if back >= 0 then 1 else -1), shift = low }
		else { z = -spin * (if side >= 0 then 1 else -1), shift = low }
	return {
		Root = root,
		Waist = { x = -35 * tuck },
		Neck = { x = -25 * tuck },
		RightShoulder = { x = 70 * tuck, z = 12 * tuck },
		LeftShoulder = { x = 70 * tuck, z = -12 * tuck },
		RightElbow = { x = 95 * tuck },
		LeftElbow = { x = 95 * tuck },
		RightHip = { x = 85 * tuck },
		LeftHip = { x = 85 * tuck },
		RightKnee = { x = -105 * tuck },
		LeftKnee = { x = -105 * tuck },
	}
end

return AttackPoses
