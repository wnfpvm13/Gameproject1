--!strict
-- How a fighter's body moves when it attacks, is hit, has landed or fell off, the same wherever its physics runs: on
-- the player's own client for a player (KnockFlight, FallDrift, the player's own attack) and on the server for a
-- sandbag (Sandbags, a bot's attack). An attack steps the body in (lunge); a light hit flinches (stagger: held still,
-- then pushed along the ground on its feet, or pulled in by a lasso); a launch or smash sends the body flying (launch).
-- How far a body may go along the ground without leaving its top is room().
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local BodyMotion = {}

-- The latest hit on each root: a hold that a newer hit restarted must not end it early.
local launches: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
-- The push of a stagger still running on each root (a newer hit removes it).
local slides: { [BasePart]: LinearVelocity } = setmetatable({}, { __mode = "k" }) :: any
-- The step of an attack still running on each root (a hit, or the next attack's step, removes it).
local lunges: { [BasePart]: LinearVelocity } = setmetatable({}, { __mode = "k" }) :: any

local function stop(pushes: { [BasePart]: LinearVelocity }, root: BasePart)
	local push = pushes[root]
	if push then
		push:Destroy()
		pushes[root] = nil
	end
end

-- A new hit on `root`: ends any push or step still running and returns this hit's number.
local function newHit(root: BasePart): number
	stop(slides, root)
	stop(lunges, root)
	local mine = (launches[root] or 0) + 1
	launches[root] = mine
	return mine
end

-- A push along the ground on `root` (a constraint: the Humanoid would stop a plain velocity at once), kept in `pushes`
-- and removed after `seconds` (or sooner by stop()).
local function push(pushes: { [BasePart]: LinearVelocity }, root: BasePart, name: string, seconds: number): LinearVelocity
	local attachment = root:FindFirstChild("StaggerAttachment") :: Attachment?
	if not attachment then
		local made = Instance.new("Attachment")
		made.Name = "StaggerAttachment"
		made.Parent = root
		attachment = made
	end
	local force = Instance.new("LinearVelocity")
	force.Name = name
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.MaxForce = 1e6
	pushes[root] = force
	task.delay(seconds, function()
		if pushes[root] == force then
			pushes[root] = nil
		end
		force:Destroy()
	end)
	return force
end

-- Whether something solid is right under the feet (the body's own parts left out).
function BodyMotion.grounded(body: CharacterParts.Body): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { body.model }
	local reach = body.root.Position.Y - CharacterParts.feetY(body) + Config.Knock.GroundReach
	return Workspace:Raycast(body.root.Position, Vector3.new(0, -reach, 0), params) ~= nil
end

-- A launch (`kind` "launch" or "smash"): stiff, held still for its Config.Feedback.HitStop, then flying with
-- `velocity`; a home run tumbles head over heels the way it was pushed (Config.Knock.SpinTurns over the flight, its time
-- taken from the lift; the turning stops as it comes down). A second hit during the hold
-- starts the hold again and its velocity wins. Unanchoring hands the physics back to Roblox's automatic choice, so
-- `reclaim(root)` runs first (the server takes a sandbag back).
function BodyMotion.launch(body: CharacterParts.Body, velocity: Vector3, kind: string, reclaim: ((BasePart) -> ())?)
	local root = body.root
	local mine = newHit(root)
	body.humanoid.PlatformStand = true
	root.Anchored = true
	task.delay(Config.Feedback.HitStop[kind] or Config.Feedback.HitStop.launch, function()
		if launches[root] ~= mine or not root.Parent then
			return
		end
		root.Anchored = false
		if reclaim then
			reclaim(root)
		end
		root.AssemblyLinearVelocity = velocity
		-- Head over heels: about the level axis across the push (pushed back, the feet swing up ahead).
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local flight = 2 * math.max(velocity.Y, 1) / Workspace.Gravity -- up and back down to the same height
		local turns = Config.Knock.SpinTurns[kind] or Config.Knock.SpinTurns.launch
		if flat.Magnitude > 1e-3 and turns > 0 then
			root.AssemblyAngularVelocity = flat.Unit:Cross(Vector3.yAxis) * -(turns * 2 * math.pi / flight)
			task.delay(flight * 0.9, function()
				if launches[root] == mine and root.Parent then
					root.AssemblyAngularVelocity = Vector3.zero
				end
			end)
		end
	end)
end

-- A light hit: held still for Config.Feedback.HitStop.light, then pushed along the ground at `velocity` (its X and
-- Z) for Config.Hit.SlideSeconds while staying on its feet (a constraint, as the Humanoid would stop a plain push at
-- once). `reclaim(root)` as for launch.
function BodyMotion.stagger(body: CharacterParts.Body, velocity: Vector3, reclaim: ((BasePart) -> ())?)
	local root = body.root
	local mine = newHit(root)
	body.humanoid.PlatformStand = false
	root.Anchored = true
	task.delay(Config.Feedback.HitStop.light, function()
		if launches[root] ~= mine or not root.Parent then
			return
		end
		root.Anchored = false
		if reclaim then
			reclaim(root)
		end
		local slide = push(slides, root, "Stagger", Config.Hit.SlideSeconds)
		slide.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane -- along the ground; falling stays free
		slide.PrimaryTangentAxis = Vector3.xAxis
		slide.SecondaryTangentAxis = Vector3.zAxis
		slide.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
		slide.Parent = root
	end)
end

-- How far `body` may step along the flat unit `flat`, up to `studs`: Config.Attack.LungeGap short of whatever is in
-- the way ahead (a fighter, a chimney), and only as far as there is still something solid to stand on (half a stud at
-- a time back from the whole step: never off the edge of a roof). Also how far a lasso may pull its catch
-- (WeaponService).
function BodyMotion.room(body: CharacterParts.Body, flat: Vector3, studs: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { body.model }
	local from = body.root.Position
	local gap = Config.Attack.LungeGap
	local blocked = Workspace:Spherecast(from, 1, flat * (studs + gap), params)
	if blocked then
		studs = math.min(studs, blocked.Distance - gap)
	end
	params.RespectCanCollide = true -- only what can be stood on
	local down = Vector3.new(0, -(from.Y - CharacterParts.feetY(body) + 1.5), 0)
	local d = studs
	while d > 0.05 do
		if Workspace:Raycast(from + flat * (d + 0.5), down, params) then
			return d
		end
		d -= 0.5
	end
	return 0
end

-- An attack steps the fighter in: up to `studs` along the flat `facing` over Config.Attack.LungeSeconds, as far as
-- room() allows, on its feet only (not flying, held or in the air). A hit ends it. Returns how far it steps.
function BodyMotion.lunge(body: CharacterParts.Body, facing: Vector3, studs: number): number
	local root, humanoid = body.root, body.humanoid
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if studs <= 0 or flat.Magnitude < 1e-3 or root.Anchored or humanoid.PlatformStand or humanoid.FloorMaterial == Enum.Material.Air then
		return 0
	end
	flat = flat.Unit
	local go = BodyMotion.room(body, flat, studs)
	if go <= 0.05 then
		return 0
	end
	stop(lunges, root)
	local seconds = Config.Attack.LungeSeconds
	local step = push(lunges, root, "Lunge", seconds)
	step.VelocityConstraintMode = Enum.VelocityConstraintMode.Line -- along the aim; sideways and falling stay free
	step.LineDirection = flat
	step.LineVelocity = go / seconds
	step.Parent = root
	return go
end

-- Whether a body launched `elapsed` seconds ago is done flying: landed (after Config.Knock.MinSeconds), or flying
-- for MaxSeconds.
function BodyMotion.landed(body: CharacterParts.Body, elapsed: number): boolean
	local k = Config.Knock
	return (elapsed >= k.MinSeconds and BodyMotion.grounded(body)) or elapsed >= k.MaxSeconds
end

-- Back on the feet after a flight or a fall.
function BodyMotion.getUp(body: CharacterParts.Body)
	body.root.AssemblyAngularVelocity = Vector3.zero
	body.humanoid.PlatformStand = false
	body.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

-- Fallen off (feet under the fall line), every frame: lying down and sliding backward at the run's speed, with the
-- ground. The trains stand still in the world while the scenery scrolls, so this is what being left behind looks like.
function BodyMotion.drift(body: CharacterParts.Body)
	body.humanoid.PlatformStand = true
	local v = body.root.AssemblyLinearVelocity
	body.root.AssemblyLinearVelocity = Vector3.new(v.X * 0.9, v.Y, Config.Run.Speed)
end

return BodyMotion
