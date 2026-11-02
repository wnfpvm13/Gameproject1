--!strict
-- The player's own dodge roll (decision 22). When the roll control is pressed (DodgeInput) and the character may roll
-- (hooks.may: in the running fight, on the trains, not on its way back; not stunned by a hit: hooks.stunned) and its
-- last roll started Config.Dodge.Cooldown ago, it rolls at once - along the way the player walks, straight back from
-- where it faces when standing still (DodgeRules.direction) - and tells the server which way (Names.DodgeRemote: the
-- server judges it the same and makes the fighter unhittable for a moment). Drawing and moving the roll is hooks.roll's
-- (DodgeShow, BodyMotion.roll). busy() says whether a roll is going (no attacking meanwhile), wait() how long until the
-- next may start, and rolledAt() when the last one started (server time), for the screen not to draw it twice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local DodgeRules = require(shared:WaitForChild("DodgeRules"))

local OwnDodge = {}
OwnDodge.__index = OwnDodge

export type Hooks = {
	may: () -> boolean, -- the character fights on the trains now
	stunned: () -> boolean, -- flinching or flying from a hit
	roll: (model: Model, at: number, direction: Vector3) -> (), -- moves and draws the roll that starts now
}

type Fields = { remote: RemoteEvent, hooks: Hooks, last: number? }
export type Dodge = typeof(setmetatable({} :: Fields, OwnDodge))

function OwnDodge.new(remote: RemoteEvent, hooks: Hooks): Dodge
	local fields: Fields = { remote = remote, hooks = hooks, last = nil }
	return setmetatable(fields, OwnDodge)
end

-- The roll control was pressed with `model` the player's character. Returns whether it rolled.
function OwnDodge.press(self: Dodge, model: Model?): boolean
	local body = CharacterParts.body(model)
	local now = Workspace:GetServerTimeNow()
	if not (model and body) or not self.hooks.may() or self.hooks.stunned() then
		return false
	end
	if not DodgeRules.ready(self.last, now, Config.Dodge.Cooldown, 0) or body.humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end
	local move = body.humanoid.MoveDirection
	local look = body.root.CFrame.LookVector
	local x, z = DodgeRules.direction(move.X, move.Z, look.X, look.Z)
	local direction = Vector3.new(x, 0, z)
	self.last = now
	self.remote:FireServer(direction)
	self.hooks.roll(model, now, direction)
	return true
end

-- Whether the player's roll is going at server time `now`.
function OwnDodge.busy(self: Dodge, now: number): boolean
	return DodgeRules.rolling(self.last, now, Config.Dodge.Seconds)
end

-- Seconds until the next roll may start, at server time `now`.
function OwnDodge.wait(self: Dodge, now: number): number
	return DodgeRules.wait(self.last, now, Config.Dodge.Cooldown)
end

-- When the player's last roll started (server time; nil: none yet).
function OwnDodge.rolledAt(self: Dodge): number?
	return self.last
end

return OwnDodge
