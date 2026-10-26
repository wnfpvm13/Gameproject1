--!strict
-- Attacks, judged on the server, for every weapon (Config.Weapons): bare fists by default, or the weapon a fighter
-- picked up (give, from a crate: WeaponDrops), kept as the character's Names.Weapon with its uses left
-- (Names.WeaponUses) or the server time it runs out (Names.WeaponEndsAt) for every screen to show.
--
-- A player's client attacks at once and tells the server where it aimed; the server takes the attack when the player
-- is fighting, alive, not stunned by a hit (from Config.Knock.SwingGrace until the hit's stun ends: an attack arriving
-- sooner was pressed before the player saw the hit) and the last attack's weapon is ready again (its cooldown: a
-- hammer's stays even if the hammer ran out with it). The server takes an attack up to Config.Attack's slack early, but
-- the next one is still counted from when this one was due, so the slack never adds up to a faster rate.
-- Each punch or swing is a step of its attacker's 1-2-3 string (AttackString: it goes on only while attacks land; the
-- client says which step it drew, the server takes that only as far as its own count allows; being hit breaks a
-- fighter's string; the launching last step lands a moment later). It marks the character's
-- Names.SwingStep and Names.SwingAt (every client draws the weapon's attack and step from them) and, the weapon's hitAt
-- later, lands it by its style: a punch or a swing hits every other fighter in a cone in front (SwingTargets, reach
-- widened by the network slack), a slam everyone around a point just ahead, a throw sends a lit dynamite stick
-- (Dynamite) whose blast hits everyone around where it bursts (not the thrower).
--
-- Every hit asks the health keeper what it was (hooks.hit with the weapon's damage and the attacker; the string's last
-- step of a punch or swing, or a weapon that always launches, makes the hit a launch, still pushed by health) and pushes by health (HitRules.force) times the weapon's push and
-- the victim's resistance (a held gold bar), away from the attacker (a blast: from where it burst); a smash (health
-- emptied) flies the same home run whatever hit it. A blast after the fight is over hits nobody. It is
-- sent to every client (Names.HitRemote: victim, velocity, attacker, kind, weapon, whether a crowd launched it): the victim's own client moves its
-- character, everyone shows it; a sandbag is moved here. A weapon goes back to bare fists when used up, when its time
-- is over, when its holder is out, and whenever no fight is running.
local Players = game:GetService("Players")
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

local WeaponService = {}

export type Hooks = {
	canSwing: (model: Model) -> boolean, -- the model is a fighter in a running fight
	fighters: () -> { Model }, -- the models that can be hit
	-- The health keeper: this hit's kind and the health left (damage taken; launch: the attacker's hit launches; by:
	-- the attacker, told apart for the guard against being ganged up on).
	hit: (victim: Model, now: number, damage: number, launch: boolean, by: Model) -> (HitRules.Kind, number, boolean),
	knockHere: (model: Model, velocity: Vector3, kind: HitRules.Kind) -> boolean, -- moves a server-owned model (a sandbag)
	onHit: (victim: Model, attacker: Model) -> (), -- for the knock-off credit
	onSmash: (victim: Model) -> (), -- health emptied: out of the round
	equip: (model: Model) -> (), -- puts the model's Names.Weapon in its hand (WeaponGear)
	-- Throws a lit stick from a fighter standing at `from` along the flat `facing`; `burst(at)` when its fuse runs out
	-- (Dynamite).
	throw: (from: Vector3, facing: Vector3, burst: (Vector3) -> ()) -> (),
	putOut: () -> (), -- puts out every stick still burning (no fight is running)
	blast: (at: Vector3, radius: number) -> (), -- tells every client a dynamite burst here
}
export type Service = {
	give: (model: Model, weapon: string) -> (), -- the model holds this weapon now
	holding: (model: Model) -> string, -- the weapon the model holds ("Fist" for bare fists)
	stop: () -> (),
}

local FIST = WeaponRules.FIST

function WeaponService.start(swingRemote: RemoteEvent, hitRemote: RemoteEvent, hooks: Hooks): Service
	local attack = Config.Attack
	local weapons = Config.Weapons
	local readyAt: { [Player]: number } = {} -- server time each player's last attack's weapon is ready again
	local strings: { [Player]: AttackString.State } = {} -- each player's 1-2-3 string
	local stringRules = AttackString.rules(attack)
	-- Per fighter: when the last hit landed and when its stun ends (server time).
	local hitAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	local stunUntil: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	local armed: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- holding something other than fists

	local function holding(model: Model): string
		return WeaponRules.named(weapons, model:GetAttribute(Names.Weapon))
	end

	-- Walking speed for what the model holds (a gold bar slows), unless the round holds it still (speed 0).
	local function pace(model: Model, weapon: string)
		local body = CharacterParts.body(model)
		if body and body.humanoid.WalkSpeed > 0 then
			body.humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed * (weapons[weapon].slow or 1)
		end
	end

	local function set(model: Model, weapon: string)
		local w = weapons[weapon]
		local player = Players:GetPlayerFromCharacter(model)
		local chain = if player and model:GetAttribute(Names.Weapon) ~= weapon then strings[player] else nil
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

	-- One hit of `weapon` by `attacker` on `victim` at `step` of the attacker's string, pushed away from `from` (or along
	-- `facing` when on top of it). `swingAt`: the server time the attack started (Names.SwingAt; nil for a blast), sent
	-- with the hit so the attacker's screen knows which of its attacks it was.
	local function land(victim: CharacterParts.Body, attacker: Model, weapon: string, from: Vector3, facing: Vector3, now: number, step: number, swingAt: number?)
		local w = weapons[weapon]
		local launch = w.launch == true or AttackString.launches(stringRules, step, w.style)
		local kind, health, ganged = hooks.hit(victim.model, now, w.damage, launch, attacker)
		if kind == "none" then
			return
		end
		local hitPlayer = Players:GetPlayerFromCharacter(victim.model)
		local broken = if hitPlayer then strings[hitPlayer] else nil
		if broken then
			AttackString.reset(broken) -- being hit breaks the victim's own string
		end
		local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
		local chain = if attackerPlayer then strings[attackerPlayer] else nil
		if chain and AttackString.uses(w.style) then
			AttackString.landed(chain) -- it landed: the attacker's string may go on
		end
		local push, lift = HitRules.force(kind, health, Config.Health.Max, Config.Hit)
		if kind ~= "smash" then
			push *= w.push * (weapons[holding(victim.model)].resist or 1)
		end
		local at = victim.root.Position
		local vx, vy, vz = BatMath.knock(from.X, from.Z, facing.X, facing.Z, at.X, at.Z, push, lift)
		local velocity = Vector3.new(vx, vy, vz)
		hitAt[victim.model] = now
		stunUntil[victim.model] = now + (if kind == "light" then Config.Hit.LightStun else Config.Knock.MinSeconds)
		hooks.knockHere(victim.model, velocity, kind)
		hitRemote:FireAllClients(victim.model, velocity, attacker, kind, weapon, ganged, swingAt)
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

	local function strike(attacker: Model, weapon: string, facing: Vector3, step: number, swingAt: number)
		local body = CharacterParts.body(attacker)
		if not (body and hooks.canSwing(attacker)) then
			return
		end
		local w = weapons[weapon]
		local now = Workspace:GetServerTimeNow()
		local from = body.root.Position
		if w.style == "slam" then
			local center = from + facing * assert(w.ahead, weapon .. ".ahead")
			for _, victim in around(center, assert(w.radius, weapon .. ".radius"), attacker) do
				land(victim, attacker, weapon, from, facing, now, step, swingAt)
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
		else
			local reach = assert(w.reach, weapon .. ".reach") + attack.ReachSlack
			for _, victim in SwingTargets.find(body, hooks.fighters(), reach, facing, w.halfAngle) do
				land(victim, attacker, weapon, from, facing, now, step, swingAt)
			end
		end
	end

	local received = swingRemote.OnServerEvent:Connect(function(player: Player, aim: unknown, drawn: unknown)
		local model = player.Character
		local body = CharacterParts.body(model)
		if not (model and body and body.humanoid.Health > 0 and hooks.canSwing(model)) then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local since = hitAt[model]
		local stunned = stunUntil[model]
		if since and stunned and now - since >= Config.Knock.SwingGrace and now < stunned then
			return -- still stunned by a hit (the client does not attack then either)
		end
		local weapon = holding(model)
		local w = weapons[weapon]
		local ready = readyAt[player]
		if ready and now < ready - attack.CooldownSlack then
			return
		end
		readyAt[player] = math.max(now, ready or now) + w.cooldown
		-- Its step in the player's string: the step the client drew, as far as this server's own count allows.
		local claim = if typeof(drawn) == "number" and drawn % 1 == 0 then drawn else nil
		local chain = strings[player]
		if not chain then
			chain = AttackString.new()
			strings[player] = chain
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
		model:SetAttribute(Names.SwingAt, now)
		-- One use spent; the last one goes back to bare fists once the attack is out of the hand.
		local uses = model:GetAttribute(Names.WeaponUses)
		local spent = typeof(uses) == "number" and uses <= 1
		if typeof(uses) == "number" then
			model:SetAttribute(Names.WeaponUses, uses - 1)
		end
		task.delay(AttackString.hitAt(stringRules, w.hitAt, step, w.style), function()
			strike(model, weapon, facing, step, now)
			if spent and holding(model) == weapon then
				set(model, FIST)
			end
		end)
	end)

	-- Weapons run out of time, and go back to bare fists when their holder is out or no fight is running.
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
				elseif not fighting or model:GetAttribute(Names.Alive) ~= true or over then
					set(model, FIST)
				end
			end
			if not fighting then
				hooks.putOut()
			end
			task.wait(0.2)
		end
	end)

	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		readyAt[player] = nil
		strings[player] = nil
	end)
	return {
		give = set,
		holding = holding,
		stop = function()
			watching = false
			received:Disconnect()
			leaving:Disconnect()
		end,
	}
end

return WeaponService
