--!strict
-- The rounds, on the server. Wait in the waiting room until enough are in (players, plus sandbags in Studio practice)
-- → count down on the roofs, everyone held still (Config.Round.CountdownSeconds) → fight until one is left or the time
-- runs out (then the ones still in are ranked: RoundRules.winners) → show the winner(s) → everyone back to the waiting
-- room → again. The phase is published on the Workspace (Names.Phase, PhaseEndsAt, AliveCount, Winner, WinnerCount)
-- and each fighter carries Names.Alive, Names.KOs and Names.Tickets. Every fighter boards with Config.Round.Tickets
-- tickets (decision 11): a fall (FallWatch, through Main) or a home run costs one, and the last one is out; with one
-- left, the fighter is sent back (hooks.comeback: up to the stands, down by parachute) and stays in the round, but is
-- not among the fighters on the trains (fighters(), isFighting) until it has landed. A fighter who dies or leaves is out
-- at once. The last one to hit a fighter within Config.Round.KillCreditSeconds before a fall gets the knock-off.
-- quietSince() says when a hit last landed in the fight (or when it began): a long quiet is a stand-off (WeaponDrops).
-- Players who come in during a fight watch until the next round. The knocked out go to a spot of their own in the
-- waiting room (stands()), so nobody lands on top of anyone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local RoundRules = require(shared:WaitForChild("RoundRules"))

local RoundService = {}

export type Service = {
	fighters: () -> { Model }, -- the models on the trains in the running round (not those on their way back)
	isFighting: (model: Model) -> boolean, -- on the trains, and the fight has started
	stands: () -> CFrame, -- a spot of its own in the waiting room (the stands)
	noteHit: (victim: Model, swinger: Model) -> (),
	quietSince: () -> number, -- server time a hit last landed in this fight (its start when none has)
	-- Fell or flew out: how is "homerun" (health emptied), "fall" (fell off) or "gone" (died or left: out at once). A
	-- fall or a home run costs a ticket; only the last one puts the fighter out.
	eliminate: (model: Model, how: string) -> (),
	stop: () -> (),
}

export type Hooks = {
	sandbagCount: () -> number, -- how many sandbags join a round (0 outside Studio practice)
	spawnSandbags: (count: number) -> { Model },
	clearSandbags: () -> (),
	resetHealth: (model: Model) -> (), -- full combat health for a fighter entering a round
	-- A fighter knocked off by a home run or a fall: its name, the name of who gets the knock-off (nil = nobody), how,
	-- whether it was its last ticket (out), and the home runs in a row the knock-off makes for who hit it (0: none).
	announce: (victim: string, by: string?, how: string, out: boolean, streak: number) -> (),
	-- Sends a fighter that fell with a ticket left back onto the trains once its fall has played for `after` seconds;
	-- back() when it has landed. Returns a function that calls it off (the round ended, or the fighter is out).
	comeback: (model: Model, after: number, back: () -> ()) -> () -> (),
}

-- tickets: left this round; returning: calls off its way back while it is on it (nil: on the trains).
type Fighter = { model: Model, player: Player?, tickets: number, returning: (() -> ())? }

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function setPhase(phase: string, endsAt: number)
	Workspace:SetAttribute(Names.Phase, phase)
	Workspace:SetAttribute(Names.PhaseEndsAt, endsAt)
end

-- Holds a player's character still (count-down) or lets it go.
local function hold(model: Model, still: boolean)
	local body = CharacterParts.body(model)
	if body then
		body.humanoid.WalkSpeed = if still then 0 else StarterPlayer.CharacterWalkSpeed
		body.humanoid.JumpHeight = if still then 0 else StarterPlayer.CharacterJumpHeight
	end
end

-- Players with a living character that was given the standard body (Names.BodyReady, AvatarRules through Main),
-- ready to fight.
local function readyPlayers(): { Player }
	local ready = {}
	for _, player in Players:GetPlayers() do
		local body = CharacterParts.body(player.Character)
		if body and body.humanoid.Health > 0 and body.model:GetAttribute(Names.BodyReady) == true then
			table.insert(ready, player)
		end
	end
	return ready
end

local function shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- spots, trains: the spawn spots and how many trains they are on (ArenaLayout); waitingSpot: the middle of the
-- waiting room's floor (where the knocked out and the waiting stand).
function RoundService.start(spots: { ArenaLayout.Spot }, trains: number, waitingSpot: CFrame, hooks: Hooks): Service
	local r = Config.Round
	local alive: { [Model]: Fighter } = {}
	local lastHit: { [Model]: { swinger: Model, at: number } } = {}
	local lastLanded = 0 -- server time a hit last landed (quietSince)
	local fighting = false
	local running = true
	-- Home runs in a row this round (RoundRules.homerunStreak), and wins in a row this visit by player (or bot name).
	local homers: { [Model]: number } = {}
	local wins: { [any]: number } = {}
	local entrants: { any } = {}
	local connections: { RBXScriptConnection } = {}

	-- Everyone still in, those on their way back too.
	local function count(): number
		local n = 0
		for _ in alive do
			n += 1
		end
		return n
	end

	-- Whether a player (not a practice bot) is still in.
	local function playerIn(): boolean
		for _, fighter in alive do
			if fighter.player then
				return true
			end
		end
		return false
	end

	local function publishAlive()
		Workspace:SetAttribute(Names.AliveCount, count())
	end

	-- A spot of its own in the waiting room, away from the glass walls.
	local function stands(): CFrame
		local half = Config.Arena.WaitingRoomSize / 2 - 3
		return waitingSpot + Vector3.new((math.random() * 2 - 1) * half, 0, (math.random() * 2 - 1) * half)
	end

	-- Calls off a fighter's way back, if it is on it (it stays wherever it is: the stands, or the air it now falls from).
	local function callOff(fighter: Fighter)
		local cancel = fighter.returning
		if cancel then
			fighter.returning = nil
			cancel()
		end
	end

	-- A fighter's shown name (the player's display name or the sandbag's).
	local function nameOf(model: Model): string
		local player = Players:GetPlayerFromCharacter(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		return if player then player.DisplayName elseif humanoid then humanoid.DisplayName else model.Name
	end

	local function eliminate(model: Model, how: string)
		local gone = how == "gone"
		-- The fall (drifting behind the train) or the home-run flight (twinkling out in the sky) plays on before the
		-- fighter goes up to the stands; a sandbag that is out just goes.
		local show = if how == "homerun" then Config.Fall.HomeRunSeconds else Config.Fall.ShowSeconds
		local fighter = alive[model]
		if not fighter or (fighter.returning and not gone) then
			return
		end
		local left, out = RoundRules.afterFall(fighter.tickets)
		if gone or not fighting then
			left, out = 0, true -- died or left; or fell outside the fight (the count-down)
		end
		fighter.tickets = left
		model:SetAttribute(Names.Tickets, left)
		local hit = lastHit[model]
		lastHit[model] = nil -- a fall after coming back is credited afresh
		local by: Model? = nil
		if hit and now() - hit.at <= r.KillCreditSeconds and hit.swinger ~= model then
			by = hit.swinger
			hit.swinger:SetAttribute(Names.KOs, (PartUtil.number(hit.swinger, Names.KOs) or 0) + 1)
			hit.swinger:SetAttribute(Names.CheerAt, now()) -- (every client draws a quick fist pump: decision 26)
		end
		local streak = RoundRules.homerunStreak(homers, model, by, how)
		if not gone then
			hooks.announce(nameOf(model), if by then nameOf(by) else nil, how, out, streak)
		end
		if not out then
			local landed = false
			local cancel = hooks.comeback(model, show, function()
				landed = true
				fighter.returning = nil
			end)
			if not landed then -- (back() could come at once, when there is nowhere to land)
				fighter.returning = cancel
			end
			return
		end
		callOff(fighter) -- died or left on the way back
		alive[model] = nil
		model:SetAttribute(Names.Alive, false)
		if fighter.player then
			hold(model, false) -- out during the count-down: free to move in the stands
		end
		publishAlive()
		task.delay(show, function()
			if fighter.player then
				if fighter.player.Character == model and model.Parent then
					model:PivotTo(stands())
				end
			elseif model.Parent then
				model:Destroy()
			end
		end)
	end

	-- Puts everyone ready on the roofs, held still, for the count-down. Returns false (and puts nobody anywhere) when
	-- too few are ready after all.
	local function enter(): boolean
		table.clear(alive)
		table.clear(lastHit)
		table.clear(homers)
		-- Sandbags made first: making them can take frames, and the players are read after it, with nothing yielding
		-- between reading them and placing them (a player who died or left meanwhile is simply not read).
		local sandbags = hooks.spawnSandbags(hooks.sandbagCount())
		-- Players placed first, so they take the middle train's spots (ArenaLayout.preferMiddle) and a few meet there.
		local fighters: { Fighter } = {}
		local players = readyPlayers()
		for _, player in players do
			table.insert(fighters, { model = player.Character :: Model, player = player, tickets = r.Tickets, returning = nil })
		end
		for _, model in sandbags do
			table.insert(fighters, { model = model, player = nil, tickets = r.Tickets, returning = nil })
		end
		if #players < 1 or #fighters < r.MinPlayers then
			hooks.clearSandbags()
			return false
		end
		entrants = {}
		for _, fighter in fighters do
			table.insert(entrants, if fighter.player then fighter.player.UserId else nameOf(fighter.model))
		end
		local free = ArenaLayout.preferMiddle(spots, trains, shuffled)
		for i, fighter in fighters do
			local spot = free[(i - 1) % #free + 1]
			local at = Vector3.new(spot.x, spot.y + 3.5, spot.z)
			-- Facing across the track, toward the middle.
			local toward = if spot.x > 0 then Vector3.new(-1, 0, 0) elseif spot.x < 0 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, -1)
			fighter.model:PivotTo(CFrame.lookAt(at, at + toward))
			local body = CharacterParts.body(fighter.model)
			if body then
				-- A pivot keeps the speed: a sandbag made under the fall line was sliding backward there.
				body.root.AssemblyLinearVelocity = Vector3.zero
				body.root.AssemblyAngularVelocity = Vector3.zero
			end
			fighter.model:SetAttribute(Names.Alive, true)
			fighter.model:SetAttribute(Names.KOs, 0)
			fighter.model:SetAttribute(Names.Tickets, fighter.tickets)
			hooks.resetHealth(fighter.model)
			if fighter.player then
				hold(fighter.model, true)
			end
			alive[fighter.model] = fighter
		end
		publishAlive()
		return true
	end

	-- Everyone still standing (or on the way back) goes back to the waiting room; sandbags go away.
	local function leave()
		for model, fighter in alive do
			callOff(fighter)
			model:SetAttribute(Names.Alive, false)
			if fighter.player and model.Parent then
				hold(model, false)
				model:PivotTo(stands())
			end
		end
		table.clear(alive)
		hooks.clearSandbags()
		publishAlive()
	end

	task.spawn(function()
		while running do
			setPhase("Waiting", 0)
			Workspace:SetAttribute(Names.Winner, "")
			Workspace:SetAttribute(Names.WinnerCount, 0)
			Workspace:SetAttribute(Names.WinnerStreak, 0)
			repeat
				task.wait(0.5)
				local players = #readyPlayers()
			until not running or (players >= 1 and players + hooks.sandbagCount() >= r.MinPlayers)
			if not running then
				break
			end
			if not enter() then
				continue
			end
			setPhase("Countdown", now() + r.CountdownSeconds)
			task.wait(r.CountdownSeconds)
			for model, fighter in alive do
				if fighter.player then
					hold(model, false)
				end
			end
			fighting = true
			local fightEnds = now() + r.MaxSeconds
			lastLanded = now()
			setPhase("Fight", fightEnds)
			-- With practice bots, it also ends once no player is left in it (the bots would fight on for minutes while
			-- the player could only watch from the stands; with players only, two or more in means a player is in).
			while running and count() > 1 and now() < fightEnds and playerIn() do
				task.wait(0.1)
			end
			local timeUp = now() >= fightEnds
			fighting = false
			-- Nobody comes down onto the roofs during the result: those on their way back stay where they are (still in).
			for _, fighter in alive do
				callOff(fighter)
			end
			-- The last one in wins; when the time ran out, the best ranked of those still in (tied ones win together).
			local winners: { string } = {}
			local single: any = nil -- the one winner, as entrants counts it
			if count() == 1 then
				local last = next(alive)
				if last then
					winners = { nameOf(last) }
					local fighter = alive[last]
					single = if fighter and fighter.player then fighter.player.UserId else nameOf(last)
				end
			elseif timeUp then
				local standings: { RoundRules.Standing } = {}
				for model, fighter in alive do
					table.insert(standings, {
						name = nameOf(model),
						tickets = fighter.tickets,
						kos = PartUtil.number(model, Names.KOs) or 0,
						health = PartUtil.number(model, Names.Health) or 0,
					})
				end
				winners = RoundRules.winners(standings)
			end
			Workspace:SetAttribute(Names.Winner, table.concat(winners, ", "))
			Workspace:SetAttribute(Names.WinnerCount, #winners)
			Workspace:SetAttribute(Names.WinnerStreak, RoundRules.winStreak(wins, entrants, single))
			setPhase("Ended", now() + r.EndSeconds)
			task.wait(r.EndSeconds)
			leave()
			setPhase("Waiting", 0)
			task.wait(r.IntermissionSeconds)
		end
	end)

	-- A player who dies or leaves is out.
	local function watchCharacter(model: Model)
		local humanoid = model:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				eliminate(model, "gone")
			end)
		end
	end
	local function watchPlayer(player: Player)
		table.insert(connections, player.CharacterAdded:Connect(watchCharacter))
		if player.Character then
			task.spawn(watchCharacter, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	table.insert(connections, Players.PlayerAdded:Connect(watchPlayer))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		for model, fighter in alive do
			if fighter.player == player then
				callOff(fighter)
				alive[model] = nil
			end
		end
		publishAlive()
	end))

	return {
		fighters = function(): { Model }
			local list = {}
			for model, fighter in alive do
				if not fighter.returning then
					table.insert(list, model)
				end
			end
			return list
		end,
		isFighting = function(model: Model): boolean
			local fighter = alive[model]
			return fighting and fighter ~= nil and not fighter.returning
		end,
		stands = stands,
		noteHit = function(victim: Model, swinger: Model)
			lastHit[victim] = { swinger = swinger, at = now() }
			lastLanded = now()
		end,
		eliminate = eliminate,
		quietSince = function(): number
			return lastLanded
		end,
		stop = function()
			running = false
			for _, connection in connections do
				connection:Disconnect()
			end
		end,
	}
end

return RoundService
