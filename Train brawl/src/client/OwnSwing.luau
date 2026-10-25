--!strict
-- The player's own attack on this client, with whatever the character holds (bare fists or a picked-up weapon:
-- Config.Weapons, the character's Names.Weapon). When the control is pressed and an attack may start (fighting, still
-- in the round, not stunned by a hit, the weapon ready), it is drawn and heard at once; a punch's or swing's hits are
-- shown at once too (the same cone the server uses, without the network slack: SwingTargets; a slam's or a thrown
-- stick's hits wait for the server's word); and the server is told where the character aims (it turns with the camera
-- under the mouse lock). The server judges it for real (WeaponService). The drawing and the hit effects come in as
-- hooks (SwingPose, HitFeedback via init).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local SwingTargets = require(shared:WaitForChild("SwingTargets"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))

local OwnSwing = {}
OwnSwing.__index = OwnSwing

-- An attack the server reports this close to the player's own last one is that one (already drawn).
local SAME_SWING_SECONDS = 0.5

export type Hooks = {
	fighters: () -> { Model }, -- the characters still in the round
	stunned: () -> boolean, -- the player's character is flinching or flying from a hit
	draw: (model: Model, at: number, weapon: string) -> (), -- draw and sound an attack that started at server time `at`
	predict: (victim: Model, weapon: string) -> (), -- show a hit the attack is about to land
}

-- last: when the player's own last attack started; ready: when the next may start (by the cooldown of the weapon that
-- attack used, as the server counts it: running out of a slow weapon does not let a quick fist out sooner).
type Fields = { remote: RemoteEvent, hooks: Hooks, last: number, ready: number }
export type Swing = typeof(setmetatable({} :: Fields, OwnSwing))

function OwnSwing.new(remote: RemoteEvent, hooks: Hooks): Swing
	local fields: Fields = { remote = remote, hooks = hooks, last = -math.huge, ready = -math.huge }
	return setmetatable(fields, OwnSwing)
end

-- The control was pressed; `model` is the player's character (nil = none).
function OwnSwing.press(self: Swing, model: Model?)
	local body = CharacterParts.body(model)
	local now = Workspace:GetServerTimeNow()
	if not body or body.model:GetAttribute(Names.Alive) ~= true or Workspace:GetAttribute(Names.Phase) ~= "Fight" then
		return
	end
	local weapon = WeaponRules.named(Config.Weapons, body.model:GetAttribute(Names.Weapon))
	local w = Config.Weapons[weapon]
	if self.hooks.stunned() or now < self.ready then
		return
	end
	self.last = now
	self.ready = now + w.cooldown
	self.hooks.draw(body.model, now, weapon)
	-- The server judges along this aim (taken now), so the hits shown at once use it too.
	local aim = body.root.CFrame.LookVector
	self.remote:FireServer(aim)
	local reach = w.reach
	if not reach then
		return -- a slam or a throw: its hits are shown when the server says
	end
	task.delay(w.hitAt, function()
		local me = CharacterParts.body(body.model)
		-- Hit while attacking: the server judges from where the knock took the player, so show no hits of its own.
		if me and not self.hooks.stunned() then
			for _, victim in SwingTargets.find(me, self.hooks.fighters(), reach, aim, w.halfAngle) do
				self.hooks.predict(victim.model, weapon)
			end
		end
	end)
end

-- Whether an attack of the player's character that the server says started at `at` is the one drawn when pressed.
function OwnSwing.drawn(self: Swing, at: number): boolean
	return math.abs(at - self.last) < SAME_SWING_SECONDS
end

return OwnSwing
