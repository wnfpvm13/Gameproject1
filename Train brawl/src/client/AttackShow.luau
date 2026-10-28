--!strict
-- The sight of an attack's own effect on this client, for every character, for the weapons that have one beyond the
-- swing itself: a steam hose's blast (a cone of steam out of the nozzle, and its hiss), firecrackers' pops (bright
-- flashes and bangs all round the attacker's feet), a lasso's rope (thrown out along the aim and drawn back in, or to
-- the one it caught: caught()). Each is timed from the attack's start (server time) to when it lands (AttackString.hitAt);
-- one heard too late to show (more than a moment past) is skipped. Everything here is made on this client and removed
-- after it.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local SoundBank = require(shared:WaitForChild("SoundBank"))
local AttackString = require(shared:WaitForChild("AttackString"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))

local AttackShow = {}

local STRING = AttackString.rules(Config.Attack)
local LATE = 0.15 -- an effect this far past when it should have shown is skipped
local ROPE = Color3.fromRGB(206, 170, 112)
local STEAM_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local POP_COLORS = { Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 150, 70), Color3.fromRGB(255, 90, 70) }
local THROW_OUT = 0.12 -- a lasso's rope flies out over this long
local DRAW_BACK = 0.22 -- and is drawn back over this long (a miss)
local PULLED = 0.35 -- a caught one is pulled in over about this long (a light hit's hold and slide)

-- An invisible spot to play a sound or hang an effect at, gone after `seconds`.
local function spot(at: Vector3, seconds: number): Part
	local part = PartUtil.decor("TrainBrawlEffect", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Workspace)
	part.Transparency = 1
	Debris:AddItem(part, seconds)
	return part
end

local function attachTo(part: Instance, at: Vector3?): Attachment
	local a = Instance.new("Attachment")
	a.Name = "TrainBrawlEffect"
	if at then
		a.Position = at
	end
	a.Parent = part
	return a
end

local function rope(a: Attachment, b: Attachment, width: number): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a
	beam.Attachment1 = b
	beam.Width0 = width
	beam.Width1 = width
	beam.FaceCamera = true
	beam.Segments = 10
	beam.Color = ColorSequence.new(ROPE)
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 1
	beam.Parent = a.Parent
	return beam
end

-- The steam blast from `model`'s hose: out of its nozzle (or its hand) along the aim, as far as the weapon reaches.
local function steam(model: Model, w: WeaponRules.Weapon)
	local held = model:FindFirstChild(Names.WeaponPart)
	local nozzle = if held then held:FindFirstChild("Nozzle") else nil
	local hand = model:FindFirstChild("RightHand")
	local at: Attachment
	if nozzle and nozzle:IsA("Attachment") then
		at = attachTo(nozzle.Parent :: Instance, nozzle.Position)
		at.Orientation = nozzle.Orientation
	elseif hand and hand:IsA("BasePart") then
		at = attachTo(hand)
	else
		return
	end
	local reach = w.reach or 8
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = STEAM_TEXTURE
	puff.Enabled = false
	puff.EmissionDirection = Enum.NormalId.Right -- the pipe's +X is ahead
	puff.Lifetime = NumberRange.new(0.35, 0.55)
	puff.Speed = NumberRange.new(reach * 3, reach * 4)
	puff.Drag = 4
	puff.SpreadAngle = Vector2.new(w.halfAngle or 30, (w.halfAngle or 30) * 0.6)
	puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(0.4, 4), NumberSequenceKeypoint.new(1, 7) })
	puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 1) })
	puff.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 226, 232))
	puff.Rotation = NumberRange.new(0, 360)
	puff.Parent = at
	puff:Emit(60)
	Debris:AddItem(at, 0.8)
	SoundBank.play("Steam", if hand and hand:IsA("BasePart") then hand else nil)
end

-- Firecrackers popping all round `model`'s feet, out to the weapon's radius.
local function pops(model: Model, w: WeaponRules.Weapon)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local radius = w.radius or 6
	local feet = root.Position - Vector3.new(0, 2.6, 0)
	for k = 1, 7 do
		task.delay((k - 1) * 0.03, function()
			local angle = math.random() * math.pi * 2
			local out = radius * (0.25 + math.random() * 0.6)
			local at = feet + Vector3.new(math.cos(angle) * out, 0.4 + math.random() * 1.2, math.sin(angle) * out)
			local flash = PartUtil.decor("TrainBrawlPop", Vector3.new(0.6, 0.6, 0.6), CFrame.new(at), POP_COLORS[1 + (k % #POP_COLORS)], Enum.Material.Neon, Workspace, Enum.PartType.Ball)
			flash.Transparency = 0.05
			TweenService:Create(flash, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(2.4, 2.4, 2.4), Transparency = 1 }):Play()
			local sparks = Instance.new("ParticleEmitter")
			sparks.Texture = SPARK_TEXTURE
			sparks.Enabled = false
			sparks.Lifetime = NumberRange.new(0.2, 0.35)
			sparks.Speed = NumberRange.new(12, 20)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.Size = NumberSequence.new(0.35, 0)
			sparks.LightEmission = 1
			sparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 60))
			sparks.Parent = attachTo(flash)
			sparks:Emit(10)
			Debris:AddItem(flash, 0.5)
			SoundBank.play("StarPop", flash, 0.85 + math.random() * 0.5)
		end)
	end
end

-- A lasso's rope from `model`'s hand along its aim: out to the weapon's reach and drawn back (a miss: a catch shows
-- caught() over it).
local function throwRope(model: Model, w: WeaponRules.Weapon)
	local hand = model:FindFirstChild("RightHand")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (hand and hand:IsA("BasePart") and root and root:IsA("BasePart")) then
		return
	end
	local look = root.CFrame.LookVector
	local aim = Vector3.new(look.X, 0, look.Z).Unit
	local reach = w.reach or 9
	local tip = spot(hand.Position, THROW_OUT + DRAW_BACK + 0.1)
	local beam = rope(attachTo(hand), attachTo(tip), 0.12)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local out = if t < THROW_OUT then t / THROW_OUT else math.max(1 - (t - THROW_OUT) / DRAW_BACK, 0)
		if not (hand.Parent and tip.Parent) or t >= THROW_OUT + DRAW_BACK then
			connection:Disconnect()
			beam:Destroy()
			return
		end
		tip.Position = hand.Position + aim * reach * out + Vector3.new(0, -0.6 * out, 0)
	end)
end

-- An attack by `model` with `weapon` at `step` of its string, begun at server time `at`: its own effect when it lands.
function AttackShow.play(model: Model, weapon: string, step: number, at: number)
	local name = WeaponRules.named(Config.Weapons, weapon)
	local w = Config.Weapons[name]
	local show: ((Model, WeaponRules.Weapon) -> ())? = if w.style == "spray" then steam elseif w.style == "burst" then pops elseif w.style == "lasso" then throwRope else nil
	if not show then
		return
	end
	local wait = at + AttackString.hitAt(STRING, w.hitAt, step, w.style) - Workspace:GetServerTimeNow()
	if wait < -LATE then
		return
	end
	task.delay(math.max(wait, 0), show, model, w)
end

-- `attacker`'s lasso caught `victim`: a taut rope from the hand to them while they are pulled in, then a few turns of
-- rope round their middle for `seconds` (tied: no attacking).
function AttackShow.caught(attacker: Model, victim: Model, seconds: number)
	local hand = attacker:FindFirstChild("RightHand")
	local torso = victim:FindFirstChild("UpperTorso") or victim:FindFirstChild("HumanoidRootPart")
	if not (hand and hand:IsA("BasePart") and torso and torso:IsA("BasePart")) then
		return
	end
	SoundBank.play("LassoCatch", torso)
	local line = rope(attachTo(hand), attachTo(torso), 0.12)
	Debris:AddItem(line, PULLED)
	-- The turns round the middle: two rings of rope about the torso's own up axis, each two half circles from its
	-- front to its back (the attachments' X axes point to the torso's right: a Beam leaves and arrives along them).
	local made: { Instance } = {}
	for _, y in { 0.25, -0.35 } do
		local r = 1.25
		local front = attachTo(torso, Vector3.new(0, y, -r))
		local back = attachTo(torso, Vector3.new(0, y, r))
		local left = rope(front, back, 0.14)
		left.CurveSize0 = -r * 4 / 3
		left.CurveSize1 = r * 4 / 3
		local right = rope(front, back, 0.14)
		right.CurveSize0 = r * 4 / 3
		right.CurveSize1 = -r * 4 / 3
		table.insert(made, left)
		table.insert(made, right)
		table.insert(made, front)
		table.insert(made, back)
	end
	task.delay(math.max(seconds, PULLED), function()
		for _, instance in made do
			instance:Destroy()
		end
	end)
end

return AttackShow
