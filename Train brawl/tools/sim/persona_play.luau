--!nocheck
-- QA only (not part of the game): plays the player's own character in Studio's solo practice as one of the persona
-- testers (docs/PERSONA_PLAYTEST_2026-10-28.md), against the practice bots, on the real server: it walks like a
-- player (staying on its top: BotPlan, as the bots do), goes for crates as the persona likes, and attacks through the
-- game's own Swing remote (the server judges it as any player's attack). Every round it plays is logged in
-- _G.PersonaLog (hits dealt and taken by kind and weapon, launches, knock-offs, crates, how it went out, time with
-- nobody to fight, time out of the round). Run it in the Client data model with PERSONA set (tools/sim/run_persona.py
-- writes that line); _G.PersonaStop = true ends it after the round.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local shared = game.ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared.Config)
local Names = require(shared.Names)
local ArenaLayout = require(shared.ArenaLayout)
local BotPlan = require(shared.BotPlan)
local CharacterParts = require(shared.CharacterParts)
local AttackString = require(shared.AttackString)
local WeaponRules = require(shared.WeaponRules)

local PERSONA = __PERSONA__ -- { name, rounds, react = {a, b}, jitter, fullString, crate, chase, retreat, distracted, reachUse }

local player = Players.LocalPlayer
local remotes = shared.Remotes
local layout = ArenaLayout.layout(Config.Arena, Config.Fall.Margin)
local STRING = AttackString.rules(Config.Attack)
local MARGIN = 1.6

local function between(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

local function topOf(body)
	local at = body.root.Position
	return at, ArenaLayout.topUnder(layout.surfaces, at.X, at.Z, CharacterParts.feetY(body))
end

-- The top a player's own character goes by: the one under it, or (standing on coal, a plank or a crate edge the layout
-- does not count as a top) the nearest top of its train along the ground - a player would still walk on from there.
local function myTop(body)
	local at, top = topOf(body)
	if top then
		return at, top, true
	end
	local best, bestD = nil, math.huge
	for _, surface in layout.surfaces do
		local dx = math.max(math.abs(at.X - surface.x) - surface.width / 2, 0)
		local dz = math.max(math.abs(at.Z - surface.z) - surface.length / 2, 0)
		local d = dx * dx + dz * dz + math.abs(CharacterParts.feetY(body) - surface.top) * 0.1
		if d < bestD then
			best, bestD = surface, d
		end
	end
	return at, best, false
end

local function fighters(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character and p.Character:GetAttribute(Names.Alive) == true then
			table.insert(list, p.Character)
		end
	end
	for _, bot in game:GetService("CollectionService"):GetTagged(Names.SandbagTag) do
		if bot:GetAttribute(Names.Alive) == true then
			table.insert(list, bot)
		end
	end
	return list
end

local function newRound()
	return {
		persona = PERSONA.name,
		dealt = { light = 0, launch = 0, smash = 0 },
		taken = { light = 0, launch = 0, smash = 0 },
		dealtBy = {},
		pickups = {},
		presses = 0,
		kos = 0,
		out = nil, -- how: "fall" | "homerun" | nil (won or time)
		outBy = nil,
		fightSeconds = 0,
		aliveSeconds = 0,
		lonelySeconds = 0, -- alive with nobody it can get to
		roamSeconds = 0, -- walking to another top (a car, a plank, another train) to find someone
		stunnedSeconds = 0,
		watchSeconds = 0, -- out, waiting for the round to end
		won = false,
		winner = nil,
		crateTrips = 0,
		lowestHealth = 100,
		states = {}, -- seconds spent in each step of its choice (what it did while alive)
	}
end

_G.PersonaLog = _G.PersonaLog or {}
_G.PersonaStop = false
local round = nil
local chain = AttackString.new()
local hitConn = remotes.Hit.OnClientEvent:Connect(function(victim, velocity, swinger, kind, weapon)
	if not round then
		return
	end
	local me = player.Character
	if victim == me then
		round.taken[kind] = (round.taken[kind] or 0) + 1
		AttackString.reset(chain) -- being hit breaks its string, as the server counts it
	elseif swinger == me then
		round.dealt[kind] = (round.dealt[kind] or 0) + 1
		round.dealtBy[weapon] = (round.dealtBy[weapon] or 0) + 1
	end
end)
local feedConn = remotes.Feed.OnClientEvent:Connect(function(victim, by, how)
	if not round then
		return
	end
	if victim == player.DisplayName then
		round.out, round.outBy = how, by
	elseif by == player.DisplayName then
		round.kos += 1
	end
end)

local lonelySince = nil
local lastPos, lastMoveCheck = nil, 0

-- Walks toward the nearest fighter on another top, as a player looking for a fight would: along its own train's middle
-- (jumping up a higher car when it stops going forward), or to the plank across to the next train and over it.
-- Returns false when nobody can be got to.
local function roam(body, here, top, others, dt: number): boolean
	local best, bestD = nil, math.huge
	for _, o in others do
		if o.top then
			local d = (Vector3.new(o.x, 0, o.z) - Vector3.new(here.X, 0, here.Z)).Magnitude
			if d < bestD then
				best, bestD = o, d
			end
		end
	end
	if not best then
		return false
	end
	local mine, theirs = top.train, best.top.train
	local goal
	if mine == theirs then
		goal = Vector3.new(layout.trains[mine].x, here.Y, best.z)
	else
		local step = if theirs > mine then 1 else -1
		local nextX = layout.trains[mine + step].x
		local midX = (layout.trains[mine].x + nextX) / 2
		local plank, plankD = nil, math.huge
		for _, candidate in layout.planks do
			local d = math.abs(candidate.z - here.Z)
			if math.abs(candidate.x - midX) < 1 and d < plankD then
				plank, plankD = candidate, d
			end
		end
		if not plank then
			return false
		end
		goal = if plankD > 1 then Vector3.new(layout.trains[mine].x, here.Y, plank.z) else Vector3.new(nextX, here.Y, plank.z)
	end
	local humanoid = body.humanoid
	humanoid.WalkSpeed = 16
	humanoid:MoveTo(goal)
	local now = os.clock()
	if now - lastMoveCheck > 0.6 then
		if lastPos and (here - lastPos).Magnitude < 0.4 then
			humanoid.Jump = true -- stopped against a higher car
		end
		lastPos, lastMoveCheck = here, now
	end
	round.roamSeconds += dt
	return true
end

local readyAt = 0
local inReachSince = nil
local idleUntil = 0
local lastWeapon = "Fist"
local tag = 500000

local function attack(me, body, facing: Vector3, weapon: string)
	local w = Config.Weapons[weapon]
	local now = Workspace:GetServerTimeNow()
	if now < readyAt then
		return
	end
	if weapon ~= lastWeapon then
		AttackString.reset(chain)
		lastWeapon = weapon
	end
	local step = AttackString.take(chain, STRING, now, w.cooldown, w.style)
	-- A persona that stops a string short starts again (waits past the gap).
	if step == STRING.count and math.random() > PERSONA.fullString then
		readyAt = now + w.cooldown + STRING.gap + 0.1
		AttackString.reset(chain)
		return
	end
	body.root.CFrame = CFrame.lookAt(body.root.Position, body.root.Position + facing)
	tag += 1
	remotes.Swing:FireServer(facing, step, tag)
	round.presses += 1
	readyAt = now + w.cooldown + math.random() * PERSONA.jitter
end

local function mark(state: string, dt: number)
	round.states[state] = (round.states[state] or 0) + dt
end

local function tick(dt: number)
	local me = player.Character
	local body = CharacterParts.body(me)
	local phase = Workspace:GetAttribute(Names.Phase)
	if phase ~= "Fight" or not body then
		return
	end
	round.fightSeconds += dt
	if me:GetAttribute(Names.Alive) ~= true then
		round.watchSeconds += dt
		return
	end
	round.aliveSeconds += dt
	local health = me:GetAttribute(Names.Health)
	if typeof(health) == "number" then
		round.lowestHealth = math.min(round.lowestHealth, health)
	end
	local humanoid = body.humanoid
	if humanoid.PlatformStand or body.root.Anchored then
		round.stunnedSeconds += dt
		return
	end
	local weapon = WeaponRules.named(Config.Weapons, me:GetAttribute(Names.Weapon))
	local now = os.clock()
	if now < idleUntil then
		mark("distracted", dt)
		return -- looking away (phone, chat)
	end
	if math.random() < PERSONA.distracted * dt then
		idleUntil = now + 1 + math.random() * 1.5
		return
	end
	local here, top, onTop = myTop(body)
	if not onTop then
		mark("offTop", dt) -- (still walks on, by the nearest top)
	end
	if not top then
		humanoid:Move(Vector3.zero)
		return
	end
	-- A crate on this top, if fists are all it holds and it likes crates.
	if weapon == "Fist" and PERSONA.crate > 0 then
		local best, bestD = nil, math.huge
		for _, crate in Workspace:FindFirstChild(Names.CratesFolder):GetChildren() do
			local box = crate:IsA("Model") and (crate.PrimaryPart or crate:FindFirstChild("Box"))
			if box and crate:GetAttribute(Names.CrateLanded) == true then
				local p = box.Position
				local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(here.X, 0, here.Z)).Magnitude
				local onTop = ArenaLayout.topUnder(layout.surfaces, p.X, p.Z, p.Y - 1) == top
				if onTop and d < bestD then
					best, bestD = p, d
				end
			end
		end
		if best and (round.goingForCrate or math.random() < PERSONA.crate) then
			if not round.goingForCrate then
				round.crateTrips += 1
			end
			round.goingForCrate = true
			humanoid.WalkSpeed = 16
			humanoid:MoveTo(Vector3.new(best.X, here.Y, best.Z))
			return
		end
	end
	round.goingForCrate = false
	local others = {}
	for _, other in fighters() do
		local ob = if other ~= me then CharacterParts.body(other) else nil
		if ob then
			local at, otherTop = topOf(ob)
			table.insert(others, { key = other, x = at.X, z = at.Z, top = otherTop })
		end
	end
	local target = BotPlan.nearest(here.X, here.Z, top, others, {}, 99)
	if not target then
		lonelySince = lonelySince or now
		-- A waiting persona waits a while for someone to come before going to look.
		if (PERSONA.chase or now - lonelySince > 6) and roam(body, here, top, others, dt) then
			return
		end
		round.lonelySeconds += dt
		humanoid:Move(Vector3.zero)
		return
	end
	lonelySince = nil
	local toward = Vector3.new(target.x - here.X, 0, target.z - here.Z)
	local distance = toward.Magnitude
	local w = Config.Weapons[weapon]
	-- How close it wants to be: in a weapon's reach (a thrown or bowled one from afar), else a fist's.
	local want = if w.style == "toss" then 12 elseif w.style == "roll" then 9 elseif w.style == "pour" then 5 elseif w.style == "lasso" then 7 elseif w.reach then math.min(w.reach * PERSONA.reachUse, w.reach - 0.6) else 3
	if w.style == "burst" or w.style == "slam" then
		want = 3
	end
	local low = typeof(health) == "number" and health <= PERSONA.retreat
	if low and distance < 7 then
		-- Low health: keep away along its top (toward the far side from the threat).
		local x, z = BotPlan.standSpot(top, here.X, here.Z, target.x, target.z, 10, MARGIN)
		humanoid.WalkSpeed = 16
		humanoid:MoveTo(Vector3.new(x, here.Y, z))
		return
	end
	if distance > want + 0.6 then
		inReachSince = nil
		mark(if PERSONA.chase or distance < want + 3 then "approach" else "waitFar", dt)
		if PERSONA.chase or distance < want + 3 then
			local x, z = BotPlan.standSpot(top, here.X, here.Z, target.x, target.z, want, MARGIN)
			humanoid.WalkSpeed = 16
			humanoid:MoveTo(Vector3.new(x, here.Y, z))
		else
			humanoid:Move(Vector3.zero)
		end
		return
	end
	humanoid:Move(Vector3.zero)
	inReachSince = inReachSince or now
	if now - inReachSince < round.reactNow then
		mark("react", dt)
		return
	end
	mark("inReach", dt)
	attack(me, body, toward.Unit, weapon)
end

local results = {}
local roundsDone = 0
local lastPhase = Workspace:GetAttribute(Names.Phase)
local stepConn
stepConn = RunService.Heartbeat:Connect(function(dt)
	local phase = Workspace:GetAttribute(Names.Phase)
	if phase == "Fight" and lastPhase ~= "Fight" then
		round = newRound()
		_G.PersonaNow = round -- to peek at mid-round
		round.reactNow = between(PERSONA.react)
		AttackString.reset(chain)
		readyAt = 0
	end
	if round and phase == "Fight" then
		round.reactNow = if inReachSince then round.reactNow else between(PERSONA.react)
		local ok, err = pcall(tick, dt)
		if not ok then
			round.error = tostring(err)
		end
		-- Track what it picked up.
		local me = player.Character
		local weapon = me and WeaponRules.named(Config.Weapons, me:GetAttribute(Names.Weapon)) or "Fist"
		if weapon ~= (round.holding or "Fist") then
			if weapon ~= "Fist" then
				round.pickups[weapon] = (round.pickups[weapon] or 0) + 1
			end
			round.holding = weapon
		end
	end
	if round and lastPhase == "Fight" and phase ~= "Fight" then
		local winner = Workspace:GetAttribute(Names.Winner)
		round.winner = winner
		round.won = winner == player.DisplayName
		round.goingForCrate = nil
		round.reactNow = nil
		round.holding = nil
		table.insert(_G.PersonaLog, round)
		round = nil
		roundsDone += 1
		if roundsDone >= PERSONA.rounds or _G.PersonaStop then
			stepConn:Disconnect()
			hitConn:Disconnect()
			feedConn:Disconnect()
			_G.PersonaRunning = false
		end
	end
	lastPhase = phase
end)
_G.PersonaRunning = true
return "playing as " .. PERSONA.name .. " for " .. PERSONA.rounds .. " rounds"
