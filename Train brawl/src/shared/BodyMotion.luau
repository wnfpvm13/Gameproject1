--!strict
-- How a fighter's body moves when hit, landed or fallen off, the same wherever its physics runs: on the player's own
-- client for a player (KnockFlight, FallDrift) and on the server for a sandbag (Sandbags).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local BodyMotion = {}

-- The latest launch of each root: a hold that a newer hit restarted must not end it early.
local launches: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any

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
	local mine = (launches[root] or 0) + 1
	launches[root] = mine
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
