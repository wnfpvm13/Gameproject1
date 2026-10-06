--!strict
-- Clients provide intent only. Context, contacts, damage and movement are server dependencies.
local CombatService = {}
CombatService.__index = CombatService
local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}; for key, child in value do result[key] = clone(child) end; return result
end
function CombatService.new(options: any): any
	assert(type(options.GetContext) == "function" and type(options.ResolveContacts) == "function"
		and type(options.ApplyHit) == "function" and type(options.GetTarget) == "function", "combat server adapters required")
	return setmetatable({ Definitions = options.Definitions, Math = options.Geometry, Contracts = options.Contracts, HitGeometry = options.HitGeometry,
		Now = options.Now, NewId = options.NewId, GetContext = options.GetContext, GetTarget = options.GetTarget,
		ResolveContacts = options.ResolveContacts, ApplyHit = options.ApplyHit, MoveDodge = options.MoveDodge,
		OnAction = options.OnAction, Log = options.Log, _actors = {} }, CombatService)
end
function CombatService._actor(self: any, actorId: number): any
	local state = self._actors[actorId]
	if not state then
		state = { SessionId = self.NewId(), LastSequence = 0, LastPacketAt = -math.huge,
			ComboIndex = 0, LastBasicAt = -math.huge, DodgeReadyAt = 0 }
		self._actors[actorId] = state
	end
	return state
end
function CombatService._context(self: any, actorId: number): any
	local context = self.GetContext(actorId)
	if not context or not context.Alive or context.Location ~= "World" or context.Eligible == false
		or not self.Math.point(context.Position) or not self.Math.point(context.Facing) then return nil end
	return context
end
function CombatService.Request(self: any, actorId: number, payload: any): any
	if not self.Math.finite(actorId) or actorId == 0 or actorId % 1 ~= 0 then return { Ok = false, Error = "Actor" } end
	local rules = self.Definitions.Combat.Rules
	local valid, reason = self.Contracts.intent(payload, rules.MaxSequence)
	if not valid then return { Ok = false, Error = reason } end
	local state, now = self:_actor(actorId), self.Now()
	if payload.Sequence <= state.LastSequence then return { Ok = false, Error = "Duplicate" } end
	state.LastSequence = payload.Sequence
	local elapsed = now - state.LastPacketAt
	state.LastPacketAt = now
	if elapsed < rules.PacketInterval then return { Ok = false, Error = "Rate" } end
	if state.Action and now < state.Action.EndAt then return { Ok = false, Error = "Busy" } end
	local context = self:_context(actorId)
	if not context then return { Ok = false, Error = "Unavailable" } end
	local weaponId, weapon = self.Contracts.weapon(context.Profile, self.Definitions.Weapon)
	if not weaponId then return { Ok = false, Error = "Weapon" } end
	local facing = self.Math.correctFacing(context.Facing, payload.Facing,
		if payload.AttackType == "Dodge" then 180 else rules.MaxFacingCorrectionDegrees)
	local action = { AttackId = state.SessionId .. ":" .. tostring(payload.Sequence), ActorId = actorId,
		AttackType = payload.AttackType, Facing = facing, StartedAt = now, LastTickAt = now,
		WeaponId = weaponId, EquippedId = context.Profile.Equipment.EquippedWeaponId, HitTargets = {} }
	if payload.AttackType == "Dodge" then
		if now < state.DodgeReadyAt then return { Ok = false, Error = "DodgeCooldown" } end
		action.EndAt = now + rules.DodgeSeconds
		state.DodgeReadyAt, state.ComboIndex = now + rules.DodgeCooldown, 0
	else
		local reach = if payload.AttackType == "Heavy" then weapon.Heavy.Reach or weapon.Reach else weapon.Reach
		if payload.TargetHint then
			local target = self.GetTarget(payload.TargetHint)
			local aim = if target then target.Position else nil
			if target and self.HitGeometry and target.MonsterId and self.Definitions.Monster[target.MonsterId] then
				aim = self.HitGeometry.aimPoint(context.Position, facing, target, self.Definitions.Monster[target.MonsterId], reach, rules.AimAssistDegrees*2, rules.VerticalTolerance)
			end
			if target and target.State ~= "Dead" and self.Math.point(target.Position)
				and self.Math.point(aim) and self.Math.inArc(context.Position, facing, aim, reach, rules.AimAssistDegrees*2, rules.VerticalTolerance) then
				action.Facing = self.Math.turnToward(facing, self.Math.direction(context.Position, aim, facing), rules.AimAssistMaxTurnDegrees)
				action.Facing = self.Math.turnToward(self.Math.direction({ X = 0, Y = 0, Z = 0 }, context.Facing), action.Facing, rules.MaxFacingCorrectionDegrees)
			end
		end
		local attack
		if payload.AttackType == "Basic" then
			state.ComboIndex = if now - state.LastBasicAt <= rules.ComboResetSeconds then state.ComboIndex % 3 + 1 else 1
			state.LastBasicAt = now
			action.ComboIndex = state.ComboIndex
			attack = weapon.Basic[state.ComboIndex]
		else state.ComboIndex = 0; attack = weapon.Heavy end
		action.Damage, action.PartPower = attack.Damage, attack.PartPower
		action.Reach, action.ArcDegrees = reach, attack.ArcDegrees or weapon.ArcDegrees
		action.WindowStartAt, action.WindowEndAt = now + attack.Windup, now + attack.Windup + attack.Window
		action.EndAt = action.WindowEndAt + attack.Recovery
	end
	state.Action = action
	if self.OnAction then
		local ok, message = pcall(self.OnAction, clone(action))
		if not ok and self.Log then (self.Log :: (string) -> ())("Combat presentation: " .. tostring(message)) end
	end
	return { Ok = true, Action = clone(action), DodgeReadyAt = state.DodgeReadyAt }
end
function CombatService.Tick(self: any)
	local now, rules = self.Now(), self.Definitions.Combat.Rules
	for actorId, state in self._actors do
		local action = state.Action
		if not action then continue end
		if now >= action.EndAt and action.AttackType ~= "Dodge" then state.Action = nil; continue end
		local context = self:_context(actorId)
		if not context or context.Profile.Equipment.EquippedWeaponId ~= action.EquippedId then state.Action = nil; continue end
		if action.AttackType == "Dodge" then
			local untilAt = math.min(now, action.EndAt)
			local duration = math.max(0, math.min(untilAt - action.LastTickAt, rules.TickSeconds*2))
			action.LastTickAt = untilAt
			if self.MoveDodge then (self.MoveDodge :: (number, any, number) -> ())(actorId, action.Facing, rules.DodgeDistance*duration/rules.DodgeSeconds) end
			if now >= action.EndAt then state.Action = nil end
		elseif now >= action.WindowStartAt and now <= action.WindowEndAt then
			for _, contact in self.ResolveContacts(context, clone(action)) do
				local target = self.GetTarget(contact.EncounterId)
				if action.HitTargets[contact.EncounterId] or not target or target.State == "Dead"
					or contact.ValidHitbox ~= true or not self.Math.point(contact.Position) then continue end
				if self.Math.point(target.Position) and self.Math.distance(context.Position,target.Position) > 0.000001
					and self.Math.dot(action.Facing,self.Math.direction(context.Position,target.Position)) < 0 then continue end
				if not self.Math.inArc(context.Position, action.Facing, contact.Position, action.Reach, action.ArcDegrees, rules.VerticalTolerance) then continue end
				action.HitTargets[contact.EncounterId] = true
				self.ApplyHit(contact.EncounterId, actorId, { AttackId = action.AttackId, Damage = action.Damage,
					PartPower = action.PartPower, Horn = contact.Horn == true, AttackType = action.AttackType,
					Position = clone(contact.Position) })
			end
		end
	end
end
function CombatService.State(self: any, actorId: number): any
	local state = self._actors[actorId]
	return if state then { Action = clone(state.Action), DodgeReadyAt = state.DodgeReadyAt, LastSequence = state.LastSequence } else {}
end
function CombatService.Forget(self: any, actorId: number) self._actors[actorId] = nil end
return CombatService
