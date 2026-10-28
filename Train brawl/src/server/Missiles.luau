--!strict
-- Thrown coal lumps on the server (a weapon of style "toss", Config.Weapons: throwSpeed, throwLift, hitRadius, flight):
-- a lump flies along its arc (WeaponRules.arc) from the thrower's hand and hits the first other fighter whose middle it
-- passes within hitRadius of (WeaponRules.nearPath), checked every frame against where the fighters are then; it breaks
-- where it first meets the arena (a roof, a crate, a chimney: ArenaRay) and is gone after `flight` seconds at most (one
-- thrown off the side falls into the canyon). Who it hits is handed to the caller, with where it was a frame before (the
-- hit pushes away from there, along its flight). clear() takes every lump still flying away (the round is over).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local ArenaRay = require(shared:WaitForChild("ArenaRay"))

local Missiles = {}

local COAL = Color3.fromRGB(38, 36, 40)
local BODY_HALF = 2.6 -- a fighter's middle is hit by a lump this far above or below it (about half a body)

type Flying = { part: BasePart, connection: RBXScriptConnection }
local flying: { Flying } = {}

local function stop(lump: Flying)
	lump.connection:Disconnect()
	lump.part:Destroy()
	local index = table.find(flying, lump)
	if index then
		table.remove(flying, index)
	end
end

-- Throws a lump of weapon `w` from the hand of `attacker` (standing at `root`) along the flat `facing` (length 1), in
-- `parent`; it can only break on `arena`. `fighters()` are those it can hit; `hit(victim, from)` for the one it hits.
function Missiles.toss(parent: Instance, arena: Instance, fighters: () -> { Model }, attacker: Model, root: Vector3, facing: Vector3, w: WeaponRules.Weapon, hit: (Model, Vector3) -> ())
	local speed = assert(w.throwSpeed, "toss.throwSpeed")
	local lift = assert(w.throwLift, "toss.throwLift")
	local radius = assert(w.hitRadius, "toss.hitRadius")
	local limit = assert(w.flight, "toss.flight")
	local params = ArenaRay.params()
	-- From the hand, a little ahead and up; from just short of a wall when the hand would be inside it.
	local from = root + Vector3.new(0, 1.5, 0) + facing * 1.2
	local blocked = ArenaRay.hit(root, from, arena, params)
	if blocked then
		from = blocked.Position - (from - root).Unit * 0.4
	end
	local size = Config.Thrown.LumpSize
	local part = PartUtil.decor(Names.LumpPart, Vector3.new(size, size * 0.8, size), CFrame.new(from), COAL, Enum.Material.Slate, parent)
	local started = os.clock()
	local previous = from
	local lump: Flying
	lump = {
		part = part,
		connection = RunService.Heartbeat:Connect(function()
			local t = math.min(os.clock() - started, limit)
			local x, y, z = WeaponRules.arc(from.X, from.Y, from.Z, facing.X, facing.Z, speed, lift, Workspace.Gravity, t)
			local now = Vector3.new(x, y, z)
			-- Through a fighter first (one standing against a wall is still hit), then the arena.
			local nearest: Model? = nil
			local best = math.huge
			for _, model in fighters() do
				local body = if model ~= attacker then CharacterParts.body(model) else nil
				if body then
					local at = body.root.Position
					if WeaponRules.nearPath(previous.X, previous.Y, previous.Z, now.X, now.Y, now.Z, at.X, at.Y, at.Z, radius, BODY_HALF) then
						local d = (at - previous).Magnitude
						if d < best then
							nearest, best = model, d
						end
					end
				end
			end
			if nearest then
				stop(lump)
				hit(nearest, previous)
				return
			end
			if ArenaRay.hit(previous, now, arena, params) or t >= limit then
				stop(lump)
				return
			end
			part.CFrame = CFrame.new(now) * CFrame.Angles(t * 14, t * 9, 0)
			previous = now
		end),
	}
	table.insert(flying, lump)
end

-- Takes every lump still flying away (no hit).
function Missiles.clear()
	for _, lump in table.clone(flying) do
		stop(lump)
	end
end

return Missiles
