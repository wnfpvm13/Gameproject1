--!strict
-- Thrown dynamite on the server: a lit stick tumbles along an arc (WeaponRules.arc) from the thrower and stops where it
-- first meets the arena (a roof, a crate, a plank, the sand; one that meets a wall drops down it to the floor below,
-- keeping the speed it was falling at), and it bursts when its fuse runs out
-- (Config.Weapons.Dynamite.fuse, counted from the throw), wherever it is. Where it will come down is marked at once
-- with an invisible flat part as wide as the blast (Names.BlastMark, with the burst's server time and the fuse), on
-- which every client draws the warning (GroundMarks), so everyone sees it coming: where the stick will be when it
-- bursts (still falling down a wall if the fuse runs out first), none on the sand below the trains (it reaches nobody
-- there). The stick fizzes at its fuse end
-- (FuseSparks). Who the burst reaches is the caller's to judge.
-- clear() puts out every stick still burning (the round is over).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local FuseSparks = require(shared:WaitForChild("FuseSparks"))
local ArenaRay = require(shared:WaitForChild("ArenaRay"))

local Dynamite = {}

local STEP = 1 / 30 -- the arc is traced this finely to find where it lands
local WALL = 0.3 -- a surface met whose normal points up less than this is a wall (a boiler's rounded top is not)
local OFF_WALL = 1 -- a stick that met a wall bounces this far back off it as it drops (not into a gap between cars)
local RED = Color3.fromRGB(220, 50, 40)

type Lit = { stick: BasePart, ring: BasePart?, connection: RBXScriptConnection }
local burning: { Lit } = {}

-- The floor under a stick that met a wall at `at` (normal `normal`): straight down from just off the wall; nil when
-- nothing of the arena is under it.
local function floorBelow(at: Vector3, normal: Vector3, arena: Instance): Vector3?
	local out = Vector3.new(normal.X, 0, normal.Z)
	local start = at + (if out.Magnitude > 1e-3 then out.Unit * OFF_WALL else Vector3.zero)
	local hit = ArenaRay.hit(start, start - Vector3.new(0, 200, 0), arena, ArenaRay.params())
	return if hit then hit.Position else nil
end

-- The height of a stick that met a wall at height `y` falling at `vy` (studs a second, 0 or less), `fell` seconds later:
-- no lower than `floorY`.
local function dropY(y: number, vy: number, floorY: number, fell: number): number
	return math.max(y + vy * fell - Workspace.Gravity * fell * fell / 2, floorY)
end

-- Where the arc first meets the arena within `limit` seconds, and when; nil when it is still flying by then. When what
-- it meets is a wall, also the floor it drops to.
local function landing(from: Vector3, facing: Vector3, speed: number, lift: number, limit: number, arena: Instance): (Vector3?, number, Vector3?)
	local params = ArenaRay.params()
	local gravity = Workspace.Gravity
	local previous = from
	local t = 0
	while t < limit do
		t += STEP
		local x, y, z = WeaponRules.arc(from.X, from.Y, from.Z, facing.X, facing.Z, speed, lift, gravity, t)
		local nextAt = Vector3.new(x, y, z)
		local hit = ArenaRay.hit(previous, nextAt, arena, params)
		if hit then
			local share = (hit.Position - previous).Magnitude / math.max((nextAt - previous).Magnitude, 1e-6)
			local floor = if hit.Normal.Y < WALL then floorBelow(hit.Position, hit.Normal, arena) else nil
			return hit.Position, t - STEP + STEP * share, floor
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
	local blocked = ArenaRay.hit(root, from, arena, ArenaRay.params())
	if blocked then
		from = blocked.Position - (from - root).Unit * 0.4
	end
	local land, landAt, floor = landing(from, facing, speed, lift, fuse, arena)
	local falling = math.min(lift - Workspace.Gravity * landAt, 0) -- how fast it falls when it meets a wall (0 while rising)
	-- Where it bursts: where it lands, or down the wall it met, as far as it has fallen when the fuse runs out.
	local rest: Vector3? = land
	if land and floor then
		rest = Vector3.new(floor.X, dropY(land.Y, falling, floor.Y, math.max(fuse - landAt, 0)), floor.Z)
	end
	local ring: BasePart? = nil
	if rest and rest.Y > Config.Arena.GroundY + 0.5 then
		local mark = PartUtil.decor(Names.BlastMark, Vector3.new(radius * 2, 0.05, radius * 2), CFrame.new(rest + Vector3.new(0, 0.05, 0)), RED, Enum.Material.SmoothPlastic, nil)
		mark.Transparency = 1
		mark:SetAttribute(Names.MarkEndsAt, Workspace:GetServerTimeNow() + fuse)
		mark:SetAttribute(Names.MarkSeconds, fuse)
		mark.Parent = parent
		ring = mark
	end
	local stick = PartUtil.decor("Dynamite", Vector3.new(1.3, 0.5, 0.5), CFrame.new(from), RED, Enum.Material.SmoothPlastic, parent, Enum.PartType.Cylinder)
	local fuseEnd = Instance.new("Attachment")
	fuseEnd.Name = "Fuse"
	fuseEnd.Position = Vector3.new(0.7, 0, 0) -- the cylinder lies along its X
	fuseEnd.Parent = stick
	FuseSparks.add(fuseEnd)
	local started = os.clock()
	local lit: Lit
	local connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		local at: Vector3
		if land and t >= landAt then
			at = land + Vector3.new(0, 0.3, 0)
			if floor then
				-- Off the wall and falling down it to the floor.
				at = Vector3.new(floor.X, dropY(land.Y, falling, floor.Y, t - landAt) + 0.3, floor.Z)
			end
		else
			local x, y, z = WeaponRules.arc(from.X, from.Y, from.Z, facing.X, facing.Z, speed, lift, Workspace.Gravity, t)
			at = Vector3.new(x, y, z)
		end
		local tumble = if rest and t >= landAt and at.Y <= rest.Y + 0.3 + 1e-3 then 0 else t
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
