--!strict
-- The practice bots' minds (Studio solo practice: the bodies are Sandbags'). Sandbags asks a bot to think whenever it
-- is free to act in a fight (not flying, not fallen). It goes for the nearest other fighter on the top it stands on
-- (BotPlan, at most Config.Sandbag.PerTarget bots on one; it keeps its choice while that one stays on its top), runs
-- up to it and steps straight in the last bit, turns to it and punches its 1-2-3 string through the same server judging as a
-- player's attacks (hooks.attack: cooldown, stun, string and hits are all checked there) - after a moment to react,
-- sometimes stopping after one or two, with a breather after each string. With nobody on its top it wanders the top.
-- With bare fists it goes for a landed crate on its top first when that is nearer than its target (hooks.crates; it
-- takes the weapon by walking into it, as a player does, and attacks with it the same way: persona fix 3, so solo
-- practice shows the weapons). Bots stay on the car top they stand on (crossing between tops comes with B), except
-- that a bot whose car is coming off (hooks.away) walks to the car in front once it notices, jumping up when it stops
-- against a higher car; and a bot on a top too high for a low bridge coming (hooks.bridge) walks to the nearest low top
-- of its train once it notices (decision 24), staying there till the bridge has gone over (bots keep to their own top),
-- or ducks under its block where it stands when the beam is about to reach it first.
-- Hit (its health dropped since it last looked), a bot sometimes holds its block a moment facing
-- its target (hooks.block: the server's own block) or rolls away from it (hooks.dodge). A fighter standing just off a
-- top - a plank's end, a roof's edge - counts as on that top (ArenaLayout.nearTop). (2nd fix 4, 2026-10-31.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local BotPlan = require(shared:WaitForChild("BotPlan"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local BridgeRules = require(shared:WaitForChild("BridgeRules"))

local BotBrain = {}

export type Hooks = {
	fighters: () -> { Model }, -- the models still in the round
	-- The bot attacks along the flat facing: how far the attack stepped it in (nil: not now).
	attack: (model: Model, facing: Vector3) -> number?,
	crates: () -> { Vector3 }, -- where the landed crates nobody has taken lie
	away: (train: number, car: number) -> boolean, -- that car is coming off or gone (Uncoupling)
	bridge: () -> BridgeRules.Pass?, -- a low bridge coming or going over now (Bridges)
	block: (model: Model, down: boolean) -> (), -- the bot's block control (Guarding)
	dodge: (model: Model, direction: Vector3) -> boolean, -- a roll (Dodging; false when not now)
}
export type Brain = {
	-- `model` (its `body`) is free to act at `now` (os.clock()) in a fight.
	think: (model: Model, body: CharacterParts.Body, now: number) -> (),
}

-- target: whom it goes for; seen: when it last thought (a long gap means it was flying or held: it reacts anew);
-- thinkAt: when it looks again; inReach: the target was in reach last time; readyAt: no punch before this (reacting);
-- nextPunch: the next punch of the string no sooner; left: punches left in this string; wanderAt: a new spot then;
-- stepping: it is stepping straight in (Humanoid:Move goes on until stopped). health: its health when it last looked;
-- blockUntil: it holds its block until then; noticeAt: it notices its car coming off then (nil: not seen coming off);
-- bridgeAt: it notices a low bridge coming then (nil: none coming); lastPlace, stuckAt: where it was when it last
-- checked it was moving, and when (to jump when it is stuck).
type Mind = {
	target: Model?,
	seen: number,
	thinkAt: number,
	inReach: boolean,
	readyAt: number,
	nextPunch: number,
	left: number,
	wanderAt: number,
	stepping: boolean,
	health: number?,
	blockUntil: number?,
	noticeAt: number?,
	bridgeAt: number?,
	lastPlace: Vector3?,
	stuckAt: number,
}

-- A random number between the two of `range`.
local function between(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

-- How many punches the next string is meant to have.
local function planString(): number
	return if math.random() < Config.Sandbag.FullString then Config.Attack.StringCount else math.random(1, Config.Attack.StringCount - 1)
end

-- Walks `humanoid` to `spot` (a step straight in, Humanoid:Move, ends first: Move(zero) alone would not end a MoveTo,
-- and a MoveTo after a Move takes over - Studio 2026-10-27).
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
			mind = {
				target = nil,
				seen = now,
				thinkAt = now,
				inReach = false,
				readyAt = now,
				nextPunch = now,
				left = planString(),
				wanderAt = now,
				stepping = false,
				health = nil,
				blockUntil = nil,
				noticeAt = nil,
				bridgeAt = nil,
				lastPlace = nil,
				stuckAt = now,
			}
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
		local stepping = mind.stepping -- each look decides anew (only the step-in below goes on with it)
		mind.stepping = false
		local humanoid = body.humanoid
		local here, top = placeOf(body)
		-- Hit since it last looked: sometimes a block for a moment, sometimes a roll away from whom it fights.
		local health = PartUtil.number(model, Names.Health)
		local hit = health ~= nil and mind.health ~= nil and health < mind.health
		mind.health = health
		if mind.blockUntil and now >= mind.blockUntil then
			mind.blockUntil = nil
			hooks.block(model, false)
		end
		if not top then
			-- Just off a top itself (a plank's end it stepped onto after someone): on that top still - it walks back onto it,
			-- and walks off a car coming off.
			top = ArenaLayout.nearTop(surfaces, here.X, here.Z, CharacterParts.feetY(body), c.SeeOff, c.SeeRise)
		end
		if not top then
			walkTo(humanoid, here) -- out on a plank, a boiler's side or the sand: stand still
			return
		end
		-- Walking somewhere it must go: jumping when it has not moved for a moment (against a higher car).
		local function unstuck()
			if now - mind.stuckAt > 0.5 then
				if mind.lastPlace and (here - mind.lastPlace).Magnitude < 0.4 then
					humanoid.Jump = true
				end
				mind.lastPlace, mind.stuckAt = here, now
			end
		end
		-- A low bridge coming and this top too high: once it notices, to the nearest low top of its train still on.
		local B = Config.Bridge
		local pass = hooks.bridge()
		if pass and not BridgeRules.safe(top.top, B.Stature, B.Clearance) then
			local bridgeAt = mind.bridgeAt or now + between(c.Notice)
			mind.bridgeAt = bridgeAt
			local beamZ = BridgeRules.beamZ(pass, Workspace:GetServerTimeNow())
			if now >= bridgeAt and beamZ > here.Z - Config.Run.Speed * c.DuckAhead and beamZ < here.Z + B.Depth then
				-- The beam is about to reach it: duck under the block where it stands.
				mind.target = nil
				mind.blockUntil = now + c.ThinkSeconds * 3
				hooks.block(model, true)
				walkTo(humanoid, here)
				return
			end
			if now >= bridgeAt then
				local low = {}
				for _, safe in BridgeRules.safeTops(surfaces, top.train, B.Stature, B.Clearance) do
					if not hooks.away(safe.train, safe.car) then
						table.insert(low, safe)
					end
				end
				local spot = BridgeRules.nearestSafe(low, here.Z)
				if spot then
					if mind.blockUntil then
						mind.blockUntil = nil
						hooks.block(model, false)
					end
					mind.target = nil
					humanoid.WalkSpeed = c.ChaseSpeed
					local inset = math.max(0, spot.length / 2 - c.Margin)
					walkTo(humanoid, Vector3.new(spot.x, here.Y, math.clamp(here.Z, spot.z - inset, spot.z + inset)))
					unstuck()
					return
				end
			end
		elseif not pass then
			mind.bridgeAt = nil
		end
		-- Its car is coming off: once it notices, to the car in front (jumping up a higher one).
		if hooks.away(top.train, top.car) then
			local noticeAt = mind.noticeAt or now + between(c.Notice)
			mind.noticeAt = noticeAt
			local front = ArenaLayout.frontTop(surfaces, top.train, top.car)
			if front and now >= noticeAt then
				if mind.blockUntil then
					mind.blockUntil = nil
					hooks.block(model, false)
				end
				mind.target = nil
				humanoid.WalkSpeed = c.ChaseSpeed
				walkTo(humanoid, Vector3.new(front.x, here.Y, front.z))
				unstuck()
				return
			end
		else
			mind.noticeAt = nil
		end
		-- Everyone else on this top, and how many other bots still in the round go for each.
		local others: { BotPlan.Seen } = {}
		local current: BotPlan.Seen? = nil
		local fighting: { [Model]: boolean } = {}
		for _, other in hooks.fighters() do
			fighting[other] = true
			local otherBody = if other ~= model then CharacterParts.body(other) else nil
			if otherBody then
				local at, otherTop = placeOf(otherBody)
				if not otherTop then
					-- Just off a top (a plank's end, over a roof's edge): seen as on it.
					otherTop = ArenaLayout.nearTop(surfaces, at.X, at.Z, CharacterParts.feetY(otherBody), c.SeeOff, c.SeeRise)
				end
				local seen: BotPlan.Seen = { key = other, x = at.X, z = at.Z, top = otherTop }
				table.insert(others, seen)
				if other == mind.target and otherTop == top then
					current = seen
				end
			end
		end
		local taken: { [any]: number } = {}
		for other, otherMind in minds do
			if other ~= model and fighting[other] and otherMind.target then
				taken[otherMind.target] = (taken[otherMind.target] or 0) + 1
			end
		end
		local target = current or BotPlan.nearest(here.X, here.Z, top, others, taken, c.PerTarget)
		-- Bare fists: a crate on this top nearer than the target first.
		if WeaponRules.named(Config.Weapons, model:GetAttribute(Names.Weapon)) == WeaponRules.FIST then
			local spots = {}
			for _, at in hooks.crates() do
				table.insert(spots, { x = at.X, z = at.Z })
			end
			local crate, away = BotPlan.crateOn(top, here.X, here.Z, spots)
			local targetAway = if target then math.sqrt((target.x - here.X) ^ 2 + (target.z - here.Z) ^ 2) else math.huge
			if crate and away < targetAway then
				mind.target = nil
				humanoid.WalkSpeed = c.ChaseSpeed
				walkTo(humanoid, Vector3.new(crate.x, here.Y, crate.z))
				return
			end
		end
		if not target then
			mind.target = nil
			humanoid.WalkSpeed = c.WalkSpeed
			if now >= mind.wanderAt then
				mind.wanderAt = now + c.WanderSeconds * (0.6 + math.random() * 0.8)
				local x, z = BotPlan.wanderSpot(top, here.Z, 8, c.Margin, math.random)
				walkTo(humanoid, Vector3.new(x, here.Y, z))
			elseif stepping then
				walkTo(humanoid, here) -- its target went away mid-step: stop rather than walk on off the top
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
		-- Hit: a block facing it for a moment, or a roll away.
		if hit and not mind.blockUntil then
			local roll = math.random()
			if roll < c.BlockChance then
				mind.blockUntil = now + between(c.BlockHold)
				hooks.block(model, true)
			elseif roll < c.BlockChance + c.RollChance and distance > 1e-3 then
				hooks.dodge(model, -toward.Unit)
			end
		end
		if mind.blockUntil then
			walkTo(humanoid, here)
			if distance > 1e-3 then
				body.root.CFrame = CFrame.lookAt(here, here + toward.Unit) -- the block faces whom it fights
			end
			return
		end
		-- In reach once it has stepped in to StandOff; out again past PunchFrom.
		if distance > (if mind.inReach then c.PunchFrom else c.StandOff) then
			mind.inReach = false
			if distance > c.PunchFrom + c.StepIn then
				humanoid.WalkSpeed = c.ChaseSpeed
				local x, z = BotPlan.standSpot(top, here.X, here.Z, target.x, target.z, c.StandOff, c.Margin)
				walkTo(humanoid, Vector3.new(x, here.Y, z))
			else
				-- Close: straight at it, slower (a MoveTo this short stops about a stud early). Both stand on the same
				-- top, so the way between stays on it (one look later, 0.6 at most, it looks again).
				humanoid.WalkSpeed = c.StepSpeed
				humanoid:Move(toward.Unit)
				mind.stepping = true
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
		local stepped = hooks.attack(model, facing)
		if not stepped then
			mind.nextPunch = now + c.ThinkSeconds -- stunned or not ready yet: try again soon
			return
		end
		if stepped > 0 then
			walkTo(humanoid, here + facing * stepped) -- stand where the attack's step took it (not walk back)
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
