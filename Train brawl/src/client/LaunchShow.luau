--!strict
-- A launched body's flight on this client, for everyone launched (a home run has its own: HomeRunShow): a short pale
-- streak behind it while it flies (it tumbles too: BodyMotion), and a puff of sand-coloured dust where it comes down
-- (Config.Feedback.DustSeconds). The landing is watched each frame: once the body has risen (on another player's screen
-- it leaves the roof a moment late, after their client's hold and the network), falling no faster than a slow drop
-- with something solid just under it - not another fighter; a body that never lands (it fell off) just loses its
-- streak. A new launch before the last one landed starts the watch again.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local LaunchShow = {}

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local DUST = ColorSequence.new(Color3.fromRGB(214, 180, 136), Color3.fromRGB(236, 214, 182))
local RISE = 1 -- a body has left the roof once it is this much higher than where it was hit
local MIN_AIR = 0.12 -- and counts as landed only after this long in the air
local GIVE_UP = 2.5 -- and stops being watched after this long
local DOWN = 4 -- something solid within this under the body's middle is the ground it landed on
local SLOW_DROP = -3 -- falling slower than this (studs a second) is no longer flying down

-- The watch running on each launched body (a newer launch replaces it).
local watching: { [Model]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

-- A puff of dust on the ground at `at`.
local function dust(at: Vector3)
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
	puff:Emit(12)
	Debris:AddItem(anchor, Config.Feedback.DustSeconds + 0.2)
end

-- A pale streak on the body's root (returned, to be turned off).
local function streak(root: BasePart): Trail
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.8, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.8, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.18
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 252, 240))
	trail.Transparency = NumberSequence.new(0.45, 1)
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Parent = root
	Debris:AddItem(trail, GIVE_UP + 0.3)
	Debris:AddItem(top, GIVE_UP + 0.3)
	Debris:AddItem(bottom, GIVE_UP + 0.3)
	return trail
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
	local trail = streak(root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { victim }
	local started = os.clock()
	local startY = root.Position.Y
	local airborne: number? = nil -- when it was first seen off the roof
	local watch: RBXScriptConnection
	watch = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local done = not root.Parent or now - started > GIVE_UP
		if not airborne and root.Position.Y > startY + RISE then
			airborne = now
		end
		if not done and airborne and now - airborne > MIN_AIR and root.AssemblyLinearVelocity.Y > SLOW_DROP then
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
			trail.Enabled = false
		end
	end)
	watching[victim] = watch
end

return LaunchShow
