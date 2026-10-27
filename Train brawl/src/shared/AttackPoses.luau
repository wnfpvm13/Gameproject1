--!strict
-- The whole-body poses of every attack and hit reaction, as keyframes over the joints of an R15 body (no uploaded
-- animation): the hips and torso turn into a blow, the free arm guards, the head keeps facing ahead. Each attack style
-- has its own (Config.Weapons style), and a punch or swing has its own pose for each step of the attacker's string
-- (AttackString); the launching last step is plainly bigger and starts with a wind-up (it lands a moment later than
-- the others: Config.Attack.FinisherWindup). A style can have a stance (stance()): the pose a fighter holding it keeps
-- while fighting, standing or walking (bare fists: a boxing guard); its attacks start from it and come back to it, and
-- a light hit's flinch settles back into it.
-- - punch: from the guard, 1 a left jab, 2 a right straight (then 1, 2 again), the last a dip into a rising uppercut
--   with a short step in. The hips turn first, the torso and shoulder follow and the elbow straightens last, as the
--   blow lands; the arm stays out only a moment and snaps back to the guard;
-- - swing: 1 a forehand, 2 a backhand, the last a big forehand with a step in that carries on into a full spin;
-- - slam: both arms overhead, leaning back, then bent over the slam with the knees giving;
-- - throw: wound back over the shoulder, then the torso turns through the throw;
-- - hit reactions: a light hit snaps the torso and head the way the hit pushed (back when hit from the front, forward
--   from behind, sideways from the side); a launch flails the arms while flying.
-- Each segment between keys has its own easing: a blow speeds into the hit and carries on through it (no stop at the
-- hit), a spin turns evenly. A pose is each joint's turn (degrees, about the joint's own axes: x raises an arm forward
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

local JOINTS = { "Root", "Waist", "Neck", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightHip", "LeftHip", "RightKnee", "LeftKnee" }

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
local GUARD_LEFT: Pose = { LeftShoulder = { x = 45 }, LeftElbow = { x = 100 } }

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

-- How far toward rest the last key of a blow has come back: SwingPose blends the rest of the way out to the walking
-- animation (a last key at rest would pull the body through standing straight on its way back to walking).
local SETTLE = 0.5

-- The usual shape of a blow: rest, wound up by `windUp`, speeding into the hit at `k`, held a moment, settling back.
local function blow(cocked: Pose, out: Pose, follow: Pose, k: number, windUp: number, hold: number): { Key }
	return ordered({
		{ t = 0, pose = REST },
		{ t = k * windUp, pose = cocked },
		{ t = k, pose = out, ease = "in" },
		{ t = k + hold, pose = follow, ease = "out" },
		{ t = 1, pose = blend(follow, REST, SETTLE) },
	})
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

-- The weapon arm lifted out to the right side (`lift` 0..1) and swung round the torso by `turn` degrees (negative =
-- toward the back, positive = across the front).
local function arm(lift: number, turn: number): Joint
	return { y = turn, z = 90 * lift }
end

local function swing(step: number, finisher: boolean, k: number): { Key }
	local cocked = with(GUARD_LEFT, { Waist = { y = -28 }, RightShoulder = arm(1, -40), Neck = { y = 14 } })
	local through = with(GUARD_LEFT, { Waist = { y = 18 }, RightShoulder = arm(1, 90), Neck = { y = -8 } })
	if not finisher then
		if step % 2 == 0 then -- a backhand: from across the body on the left out to the right, pointing ahead as it lands
			local back = with(GUARD_LEFT, { Waist = { y = 30 }, RightShoulder = arm(1, 120), Neck = { y = -14 } })
			local hit = with(GUARD_LEFT, { RightShoulder = arm(1, 85) })
			local follow = with(GUARD_LEFT, { Waist = { y = -32 }, RightShoulder = arm(0.9, -50), Neck = { y = 14 } })
			return blow(back, hit, follow, k, 0.6, 0.3)
		end
		local follow = with(GUARD_LEFT, { Waist = { y = 36 }, RightShoulder = arm(0.9, 130), Neck = { y = -16 } })
		return blow(cocked, through, follow, k, 0.6, 0.3)
	end
	-- The finisher: a bigger forehand with a step in that carries on round into a full spin, arm out.
	local wound = with(cocked, { Root = { shift = Vector3.new(0, -0.2, 0.2) }, Waist = { y = -40 }, RightKnee = { x = -20 }, LeftKnee = { x = -20 } })
	local hit = with(through, { Root = { y = 0, shift = Vector3.new(0, 0, -0.5) }, LeftHip = { x = 25 }, RightHip = { x = -15 } })
	local spinning = with(GUARD_LEFT, { Root = { y = 200, shift = Vector3.new(0, 0, -0.5) }, RightShoulder = arm(1, 70) })
	local round = with(GUARD_LEFT, { Root = { y = 360, shift = Vector3.new(0, 0, -0.3) }, RightShoulder = arm(0.6, 40) })
	return ordered({
		{ t = 0, pose = REST },
		{ t = k * 0.65, pose = wound },
		{ t = k, pose = hit, ease = "in" },
		{ t = k + (1 - k) * 0.45, pose = spinning, ease = "linear" },
		{ t = k + (1 - k) * 0.8, pose = round, ease = "linear" },
		-- Half way back like any blow; the root keeps its whole turn (the same as none) instead of unwinding half of it.
		{ t = 1, pose = with(blend(round, REST, SETTLE), { Root = { y = 360, shift = Vector3.new(0, 0, -0.15) } }), ease = "out" },
	})
end

local function slam(k: number): { Key }
	-- Both hands on the handle: the left arm follows the right.
	local up: Pose = { Waist = { x = 16 }, Neck = { x = -8 }, RightShoulder = { x = 185 }, LeftShoulder = { x = 185 }, RightElbow = { x = 20 }, LeftElbow = { x = 20 } }
	local down: Pose = {
		Root = { shift = Vector3.new(0, -0.45, -0.2) },
		Waist = { x = -28 },
		Neck = { x = 14 },
		RightShoulder = { x = 75 },
		LeftShoulder = { x = 75 },
		RightKnee = { x = -35 },
		LeftKnee = { x = -35 },
		RightHip = { x = 20 },
		LeftHip = { x = 20 },
	}
	return blow(up, down, down, k, 0.85, 0.2)
end

-- The stick leaves the hand at `k`, with the arm on its way forward over the shoulder (wound back before it, followed
-- through low after).
local function throw(k: number): { Key }
	local back: Pose = { Waist = { x = 8, y = -30 }, Neck = { y = 18 }, RightShoulder = { x = 170 }, RightElbow = { x = 60 }, LeftShoulder = { x = 70 } }
	local out: Pose = { Waist = { x = -8, y = 26 }, Neck = { y = -10 }, RightShoulder = { x = 40 }, RightElbow = { x = 10 }, LeftShoulder = { x = 20 } }
	return ordered({
		{ t = 0, pose = REST },
		{ t = k * 0.6, pose = back },
		{ t = k, pose = blend(back, out, 0.5), ease = "in" },
		{ t = math.min(k + 0.25, 0.9), pose = out, ease = "out" },
		{ t = 1, pose = blend(out, REST, SETTLE) },
	})
end

-- The stance a fighter holding a weapon of `style` keeps while fighting (nil: none, the walking animation as it is).
function AttackPoses.stance(style: string): Pose?
	return if style == "punch" then GUARD else nil
end

-- The keys of an attack of `style` at `step` of the string (`finisher`: its launching last step), the blow landing
-- at `k` (a share of the drawn length). Made once per attack; sample() reads them each frame.
function AttackPoses.keys(style: string, step: number, finisher: boolean, k: number): { Key }
	if style == "punch" then
		return punch(step, finisher, k)
	elseif style == "slam" then
		return slam(k)
	elseif style == "throw" then
		return throw(k)
	end
	return swing(step, finisher, k)
end

-- A hit reaction ("light" or a launch), `u` (0..1) through it. `back` and `side` say which way the hit pushed, in the
-- body's own frame (back: +1 straight backward, -1 forward; side: +1 to its right): a light hit snaps the torso and
-- head that way at once, knocks the arms open and eases back into `stance` (the fighter's stance; nil: none); a launch
-- throws the arms up and flails them while flying.
function AttackPoses.react(kind: string, u: number, back: number, side: number, stance: Pose?): Pose
	if kind == "light" then
		local peak: Pose = {
			Waist = { x = 20 * back, y = -10 * side, z = -14 * side },
			Neck = { x = 16 * back, y = -16 * side, z = -10 * side },
			RightShoulder = { x = 30, z = 28 + 15 * math.max(side, 0) },
			LeftShoulder = { x = 30, z = -28 - 15 * math.max(-side, 0) },
			RightElbow = { x = 55 },
			LeftElbow = { x = 55 },
		}
		if u <= 0.25 then
			return peak
		end
		return blend(peak, stance or REST, ease(nil, (u - 0.25) / 0.75))
	end
	local wave = math.sin(u * math.pi * 6) * 30 * (1 - u) -- the arms flail, less as the flight ends
	local flail: Pose = {
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

return AttackPoses
