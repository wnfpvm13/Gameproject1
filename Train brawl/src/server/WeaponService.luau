--!strict
-- Attacks, judged on the server, for every weapon (Config.Weapons): bare fists by default, or the weapon a fighter
-- picked up (give, from a crate: WeaponDrops), kept as the character's Names.Weapon with its uses left
-- (Names.WeaponUses) or the server time it runs out (Names.WeaponEndsAt) for every screen to show.
--
-- A player's client attacks at once and tells the server where it aimed; the server takes the attack when the player
-- is fighting, alive, not stunned by a hit (from Config.Knock.SwingGrace until the hit's stun ends: an attack arriving
-- sooner was pressed before the player saw the hit) and the last attack's weapon is ready again (its cooldown: a
-- hammer's stays even if the hammer ran out with it). The server takes an attack up to Config.Attack's slack early, but
-- the next one is still counted from when this one was due, so the slack never adds up to a faster rate. A fighter the
-- server runs itself (a practice bot: attack()) goes through the same judging with no network allowances: refused all
-- through a stun and until its weapon is ready.
-- Each punch or swing is a step of its attacker's 1-2-3 string (AttackString: it goes on hit or miss while the attacks
-- come in time; the client says which step it drew, the server takes that only as far as its own count allows; being
-- hit breaks a fighter's string; the launching last step lands a moment later). It marks the character's
-- Names.SwingStep, Names.SwingTag (the attack's number its client sent) and Names.SwingAt (every client draws the
-- weapon's attack and step from them) and, the weapon's hitAt
-- later, lands it by its style: a punch, a swing or a spray hits every other fighter in a cone in front (SwingTargets,
-- reach widened by the network slack), a lasso only the nearest one in its cone (pulled in to just in front of its
-- thrower: never past the edge of what the catch stands on, BodyMotion.room, and tied for the weapon's stun), a slam
-- everyone around a point just ahead, a burst everyone around the attacker, a throw sends a lit dynamite stick (Dynamite)
-- whose blast hits everyone around where it bursts (not the thrower), and a toss, a roll or a pour sends out a coal lump,
-- a wheel or an oil slick (hooks.send) that hits on its own whoever it reaches (not its sender).
--
-- Every hit asks the health keeper what it was (hooks.hit with the weapon's damage and the attacker; the string's last
-- step of a punch or swing, or a weapon that always launches, makes the hit a launch, still pushed by health) and pushes by health (HitRules.force) times the weapon's push and
-- the victim's resistance (a held gold bar), away from the attacker (a blast: from where it burst); a smash (health
-- emptied) flies the same home run whatever hit it. A hit meeting a block (hooks.blocking, from the front, a weapon that
-- can be blocked: BlockRules) lands softened, and a blocked string finisher breaks the guard instead of launching
-- (hooks.guardBroken); a blocker cannot attack and walks slower. A blast after the fight is over hits nobody. It is
-- sent to every client (Names.HitRemote: victim, velocity, attacker, kind, weapon, whether a crowd launched it, the
-- attack's number as its player's client counted them - none for a blast - and "blocked" or "broken" when it met a
-- block): the victim's own client moves its
-- character, everyone shows it; a sandbag is moved here. A weapon goes back to bare fists when used up, when its time
-- is over, when its holder is out or fell off (on its way back: Names.ReturnPhase), and whenever no fight is running.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local BatMath = require(shared:WaitForChild("BatMath"))
local HitRules = require(shared:WaitForChild("HitRules"))
local AttackString = require(shared:WaitForChild("AttackString"))
local SwingTargets = require(shared:WaitForChild("SwingTargets"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local BodyMotion = require(shared:WaitForChild("BodyMotion"))
local BlockRules = require(shared:WaitForChild("BlockRules"))

local WeaponService = {}

export type Hooks = {
	canSwing: (model: Model) -> boolean, -- the model is a fighter in a running fight
	fighters: () -> { Model }, -- the models that can be hit
	-- The health keeper: this hit's kind and the health left (damage taken; launch: the attacker's hit launches; by:
	-- the attacker, told apart for the guard against being ganged up on).
	hit: (victim: Model, now: number, damage: number, launch: boolean, by: Model) -> (HitRules.Kind, number, boolean),
	knockHere: (model: Model, velocity: Vector3, kind: HitRules.Kind) -> boolean, -- moves a server-owned model (a sandbag)
	onHit: (victim: Model, attacker: Model) -> (), -- for the knock-off credit
	attacked: (model: Model) -> (), -- an attack of the model's was taken (a fighter just back loses its guard)
	blocking: (model: Model) -> boolean, -- the model holds its block now (Guarding)
	guardBroken: (model: Model, now: number) -> (), -- a string finisher met its block: the guard breaks
	onSmash: (victim: Model) -> (), -- health emptied: out of the round
	equip: (model: Model) -> (), -- puts the model's Names.Weapon in its hand (WeaponGear)
	-- Throws a lit stick from a fighter standing at `from` along the flat `facing`; `burst(at)` when its fuse runs out
	-- (Dynamite).
	throw: (from: Vector3, facing: Vector3, burst: (Vector3) -> ()) -> (),
	-- Sends out what `weapon` (a toss, a roll or a pour) leaves in the arena, from `attacker` standing at `from` along the
	-- flat `facing`: `hit(victim, push)` for every other fighter it reaches, pushed away from `push` (Missiles, Wheels,
	-- Slicks).
	send: (weapon: string, attacker: Model, from: Vector3, facing: Vector3, hit: (Model, Vector3) -> ()) -> (),
	putOut: () -> (), -- puts out every stick still burning and takes away what was sent out (no fight is running)
	blast: (at: Vector3, radius: number) -> (), -- tells every client a dynamite burst here
}
export type Service = {
	give: (model: Model, weapon: string) -> (), -- the model holds this weapon now
	holding: (model: Model) -> string, -- the weapon the model holds ("Fist" for bare fists)
	-- A fighter the server runs (a practice bot) attacks along the flat `facing`; false when it may not now.
	attack: (model: Model, facing: Vector3) -> boolean,
	repace: (model: Model) -> (), -- sets the model's walk again (it started or stopped blocking)
	stop: () -> (),
}

local FIST = WeaponRules.FIST

function WeaponService.start(swingRemote: RemoteEvent, hitRemote: RemoteEvent, hooks: Hooks): Service
	local attack = Config.Attack
	local weapons = Config.Weapons
	-- Per fighter (a player's character or a bot): the server time its last attack's weapon is ready again, and its
	-- 1-2-3 string.
	local readyAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	local strings: { [Model]: AttackString.State } = setmetatable({}, { __mode = "k" }) :: any
	local stringRules = AttackString.rules(attack)
	-- Per fighter: when the last hit landed and when its stun ends (server time).
	local hitAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	local stunUntil: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	local armed: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- holding something other than fists

	local function holding(model: Model): string
		return WeaponRules.named(weapons, model:GetAttribute(Names.Weapon))
	end

	-- Walking speed for what the model holds (a gold bar slows) and whether it blocks, unless the round or a parachute
	-- holds it still (speed 0).
	local function pace(model: Model, weapon: string)
		local body = CharacterParts.body(model)
		if body and body.humanoid.WalkSpeed > 0 then
			local block = if hooks.blocking(model) then Config.Block.WalkShare else 1
			body.humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed * (weapons[weapon].slow or 1) * block
		end
	end

	local function set(model: Model, weapon: string)
		local w = weapons[weapon]
		local chain = if model:GetAttribute(Names.Weapon) ~= weapon then strings[model] else nil
		if chain then
			AttackString.reset(chain) -- a new weapon in hand starts the string over
		end
		model:SetAttribute(Names.Weapon, weapon)
		model:SetAttribute(Names.WeaponUses, w.uses)
		model:SetAttribute(Names.WeaponEndsAt, if w.heldSeconds then Workspace:GetServerTimeNow() + w.heldSeconds else nil)
		if weapon ~= FIST then
			armed[model] = true
		else
			armed[model] = nil
		end
		pace(model, weapon)
		hooks.equip(model)
	end

	-- The velocity that yanks a lassoed `victim` in to `pull` in front of `attacker` over a light hit's slide, as far as
	-- the victim has floor to slide on (never off its own top) and short of the attacker's body.
	local function pulled(victim: CharacterParts.Body, attacker: Model, pull: number): Vector3
		local me = CharacterParts.body(attacker)
		if not me then
			return Vector3.zero
		end
		local gap = me.root.Position - victim.root.Position
		local flat = Vector3.new(gap.X, 0, gap.Z)
		local distance = flat.Magnitude
		if distance <= pull + 0.05 then
			return Vector3.zero
		end
		local unit = flat / distance
		return unit * (BodyMotion.room(victim, unit, distance - pull) / Config.Hit.SlideSeconds)
	end

	-- One hit of `weapon` by `attacker` on `victim` at `step` of the attacker's string, pushed away from `from` (or along
	-- `facing` when on top of it). `tag`: the attack's number its player's client sent (Names.SwingTag; nil for a blast
	-- or none sent), sent with the hit so the attacker's screen knows which of its attacks it was.
	local function land(victim: CharacterParts.Body, attacker: Model, weapon: string, from: Vector3, facing: Vector3, now: number, step: number, tag: number?)
		local w = weapons[weapon]
		local launch = w.launch == true or AttackString.launches(stringRules, step, w.style)
		local at = victim.root.Position
		-- Met by a block: from the front, with a weapon that can be blocked (Config.Block).
		local look = victim.root.CFrame.LookVector
		local blocked = hooks.blocking(victim.model) and BlockRules.blockable(w.launch)
			and BlockRules.covers(at.X, at.Z, look.X, look.Z, from.X, from.Z, Config.Block.Arc)
		local damage, pushShare, broke = w.damage, 1, false
		if blocked then
			local share
			share, pushShare, broke = BlockRules.outcome(launch, Config.Block)
			damage *= share
			launch = false
		end
		local kind, health, ganged = hooks.hit(victim.model, now, damage, launch, attacker)
		if kind == "none" then
			return
		end
		-- Only a light hit stays a blocked one (a crowd's launch or a hit that empties health goes through as it is).
		local guard: string? = if blocked and kind == "light" then (if broke then "broken" else "blocked") else nil
		local broken = strings[victim.model]
		if broken then
			AttackString.reset(broken) -- being hit breaks the victim's own string
		end
		local push, lift = HitRules.force(kind, health, Config.Health.Max, Config.Hit)
		if kind ~= "smash" then
			push *= w.push * (weapons[holding(victim.model)].resist or 1)
		end
		if guard == "blocked" then
			push *= pushShare
		end
		local velocity: Vector3
		if w.pull and kind == "light" and not guard then
			velocity = pulled(victim, attacker, w.pull)
		else
			local vx, vy, vz = BatMath.knock(from.X, from.Z, facing.X, facing.Z, at.X, at.Z, push, lift)
			velocity = Vector3.new(vx, vy, vz)
		end
		hitAt[victim.model] = now
		-- A hit never shortens a stun still running (a lasso's tie outlasts the jab that follows it).
		local stun = if kind ~= "light" then Config.Knock.MinSeconds
			elseif guard == "blocked" then Config.Block.Stun
			elseif guard == "broken" then Config.Hit.LightStun
			else w.stun or Config.Hit.LightStun
		stunUntil[victim.model] = math.max(stunUntil[victim.model] or now, now + stun)
		if guard == "broken" then
			hooks.guardBroken(victim.model, now)
		end
		hooks.knockHere(victim.model, velocity, kind)
		hitRemote:FireAllClients(victim.model, velocity, attacker, kind, weapon, ganged, tag, guard)
		hooks.onHit(victim.model, attacker)
		if kind == "smash" then
			hooks.onSmash(victim.model)
		end
	end

	-- Everyone but `attacker` around `center` (an area hit).
	local function around(center: Vector3, radius: number, attacker: Model): { CharacterParts.Body }
		local list = {}
		for _, model in hooks.fighters() do
			local body = if model ~= attacker then CharacterParts.body(model) else nil
			if body then
				local at = body.root.Position
				if WeaponRules.inArea(center.X, center.Y, center.Z, at.X, at.Y, at.Z, radius, attack.HeightReach) then
					table.insert(list, body)
				end
			end
		end
		return list
	end

	local function strike(attacker: Model, weapon: string, facing: Vector3, step: number, tag: number?)
		local body = CharacterParts.body(attacker)
		if not (body and hooks.canSwing(attacker)) then
			return
		end
		local w = weapons[weapon]
		local now = Workspace:GetServerTimeNow()
		local from = body.root.Position
		if WeaponRules.area(w.style) then
			local center = from + facing * assert(w.ahead, weapon .. ".ahead")
			for _, victim in around(center, assert(w.radius, weapon .. ".radius"), attacker) do
				land(victim, attacker, weapon, from, facing, now, step, tag)
			end
		elseif w.style == "throw" then
			hooks.throw(from, facing, function(at: Vector3)
				if Workspace:GetAttribute(Names.Phase) ~= "Fight" then
					return -- the round ended while it burned
				end
				local radius = assert(w.radius, weapon .. ".radius")
				hooks.blast(at, radius)
				for _, victim in around(at, radius, attacker) do
					land(victim, attacker, weapon, at, facing, Workspace:GetServerTimeNow(), step)
				end
			end)
		elseif w.style == "toss" or w.style == "roll" or w.style == "pour" then
			hooks.send(weapon, attacker, from, facing, function(victim: Model, push: Vector3)
				local reached = if victim ~= attacker then CharacterParts.body(victim) else nil
				if reached and Workspace:GetAttribute(Names.Phase) == "Fight" then
					local along = reached.root.Position - push
					local flat = Vector3.new(along.X, 0, along.Z)
					land(reached, attacker, weapon, push, if flat.Magnitude > 1e-3 then flat.Unit else facing, Workspace:GetServerTimeNow(), step)
				end
			end)
		elseif w.style == "lasso" then
			-- Only the nearest one in its line is caught.
			local reach = assert(w.reach, weapon .. ".reach") + attack.ReachSlack
			local caught: CharacterParts.Body? = nil
			local best = math.huge
			for _, victim in SwingTargets.find(body, hooks.fighters(), reach, facing, w.halfAngle) do
				local d = (victim.root.Position - from).Magnitude
				if d < best then
					caught, best = victim, d
				end
			end
			if caught then
				land(caught, attacker, weapon, from, facing, now, step, tag)
			end
		else
			local reach = assert(w.reach, weapon .. ".reach") + attack.ReachSlack
			for _, victim in SwingTargets.find(body, hooks.fighters(), reach, facing, w.halfAngle) do
				land(victim, attacker, weapon, from, facing, now, step, tag)
			end
		end
	end

	-- An attack by `model` along `aim` (unchecked: the flat facing the server sees when unusable). `claim`: the step its
	-- client drew; `tag`: the attack's number its client sent; `allowance`: whether to grant a player's network
	-- allowances (taken a little early, and pressed before the hit that stuns it showed). Returns whether it was taken.
	local function begin(model: Model, aim: unknown, claim: number?, tag: number?, allowance: boolean): boolean
		local body = CharacterParts.body(model)
		if not (body and body.humanoid.Health > 0 and hooks.canSwing(model)) or hooks.blocking(model) then
			return false -- (a blocker cannot attack)
		end
		local now = Workspace:GetServerTimeNow()
		local since = hitAt[model]
		local stunned = stunUntil[model]
		local grace = if allowance then Config.Knock.SwingGrace else 0
		if since and stunned and now - since >= grace and now < stunned then
			return false -- still stunned by a hit (the client does not attack then either)
		end
		local weapon = holding(model)
		local w = weapons[weapon]
		local ready = readyAt[model]
		if ready and now < ready - (if allowance then attack.CooldownSlack else 0) then
			return false
		end
		readyAt[model] = math.max(now, ready or now) + w.cooldown
		local chain = strings[model]
		if not chain then
			chain = AttackString.new()
			strings[model] = chain
		end
		local step = AttackString.take(chain, stringRules, now, w.cooldown, w.style, claim)
		-- Where the attacker aimed when pressed (along the ground); the facing this server sees if that is unusable.
		local seen = body.root.CFrame.LookVector
		local look = Vector3.new(seen.X, 0, seen.Z)
		local facing = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
		if typeof(aim) == "Vector3" then
			local flat = Vector3.new(aim.X, 0, aim.Z)
			local length = flat.Magnitude
			if length > 1e-3 and length < math.huge then -- also false for NaN
				facing = flat / length
			end
		end
		model:SetAttribute(Names.SwingWeapon, weapon)
		model:SetAttribute(Names.SwingStep, step)
		model:SetAttribute(Names.SwingTag, tag)
		model:SetAttribute(Names.SwingAt, now)
		hooks.attacked(model)
		-- One use spent; the last one goes back to bare fists once the attack is out of the hand.
		local uses = model:GetAttribute(Names.WeaponUses)
		local spent = typeof(uses) == "number" and uses <= 1
		if typeof(uses) == "number" then
			model:SetAttribute(Names.WeaponUses, uses - 1)
		end
		task.delay(AttackString.hitAt(stringRules, w.hitAt, step, w.style), function()
			strike(model, weapon, facing, step, tag)
			if spent and holding(model) == weapon then
				set(model, FIST)
			end
		end)
		return true
	end

	local received = swingRemote.OnServerEvent:Connect(function(player: Player, aim: unknown, drawn: unknown, number: unknown)
		local model = player.Character
		if not model then
			return
		end
		-- Its step in the player's string: the step the client drew, as far as this server's own count allows.
		local claim = if typeof(drawn) == "number" and drawn % 1 == 0 then drawn else nil
		-- The attack's number as the client counted them: only handed back (whole numbers only, also false for NaN).
		local tag = if typeof(number) == "number" and number % 1 == 0 and math.abs(number) < 2 ^ 31 then number else nil
		begin(model, aim, claim, tag, true)
	end)

	-- Weapons run out of time, and go back to bare fists when their holder is out or fell off, or no fight is running.
	local watching = true
	task.spawn(function()
		while watching do
			local now = Workspace:GetServerTimeNow()
			local fighting = Workspace:GetAttribute(Names.Phase) == "Fight"
			for model in table.clone(armed) do
				local ends = model:GetAttribute(Names.WeaponEndsAt)
				local over = typeof(ends) == "number" and now >= ends
				if not model.Parent then
					armed[model] = nil -- its player left: nothing to put back in a hand
				elseif not fighting or model:GetAttribute(Names.Alive) ~= true or model:GetAttribute(Names.ReturnPhase) ~= nil or over then
					set(model, FIST)
				end
			end
			if not fighting then
				hooks.putOut()
			end
			task.wait(0.2)
		end
	end)

	return {
		give = set,
		holding = holding,
		attack = function(model: Model, facing: Vector3): boolean
			return begin(model, facing, nil, nil, false)
		end,
		repace = function(model: Model)
			pace(model, holding(model))
		end,
		stop = function()
			watching = false
			received:Disconnect()
		end,
	}
end

return WeaponService
