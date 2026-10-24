--!strict
-- How a fighter's body moves when hit, landed or fallen off, the same wherever its physics runs: on the player's own
-- client for a player (KnockFlight, FallDrift) and on the server for a sandbag (Sandbags). A light hit flinches
-- (stagger: held still, then pushed along the ground on its feet); a launch or smash sends the body flying (launch).
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

-- A new hit on `root`: ends any push still running and returns this hit's number.
local function newHit(root: BasePart): number
	local slide = slides[root]
	if slide then
		slide:Destroy()
		slides[root] = nil
	end
	local mine = (launches[root] or 0) + 1
	launches[root] = mine
	return mine
end

-- Whether something solid is right under the feet (the body's own parts left out).
function BodyMotion.grounded(body: CharacterParts.Body): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { body.model }
	local reach = body.root.Position.Y - CharacterParts.feetY(body) + Config.Knock.GroundReach
	return Workspace:Raycast(body.root.Position, Vector3.new(0, -reach, 0), params) ~= nil
end

-- A hit: stiff, held still for Config.Feedback.HitStopSeconds, then flying with `velocity`. A second hit during the
-- hold starts the hold again and its velocity wins. Unanchoring hands the physics back to Roblox's automatic choice,
-- so `reclaim(root)` runs first (the server takes a sandbag back).
function BodyMotion.launch(body: CharacterParts.Body, velocity: Vector3, reclaim: ((BasePart) -> ())?)
	local root = body.root
	local mine = newHit(root)
	body.humanoid.PlatformStand = true
	root.Anchored = true
	task.delay(Config.Feedback.HitStopSeconds, function()
		if launches[root] ~= mine or not root.Parent then
			return
		end
		root.Anchored = false
		if reclaim then
			reclaim(root)
		end
		root.AssemblyLinearVelocity = velocity
	end)
end

-- A light hit: held still for Config.Feedback.HitStopSeconds, then pushed along the ground at `velocity` (its X and
-- Z) for Config.Hit.SlideSeconds while staying on its feet (a constraint, as the Humanoid would stop a plain push at
-- once). `reclaim(root)` as for launch.
function BodyMotion.stagger(body: CharacterParts.Body, velocity: Vector3, reclaim: ((BasePart) -> ())?)
	local root = body.root
	local mine = newHit(root)
	body.humanoid.PlatformStand = false
	root.Anchored = true
	task.delay(Config.Feedback.HitStopSeconds, function()
		if launches[root] ~= mine or not root.Parent then
			return
		end
		root.Anchored = false
		if reclaim then
			reclaim(root)
		end
		local attachment = root:FindFirstChild("StaggerAttachment") :: Attachment?
		if not attachment then
			local made = Instance.new("Attachment")
			made.Name = "StaggerAttachment"
			made.Parent = root
			attachment = made
		end
		local push = Instance.new("LinearVelocity")
		push.Name = "Stagger"
		push.Attachment0 = attachment
		push.RelativeTo = Enum.ActuatorRelativeTo.World
		push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane -- along the ground; falling stays free
		push.PrimaryTangentAxis = Vector3.xAxis
		push.SecondaryTangentAxis = Vector3.zAxis
		push.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
		push.MaxForce = 1e6
		push.Parent = root
		slides[root] = push
		task.delay(Config.Hit.SlideSeconds, function()
			if slides[root] == push then
				slides[root] = nil
			end
			push:Destroy()
		end)
	end)
end

-- Whether a body launched `elapsed` seconds ago is done flying: landed (after Config.Knock.MinSeconds), or flying
-- for MaxSeconds.
function BodyMotion.landed(body: CharacterParts.Body, elapsed: number): boolean
	local k = Config.Knock
	return (elapsed >= k.MinSeconds and BodyMotion.grounded(body)) or elapsed >= k.MaxSeconds
end

-- Back on the feet after a flight or a fall.
function BodyMotion.getUp(body: CharacterParts.Body)
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
