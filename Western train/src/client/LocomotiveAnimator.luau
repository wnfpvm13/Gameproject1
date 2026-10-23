--!strict
-- Animates one locomotive's moving parts on this client: a spring follows the squash target (flat or normal) and
-- every part is resized and moved from its rest pose (the Names.Rest* attributes written by the server's
-- LocomotiveBuilder); the coupling rods and crank pins (Names.Crank*) also circle with the driving wheels all the
-- time (as fast as the run moves, see setRunSpeed), and the legs (Names.Kick*) swing about the hip while the spring
-- moves. It also keeps the locomotive's current top height for the bridge judgement. Local only: the server never
-- moves these parts after building them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local SquashSpring = require(shared:WaitForChild("SquashSpring"))
local SquashPose = require(shared:WaitForChild("SquashPose"))
local CrankMotion = require(shared:WaitForChild("CrankMotion"))

local LocomotiveAnimator = {}
LocomotiveAnimator.__index = LocomotiveAnimator

local KICK_LIMITS: SquashPose.KickLimits = {
	gain = Config.Squash.LegKickGain,
	up = Config.Squash.LegKickUp,
	down = Config.Squash.LegKickDown,
	flatHeight = Config.Squash.HeightAtFull,
}

type Entry = {
	part: BasePart,
	rotation: CFrame, -- rest rotation only
	rest: SquashPose.Rest,
	restSize: Vector3,
	mesh: SpecialMesh?, -- a FileMesh whose scale follows the size
	meshScale: Vector3?,
	crank: CrankMotion.Crank?,
	kick: { pivot: Vector3, side: number }?, -- pivot at rest, relative to the Base part
}

type Fields = {
	base: BasePart,
	entries: { Entry },
	cranks: { Entry }, -- the entries that circle with the wheels
	spring: SquashSpring.State,
	target: number,
	settled: boolean,
	body: SquashPose.Vec, -- the squash scale last drawn
	angle: number, -- crank angle
	turnsPerSecond: number, -- crank speed
	top: number, -- the highest part's top above the rails, as last drawn (locomotive space)
}
export type Animator = typeof(setmetatable({} :: Fields, LocomotiveAnimator))

local function vec(v: Vector3): SquashPose.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

local function entryFor(part: BasePart): Entry?
	local rest = part:GetAttribute(Names.RestCFrame)
	local size = part:GetAttribute(Names.RestSize)
	if typeof(rest) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return nil
	end
	local anchor = part:GetAttribute(Names.RestAnchor)
	local exponent = part:GetAttribute(Names.SquashExponent)
	local meshScale = part:GetAttribute(Names.RestMeshScale)
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	local hasMeshScale = mesh ~= nil and typeof(meshScale) == "Vector3"
	local radius = part:GetAttribute(Names.CrankRadius)
	local phase = part:GetAttribute(Names.CrankPhase)
	local pivot = part:GetAttribute(Names.KickPivot)
	local side = part:GetAttribute(Names.KickSide)
	return {
		part = part,
		rotation = rest - rest.Position,
		restSize = size,
		rest = {
			position = vec(rest.Position),
			anchor = vec(if typeof(anchor) == "Vector3" then anchor else rest.Position),
			size = vec(size),
			axes = { vec(rest.XVector), vec(rest.YVector), vec(rest.ZVector) },
			exponent = if typeof(exponent) == "number" then exponent else 1,
		},
		mesh = if hasMeshScale then mesh else nil,
		meshScale = if hasMeshScale then meshScale :: Vector3 else nil,
		crank = if typeof(radius) == "number" then { radius = radius, phase = if typeof(phase) == "number" then phase else 0 } else nil,
		kick = if typeof(pivot) == "Vector3" and typeof(side) == "number" then { pivot = pivot, side = side } else nil,
	}
end

-- nil when the locomotive has no Base part (it is still arriving or was built wrongly).
function LocomotiveAnimator.new(locomotive: Model): Animator?
	local base = locomotive:FindFirstChild(Names.BasePart)
	if not (base and base:IsA("BasePart")) then
		return nil
	end
	local entries, cranks = {}, {}
	for _, item in locomotive:GetDescendants() do
		if item:IsA("BasePart") then
			local entry = entryFor(item)
			if entry then
				-- The avatar's Humanoid turns collisions back on for its torso parts when the model arrives on this
				-- client too (no change signal; seen in Studio), and Roblox's camera would then zoom in behind the cab.
				-- The roof floors the cowboy stands on keep theirs (they are invisible, so the camera ignores them).
				PartUtil.ghost(item)
				if item:GetAttribute(Names.Walkable) == true then
					item.CanCollide = true
					item.CanQuery = true
				end
				table.insert(entries, entry)
				if entry.crank then
					table.insert(cranks, entry)
				end
			end
		end
	end
	-- Not settled yet, so the first update draws the rest pose (the parts may still hold an older pose).
	local fields: Fields = {
		base = base,
		entries = entries,
		cranks = cranks,
		spring = SquashSpring.new(),
		target = 0,
		settled = false,
		body = { x = 1, y = 1, z = 1 },
		angle = 0,
		turnsPerSecond = Config.Locomotive.CrankTurnsPerSecond,
		top = 0,
	}
	return setmetatable(fields, LocomotiveAnimator)
end

-- The rods turn as fast as the wheels would roll at this run speed (studs per second; 0 stops them). nil = no run:
-- the idle speed from Config.
function LocomotiveAnimator.setRunSpeed(self: Animator, studsPerSecond: number?)
	self.turnsPerSecond = if studsPerSecond
		then studsPerSecond / (2 * math.pi * Config.Locomotive.DriverRadius)
		else Config.Locomotive.CrankTurnsPerSecond
end

-- A knock (a crash): adds this much spring speed, so the body stretches or folds, wobbles and the legs flail.
function LocomotiveAnimator.jolt(self: Animator, velocity: number)
	self.spring.velocity += velocity
	self.settled = false
end

-- The locomotive's current height above the rails (its highest part's top, as last drawn).
function LocomotiveAnimator.height(self: Animator): number
	return self.top
end

-- How flat the train is drawn right now: 0 standing, 1 fully flat (the bounce's overshoot is cut off).
function LocomotiveAnimator.flatness(self: Animator): number
	return math.clamp(self.spring.value, 0, 1)
end

function LocomotiveAnimator.setTarget(self: Animator, squashed: boolean)
	local target = if squashed then 1 else 0
	if target ~= self.target then
		self.target = target
		self.settled = false
	end
end

-- Puts one part where the squash scale, crank angle and spring speed say; resize = false skips the size (it has not
-- changed). Returns the part's top above the rails (before the crank and leg swing, which only move low parts).
local function place(entry: Entry, baseCFrame: CFrame, body: SquashPose.Vec, angle: number, velocity: number, resize: boolean): number
	local position, size = SquashPose.pose(entry.rest, body)
	local top = position.y + SquashPose.halfHeight(entry.rest, size)
	if resize then
		local newSize = Vector3.new(size.x, size.y, size.z)
		entry.part.Size = newSize
		local mesh, meshScale = entry.mesh, entry.meshScale
		if mesh and meshScale then
			mesh.Scale = PartUtil.meshScale(meshScale, entry.restSize, newSize)
		end
	end
	local x, y, z = position.x, position.y, position.z
	local crank = entry.crank
	if crank then
		local dy, dz = CrankMotion.offset(angle, crank.phase, crank.radius, body.y, body.z)
		y += dy
		z += dz
	end
	local kick = entry.kick
	if kick then
		-- The hip rides on the body like an anchor; the leg turns about it.
		local hip = kick.pivot * Vector3.new(body.x, body.y, body.z)
		local swing = SquashPose.kickAngle(velocity, kick.side, body.y, KICK_LIMITS)
		entry.part.CFrame = baseCFrame * CFrame.new(hip) * CFrame.Angles(swing, 0, 0) * CFrame.new(Vector3.new(x, y, z) - hip) * entry.rotation
		return top
	end
	entry.part.CFrame = baseCFrame * CFrame.new(x, y, z) * entry.rotation
	return top
end

function LocomotiveAnimator.update(self: Animator, dt: number)
	self.angle = CrankMotion.advance(self.angle, dt, self.turnsPerSecond)
	local baseCFrame = self.base.CFrame
	if self.settled then
		for _, entry in self.cranks do
			place(entry, baseCFrame, self.body, self.angle, 0, false)
		end
		return
	end
	local c = Config.Squash
	local pressing = self.target == 1
	local frequency = if pressing then c.PressFrequency else c.ReleaseFrequency
	local damping = if pressing then c.PressDamping else c.ReleaseDamping
	SquashSpring.step(self.spring, self.target, dt, frequency, damping, c.MinValue, c.MaxValue)
	self.settled = SquashSpring.settle(self.spring, self.target, c.RestEpsilon)
	self.body = SquashPose.bodyScale(self.spring.value, c.HeightAtFull, c.WidthAtFull, c.LengthAtFull)
	local top = 0
	for _, entry in self.entries do
		top = math.max(top, place(entry, baseCFrame, self.body, self.angle, self.spring.velocity, true))
	end
	self.top = top
end

return LocomotiveAnimator
