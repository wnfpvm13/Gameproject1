--!strict
-- A launched body's flight on this client, for everyone launched (a home run has its own: HomeRunShow): it goes off
-- like a blast where it is hit (blast(): a white-hot flash, a fireball, a shock dome, smoke, embers, a light and a low
-- boom - also for a home run, bigger; owner 2026-10-28: "금칙어게임의 의자 날라가기처럼 아주 쾅 하고 날라가야 해", "날라갈 때
-- 이펙트가 더 화려해야 해"), it trails fire, smoke and sparkles while it flies, and a puff of sand-coloured dust shows where
-- it comes down (Config.Feedback.DustSeconds; dust() also puffs where a dodge roll starts: DodgeShow).
-- The landing is watched each frame: once the body is seen leaving the roof (higher than where it was hit, or rising
-- fast: on another player's screen it leaves a moment late, after their client's hold and the network), then seen
-- falling, it has landed when it no longer falls with something solid just under it - not another fighter (rising or
-- at the top of its flight it never counts, whatever it passes over). A body never seen leaving the roof loses its
-- streak after a moment; one that never lands (it fell off) loses it too. A new launch before the last one landed
-- starts the watch again.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local SoundBank = require(shared:WaitForChild("SoundBank"))

local LaunchShow = {}

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
-- (Saturated, and the streak lit only a little: a bright glow washes out to white against the desert sky.)
local FIRE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 150)),
	ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 150, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 56, 24)),
})
local DUST = ColorSequence.new(Color3.fromRGB(214, 180, 136), Color3.fromRGB(236, 214, 182))
local RISE = 0.5 -- a body has left the roof once it is this much higher than where it was hit
local RISING = 6 -- or once it rises faster than this (studs a second)
local LEAVE_WITHIN = 0.8 -- a body not seen leaving the roof by then was not thrown up (its streak goes)
local FALLING = -6 -- it has come down from the top of its flight once it falls faster than this
local STOPPED = 3 -- and has landed once its vertical speed is under this again
local GIVE_UP = 2.5 -- and stops being watched after this long
local DOWN = 4 -- something solid within this under the body's middle is the ground it landed on

-- The watch running on each launched body (a newer launch replaces it).
local watching: { [Model]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

-- A puff of dust on the ground at `at` (`amount` specks, 12 when not given).
local function dust(at: Vector3, amount: number?)
	local anchor = Instance.new("Part")
	anchor.Name = "TrainBrawlDust"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0))
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = SMOKE_TEXTURE
	puff.Enabled = false
	puff.Color = DUST
	puff.Lifetime = NumberRange.new(Config.Feedback.DustSeconds * 0.7, Config.Feedback.DustSeconds)
	puff.Speed = NumberRange.new(4, 8)
	puff.SpreadAngle = Vector2.new(80, 80)
	puff.EmissionDirection = Enum.NormalId.Top
	puff.Drag = 4
	puff.Acceleration = Vector3.new(0, -2, 0)
	puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) })
	puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	puff.Rotation = NumberRange.new(0, 360)
	puff.Parent = anchor
	anchor.Parent = Workspace
	puff:Emit(amount or 12)
	Debris:AddItem(anchor, Config.Feedback.DustSeconds + 0.2)
end

LaunchShow.dust = dust

-- A part only seen (no collisions, no rays) at `at`, gone after `seconds`.
local function seen(name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType, seconds: number): Part
	local part = PartUtil.decor(name, size, at, color, material, Workspace, shape)
	Debris:AddItem(part, seconds)
	return part
end

-- A particle emitter on `parent`, not emitting on its own.
local function emitter(parent: Instance, texture: string): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Texture = texture
	made.Enabled = false
	made.SpreadAngle = Vector2.new(180, 180)
	made.Parent = parent
	return made
end

-- What trails a flying body (on its root, to be turned off): a wide fire-coloured streak, a stream of smoke puffs and
-- sparkles.
local function flightTrail(root: BasePart): { Instance }
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 1.3, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -1.3, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.3
	trail.Color = FIRE
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.LightEmission = 0.25
	trail.FaceCamera = true
	trail.Parent = root
	local center = Instance.new("Attachment")
	center.Parent = root
	local smoke = emitter(center, SMOKE_TEXTURE)
	smoke.Rate = 45
	smoke.Lifetime = NumberRange.new(0.4, 0.7)
	smoke.Speed = NumberRange.new(0.5, 2)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 2.6) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 112, 104), Color3.fromRGB(210, 200, 190))
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.Enabled = true
	local sparks = emitter(center, SPARK_TEXTURE)
	sparks.Rate = 30
	sparks.Lifetime = NumberRange.new(0.25, 0.45)
	sparks.Speed = NumberRange.new(3, 7)
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.LightEmission = 1
	sparks.Color = FIRE
	sparks.Enabled = true
	local made: { Instance } = { trail, top, bottom, center }
	for _, instance in made do
		Debris:AddItem(instance, GIVE_UP + 0.8)
	end
	return { trail, smoke, sparks }
end

-- A launch (or with `big`, a home run) goes off at `at` like a blast: a white-hot flash and a fireball growing fast,
-- a shock dome swelling out, smoke rolling out, embers flying, a flash of light and a low boom. `push` (the knock, if
-- known) leans the smoke and embers its way.
function LaunchShow.blast(at: Vector3, push: Vector3?, big: boolean)
	local f = Config.Feedback
	local size = if big then f.SmashBlast else f.BlastSize
	local seconds = f.BlastSeconds
	local quick = TweenInfo.new(seconds * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local slow = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local flash = seen("TrainBrawlBlast", Vector3.one * 1.2, CFrame.new(at), Color3.fromRGB(255, 255, 240), Enum.Material.Neon, Enum.PartType.Ball, seconds + 0.2)
	TweenService:Create(flash, quick, { Size = Vector3.one * size * 0.6, Transparency = 1 }):Play()
	local fire = seen("TrainBrawlBlast", Vector3.one * 2, CFrame.new(at), Color3.fromRGB(255, 150, 50), Enum.Material.Neon, Enum.PartType.Ball, seconds + 0.2)
	fire.Transparency = 0.15
	TweenService:Create(fire, slow, { Size = Vector3.one * size, Transparency = 1, Color = Color3.fromRGB(200, 70, 30) }):Play()
	local dome = seen("TrainBrawlShock", Vector3.one * 2, CFrame.new(at), Color3.fromRGB(255, 236, 200), Enum.Material.ForceField, Enum.PartType.Ball, seconds * 1.6 + 0.2)
	TweenService:Create(dome, TweenInfo.new(seconds * 1.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(size * 2.4, size * 1.2, size * 2.4), Transparency = 1 }):Play()
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Range = size * 3
	light.Brightness = 6
	light.Parent = fire
	TweenService:Create(light, slow, { Brightness = 0 }):Play()
	local way = if push then Vector3.new(push.X, math.max(push.Y, 0), push.Z) else Vector3.zero
	local lean = if way.Magnitude > 1e-3 then way.Unit * 6 else Vector3.zero
	local holder = seen("TrainBrawlBlastSmoke", Vector3.one * 0.2, CFrame.new(at), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, Enum.PartType.Block, 2)
	holder.Transparency = 1
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local smoke = emitter(attachment, SMOKE_TEXTURE)
	smoke.Lifetime = NumberRange.new(0.6, 1.1)
	smoke.Speed = NumberRange.new(size * 1.5, size * 3)
	smoke.Drag = 5
	smoke.Acceleration = lean + Vector3.new(0, 3, 0)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.3), NumberSequenceKeypoint.new(1, size * 0.8) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 82, 76), Color3.fromRGB(200, 190, 180))
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-90, 90)
	smoke:Emit(if big then 22 else 14)
	local embers = emitter(attachment, SPARK_TEXTURE)
	embers.Lifetime = NumberRange.new(0.3, 0.7)
	embers.Speed = NumberRange.new(size * 3, size * 6)
	embers.Drag = 2
	embers.Acceleration = lean + Vector3.new(0, -30, 0)
	embers.Size = NumberSequence.new(0.6, 0)
	embers.LightEmission = 1
	embers.Color = FIRE
	embers:Emit(if big then 40 else 26)
	SoundBank.play("LaunchBoom", holder, if big then 0.8 else nil)
end

-- `victim` was just launched.
function LaunchShow.play(victim: Model)
	local body = CharacterParts.body(victim)
	if not body then
		return
	end
	local old = watching[victim]
	if old then
		old:Disconnect()
	end
	local root = body.root
	local trail = flightTrail(root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { victim }
	local started = os.clock()
	local startY = root.Position.Y
	local airborne = false -- seen off the roof
	local fell = false -- seen falling after that
	local watch: RBXScriptConnection
	watch = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local vy = root.AssemblyLinearVelocity.Y
		local done = not root.Parent or now - started > GIVE_UP
		if not airborne and (root.Position.Y > startY + RISE or vy > RISING) then
			airborne = true
		elseif not airborne and now - started > LEAVE_WITHIN then
			done = true
		end
		if airborne and vy < FALLING then
			fell = true
		end
		if not done and fell and math.abs(vy) < STOPPED then
			-- From above the body: a body lying on a roof can sink a little into it, and a ray starting inside a part
			-- does not see that part.
			local ground = Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -(DOWN + 2), 0), params)
			local onFighter = ground and ground.Instance:FindFirstAncestorWhichIsA("Model")
			if onFighter and onFighter:FindFirstChildOfClass("Humanoid") then
				ground = nil -- passing over someone's head is not landing
			end
			if ground then
				dust(ground.Position)
				done = true
			end
		end
		if done then
			watch:Disconnect()
			if watching[victim] == watch then
				watching[victim] = nil
			end
			for _, part in trail do
				(part :: any).Enabled = false -- a Trail or a ParticleEmitter
			end
		end
	end)
	watching[victim] = watch
end

return LaunchShow
