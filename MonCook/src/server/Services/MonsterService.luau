--!strict
-- Pure encounter authority. Geometry, time, movement and presentation are injected.
local MonsterService = {}
MonsterService.__index = MonsterService
local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}; for key, child in value do result[key] = clone(child) end; return result
end
function MonsterService.new(options: any): any
	assert(type(options.Definitions) == "table" and type(options.Geometry) == "table"
		and type(options.Now) == "function" and type(options.NewId) == "function", "monster dependencies required")
	local zones = {}
	local initialNow = (options.Now :: () -> number)()
	for id, definition in options.Definitions.Spawn do
		local slots = {}
		for index = 1, definition.MaxAlive do slots[index] = { NextSpawnAt = initialNow, EncounterId = nil } end
		zones[id] = { Definition = definition, Slots = slots }
	end
	return setmetatable({ Definitions = options.Definitions, Math = options.Geometry, Now = options.Now,
		NewId = options.NewId, Move = options.Move, OnEvent = options.OnEvent, Log = options.Log,
		_monsters = {}, _zones = zones, _issued = {}, _rewards = {} }, MonsterService)
end
function MonsterService._emit(self: any, kind: string, monster: any, extra: any?)
	local event = { Kind = kind, EventId = monster.EncounterId .. ":" .. kind,
		EncounterId = monster.EncounterId, MonsterId = monster.MonsterId, ZoneId = monster.ZoneId,
		Origin = self.Math.copy(monster.Position), At = self.Now() }
	if extra then for key, value in extra do event[key] = clone(value) end end
	if kind == "PartBroken" or kind == "Dead" then self._rewards[event.EventId] = clone(event) end
	if self.OnEvent then
		local ok, reason = pcall(self.OnEvent, clone(event))
		if not ok and self.Log then (self.Log :: (string) -> ())("Monster presentation: " .. tostring(reason)) end
	end
end
function MonsterService.PendingRewards(self: any): { any }
	local result = {}; for _, event in self._rewards do table.insert(result, clone(event)) end
	table.sort(result, function(a: any, b: any) return a.EventId < b.EventId end)
	return result
end
function MonsterService.AckReward(self: any, eventId: string) self._rewards[eventId] = nil end
function MonsterService._state(self: any, monster: any, state: string, seconds: number)
	monster.State, monster.StateStartedAt, monster.StateUntil = state, self.Now(), self.Now() + seconds
	self:_emit("StateChanged", monster, { State = state, AttackType = monster.AttackType })
end
function MonsterService._spawn(self: any, zoneId: string, slotIndex: number)
	local zone = self._zones[zoneId]
	local id = self.NewId()
	assert(type(id) == "string" and #id > 0 and #id <= 100 and not self._issued[id], "invalid/reused encounter ID")
	self._issued[id] = true
	local config = self.Definitions.Monster[zone.Definition.MonsterId]
	local home = self.Math.add(zone.Definition.Center, zone.Definition.Offsets[slotIndex])
	local now = self.Now()
	local monster = { EncounterId = id, MonsterId = zone.Definition.MonsterId, ZoneId = zoneId, Slot = slotIndex,
		Position = self.Math.copy(home), Home = home, Facing = { X = 0, Y = 0, Z = 1 },
		BodyHP = config.MaxHealth, HornHP = config.HornHealth, HornBroken = false,
		State = "Idle", StateStartedAt = now, StateUntil = now + config.IdleSeconds,
		Contributors = {}, AppliedAttacks = {}, AttackHitActors = {}, RoamIndex = 0 }
	self._monsters[id], zone.Slots[slotIndex].EncounterId = monster, id
	self:_emit("Spawned", monster)
end
function MonsterService.Get(self: any, encounterId: string): any return clone(self._monsters[encounterId]) end
function MonsterService.List(self: any): { any }
	local result = {}; for _, monster in self._monsters do table.insert(result, clone(monster)) end
	table.sort(result, function(a: any, b: any) return a.EncounterId < b.EncounterId end)
	return result
end
function MonsterService.Eligible(self: any, encounterId: string): { number }
	local monster = self._monsters[encounterId]
	if not monster then return {} end
	local config, now, result = self.Definitions.Monster[monster.MonsterId], self.Now(), {}
	for actorId, contribution in monster.Contributors do
		if contribution.BodyDamage + contribution.PartDamage >= config.ContributionMinimum
			and now - contribution.LastAt <= config.ContributionExpirySeconds then table.insert(result, actorId) end
	end
	table.sort(result)
	return result
end
function MonsterService.ApplyHit(self: any, encounterId: string, actorId: number, hit: any): (boolean, any)
	local monster = self._monsters[encounterId]
	if not monster or monster.State == "Dead" then return false, "DeadOrMissing" end
	assert(self.Math.finite(actorId) and actorId ~= 0 and actorId % 1 == 0, "invalid contributor")
	assert(type(hit.AttackId) == "string" and #hit.AttackId > 0 and self.Math.finite(hit.Damage)
		and hit.Damage > 0 and self.Math.finite(hit.PartPower) and hit.PartPower >= 0, "invalid trusted hit")
	local key = tostring(actorId) .. ":" .. hit.AttackId
	if monster.AppliedAttacks[key] then return false, "Duplicate" end
	monster.AppliedAttacks[key] = true
	local bodyDamage = math.min(monster.BodyHP, hit.Damage)
	local partDamage = if hit.Horn and not monster.HornBroken then math.min(monster.HornHP, hit.PartPower) else 0
	monster.BodyHP -= bodyDamage
	monster.HornHP -= partDamage
	local contribution = monster.Contributors[actorId]
	if not contribution then
		contribution = { BodyDamage = 0, PartDamage = 0, LastAt = self.Now() }
		monster.Contributors[actorId] = contribution
		self:_emit("MonsterEncounterStarted", monster, { ActorId = actorId })
	end
	contribution.BodyDamage += bodyDamage; contribution.PartDamage += partDamage; contribution.LastAt = self.Now()
	monster.LastHitAt = self.Now()
	self:_emit("Damaged", monster, { ActorId = actorId, BodyHP = monster.BodyHP, HornHP = monster.HornHP })
	if monster.HornHP == 0 and not monster.HornBroken then
		monster.HornBroken = true
		self:_emit("PartBroken", monster, { PartId = "Horn", DropId = self.Definitions.Monster[monster.MonsterId].Parts.Horn.DropId,
			Members = self:Eligible(encounterId) })
		self:_state(monster, "Stagger", self.Definitions.Monster[monster.MonsterId].StaggerSeconds)
	end
	if monster.BodyHP == 0 then
		monster.DeathAt = self.Now()
		self:_state(monster, "Dead", self.Definitions.Monster[monster.MonsterId].DeathDespawnSeconds)
		self._zones[monster.ZoneId].Slots[monster.Slot].NextSpawnAt = self.Now() + self._zones[monster.ZoneId].Definition.RespawnDelay
		self:_emit("Dead", monster, { DropId = self.Definitions.Monster[monster.MonsterId].DropId, Members = self:Eligible(encounterId) })
	end
	return true, { BodyDamage = bodyDamage, PartDamage = partDamage, BodyHP = monster.BodyHP, HornHP = monster.HornHP }
end
function MonsterService._nearest(self: any, monster: any, players: { any }, range: number): any
	local nearest, distance = nil, range
	for _, player in players do
		if player.Alive and player.Location == "World" and player.Eligible ~= false and self.Math.point(player.Position)
			and math.abs(player.Position.Y - monster.Position.Y) <= self.Definitions.Combat.Rules.VerticalTolerance then
			local d = self.Math.distance(monster.Position, player.Position)
			if d <= distance then nearest, distance = player, d end
		end
	end
	return nearest
end
function MonsterService._move(self: any, monster: any, destination: any)
	local actual = if self.Move then (self.Move :: (string, any, any) -> any)(monster.EncounterId, self.Math.copy(monster.Position), destination) else destination
	if self.Math.point(actual) then monster.Position = self.Math.copy(actual) end
end
function MonsterService._walk(self: any, monster: any, destination: any, speed: number, dt: number)
	monster.Facing = self.Math.direction(monster.Position, destination, monster.Facing)
	self:_move(monster, self.Math.advance(monster.Position, monster.Facing, math.min(speed*dt, self.Math.distance(monster.Position, destination))))
end
function MonsterService._attackHits(self: any, monster: any, previous: any, players: { any })
	local attack = self.Definitions.Monster[monster.MonsterId].Attacks[monster.AttackType]
	local elapsed = self.Now() - monster.StateStartedAt
	if elapsed < attack.HitStart or elapsed > attack.HitEnd then return end
	for _, player in players do
		if player.Alive and player.Location == "World" and player.Eligible ~= false and not monster.AttackHitActors[player.ActorId]
			and self.Math.point(player.Position) and math.abs(player.Position.Y-monster.Position.Y) <= self.Definitions.Combat.Rules.VerticalTolerance then
			local hit
			if monster.AttackType == "Charge" then
				local from = self.Math.advance(previous, monster.Facing, 2)
				local to = self.Math.advance(monster.Position, monster.Facing, 2)
				hit = self.Math.segmentDistance(player.Position, from, to) <= attack.Radius
			else
				hit = self.Math.inArc(monster.Position, monster.Facing, player.Position, attack.Range, attack.ArcDegrees,
					self.Definitions.Combat.Rules.VerticalTolerance)
			end
			if hit then
				monster.AttackHitActors[player.ActorId] = true
				self:_emit("AttackHit", monster, { ActorId = player.ActorId, Damage = attack.Damage, AttackType = monster.AttackType })
			end
		end
	end
end
function MonsterService._update(self: any, monster: any, players: { any }, dt: number)
	local config, now = self.Definitions.Monster[monster.MonsterId], self.Now()
	if monster.State == "Dead" then
		if now >= monster.StateUntil then
			self:_emit("Despawned", monster)
			self._monsters[monster.EncounterId] = nil
			self._zones[monster.ZoneId].Slots[monster.Slot].EncounterId = nil
		end
		return
	end
	if monster.State == "Windup" then
		-- Facing remains locked throughout telegraph and charge.
		if now >= monster.StateUntil then
			monster.AttackHitActors = {}
			self:_state(monster, "Attack", config.Attacks[monster.AttackType].Duration)
		end
		return
	elseif monster.State == "Attack" then
		if now >= monster.StateUntil then self:_state(monster, "Recover", config.Attacks[monster.AttackType].Recover); return end
		local previous = self.Math.copy(monster.Position)
		if monster.AttackType == "Charge" then self:_move(monster, self.Math.advance(monster.Position, monster.Facing, config.Attacks.Charge.Speed*dt)) end
		self:_attackHits(monster, previous, players)
		return
	elseif monster.State == "Recover" or monster.State == "Stagger" then
		if now >= monster.StateUntil then monster.AttackType = nil; self:_state(monster, "Idle", config.IdleSeconds) end
		return
	end
	local target = self:_nearest(monster, players, config.AlertDistance)
	if self.Math.distance(monster.Position, monster.Home) > config.LeashDistance then target = nil end
	if monster.State == "Alert" then
		if now >= monster.StateUntil then self:_state(monster, if target then "Chase" else "Idle", config.IdleSeconds) end
		return
	elseif target and (monster.State == "Idle" or monster.State == "Roam") then
		monster.Facing = self.Math.direction(monster.Position, target.Position, monster.Facing)
		self:_state(monster, "Alert", config.AlertSeconds)
		return
	elseif monster.State == "Chase" then
		if not target then monster.RoamTarget = self.Math.copy(monster.Home); self:_state(monster, "Roam", config.RoamSeconds); return end
		local distance = self.Math.distance(monster.Position, target.Position)
		monster.Facing = self.Math.direction(monster.Position, target.Position, monster.Facing)
		if distance <= config.Attacks.Charge.Range then
			monster.AttackType = if distance >= config.Attacks.Charge.MinimumRange then "Charge" else "Headbutt"
			if monster.AttackType == "Headbutt" and distance > config.Attacks.Headbutt.Range then
				self:_walk(monster, target.Position, config.MoveSpeed, dt); return
			end
			self:_state(monster, "Windup", config.Attacks[monster.AttackType].Windup)
		else self:_walk(monster, target.Position, config.MoveSpeed, dt) end
		return
	elseif monster.State == "Idle" and now >= monster.StateUntil then
		monster.RoamIndex += 1
		local angle = monster.RoamIndex*math.pi/2
		monster.RoamTarget = self.Math.add(monster.Home, { X = math.cos(angle)*config.RoamRadius, Y = 0, Z = math.sin(angle)*config.RoamRadius })
		self:_state(monster, "Roam", config.RoamSeconds)
	elseif monster.State == "Roam" then
		if now >= monster.StateUntil or self.Math.distance(monster.Position, monster.RoamTarget) < 0.1 then self:_state(monster, "Idle", config.IdleSeconds)
		else self:_walk(monster, monster.RoamTarget, config.RoamSpeed, dt) end
	end
end
function MonsterService.Tick(self: any, players: { any }, delta: number)
	assert(self.Math.finite(delta) and delta >= 0, "invalid monster tick")
	local dt = math.min(delta, self.Definitions.Combat.Rules.TickSeconds*2)
	for _, monster in self._monsters do self:_update(monster, players, dt) end
	for zoneId, zone in self._zones do
		for slotIndex, slot in zone.Slots do
			if not slot.EncounterId and self.Now() >= slot.NextSpawnAt then self:_spawn(zoneId, slotIndex) end
		end
	end
end
return MonsterService
