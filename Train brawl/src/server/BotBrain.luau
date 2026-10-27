--!strict
-- The practice bots' minds (Studio solo practice: the bodies are Sandbags'). Sandbags asks a bot to think whenever it
-- is free to act in a fight (not flying, not fallen). It goes for the nearest other fighter on the top it stands on
-- (BotPlan, at most Config.Sandbag.PerTarget bots on one; it keeps its choice while that one stays on its top), runs
-- up to it and steps straight in the last bit, turns to it and punches its 1-2-3 string through the same server judging as a
-- player's attacks (hooks.attack: cooldown, stun, string and hits are all checked there) - after a moment to react,
-- sometimes stopping after one or two, with a breather after each string. With nobody on its top it wanders the top.
-- For now bots punch with bare fists (they do not pick crates up) and stay on the car top they stand on (crossing
-- between tops comes with B).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local BotPlan = require(shared:WaitForChild("BotPlan"))

local BotBrain = {}

export type Hooks = {
	fighters: () -> { Model }, -- the models still in the round
	attack: (model: Model, facing: Vector3) -> boolean, -- the bot attacks along the flat facing (false: not now)
}
export type Brain = {
	-- `model` (its `body`) is free to act at `now` (os.clock()) in a fight.
	think: (model: Model, body: CharacterParts.Body, now: number) -> (),
}

-- target: whom it goes for; seen: when it last thought (a long gap means it was flying or held: it reacts anew);
-- thinkAt: when it looks again; inReach: the target was in reach last time; readyAt: no punch before this (reacting);
-- nextPunch: the next punch of the string no sooner; left: punches left in this string; wanderAt: a new spot then.
type Mind = {
	target: Model?,
	seen: number,
	thinkAt: number,
	inReach: boolean,
	readyAt: number,
	nextPunch: number,
	left: number,
	wanderAt: number,
}

-- A random number between the two of `range`.
local function between(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

-- How many punches the next string is meant to have.
local function planString(): number
	return if math.random() < Config.Sandbag.FullString then Config.Attack.StringCount else math.random(1, Config.Attack.StringCount - 1)
end

-- Walks `humanoid` to `spot` (a step straight in, Humanoid:Move, ends first).
local function walkTo(humanoid: Humanoid, spot: Vector3)
	humanoid:Move(Vector3.zero)
	humanoid:MoveTo(spot)
end

-- surfaces: the arena's walkable tops (ArenaLayout).
function BotBrain.new(surfaces: { ArenaLayout.Surface }, hooks: Hooks): Brain
	local c = Config.Sandbag
	local fist = Config.Weapons.Fist
	local minds: { [Model]: Mind } = setmetatable({}, { __mode = "k" }) :: any

	-- Where `body` stands and the top under it.
	local function placeOf(body: CharacterParts.Body): (Vector3, ArenaLayout.Surface?)
		local at = body.root.Position
		return at, ArenaLayout.topUnder(surfaces, at.X, at.Z, CharacterParts.feetY(body))
	end

	local function think(model: Model, body: CharacterParts.Body, now: number)
		local mind = minds[model]
		if not mind then
			mind = { target = nil, seen = now, thinkAt = now, inReach = false, readyAt = now, nextPunch = now, left = planString(), wanderAt = now }
			minds[model] = mind
		end
		if now < mind.thinkAt then
			return
		end
		if now - mind.seen > 0.5 then
			mind.inReach = false -- back on its feet after a flight: take a moment again
		end
		mind.seen = now
		mind.thinkAt = now + c.ThinkSeconds
		local humanoid = body.humanoid
		local here, top = placeOf(body)
		if not top then
			walkTo(humanoid, here) -- on a plank, a boiler's side or the sand: stand still
			return
		end
		-- Everyone else on this top, and how many other bots go for each.
		local others: { BotPlan.Seen } = {}
		local current: BotPlan.Seen? = nil
		for _, other in hooks.fighters() do
			local otherBody = if other ~= model then CharacterParts.body(other) else nil
			if otherBody then
				local at, otherTop = placeOf(otherBody)
				local seen: BotPlan.Seen = { key = other, x = at.X, z = at.Z, top = otherTop }
				table.insert(others, seen)
				if other == mind.target and otherTop == top then
					current = seen
				end
			end
		end
		local taken: { [any]: number } = {}
		for other, otherMind in minds do
			if other ~= model and otherMind.target then
				taken[otherMind.target] = (taken[otherMind.target] or 0) + 1
			end
		end
		local target = current or BotPlan.nearest(here.X, here.Z, top, others, taken, c.PerTarget)
		if not target then
			mind.target = nil
			humanoid.WalkSpeed = c.WalkSpeed
			if now >= mind.wanderAt then
				mind.wanderAt = now + c.WanderSeconds * (0.6 + math.random() * 0.8)
				local x, z = BotPlan.wanderSpot(top, here.Z, 8, c.Margin, math.random)
				walkTo(humanoid, Vector3.new(x, here.Y, z))
			end
			return
		end
		if target.key ~= mind.target then
			mind.target = target.key
			mind.inReach = false
			mind.left = planString()
		end
		local toward = Vector3.new(target.x - here.X, 0, target.z - here.Z)
		local distance = toward.Magnitude
		-- In reach once it has stepped in to StandOff; out again past PunchFrom.
		if distance > (if mind.inReach then c.PunchFrom else c.StandOff) then
			mind.inReach = false
			if distance > c.PunchFrom + c.StepIn then
				humanoid.WalkSpeed = c.ChaseSpeed
				local x, z = BotPlan.standSpot(top, here.X, here.Z, target.x, target.z, c.StandOff, c.Margin)
				walkTo(humanoid, Vector3.new(x, here.Y, z))
			else
				-- Close: straight at it, slower (a MoveTo this short stops about a stud early). Both stand on the same
				-- top, so the way between stays on it.
				humanoid.WalkSpeed = c.StepSpeed
				humanoid:Move(toward.Unit)
			end
			return
		end
		if not mind.inReach then
			mind.inReach = true
			mind.readyAt = math.max(mind.readyAt, now + between(c.React))
		end
		walkTo(humanoid, here)
		local facing = if distance > 1e-3 then toward.Unit else body.root.CFrame.LookVector
		if body.root.CFrame.LookVector:Dot(facing) < 0.98 then
			body.root.CFrame = CFrame.lookAt(here, here + facing) -- face it (the server moves the bot)
		end
		if now < mind.readyAt or now < mind.nextPunch then
			return
		end
		if not hooks.attack(model, facing) then
			mind.nextPunch = now + c.ThinkSeconds -- stunned or not ready yet: try again soon
			return
		end
		mind.left -= 1
		if mind.left <= 0 then
			mind.left = planString()
			mind.nextPunch = now + fist.cooldown + between(c.Rest)
		else
			mind.nextPunch = now + fist.cooldown + math.random() * c.Jitter
		end
	end

	return { think = think }
end

return BotBrain
