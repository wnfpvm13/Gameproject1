--!strict
-- The player's own attack on this client, with whatever the character holds (bare fists or a picked-up weapon:
-- Config.Weapons, the character's Names.Weapon). When the control is pressed and an attack may start (fighting, still
-- in the round, not stunned by a hit, the weapon ready), it is drawn and heard at once as the next step of the
-- player's 1-2-3 string (AttackString, counted here the same way the server counts it: it goes on while this
-- client's shown hits land, a hit on the player breaks it, and the server's word corrects it); a punch's or swing's hits are
-- shown at once too (the same cone the server uses, without the network slack: SwingTargets; a slam's or a thrown
-- stick's hits wait for the server's word); and the server is told where the character aims (it turns with the camera
-- under the mouse lock) and which step was drawn. The server judges it for real (WeaponService). The drawing and the hit effects come in as
-- hooks (SwingPose, HitFeedback via init).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local SwingTargets = require(shared:WaitForChild("SwingTargets"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local AttackString = require(shared:WaitForChild("AttackString"))

local STRING = AttackString.rules(Config.Attack)

local OwnSwing = {}
OwnSwing.__index = OwnSwing

-- An attack the server reports this close to the player's own last one is that one (already drawn).
local SAME_SWING_SECONDS = 0.5
-- The server's word on the player's latest attack comes within this of when it was pressed (a one-way trip; every
-- attack waits at least a cooldown after the last).
local LATEST_SECONDS = 0.25

export type Hooks = {
	fighters: () -> { Model }, -- the characters still in the round
	stunned: () -> boolean, -- the player's character is flinching or flying from a hit
	-- Draw and sound an attack that started at server time `at`, at `step` of the string.
	draw: (model: Model, at: number, weapon: string, step: number) -> (),
	-- Show a hit the attack is about to land (`finisher`: the string's launching last step).
	predict: (victim: Model, weapon: string, finisher: boolean) -> (),
}

-- last: when the player's own last attack started; ready: when the next may start (by the cooldown of the weapon that
-- attack used, as the server counts it: running out of a slow weapon does not let a quick fist out sooner).
-- chain: the player's 1-2-3 string.
type Fields = { remote: RemoteEvent, hooks: Hooks, last: number, ready: number, chain: AttackString.State }
export type Swing = typeof(setmetatable({} :: Fields, OwnSwing))

function OwnSwing.new(remote: RemoteEvent, hooks: Hooks): Swing
	local fields: Fields = { remote = remote, hooks = hooks, last = -math.huge, ready = -math.huge, chain = AttackString.new() }
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
	local step = AttackString.take(self.chain, STRING, now, w.cooldown, w.style)
	self.hooks.draw(body.model, now, weapon, step)
	-- The server judges along this aim (taken now), so the hits shown at once use it too.
	local aim = body.root.CFrame.LookVector
	self.remote:FireServer(aim, step)
	local reach = w.reach
	if not reach then
		return -- a slam or a throw: its hits are shown when the server says
	end
	task.delay(AttackString.hitAt(STRING, w.hitAt, step, w.style), function()
		local me = CharacterParts.body(body.model)
		-- Hit while attacking: the server judges from where the knock took the player, so show no hits of its own.
		if me and not self.hooks.stunned() then
			local victims = SwingTargets.find(me, self.hooks.fighters(), reach, aim, w.halfAngle)
			local finisher = AttackString.launches(STRING, step, w.style)
			for _, victim in victims do
				self.hooks.predict(victim.model, weapon, finisher)
			end
			if #victims > 0 then
				AttackString.landed(self.chain) -- it landed: the string may go on (as the server counts it)
			end
		end
	end)
end

-- The player was hit: the string is broken (the next attack is a 1, as on the server).
function OwnSwing.broken(self: Swing)
	AttackString.reset(self.chain)
end

-- The server's step for an attack of the player's that it says started at `at` (Names.SwingStep): when that is the
-- player's latest attack and the server counted differently (it dropped an attack, or the network shook more than its
-- slack), this client counts on from the server's step. (An older attack's word, arriving after the next press, is
-- left alone.)
function OwnSwing.settle(self: Swing, at: number, step: number)
	if math.abs(at - self.last) < LATEST_SECONDS and step ~= self.chain.step then
		self.chain.step = step
	end
end

-- Whether an attack of the player's character that the server says started at `at` is the one drawn when pressed.
function OwnSwing.drawn(self: Swing, at: number): boolean
	return math.abs(at - self.last) < SAME_SWING_SECONDS
end

return OwnSwing
