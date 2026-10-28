--!strict
-- Bowled wheels on the server (a weapon of style "roll", Config.Weapons: rollSpeed, rollSeconds, hitRadius): a spare
-- locomotive wheel set down just ahead of its bowler rolls straight on along the flat facing, on whatever top it is on
-- (up a step no higher than Config.Thrown.StepUp, down any), and hits every other fighter whose middle it passes within
-- hitRadius of (WeaponRules.nearPath), each once, pushing them on along its way. Something taller in its way stops it;
-- off an edge it falls and rolls on wherever it lands (into the canyon: gone); it is gone after rollSeconds. Seen
-- only, never collides (Names.WheelModel; DropShow sounds it). Who it hits is handed to the caller. clear() takes every
-- wheel still rolling away (the round is over).
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

local Wheels = {}

local IRON = Color3.fromRGB(52, 50, 56)
local RED = Color3.fromRGB(176, 44, 36)
local WALL = 0.3 -- a surface met whose normal points up less than this is a wall
local BODY_HALF = 3 -- a fighter's middle is hit this far above or below the wheel's middle
local FALL_MOST = 1.2 -- a wheel falling this long is gone (off into the canyon)

type Rolling = { model: Model, connection: RBXScriptConnection }
local rolling: { Rolling } = {}

local function stop(wheel: Rolling)
	wheel.connection:Disconnect()
	wheel.model:Destroy()
	local index = table.find(rolling, wheel)
	if index then
		table.remove(rolling, index)
	end
end

-- The wheel's look: an iron rim with a red hub and spokes, its axle along X (rolling along -Z).
local function build(parent: Instance): Model
	local t = Config.Thrown
	local r, width = t.WheelRadius, t.WheelWidth
	local model = Instance.new("Model")
	model.Name = Names.WheelModel
	local rim = PartUtil.decor("Rim", Vector3.new(width, r * 2, r * 2), CFrame.new(), IRON, Enum.Material.Metal, model, Enum.PartType.Cylinder)
	PartUtil.decor("Hub", Vector3.new(width + 0.3, r * 0.6, r * 0.6), CFrame.new(), RED, Enum.Material.Metal, model, Enum.PartType.Cylinder)
	for k = 0, 3 do
		PartUtil.decor("Spoke", Vector3.new(width * 0.6, r * 1.8, 0.22), CFrame.Angles(math.rad(45 * k), 0, 0), RED, Enum.Material.Metal, model)
	end
	model.PrimaryPart = rim
	model.Parent = parent
	return model
end

-- Bowls a wheel of weapon `w` from `attacker` (standing at `root`) along the flat `facing` (length 1), in `parent`; it
-- rolls on `arena` only. `fighters()` are those it can hit; `hit(victim, from)` for each one it hits.
function Wheels.roll(parent: Instance, arena: Instance, fighters: () -> { Model }, attacker: Model, root: Vector3, facing: Vector3, w: WeaponRules.Weapon, hit: (Model, Vector3) -> ())
	local speed = assert(w.rollSpeed, "roll.rollSpeed")
	local limit = assert(w.rollSeconds, "roll.rollSeconds")
	local reach = assert(w.hitRadius, "roll.hitRadius")
	local t = Config.Thrown
	local r = t.WheelRadius
	local up = Vector3.new(0, 1, 0)
	local params = ArenaRay.params()
	-- Set down just ahead (short of a wall), on the floor there, or falling from hand height when there is none.
	local ahead = 2
	local blocked = ArenaRay.hit(root, root + facing * (ahead + r), arena, params)
	if blocked then
		ahead = math.max(blocked.Distance - r - 0.2, 0)
	end
	local start = root + facing * ahead
	local floor = ArenaRay.floor(start, 1, 6, arena, params)
	local at = if floor then Vector3.new(start.X, floor.Position.Y + r, start.Z) else start
	local falling, vy, fell = floor == nil, 0, 0
	local spin = 0
	local struck: { [Model]: boolean } = {}
	local model = build(parent)
	local started = os.clock()
	local last = started
	local wheel: Rolling
	local function place()
		model:PivotTo(CFrame.lookAt(at, at + facing) * CFrame.Angles(-spin, 0, 0))
	end
	place()
	wheel = {
		model = model,
		connection = RunService.Heartbeat:Connect(function()
			local clock = os.clock()
			local dt = math.min(clock - last, 0.1)
			last = clock
			local nextAt = at + facing * speed * dt
			-- Something taller than a step ahead (low down or at the middle) stops it.
			for _, height in { t.StepUp + 0.1 - r, 0 } do
				local from = at + up * height
				local wall = ArenaRay.hit(from, from + facing * (speed * dt + r), arena, params)
				if wall and wall.Normal.Y < WALL then
					stop(wheel)
					return
				end
			end
			if falling then
				vy -= Workspace.Gravity * dt
				nextAt += up * vy * dt
				fell += dt
				local land = ArenaRay.hit(at - up * r, nextAt - up * r, arena, params)
				if land and land.Normal.Y >= WALL then
					nextAt = Vector3.new(nextAt.X, land.Position.Y + r, nextAt.Z)
					falling, vy = false, 0
				end
			else
				local under = ArenaRay.floor(nextAt - up * r, t.StepUp + 0.05, 0.6, arena, params)
				if under then
					nextAt = Vector3.new(nextAt.X, under.Position.Y + r, nextAt.Z)
				else
					falling, vy, fell = true, 0, 0 -- off the edge
				end
			end
			for _, other in fighters() do
				local body = if other ~= attacker and not struck[other] then CharacterParts.body(other) else nil
				if body then
					local p = body.root.Position
					if WeaponRules.nearPath(at.X, at.Y, at.Z, nextAt.X, nextAt.Y, nextAt.Z, p.X, p.Y, p.Z, reach, BODY_HALF) then
						struck[other] = true
						hit(other, p - facing * 2) -- pushed on along its way
					end
				end
			end
			spin += speed * dt / r
			at = nextAt
			if clock - started >= limit or (falling and fell >= FALL_MOST) or not model.Parent then
				stop(wheel)
				return
			end
			place()
		end),
	}
	table.insert(rolling, wheel)
end

-- Takes every wheel still rolling away (no hits).
function Wheels.clear()
	for _, wheel in table.clone(rolling) do
		stop(wheel)
	end
end

return Wheels
