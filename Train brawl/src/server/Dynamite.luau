--!strict
-- Thrown dynamite on the server: a lit stick tumbles along an arc (WeaponRules.arc) from the thrower and stops where it
-- first meets the arena (a roof, a crate, a plank, the sand), and it bursts when its fuse runs out
-- (Config.Weapons.Dynamite.fuse, counted from the throw), wherever it is. Where it will come down is marked at once
-- with an invisible flat part as wide as the blast (Names.BlastMark, with the burst's server time and the fuse), on
-- which every client draws the warning (GroundMarks), so everyone sees it coming. The stick fizzes (FuseSparks). Who the burst reaches is the caller's to judge.
-- clear() puts out every stick still burning (the round is over).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local FuseSparks = require(shared:WaitForChild("FuseSparks"))

local Dynamite = {}

local STEP = 1 / 30 -- the arc is traced this finely to find where it lands
local RED = Color3.fromRGB(220, 50, 40)

type Lit = { stick: BasePart, ring: BasePart?, connection: RBXScriptConnection }
local burning: { Lit } = {}

-- What a stick flies through: characters (players' and sandbags').
local function passThrough(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = CollectionService:GetTagged(Names.SandbagTag)
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

-- The first thing of the arena between `a` and `b`, flying through everything else (up to a few things in the way).
local function arenaHit(a: Vector3, b: Vector3, arena: Instance, params: RaycastParams): RaycastResult?
	for _ = 1, 4 do
		local hit = Workspace:Raycast(a, b - a, params)
		if not hit or hit.Instance:IsDescendantOf(arena) then
			return hit
		end
		params:AddToFilter(hit.Instance) -- not the arena's: fly through it and look again
	end
	return nil
end

-- Where the arc first meets the arena within `limit` seconds, and when; nil when it is still flying by then.
local function landing(from: Vector3, facing: Vector3, speed: number, lift: number, limit: number, arena: Instance): (Vector3?, number)
	local params = passThrough()
	local gravity = Workspace.Gravity
	local previous = from
	local t = 0
	while t < limit do
		t += STEP
		local x, y, z = WeaponRules.arc(from.X, from.Y, from.Z, facing.X, facing.Z, speed, lift, gravity, t)
		local nextAt = Vector3.new(x, y, z)
		local hit = arenaHit(previous, nextAt, arena, params)
		if hit then
			local share = (hit.Position - previous).Magnitude / math.max((nextAt - previous).Magnitude, 1e-6)
			return hit.Position, t - STEP + STEP * share
		end
		previous = nextAt
	end
	return nil, limit
end

-- Throws a lit stick from the hand of a fighter standing at `root`, along the flat direction `facing` (length 1). It can
-- only land on `arena` (the solid trains, planks and sand). `burst(at)` is called when the fuse runs out, with where the
-- stick is then.
function Dynamite.throw(parent: Instance, arena: Instance, root: Vector3, facing: Vector3, burst: (Vector3) -> ())
	local w = Config.Weapons.Dynamite
	local speed = assert(w.throwSpeed, "Config.Weapons.Dynamite.throwSpeed")
	local lift = assert(w.throwLift, "Config.Weapons.Dynamite.throwLift")
	local fuse = assert(w.fuse, "Config.Weapons.Dynamite.fuse")
	local radius = assert(w.radius, "Config.Weapons.Dynamite.radius")
	-- From the hand, a little ahead and up; from just short of a wall when the hand would be inside it.
	local from = root + Vector3.new(0, 1.5, 0) + facing * 1.5
	local blocked = arenaHit(root, from, arena, passThrough())
	if blocked then
		from = blocked.Position - (from - root).Unit * 0.4
	end
	local land, landAt = landing(from, facing, speed, lift, fuse, arena)
	local ring: BasePart? = nil
	if land then
		local mark = PartUtil.decor(Names.BlastMark, Vector3.new(radius * 2, 0.05, radius * 2), CFrame.new(land + Vector3.new(0, 0.05, 0)), RED, Enum.Material.SmoothPlastic, nil)
		mark.Transparency = 1
		mark:SetAttribute(Names.MarkEndsAt, Workspace:GetServerTimeNow() + fuse)
		mark:SetAttribute(Names.MarkSeconds, fuse)
		mark.Parent = parent
		ring = mark
	end
	local stick = PartUtil.decor("Dynamite", Vector3.new(1.3, 0.5, 0.5), CFrame.new(from), RED, Enum.Material.SmoothPlastic, parent, Enum.PartType.Cylinder)
	FuseSparks.add(stick)
	local started = os.clock()
	local lit: Lit
	local connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		local at: Vector3
		if land and t >= landAt then
			at = land + Vector3.new(0, 0.3, 0)
		else
			local x, y, z = WeaponRules.arc(from.X, from.Y, from.Z, facing.X, facing.Z, speed, lift, Workspace.Gravity, t)
			at = Vector3.new(x, y, z)
		end
		local tumble = if land and t >= landAt then 0 else t
		stick.CFrame = CFrame.new(at) * CFrame.Angles(tumble * 9, 0, tumble * 5)
		if t >= fuse then
			lit.connection:Disconnect()
			stick:Destroy()
			if ring then
				ring:Destroy()
			end
			local index = table.find(burning, lit)
			if index then
				table.remove(burning, index)
			end
			burst(at)
		end
	end)
	lit = { stick = stick, ring = ring, connection = connection }
	table.insert(burning, lit)
end

-- Puts out every stick still burning (no burst).
function Dynamite.clear()
	for _, lit in burning do
		lit.connection:Disconnect()
		lit.stick:Destroy()
		if lit.ring then
			lit.ring:Destroy()
		end
	end
	table.clear(burning)
end

return Dynamite
