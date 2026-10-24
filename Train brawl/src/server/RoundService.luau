--!strict
-- The rounds, on the server. Wait in the waiting room until enough are in (players, plus sandbags in Studio practice)
-- → count down on the roofs, everyone held still (Config.Round.CountdownSeconds) → fight until one is left or the time
-- runs out → show the winner → everyone back to the waiting room → again. The phase is published on the Workspace
-- (Names.Phase, PhaseEndsAt, AliveCount, Winner) and each fighter carries Names.Alive and Names.KOs. A fighter who
-- falls off (FallWatch, through Main) or dies is out; the last one to hit them within Config.Round.KillCreditSeconds
-- gets the knock-off. Players who come in during a fight watch until the next round. The knocked out go to a spot
-- of their own in the waiting room (stands()), so nobody lands on top of anyone.
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

local RoundService = {}

export type Service = {
	fighters: () -> { Model }, -- the models still in the running round
	isFighting: (model: Model) -> boolean, -- still in, and the fight has started
	noteHit: (victim: Model, swinger: Model) -> (),
	eliminate: (model: Model) -> (), -- fell off (or died, or left)
	stop: () -> (),
}

export type Hooks = {
	sandbagCount: () -> number, -- how many sandbags join a round (0 outside Studio practice)
	spawnSandbags: (count: number) -> { Model },
	clearSandbags: () -> (),
	resetHealth: (model: Model) -> (), -- full combat health for a fighter entering a round
}

type Fighter = { model: Model, player: Player? }

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

-- Players with a living character, ready to fight.
local function readyPlayers(): { Player }
	local ready = {}
	for _, player in Players:GetPlayers() do
		local body = CharacterParts.body(player.Character)
		if body and body.humanoid.Health > 0 then
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

-- waitingSpot: the middle of the waiting room's floor (where the knocked out and the waiting stand).
function RoundService.start(spots: { ArenaLayout.Spot }, waitingSpot: CFrame, hooks: Hooks): Service
	local r = Config.Round
	local alive: { [Model]: Fighter } = {}
	local lastHit: { [Model]: { swinger: Model, at: number } } = {}
	local fighting = false
	local running = true
	local connections: { RBXScriptConnection } = {}

	local function count(): number
		local n = 0
		for _ in alive do
			n += 1
		end
		return n
	end

	local function publishAlive()
		Workspace:SetAttribute(Names.AliveCount, count())
	end

	-- A spot of its own in the waiting room, away from the glass walls.
	local function stands(): CFrame
		local half = Config.Arena.WaitingRoomSize / 2 - 3
		return waitingSpot + Vector3.new((math.random() * 2 - 1) * half, 0, (math.random() * 2 - 1) * half)
	end

	local function eliminate(model: Model)
		local fighter = alive[model]
		if not fighter then
			return
		end
		alive[model] = nil
		model:SetAttribute(Names.Alive, false)
		if fighter.player then
			hold(model, false) -- out during the count-down: free to move in the stands
		end
		local hit = lastHit[model]
		if hit and now() - hit.at <= r.KillCreditSeconds and hit.swinger ~= model then
			hit.swinger:SetAttribute(Names.KOs, (PartUtil.number(hit.swinger, Names.KOs) or 0) + 1)
		end
		publishAlive()
		-- The fall plays on (drifting behind the train) before the player goes up to the stands; a sandbag just goes.
		task.delay(Config.Fall.ShowSeconds, function()
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
		-- Sandbags first: making them can take frames, and the players are read after it, with nothing yielding between
		-- reading them and placing them (a player who died or left meanwhile is simply not read).
		local fighters: { Fighter } = {}
		for _, model in hooks.spawnSandbags(hooks.sandbagCount()) do
			table.insert(fighters, { model = model, player = nil })
		end
		local players = readyPlayers()
		for _, player in players do
			table.insert(fighters, { model = player.Character :: Model, player = player })
		end
		if #players < 1 or #fighters < r.MinPlayers then
			hooks.clearSandbags()
			return false
		end
		local free = shuffled(spots)
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
			hooks.resetHealth(fighter.model)
			if fighter.player then
				hold(fighter.model, true)
			end
			alive[fighter.model] = fighter
		end
		publishAlive()
		return true
	end

	-- Everyone still standing goes back to the waiting room; sandbags go away.
	local function leave()
		for model, fighter in alive do
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
			setPhase("Fight", fightEnds)
			while running and count() > 1 and now() < fightEnds do
				task.wait(0.1)
			end
			fighting = false
			local winner = ""
			local last = if count() == 1 then next(alive) else nil
			if last then
				local fighter = alive[last]
				local humanoid = last:FindFirstChildOfClass("Humanoid")
				winner = if fighter.player then fighter.player.DisplayName elseif humanoid then humanoid.DisplayName else last.Name
			end
			Workspace:SetAttribute(Names.Winner, winner)
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
				eliminate(model)
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
				alive[model] = nil
			end
		end
		publishAlive()
	end))

	return {
		fighters = function(): { Model }
			local list = {}
			for model in alive do
				table.insert(list, model)
			end
			return list
		end,
		isFighting = function(model: Model): boolean
			return fighting and alive[model] ~= nil
		end,
		noteHit = function(victim: Model, swinger: Model)
			lastHit[victim] = { swinger = swinger, at = now() }
		end,
		eliminate = eliminate,
		stop = function()
			running = false
			for _, connection in connections do
				connection:Disconnect()
			end
		end,
	}
end

return RoundService
