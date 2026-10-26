--!strict
-- Draws attacks and hit reactions on every client, for every character, by turning its R15 joints (no uploaded
-- animation): the poses are AttackPoses' (each weapon style's own, each step of the attacker's string its own, the
-- launching last step bigger, drawn Config.Attack.FinisherStretch times longer and landing a moment later), timed
-- over the weapon's `seconds` with the blow when AttackString says it lands. An attack starts at the character's
-- Names.SwingAt (server time, set by WeaponService with Names.SwingWeapon and Names.SwingStep), or at once for the
-- player's own (play()). A hit reaction (react(): a light hit's flinch the way the hit pushed, a launch's flail) takes
-- over from an attack, and no attack is drawn over a flail. The pose is blended in from what the walking or idle
-- animation shows and back out to it (no snap through standing straight). The joints are written in
-- RunService.Stepped, after the Animator has written them for the frame (a value written in RenderStepped is
-- overwritten before it is drawn - learned in Western train's CowboyPose), and put straight once a pose ends so the
-- Animator has them back.
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

-- A pose being drawn on a character: its joints, what kind ("attack", "light" or "flail"), when it started (server
-- time for attacks, os.clock for reactions) and how long it lasts, the pose at a share of it, how it blends in, and
-- the joints written so far (put straight at the end).
type Drawing = {
	joints: { [string]: CharacterParts.Joint },
	kind: string,
	start: number,
	length: number,
	clock: () -> number,
	pose: (u: number) -> AttackPoses.Pose,
	blendIn: number,
	touched: { [string]: boolean },
}
local drawing: { [Model]: Drawing } = {}

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- Puts every joint the drawing wrote back to straight (when the character is still in the world).
local function release(d: Drawing)
	for name in d.touched do
		local joint = d.joints[name]
		if joint and joint:IsDescendantOf(Workspace) then
			(joint :: any).Transform = CFrame.identity
		end
	end
end

-- Starts drawing on `model` (replacing what was drawn on it).
local function begin(model: Model, kind: string, start: number, length: number, clock: () -> number, pose: (number) -> AttackPoses.Pose, blendIn: number)
	local before = drawing[model]
	if before then
		release(before)
	end
	local joints = CharacterParts.joints(model)
	if next(joints) == nil then
		drawing[model] = nil
		return
	end
	drawing[model] = { joints = joints, kind = kind, start = start, length = length, clock = clock, pose = pose, blendIn = blendIn, touched = {} }
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
		local u = (d.clock() - d.start) / d.length
		local root = d.joints.Root or d.joints.Waist
		if u >= 1 or not (root and root:IsDescendantOf(Workspace)) then
			drawing[model] = nil
			release(d)
		elseif u >= 0 then
			local w = weight(d, u)
			for name, turn in d.pose(u) do
				local joint = d.joints[name]
				if joint then
					local frame = CFrame.Angles(math.rad(turn.x or 0), math.rad(turn.y or 0), math.rad(turn.z or 0))
					if turn.shift then
						frame = CFrame.new(turn.shift) * frame
					end
					-- The Animator has written this frame's pose already: blend from it. (Both joint kinds have
					-- Transform; the type checker cannot read or write through the union.)
					local motor = joint :: any
					local animated: CFrame = motor.Transform
					motor.Transform = animated:Lerp(frame, w)
					d.touched[name] = true
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
	end, BLEND_IN)
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
	end, 0)
end

-- Follows a character's Names.SwingAt (every attack the server takes). `skip(at, step)` returns true for an attack
-- this client already drew (the player's own, started at once); `heard(weapon)` sounds the others. Returns the
-- connection.
function SwingPose.follow(model: Model, skip: (number, number) -> boolean, heard: (string) -> ()): RBXScriptConnection
	return model:GetAttributeChangedSignal(Names.SwingAt):Connect(function()
		local at = model:GetAttribute(Names.SwingAt)
		local raw = model:GetAttribute(Names.SwingStep)
		local step = if typeof(raw) == "number" then raw else 1
		if typeof(at) == "number" and not skip(at, step) then
			local weapon = WeaponRules.named(Config.Weapons, model:GetAttribute(Names.SwingWeapon))
			SwingPose.play(model, at, weapon, step)
			heard(weapon)
		end
	end)
end

return SwingPose
