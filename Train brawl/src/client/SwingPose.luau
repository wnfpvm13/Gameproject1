--!strict
-- Draws attacks and hit reactions on every client, for every character, by turning its R15 joints (no uploaded
-- animation): the poses are AttackPoses' (each weapon style's own, each step of the attacker's string its own, the
-- launching last step bigger, drawn Config.Attack.FinisherStretch times longer and landing a moment later), timed
-- over the weapon's `seconds` with the blow when AttackString says it lands. An attack starts at the character's
-- Names.SwingAt (server time, set by WeaponService with Names.SwingWeapon and Names.SwingStep), or at once for the
-- player's own (play(); redrawn as another step when the server counted it differently, restep()). A hit reaction
-- (react(): a light hit's flinch the way the hit pushed, a launch's flail) takes over from an attack at once, and no
-- attack is drawn over a flail; an attack taking over from another pose fades from where that one left each joint
-- (FADE), the joints it does not turn back to the animation. The pose is blended in from what the walking or idle
-- animation shows and back out to it (no snap through standing straight). The joints are written in
-- RunService.Stepped, after the Animator has written them for the frame (a value written in RenderStepped is
-- overwritten before it is drawn - learned in Western train's CowboyPose), and put straight each frame just before
-- the Animator runs (RunService.PreAnimation): so what Stepped finds is the animation's pose - straight for a joint no
-- animation moves - and a pose that ends simply stops (writing joints straight in Stepped would show a frame of
-- standing straight; they are put straight once more before the next animation step). When a blow lands, its
-- attacker's pose pauses for the hit's hold (hold()), as the victim holds still. Under all of it, every fighter
-- followed (follow()) keeps the stance of what it holds (AttackPoses.stance: bare fists' guard) while it is in a round
-- that is counting down or fighting and on its feet, coming up and going down over STANCE_BLEND (at once when it is
-- knocked flying or takes up a weapon with none) and showing less while running fast (the arms swing a little): what
-- an attack or a hit reaction blends from and back to.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local AttackString = require(shared:WaitForChild("AttackString"))
local AttackPoses = require(shared:WaitForChild("AttackPoses"))

local SwingPose = {}

local STRING = AttackString.rules(Config.Attack)
local BLEND_IN = 0.12 -- an attack blends in from the animation over this share of it
local BLEND_OUT = 0.2 -- and back out over its last this share
local FADE = 0.08 -- an attack taking over from another pose fades from it over this many seconds
local STANCE_BLEND = 0.15 -- a stance comes up or goes down over this many seconds
-- A stance shows fully up to RUN_FROM studs a second along the ground and RUN_LEAST of it from RUN_TO.
local RUN_FROM, RUN_TO, RUN_LEAST = 10, 16, 0.6

-- A pose being drawn on a character: its joints, what kind ("attack", "light" or "flail"), when it started (server
-- time for attacks, os.clock for reactions) and how long it lasts, the pose at a share of it, how it blends in, and
-- what was written to each joint last (put straight before each animation step, and faded from by the next pose).
-- holdFrom/holdUntil: a hold on the pose (when a blow lands): time stands still for the drawing between them.
-- fadeFrom/fadeAt: where the pose it took over from left each joint, and when (os.clock) it took over.
type Drawing = {
	joints: { [string]: CharacterParts.Joint },
	kind: string,
	start: number,
	length: number,
	clock: () -> number,
	pose: (u: number) -> AttackPoses.Pose,
	blendIn: number,
	written: { [string]: CFrame },
	holdFrom: number?,
	holdUntil: number?,
	fadeFrom: { [string]: CFrame }?,
	fadeAt: number,
}
local drawing: { [Model]: Drawing } = {}
-- Joints a pose wrote that is over or replaced: put straight once before the next animation step.
local loose: { CharacterParts.Joint } = {}
-- A fighter's stance: the pose (the last one it had, while going down), how much of it shows (0..1), the joints found
-- for it and the ones it wrote this frame.
type Stance = { pose: AttackPoses.Pose?, weight: number, joints: { [string]: CharacterParts.Joint }, written: { [string]: boolean } }
local stances: { [Model]: Stance } = {}

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- Calls `each` on the joints of `joints` named in `written` (the joints a drawing or a stance wrote).
local function eachWritten(joints: { [string]: CharacterParts.Joint }, written: { [string]: any }, each: (CharacterParts.Joint) -> ())
	for name in written do
		local joint = joints[name]
		if joint then
			each(joint)
		end
	end
end

-- Puts `joint` straight once before the next animation step.
local function loosen(joint: CharacterParts.Joint)
	table.insert(loose, joint)
end

-- Hands the joints the drawing wrote back to the animation.
local function release(d: Drawing)
	eachWritten(d.joints, d.written, loosen)
end

-- Puts `joint` straight (when the character is still in the world). Both joint kinds have Transform; the type checker
-- cannot read or write through the union.
local function straighten(joint: CharacterParts.Joint)
	if joint:IsDescendantOf(Workspace) then
		(joint :: any).Transform = CFrame.identity
	end
end

-- Starts drawing on `model` (replacing what was drawn on it; `fade`: from where that left each joint).
local function begin(model: Model, kind: string, start: number, length: number, clock: () -> number, pose: (number) -> AttackPoses.Pose, blendIn: number, fade: boolean)
	local before = drawing[model]
	local from = if fade and before and next(before.written) then table.clone(before.written) else nil
	if before then
		release(before)
	end
	local joints = CharacterParts.joints(model)
	if next(joints) == nil then
		drawing[model] = nil
		return
	end
	drawing[model] = {
		joints = joints,
		kind = kind,
		start = start,
		length = length,
		clock = clock,
		pose = pose,
		blendIn = blendIn,
		written = {},
		fadeFrom = from,
		fadeAt = os.clock(),
	}
end

-- The joint turn of a pose's joint.
local function frameOf(turn: AttackPoses.Joint): CFrame
	local frame = CFrame.Angles(math.rad(turn.x or 0), math.rad(turn.y or 0), math.rad(turn.z or 0))
	return if turn.shift then CFrame.new(turn.shift) * frame else frame
end

-- The stance `model` keeps now (nil: none), and whether one it had goes down gently: when the round is not counting
-- down or fighting, or the fighter is out of it. Flying, lying fallen or holding a weapon with no stance, it goes at
-- once (another pose takes over, and would show a stance's bent elbow it does not turn).
local function stanceOf(model: Model): (AttackPoses.Pose?, boolean)
	local phase = Workspace:GetAttribute(Names.Phase)
	if model:GetAttribute(Names.Alive) ~= true or (phase ~= "Fight" and phase ~= "Countdown") then
		return nil, true
	end
	local body = CharacterParts.body(model)
	if not body or body.humanoid.Health <= 0 then
		return nil, true
	end
	local now = drawing[model]
	if body.humanoid.PlatformStand or (now and now.kind == "flail") then
		return nil, false -- the flail may come before the stiffness reaches this client
	end
	local weapon = WeaponRules.named(Config.Weapons, model:GetAttribute(Names.Weapon))
	local stance = AttackPoses.stance(Config.Weapons[weapon].style)
	return stance, stance ~= nil
end

-- How much of a stance shows at `model`'s speed along the ground.
local function runShare(model: Model): number
	local body = CharacterParts.body(model)
	if not body then
		return 1
	end
	local v = body.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	return 1 - (1 - RUN_LEAST) * math.clamp((speed - RUN_FROM) / (RUN_TO - RUN_FROM), 0, 1)
end

-- The joints of `model` for `pose`, found again when one it turns is missing or gone (any of its body parts replaced,
-- or one arriving late).
local function stanceJoints(model: Model, stance: Stance, pose: AttackPoses.Pose): { [string]: CharacterParts.Joint }
	for name in pose do
		local joint = stance.joints[name]
		if not (joint and joint:IsDescendantOf(model)) then
			stance.joints = CharacterParts.joints(model)
			break
		end
	end
	return stance.joints
end

-- Hands the joints a stance wrote back to the animation.
local function dropStance(stance: Stance)
	eachWritten(stance.joints, stance.written, loosen)
	table.clear(stance.written)
end

-- How far through its move a drawing is, 0..1 (time stands still during its hold).
local function progress(d: Drawing): number
	local now = d.clock()
	local from, untilAt = d.holdFrom, d.holdUntil
	local elapsed = now - d.start
	if from and untilAt then
		elapsed -= math.clamp(now, from, untilAt) - from
	end
	return elapsed / d.length
end

-- How much of the pose shows at `u` (0..1): blended in from the animation at the start and back out at the end.
local function weight(d: Drawing, u: number): number
	local into = if d.blendIn > 0 then math.min(u / d.blendIn, 1) else 1
	local out = math.min((1 - u) / BLEND_OUT, 1)
	local w = math.min(into, out)
	return w * w * (3 - 2 * w)
end

RunService.PreAnimation:Connect(function()
	for _, joint in loose do
		straighten(joint)
	end
	table.clear(loose)
	for _, stance in stances do
		eachWritten(stance.joints, stance.written, straighten)
	end
	for _, d in drawing do
		eachWritten(d.joints, d.written, straighten)
	end
end)

-- Writes `value` to the drawing's joint `name` (remembered for the next frame and the next pose).
local function write(d: Drawing, name: string, motor: any, value: CFrame)
	motor.Transform = value
	d.written[name] = value
end

RunService.Stepped:Connect(function(_time: number, dt: number)
	-- The stances first: the animation's pose with the stance over it is what the drawings below blend from.
	for model, stance in stances do
		if not model.Parent then
			stances[model] = nil
			dropStance(stance)
			continue
		end
		local pose, gentle = stanceOf(model)
		if pose then
			stance.pose = pose
		end
		if pose or gentle then
			local target = if pose then runShare(model) else 0
			local step = dt / STANCE_BLEND
			stance.weight = if stance.weight < target then math.min(stance.weight + step, target) else math.max(stance.weight - step, target)
		else
			stance.weight = 0
		end
		local shown = stance.pose
		if stance.weight <= 0 or not shown then
			dropStance(stance)
			continue
		end
		local joints = stanceJoints(model, stance, shown)
		local w = stance.weight * stance.weight * (3 - 2 * stance.weight)
		for name, turn in shown do
			local joint = joints[name]
			if joint and joint:IsDescendantOf(Workspace) then
				local motor = joint :: any
				motor.Transform = (motor.Transform :: CFrame):Lerp(frameOf(turn), w)
				stance.written[name] = true
			end
		end
	end
	for model, d in drawing do
		local u = progress(d)
		local root = d.joints.Root or d.joints.Waist
		if u >= 1 or not (root and root:IsDescendantOf(Workspace)) then
			drawing[model] = nil
			release(d)
		elseif u >= 0 then
			local w = weight(d, u)
			local fade = d.fadeFrom
			local faded = if fade then math.min((os.clock() - d.fadeAt) / FADE, 1) else 1
			if faded >= 1 then
				fade = nil
				d.fadeFrom = nil
			end
			local s = faded * faded * (3 - 2 * faded)
			local pose = d.pose(u)
			for name, turn in pose do
				local joint = d.joints[name]
				if joint then
					-- The animation's pose for this frame is in the joint already (the Animator's, or straight, with the
					-- stance over it): blend from it.
					local motor = joint :: any
					local value = (motor.Transform :: CFrame):Lerp(frameOf(turn), w)
					local left = if fade then fade[name] else nil
					write(d, name, motor, if left then left:Lerp(value, s) else value)
				end
			end
			if fade then
				-- The joints the pose taken over from turned and this one does not, back to the animation.
				for name, left in fade do
					local joint = d.joints[name]
					if joint and not pose[name] then
						local motor = joint :: any
						write(d, name, motor, left:Lerp(motor.Transform, s))
					end
				end
			end
		end
	end
end)

-- Starts drawing an attack of `model` with `weapon` at `step` of its string, begun at server time `at` (not over a
-- flail still being drawn: an attack pressed just before a launch landed).
function SwingPose.play(model: Model, at: number, weapon: string, step: number)
	local now = drawing[model]
	if now and now.kind == "flail" then
		return
	end
	local name = WeaponRules.named(Config.Weapons, weapon)
	local w = Config.Weapons[name]
	local finisher = AttackString.launches(STRING, step, w.style)
	local length = w.seconds * (if finisher then Config.Attack.FinisherStretch else 1)
	local k = math.clamp(AttackString.hitAt(STRING, w.hitAt, step, w.style) / length, 0.1, 0.9) -- the blow, as a share of the move
	local keys = AttackPoses.keys(w.style, step, finisher, k)
	begin(model, "attack", at, length, serverNow, function(u: number): AttackPoses.Pose
		return AttackPoses.sample(keys, u)
	end, BLEND_IN, true)
end

-- The player's own attack begun at `at` and still being drawn is drawn as `step` from now on (the server counted it
-- differently): the same start and hold, faded over from the step drawn so far.
function SwingPose.restep(model: Model, at: number, weapon: string, step: number)
	local before = drawing[model]
	if not (before and before.kind == "attack" and before.start == at) then
		return -- already over, or something else took over
	end
	SwingPose.play(model, at, weapon, step)
	local now = drawing[model]
	if now and now ~= before then
		now.holdFrom, now.holdUntil = before.holdFrom, before.holdUntil
	end
end

-- A blow of `model`'s landed: its attack pose stands still `seconds` from now (the hold that makes a hit land, on both
-- sides). One hold per attack: a blow landing on several fighters, or the server's word after this client's own, holds
-- it no longer than the longest of them.
function SwingPose.hold(model: Model, seconds: number)
	local d = drawing[model]
	if not (d and d.kind == "attack") or seconds <= 0 then
		return
	end
	local from = d.holdFrom
	if from then
		d.holdUntil = math.max(d.holdUntil or from, from + seconds)
	else
		local now = d.clock()
		d.holdFrom, d.holdUntil = now, now + seconds
	end
end

-- A hit on `model` of `kind` ("light", "launch" or "smash") that pushed it along `push`: its reaction, starting now
-- (snapping in at once).
function SwingPose.react(model: Model, kind: string, push: Vector3?)
	local body = CharacterParts.body(model)
	local back, side = 1, 0 -- straight back when the push is unknown
	if body and push then
		local flat = body.root.CFrame:VectorToObjectSpace(Vector3.new(push.X, 0, push.Z))
		if flat.Magnitude > 1e-3 then
			flat = flat.Unit
			back, side = flat.Z, flat.X -- the body's own +Z is backward
		end
	end
	local light = kind == "light"
	local length = if light then AttackPoses.FlinchSeconds else AttackPoses.FlailSeconds
	-- A flinch settles back into the stance the fighter keeps.
	local stance = stances[model]
	local settle = if stance and stance.weight > 0 then stance.pose else nil
	begin(model, if light then "light" else "flail", os.clock(), length, os.clock, function(u: number): AttackPoses.Pose
		return AttackPoses.react(kind, u, back, side, settle)
	end, 0, false)
end

-- Follows a character's Names.SwingAt (every attack the server takes) and keeps its stance. `skip(at, step)` returns
-- true for an attack this client already drew (the player's own, started at once); `heard(weapon, step)` sounds the
-- others. Returns the connection.
function SwingPose.follow(model: Model, skip: (number, number) -> boolean, heard: (string, number) -> ()): RBXScriptConnection
	if not stances[model] then
		stances[model] = { pose = nil, weight = 0, joints = {}, written = {} }
	end
	return model:GetAttributeChangedSignal(Names.SwingAt):Connect(function()
		local at = model:GetAttribute(Names.SwingAt)
		local raw = model:GetAttribute(Names.SwingStep)
		local step = if typeof(raw) == "number" then raw else 1
		if typeof(at) == "number" and not skip(at, step) then
			local weapon = WeaponRules.named(Config.Weapons, model:GetAttribute(Names.SwingWeapon))
			SwingPose.play(model, at, weapon, step)
			heard(weapon, step)
		end
	end)
end

return SwingPose
