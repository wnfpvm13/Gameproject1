--!strict
-- Presentation only: predicts timing, never health, contacts, damage or movement.
local Prediction = {}
Prediction.__index = Prediction
function Prediction.new(definitions: any, timeout: number): any
	return setmetatable({ Definitions = definitions, Timeout = timeout, Pending = nil,
		Action = nil, Combo = 0, LastBasicAt = -math.huge, DodgeReadyAt = 0, LastResolved = 0 }, Prediction)
end
function Prediction.Expire(self: any, at: number): boolean
	if self.Pending and at >= self.Pending.ExpiresAt then
		self.Pending, self.Action = nil, nil
		return true
	end
	return false
end
function Prediction.Plan(self: any, sequence: number, kind: string, at: number, weaponId: string): any
	self:Expire(at)
	if self.Pending or (self.Action and at < self.Action.EndAt) then return nil end
	if kind ~= "Basic" and kind ~= "Heavy" and kind ~= "Dodge" then return nil end
	if kind == "Dodge" and at < self.DodgeReadyAt then return nil end
	local weapon = self.Definitions.Weapon[weaponId]
	if not weapon then return nil end
	local rules = self.Definitions.Combat.Rules
	local action: any = { AttackId = "Predicted:"..tostring(sequence), Sequence = sequence,
		AttackType = kind, StartedAt = at, Predicted = true }
	if kind == "Dodge" then action.EndAt = at+rules.DodgeSeconds
	else
		local combo = if kind == "Basic" then (if at-self.LastBasicAt <= rules.ComboResetSeconds then self.Combo%3+1 else 1) else 0
		local attack = if kind == "Basic" then weapon.Basic[combo] else weapon.Heavy
		action.ComboIndex = combo
		action.WindowStartAt, action.WindowEndAt = at+attack.Windup, at+attack.Windup+attack.Window
		action.EndAt = action.WindowEndAt+attack.Recovery
	end
	self.Pending = { Sequence = sequence, ExpiresAt = at+self.Timeout }
	self.Action = action
	return action
end
function Prediction.Resolve(self: any, sequence: number, result: any): (boolean, any)
	-- A late reply cannot cancel or replace a newer local action, including after timeout.
	if sequence <= self.LastResolved or not self.Pending or sequence ~= self.Pending.Sequence then return false, self.Action end
	self.LastResolved, self.Pending = sequence, nil
	if not result or not result.Ok or not result.Action then self.Action = nil; return true, nil end
	local action = result.Action
	self.Action, self.DodgeReadyAt = action, result.DodgeReadyAt or self.DodgeReadyAt
	self.Combo = action.ComboIndex or 0
	if action.AttackType == "Basic" then self.LastBasicAt = action.StartedAt end
	return true, action
end
function Prediction.Reset(self: any)
	self.Pending, self.Action = nil, nil
	self.Combo, self.LastBasicAt, self.DodgeReadyAt = 0, -math.huge, 0
end
return Prediction
