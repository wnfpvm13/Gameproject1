--!strict
-- Animates one locomotive's squash on this client: a spring follows the target (flat or normal) and every frame each
-- part is resized and moved from its rest pose (the Names.Rest* attributes written by the server's
-- LocomotiveBuilder). Local only: the server never moves these parts after building them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local SquashSpring = require(shared:WaitForChild("SquashSpring"))
local SquashPose = require(shared:WaitForChild("SquashPose"))

local SquashAnimator = {}
SquashAnimator.__index = SquashAnimator

type Entry = {
	part: BasePart,
	rotation: CFrame, -- rest rotation only
	rest: SquashPose.Rest,
	restSize: Vector3,
	mesh: SpecialMesh?, -- a FileMesh whose scale follows the size
	meshScale: Vector3?,
}

type Fields = { base: BasePart, entries: { Entry }, spring: SquashSpring.State, target: number, settled: boolean }
export type Animator = typeof(setmetatable({} :: Fields, SquashAnimator))

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
	}
end

-- nil when the locomotive has no Base part (it is still arriving or was built wrongly).
function SquashAnimator.new(locomotive: Model): Animator?
	local base = locomotive:FindFirstChild(Names.BasePart)
	if not (base and base:IsA("BasePart")) then
		return nil
	end
	local entries = {}
	for _, item in locomotive:GetDescendants() do
		if item:IsA("BasePart") then
			local entry = entryFor(item)
			if entry then
				table.insert(entries, entry)
			end
		end
	end
	-- Not settled yet, so the first update draws the rest pose (the parts may still hold an older pose).
	local fields: Fields = { base = base, entries = entries, spring = SquashSpring.new(), target = 0, settled = false }
	return setmetatable(fields, SquashAnimator)
end

function SquashAnimator.setTarget(self: Animator, squashed: boolean)
	local target = if squashed then 1 else 0
	if target ~= self.target then
		self.target = target
		self.settled = false
	end
end

function SquashAnimator.update(self: Animator, dt: number)
	if self.settled then
		return
	end
	local c = Config.Squash
	local pressing = self.target == 1
	local frequency = if pressing then c.PressFrequency else c.ReleaseFrequency
	local damping = if pressing then c.PressDamping else c.ReleaseDamping
	SquashSpring.step(self.spring, self.target, dt, frequency, damping, c.MinValue, c.MaxValue)
	self.settled = SquashSpring.settle(self.spring, self.target, c.RestEpsilon)
	local body = SquashPose.bodyScale(self.spring.value, c.HeightAtFull, c.WidthAtFull, c.LengthAtFull)
	local baseCFrame = self.base.CFrame
	for _, entry in self.entries do
		local position, size = SquashPose.pose(entry.rest, body)
		local newSize = Vector3.new(size.x, size.y, size.z)
		entry.part.Size = newSize
		local mesh, meshScale = entry.mesh, entry.meshScale
		if mesh and meshScale then
			mesh.Scale = PartUtil.meshScale(meshScale, entry.restSize, newSize)
		end
		entry.part.CFrame = baseCFrame * CFrame.new(position.x, position.y, position.z) * entry.rotation
	end
end

return SquashAnimator
