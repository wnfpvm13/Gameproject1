--!nocheck
-- QA only (not part of the game): plays the player's own character in Studio's solo practice as one of the persona
-- testers (docs/PERSONA_PLAYTEST_2026-10-28.md, rerun after the fixes: docs/PERSONA_RERUN_2026-10-31.md), against the
-- practice bots, on the real server: it walks like a player (staying on its top: BotPlan, as the bots do), goes for
-- the crates it likes wherever they land (the edge arrows show them all), holds its block after taking a hit as the
-- persona would, walks off a back car that is about to come off once it notices the warning, sits out its comeback
-- (the stands, then the parachute), and attacks through the game's own Swing remote (the server judges it as any
-- player's attack). Every round it plays is logged in _G.PersonaLog (hits dealt and taken by kind and weapon, blocks,
-- falls with how and by whom, every knock-off notice, crates, cars coming off, time with nobody to fight, time on the
-- way back). Run it in the Client data model with PERSONA set (tools/sim/run_persona.py writes that line);
-- _G.PersonaStop = true ends it after the round.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = game.ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared.Config)
local Names = require(shared.Names)
local ArenaLayout = require(shared.ArenaLayout)
local BotPlan = require(shared.BotPlan)
local CharacterParts = require(shared.CharacterParts)
local AttackString = require(shared.AttackString)
local WeaponRules = require(shared.WeaponRules)

-- { name, rounds, react = {a, b}, jitter, fullString, crate, chase, retreat, distracted, reachUse, block, blockHold = {a, b},
-- notice = {a, b}, patience }
local PERSONA = __PERSONA__

local player = Players.LocalPlayer
local remotes = shared.Remotes
local layout = ArenaLayout.layout(Config.Arena, Config.Fall.Margin)
local STRING = AttackString.rules(Config.Attack)
local MARGIN = 1.6

local function between(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
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

-- A car's state: "gone", "leaving" (warned or on its way off) or nil (on its train).
local function carState(train: number, car: number): string?
	local arena = Workspace:FindFirstChild(Names.ArenaFolder)
	local trainModel = arena and arena:FindFirstChild(Names.TrainModel .. train)
	local model = trainModel and trainModel:FindFirstChild(Names.CarModel .. car)
	if not model then
		return nil
	elseif model:GetAttribute(Names.CarGone) == true then
		return "gone"
	elseif model:GetAttribute(Names.CarLeavingAt) ~= nil then
		return "leaving"
	end
	return nil
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
		me = player.DisplayName, -- the name the feed knows it by
		dealt ={ light = 0, launch = 0, smash = 0 },
		taken = { light = 0, launch = 0, smash = 0 }, -- not counting blocked ones (as the result card counts them)
		dealtBy = {},
		pickups = {},
		presses = 0,
		kos = 0,
		out = nil, -- how it went out for good: "fall" | "homerun" | nil (won, or in at the end)
		outBy = nil,
		-- every fall or home run it took: { t, how, by, out, car = "leaving" when its car was coming off, state = what it was
		-- doing then, from = where it last stood on a top { x, z, train, car, ago = seconds before the fall } }
		falls = {},
		feed = {}, -- every knock-off notice: { t, victim, by, how, out, streak }
		bestStreak = 0, -- most home runs in a row it hit
		block = { starts = 0, seconds = 0, blocked = 0, broken = 0 },
		fightSeconds = 0,
		aliveSeconds = 0,
		returnSeconds = 0, -- on the way back (the stands, the parachute)
		guardSeconds = 0, -- just back, unhittable
		weaponSeconds = 0, -- holding a weapon
		lonelySeconds = 0, -- in with nobody it can get to
		roamSeconds = 0, -- walking to another top (a car, a plank, another train) to find someone
		stunnedSeconds = 0,
		watchSeconds = 0, -- out, waiting for the round to end
		won = false,
		winner = nil,
		crateTrips = 0,
		crateFar = 0, -- of those, crates on another top
		carsWarned = 0, -- cars it saw warned while it was on them
		carEscapes = 0, -- of those, walked off in time
		lowestHealth = 100,
		states = {}, -- seconds spent in each step of its choice (what it did while in)
	}
end

if _G.PersonaKill then
	_G.PersonaKill() -- an earlier run still connected (stopped mid-way): end it first
end
_G.PersonaLog = _G.PersonaLog or {}
_G.PersonaStop = false
local round = nil
local chain = AttackString.new()

-- The block it holds: from blockAt (os.clock) to blockUntil, facing blockFrom; held = the server was told it is down.
local blockAt, blockUntil, blockFrom, held = nil, nil, nil, false
local blockSince = nil

local function setBlock(down: boolean)
	if held ~= down then
		held = down
		remotes.Block:FireServer(down)
		if down and round then
			round.block.starts += 1
		end
	end
end

local function stopBlock()
	setBlock(false)
	blockAt, blockUntil, blockFrom = nil, nil, nil
end

local hitConn = remotes.Hit.OnClientEvent:Connect(function(victim, velocity, swinger, kind, weapon, ganged, tag, guard)
	if not round then
		return
	end
	local me = player.Character
	if victim == me then
		if guard == "blocked" then
			round.block.blocked += 1
		else
			round.taken[kind] = (round.taken[kind] or 0) + 1
			if guard == "broken" then
				round.block.broken += 1
			end
			-- Hit through: a persona that blocks holds it now, after its reaction.
			if not blockAt and math.random() < (PERSONA.block or 0) then
				blockAt = os.clock() + between(PERSONA.react)
				blockUntil = blockAt + between(PERSONA.blockHold)
				blockFrom = swinger
			end
		end
		AttackString.reset(chain) -- being hit breaks its string, as the server counts it
	elseif swinger == me then
		round.dealt[kind] = (round.dealt[kind] or 0) + 1
		round.dealtBy[weapon] = (round.dealtBy[weapon] or 0) + 1
	end
end)

local lastCar = nil -- { train, car, x, z, t } of the top it was last on (and where on it, when)
-- Where it was over the last 3 seconds (every 0.2 s: time, position, what it was doing), copied into a fall's entry.
local trail = {}
local trailAt = 0
local feedConn = remotes.Feed.OnClientEvent:Connect(function(victim, by, how, out, streak)
	if not round then
		return
	end
	table.insert(round.feed, { t = round.fightSeconds, victim = victim, by = by, how = how, out = out, streak = streak })
	if victim == player.DisplayName then
		local car = if lastCar then carState(lastCar.train, lastCar.car) else nil
		local from = if lastCar then { x = math.floor(lastCar.x * 10 + 0.5) / 10, z = math.floor(lastCar.z * 10 + 0.5) / 10, train = lastCar.train, car = lastCar.car, ago = round.fightSeconds - lastCar.t } else nil
		table.insert(round.falls, { t = round.fightSeconds, how = how, by = by, out = out, car = car, state = round.lastState, from = from, trail = table.clone(trail) })
		if out then
			round.out, round.outBy = how, by
		end
		stopBlock()
	elseif by == player.DisplayName then
		round.kos += 1
		if how == "homerun" and typeof(streak) == "number" then
			round.bestStreak = math.max(round.bestStreak, streak)
		end
	end
end)

local lonelySince = nil
local lastPos, lastMoveCheck = nil, 0
local plankHeading = nil -- +1 or -1 along X: the way it crosses the plank it is on

-- Jumps when it has stopped going forward (against a higher car).
local function unstick(humanoid, here: Vector3)
	local now = os.clock()
	if now - lastMoveCheck > 0.6 then
		if lastPos and (here - lastPos).Magnitude < 0.4 then
			humanoid.Jump = true
		end
		lastPos, lastMoveCheck = here, now
	end
end

-- The planks gone with a car coming off (a plank resting on a car that is leaving or gone went with it, or with the
-- other car it rests on, earlier): number -> true.
local function planksGone(): { [number]: boolean }
	local gone = {}
	for i, line in layout.trains do
		for k in line.cars do
			if carState(i, k) then
				for _, number in ArenaLayout.planksOn(layout, i, k) do
					gone[number] = true
				end
			end
		end
	end
	return gone
end

-- Whether it stands on a plank between two trains (past its train's roof, within a plank's run and width).
local function onPlankAt(here: Vector3, top): boolean
	if math.abs(here.X - layout.trains[top.train].x) <= Config.Arena.RoofWidth / 2 - 0.5 then
		return false
	end
	local gone = planksGone()
	for number, plank in layout.planks do
		if not gone[number] and math.abs(here.X - plank.x) < plank.length / 2 and math.abs(here.Z - plank.z) < Config.Arena.PlankWidth / 2 + 0.5 then
			return true
		end
	end
	return false
end

-- Walks toward (goalX, goalZ) on top `goalTop`, as a player would get there from `top`: along its own train's middle
-- (jumping up a higher car when it stops going forward), or to the plank across to the next train and over it.
-- Returns false when there is no way.
local function route(body, here, top, goalX: number, goalZ: number, goalTop): boolean
	local mine, theirs = top.train, goalTop.train
	local goal
	if onPlankAt(here, top) then
		-- Out over the gap (on a plank): straight on across to the roof, never turning off the plank's side (the
		-- nearest top flips to the other train halfway over, and heading for its middle at another z walked it off).
		goal = Vector3.new(if theirs == mine then layout.trains[mine].x else layout.trains[mine + (if theirs > mine then 1 else -1)].x, here.Y, here.Z)
	elseif mine == theirs then
		goal = if math.abs(here.Z - goalZ) > 1.5 then Vector3.new(layout.trains[mine].x, here.Y, goalZ) else Vector3.new(goalX, here.Y, goalZ)
	else
		local step = if theirs > mine then 1 else -1
		local nextX = layout.trains[mine + step].x
		local midX = (layout.trains[mine].x + nextX) / 2
		local plank, plankD = nil, math.huge
		local gone = planksGone() -- (never across a plank that went with a car)
		for number, candidate in layout.planks do
			local d = math.abs(candidate.z - here.Z)
			if not gone[number] and math.abs(candidate.x - midX) < 1 and d < plankD then
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
	unstick(humanoid, here)
	return true
end

-- Walks toward the nearest fighter on another top, as a player looking for a fight would. False when nobody can be
-- got to.
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
	if not best or not route(body, here, top, best.x, best.z, best.top) then
		return false
	end
	round.roamSeconds += dt
	return true
end

-- The car it is walking off (it noticed the warning): { train, car, z = the front car's middle } or nil.
local escaping = nil
local noticed = {} -- car key -> os.clock() it notices the warning (decided once per car)

local function frontOf(train: number, car: number)
	local best = nil
	for _, surface in layout.surfaces do
		if surface.train == train and surface.car == car - 1 and (not best or surface.width * surface.length > best.width * best.length) then
			best = surface
		end
	end
	return best
end

local wanted = setmetatable({}, { __mode = "k" }) -- crate model -> whether the persona goes for it (decided once)
local tripTo = nil -- the crate it is going for

-- The nearest landed crate it wants, with the top it is on, or nil.
local function crateToGet(here)
	local folder = Workspace:FindFirstChild(Names.CratesFolder)
	if not folder then
		return nil
	end
	local best, bestD, bestTop = nil, math.huge, nil
	for _, crate in folder:GetChildren() do
		local box = crate:IsA("Model") and (crate.PrimaryPart or crate:FindFirstChild("Box"))
		if box and crate:GetAttribute(Names.CrateLanded) == true then
			if wanted[crate] == nil then
				wanted[crate] = math.random() < PERSONA.crate
			end
			local p = box.Position
			local on = ArenaLayout.topUnder(layout.surfaces, p.X, p.Z, p.Y - 1)
			local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(here.X, 0, here.Z)).Magnitude
			if wanted[crate] and on and not carState(on.train, on.car) and d < bestD then
				best, bestD, bestTop = crate, d, on
			end
		end
	end
	if not best then
		return nil
	end
	local box = best.PrimaryPart or best:FindFirstChild("Box")
	return best, box.Position, bestTop
end

local readyAt = 0
local inReachSince = nil
local farSince = nil -- since when its target has stayed out of reach (for a waiting persona's patience)
local idleUntil = 0
local lastWeapon = "Fist"
local tag = 500000

local function attack(me, body, facing: Vector3, weapon: string)
	local w = Config.Weapons[weapon]
	local now = serverNow()
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
	round.lastState = state
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
	local humanoid = body.humanoid
	if round.fightSeconds - trailAt >= 0.2 then
		trailAt = round.fightSeconds
		local p = body.root.Position
		table.insert(trail, string.format("%.1f (%.1f,%.1f,%.1f) %s", round.fightSeconds, p.X, p.Y, p.Z, round.lastState or "-"))
		if #trail > 15 then
			table.remove(trail, 1)
		end
	end
	-- On the way back (the stands, then the parachute): nothing to do until it lands.
	if me:GetAttribute(Names.ReturnPhase) ~= nil then
		round.returnSeconds += dt
		mark("returning", dt)
		stopBlock()
		escaping = nil
		tripTo = nil
		humanoid:Move(Vector3.zero)
		return
	end
	local guardUntil = me:GetAttribute(Names.GuardUntil)
	if typeof(guardUntil) == "number" and guardUntil > serverNow() then
		round.guardSeconds += dt
	end
	local health = me:GetAttribute(Names.Health)
	if typeof(health) == "number" then
		round.lowestHealth = math.min(round.lowestHealth, health)
	end
	local weapon = WeaponRules.named(Config.Weapons, me:GetAttribute(Names.Weapon))
	if weapon ~= "Fist" then
		round.weaponSeconds += dt
	end
	if humanoid.PlatformStand or body.root.Anchored then
		round.stunnedSeconds += dt
		return
	end
	local now = os.clock()
	-- Holding its block (after being hit): faces the one who hit it, does nothing else.
	if blockAt and now >= blockAt then
		if now < blockUntil then
			setBlock(true)
			blockSince = blockSince or now
			round.block.seconds += dt
			mark("block", dt)
			local from = blockFrom and CharacterParts.body(blockFrom)
			if from then
				local toward = Vector3.new(from.root.Position.X - body.root.Position.X, 0, from.root.Position.Z - body.root.Position.Z)
				if toward.Magnitude > 0.1 then
					body.root.CFrame = CFrame.lookAt(body.root.Position, body.root.Position + toward.Unit)
				end
			end
			humanoid:Move(Vector3.zero)
			return
		end
		stopBlock()
		blockSince = nil
	end
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
	if onTop then
		lastCar = { train = top.train, car = top.car, x = here.X, z = here.Z, t = round.fightSeconds }
	end
	-- On a plank: a player walks on along it, straight, the way it was going when it stepped on (or was pushed on), to
	-- that train's roof, before doing anything else - turning toward someone or a crate there walked it off the plank's
	-- side (and the bots do not see anyone on a plank, so standing there was also a safe place to wait).
	if onTop then
		plankHeading = nil
	elseif onPlankAt(here, top) then
		if not plankHeading then
			local vx = body.root.AssemblyLinearVelocity.X
			plankHeading = if math.abs(vx) > 1 then math.sign(vx) else (if layout.trains[top.train].x >= here.X then 1 else -1)
		end
		local goalX = nil
		for _, line in layout.trains do
			if (line.x - here.X) * plankHeading > 0 and (not goalX or math.abs(line.x - here.X) < math.abs(goalX - here.X)) then
				goalX = line.x
			end
		end
		mark("offPlank", dt)
		humanoid.WalkSpeed = 16
		humanoid:MoveTo(Vector3.new(goalX or layout.trains[top.train].x, here.Y, here.Z))
		return
	end
	-- Its car is coming off: once it notices the warning (band, banner, sound), it walks to the car in front.
	local carKey = top.train .. ":" .. top.car
	if not escaping and onTop and carState(top.train, top.car) == "leaving" then
		if not noticed[carKey] then
			noticed[carKey] = now + between(PERSONA.notice)
			round.carsWarned += 1
		end
		if now >= noticed[carKey] then
			local front = frontOf(top.train, top.car)
			if front then
				escaping = { train = top.train, car = top.car, z = front.z, x = front.x, front = front }
				round.carEscapes += 1
			end
		end
	end
	if escaping then
		local state = carState(escaping.train, escaping.car)
		local onFront = onTop and top.train == escaping.train and top.car < escaping.car
		if state ~= "leaving" or onFront then
			escaping = nil
		else
			mark("escape", dt)
			humanoid.WalkSpeed = 16
			humanoid:MoveTo(Vector3.new(escaping.x, here.Y, escaping.z))
			unstick(humanoid, here)
			return
		end
	end
	-- A crate it likes, if fists are all it holds (the edge arrows show where every crate is).
	if weapon == "Fist" and PERSONA.crate > 0 then
		local crate, at, crateTop = crateToGet(here)
		if crate then
			if tripTo ~= crate then
				tripTo = crate
				round.crateTrips += 1
				if crateTop ~= top then
					round.crateFar += 1
				end
			end
			mark("crate", dt)
			if crateTop == top then
				humanoid.WalkSpeed = 16
				humanoid:MoveTo(Vector3.new(at.X, here.Y, at.Z))
				unstick(humanoid, here)
				return
			elseif route(body, here, top, at.X, at.Z, crateTop) then
				return
			end
		end
	end
	tripTo = nil
	local others = {}
	for _, other in fighters() do
		local ob = if other ~= me then CharacterParts.body(other) else nil
		if ob and other:GetAttribute(Names.ReturnPhase) == nil then
			local at, otherTop = topOf(ob)
			-- Nobody it would follow onto a car that is coming off.
			if not (otherTop and carState(otherTop.train, otherTop.car)) then
				table.insert(others, { key = other, x = at.X, z = at.Z, top = otherTop })
			end
		end
	end
	local target = BotPlan.nearest(here.X, here.Z, top, others, {}, 99)
	if not target then
		farSince = nil
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
		mark("retreat", dt)
		return
	end
	if distance > want + 0.6 then
		inReachSince = nil
		-- A waiting persona waits for the other to come near, but only so long (its patience): then it goes itself.
		farSince = farSince or now
		local go = PERSONA.chase or distance < want + 3 or now - farSince > (PERSONA.patience or math.huge)
		mark(if go then "approach" else "waitFar", dt)
		if go then
			local x, z = BotPlan.standSpot(top, here.X, here.Z, target.x, target.z, want, MARGIN)
			humanoid.WalkSpeed = 16
			humanoid:MoveTo(Vector3.new(x, here.Y, z))
		else
			humanoid:Move(Vector3.zero)
		end
		return
	end
	humanoid:Move(Vector3.zero)
	farSince = nil
	inReachSince = inReachSince or now
	if now - inReachSince < round.reactNow then
		mark("react", dt)
		return
	end
	mark("inReach", dt)
	attack(me, body, toward.Unit, weapon)
end

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
		escaping, tripTo, lastCar, farSince, inReachSince, plankHeading = nil, nil, nil, nil, nil, nil
		table.clear(trail)
		trailAt = 0
		table.clear(noticed)
		stopBlock()
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
		stopBlock()
		local me = player.Character
		round.winner = Workspace:GetAttribute(Names.Winner)
		round.winnerCount = Workspace:GetAttribute(Names.WinnerCount)
		round.winnerStreak = Workspace:GetAttribute(Names.WinnerStreak)
		round.won = false
		for name in string.gmatch(round.winner or "", "[^,]+") do
			if string.gsub(name, "^%s+", "") == player.DisplayName then
				round.won = true
			end
		end
		round.ticketsLeft = me and me:GetAttribute(Names.Tickets)
		round.inAtEnd = me ~= nil and me:GetAttribute(Names.Alive) == true
		round.goingForCrate = nil
		round.reactNow = nil
		round.holding = nil
		table.insert(_G.PersonaLog, round)
		round = nil
		roundsDone += 1
		if roundsDone >= PERSONA.rounds or _G.PersonaStop then
			_G.PersonaKill()
		end
	end
	lastPhase = phase
end)
_G.PersonaKill = function()
	stepConn:Disconnect()
	hitConn:Disconnect()
	feedConn:Disconnect()
	setBlock(false)
	_G.PersonaRunning = false
	_G.PersonaKill = nil
end
_G.PersonaRunning = true
return "playing as " .. PERSONA.name .. " for " .. PERSONA.rounds .. " rounds"
