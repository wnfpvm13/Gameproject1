--!strict
-- Draws attacks and hit reactions on every client, for every character, by turning its R15 joints (no uploaded
-- animation): the poses are AttackPoses' (each weapon style's own, each step of the attacker's string its own, the
-- launching last step bigger, drawn Config.Attack.FinisherStretch times longer and landing a moment later), timed
-- over the weapon's `seconds` with the blow when AttackString says it lands. An attack starts at the character's
-- Names.SwingAt (server time, set by WeaponService with Names.SwingWeapon and Names.SwingStep), or at once for the
-- player's own (play(); redrawn as another step when the server counted it differently, restep()). A hit reaction
-- (react(): a light hit's flinch the way the hit pushed, a launch's flail) takes over from an attack at once, and no
-- attack is drawn over a flail; an attack taking over from another pose fades from where that one left each joint
-- (FADE). The pose is blended in from what the walking or idle animation shows and back out to it (no snap through
-- standing straight); a joint no animation moves blends from and back to straight instead. The joints are written in
-- RunService.Stepped, after the Animator has written them for the frame (a value written in RenderStepped is
-- overwritten before it is drawn - learned in Western train's CowboyPose); when a pose ends, the joints the Animator
-- moves are simply left to it (writing them straight there would show one frame of standing straight) and the others
-- put straight. When a blow lands, its attacker's pose pauses for the hit's hold (hold()), as the victim holds still.
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

-- A pose being drawn on a character: its joints, what kind ("attack", "light" or "flail"), when it started (server
-- time for attacks, os.clock for reactions) and how long it lasts, the pose at a share of it, how it blends in, and
-- what was written to each joint last (to tell a joint no animation moves, and to fade the next pose from).
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

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- Hands the joints the drawing wrote back (when the character is still in the world): each one still holding what
-- was written last is put straight - between frames that is every one (the Animator writes its own again before the
-- next is drawn); at a pose's end, in Stepped, only those no animation moves (the others show the animation already).
local function release(d: Drawing)
	for name, value in d.written do
		local joint = d.joints[name]
		if joint and joint:IsDescendantOf(Workspace) and (joint :: any).Transform == value then
			(joint :: any).Transform = CFrame.identity
		end
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

RunService.Stepped:Connect(function()
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
				d.fadeFrom = nil
			end
			for name, turn in d.pose(u) do
				local joint = d.joints[name]
				if joint then
					local frame = CFrame.Angles(math.rad(turn.x or 0), math.rad(turn.y or 0), math.rad(turn.z or 0))
					if turn.shift then
						frame = CFrame.new(turn.shift) * frame
					end
					-- The Animator has written this frame's pose already: blend from it - from straight for a joint
					-- still holding what was written last frame (no animation moves it). (Both joint kinds have
					-- Transform; the type checker cannot read or write through the union.)
					local motor = joint :: any
					local seen: CFrame = motor.Transform
					local animated = if d.written[name] == seen then CFrame.identity else seen
					local value = animated:Lerp(frame, w)
					local left = if fade and faded < 1 then fade[name] else nil
					if left then
						value = left:Lerp(value, faded * faded * (3 - 2 * faded))
					end
					motor.Transform = value
					d.written[name] = value
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
	begin(model, if light then "light" else "flail", os.clock(), length, os.clock, function(u: number): AttackPoses.Pose
		return AttackPoses.react(kind, u, back, side)
	end, 0, false)
end

-- Follows a character's Names.SwingAt (every attack the server takes). `skip(at, step)` returns true for an attack
-- this client already drew (the player's own, started at once); `heard(weapon, step)` sounds the others. Returns the
-- connection.
function SwingPose.follow(model: Model, skip: (number, number) -> boolean, heard: (string, number) -> ()): RBXScriptConnection
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
