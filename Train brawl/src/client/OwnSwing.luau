--!strict
-- The player's own attack on this client, with whatever the character holds (bare fists or a picked-up weapon:
-- Config.Weapons, the character's Names.Weapon). When the control is pressed and an attack may start (fighting, still
-- in the round, not stunned by a hit, the weapon ready), it is drawn and heard at once, and the character steps in, as
-- the next step of the
-- player's 1-2-3 string (AttackString, counted here the same way the server counts it: it goes on hit or miss while
-- the presses come in time, a hit on the player breaks it, and the server's word corrects it); a punch's or swing's hits are
-- shown at once too (the same cone the server uses, without the network slack: SwingTargets; every other style's hits
-- wait for the server's word); and the server is told where the character aims (it turns with the camera
-- under the mouse lock), which step was drawn and the attack's number (counted here: the server hands it back with
-- the attack, Names.SwingTag, and with its hits, so each word is matched to the attack it is about, however late it
-- comes). The server judges it for real (WeaponService). A press a moment too early (Config.Attack.PressBuffer before
-- the weapon is ready again or a light hit's flinch ends) is kept and made as soon as it may (update(), every frame), so
-- a press in time with the attacks is never lost; it is dropped if the character takes up another weapon meanwhile or
-- is hit, and a press while flying from a launch is not kept. The drawing and the hit effects come in as hooks (SwingPose, HitFeedback via
-- init). The string as it stands is read for the screen (stringView: StringHud).
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

-- What this client showed of the last this many attacks is kept (a word on an older one is long overdue: more than
-- 1.8 s even with fists).
local KEEP = 4

export type Hooks = {
	fighters: () -> { Model }, -- the characters still in the round
	stunned: () -> boolean, -- the player's character is flinching or flying from a hit
	launched: () -> boolean, -- flying from a launch (lying down until it lands)
	-- Draw and sound an attack that started at server time `at`, at `step` of the string.
	draw: (model: Model, at: number, weapon: string, step: number) -> (),
	-- Step the character in along the flat `aim` for an attack at `step` (BodyMotion.lunge).
	lunge: (model: Model, aim: Vector3, weapon: string, step: number) -> (),
	-- Draw the attack drawn at `at` as `step` instead (the server counted it differently; not sounded again).
	restep: (model: Model, at: number, weapon: string, step: number) -> (),
	-- Show a hit the attack is about to land (`finisher`: the string's launching last step); returns the kind of burst
	-- shown ("light" or "launch"), nil when it was not shown (the victim cannot be hit just now).
	predict: (victim: Model, weapon: string, finisher: boolean) -> string?,
}

-- One attack's showing: the burst kind this client showed at once on each victim, and the victims the server's word
-- came for first (the server took the attack as an earlier step, which lands sooner).
type Showing = { shown: { [Model]: string }, confirmed: { [Model]: boolean } }

-- last: when the player's own last attack started; ready: when the next may start (by the cooldown of the weapon that
-- attack used, as the server counts it: running out of a slow weapon does not let a quick fist out sooner).
-- chain: the player's 1-2-3 string; weapon: what the last attack was made with (a new weapon starts the string over);
-- model: the character it was made by. count: the attacks pressed so far (the last one's number); cut: the count when
-- the string was last broken (a word on an attack pressed before that does not touch the string). showings: the last
-- KEEP attacks' showings, by number. queued: when (server time) a press that came a moment too early was made, still
-- waiting to start, and queuedWith: the weapon held then. breaks: how many running strings a hit has broken.
type Fields = {
	remote: RemoteEvent,
	hooks: Hooks,
	last: number,
	ready: number,
	chain: AttackString.State,
	weapon: string?,
	model: Model?,
	count: number,
	cut: number,
	showings: { [number]: Showing },
	queued: number?,
	queuedWith: string?,
	breaks: number,
}
export type Swing = typeof(setmetatable({} :: Fields, OwnSwing))

function OwnSwing.new(remote: RemoteEvent, hooks: Hooks): Swing
	local fields: Fields = {
		remote = remote,
		hooks = hooks,
		last = -math.huge,
		ready = -math.huge,
		chain = AttackString.new(),
		weapon = nil,
		model = nil,
		count = 0,
		cut = 0,
		showings = {},
		queued = nil,
		queuedWith = nil,
		breaks = 0,
	}
	return setmetatable(fields, OwnSwing)
end

-- Whether attack number `tag` is the player's latest and pressed since the string was last broken (a word on it may
-- move the string).
local function current(self: Swing, tag: number): boolean
	return tag == self.count and tag > self.cut
end

-- Starts an attack by `model` (the player's character) if one may start now. Returns "started", "soon" (not yet: the
-- weapon is getting ready or the character is flinching or flying) or "no" (not fighting).
local function try(self: Swing, model: Model?): string
	local body = CharacterParts.body(model)
	local now = Workspace:GetServerTimeNow()
	if not body or body.model:GetAttribute(Names.Alive) ~= true or Workspace:GetAttribute(Names.Phase) ~= "Fight" then
		return "no"
	end
	if body.model:GetAttribute(Names.ReturnPhase) ~= nil then
		return "no" -- on the way back after a fall (the server takes no attacks then)
	end
	local weapon = WeaponRules.named(Config.Weapons, body.model:GetAttribute(Names.Weapon))
	local w = Config.Weapons[weapon]
	if self.hooks.stunned() or now < self.ready then
		return "soon"
	end
	self.last = now
	self.ready = now + w.cooldown
	self.count += 1
	local tag = self.count
	local showing: Showing = { shown = {}, confirmed = {} }
	self.showings[tag] = showing
	self.showings[tag - KEEP] = nil
	self.model = body.model
	if weapon ~= self.weapon then
		AttackString.reset(self.chain) -- a new weapon in hand starts the string over (as on the server)
		self.weapon = weapon
	end
	local step = AttackString.take(self.chain, STRING, now, w.cooldown, w.style)
	self.hooks.draw(body.model, now, weapon, step)
	-- The server judges along this aim (taken now), so the hits shown at once use it too.
	local aim = body.root.CFrame.LookVector
	self.hooks.lunge(body.model, aim, weapon, step)
	self.remote:FireServer(aim, step, tag)
	local reach = w.reach
	if not (reach and WeaponRules.predicted(w.style)) then
		return "started" -- not a punch or a swing (a lasso, a spray, an area, a thing sent out): shown when the server says
	end
	task.delay(AttackString.hitAt(STRING, w.hitAt, step, w.style), function()
		local me = CharacterParts.body(body.model)
		-- Hit while attacking: the server judges from where the knock took the player, so show no hits of its own.
		if me and not self.hooks.stunned() then
			local victims = SwingTargets.find(me, self.hooks.fighters(), reach, aim, w.halfAngle)
			-- The server's word may have corrected this attack's step meanwhile (settle): show the step it counts.
			local counted = if current(self, tag) then self.chain.step else step
			local finisher = AttackString.launches(STRING, counted, w.style)
			for _, victim in victims do
				-- (One the server's word came for first was shown then.)
				if not showing.confirmed[victim.model] then
					local kind = self.hooks.predict(victim.model, weapon, finisher)
					if kind then
						showing.shown[victim.model] = kind
					end
				end
			end
		end
	end)
	return "started"
end

-- The weapon `model` holds now.
local function held(model: Model?): string
	return WeaponRules.named(Config.Weapons, if model then model:GetAttribute(Names.Weapon) else nil)
end

-- The control was pressed; `model` is the player's character (nil = none). Too early, it is kept for a moment (not
-- while flying from a launch).
function OwnSwing.press(self: Swing, model: Model?)
	local result = try(self, model)
	if result == "soon" and not self.hooks.launched() then
		self.queued, self.queuedWith = Workspace:GetServerTimeNow(), held(model)
	else
		self.queued, self.queuedWith = nil, nil
	end
end

-- Every frame (after a flinch may have ended): a press kept from a moment ago starts now if it may, or is dropped once
-- older than Config.Attack.PressBuffer or when another weapon is held now (it was meant for the one before).
function OwnSwing.update(self: Swing, model: Model?)
	local queued = self.queued
	if not queued then
		return
	end
	if Workspace:GetServerTimeNow() - queued > Config.Attack.PressBuffer or held(model) ~= self.queuedWith or try(self, model) ~= "soon" then
		self.queued, self.queuedWith = nil, nil
	end
end

-- The server's word that the player's attack number `tag` (nil: not an attack, a blast) hit `victim`. Returns the
-- burst kind this client already showed on that victim for that attack - nil when it showed none (then show it now;
-- the attack's own showing skips the victim) - and whether it is the latest attack (the one drawn now).
function OwnSwing.serverHit(self: Swing, tag: number?, victim: Model): (string?, boolean)
	if tag == nil then
		return nil, false
	end
	local showing = self.showings[tag]
	if not showing then
		return nil, false -- an attack too long ago to know what was shown
	end
	local kind = showing.shown[victim]
	if not kind then
		showing.confirmed[victim] = true
	end
	return kind, tag == self.count
end

-- The player was hit: the string is broken (the next attack is a 1, as on the server), and words on the attacks
-- pressed before it leave the string alone.
function OwnSwing.broken(self: Swing)
	if self.chain.step > 0 and AttackString.next(self.chain, STRING, Workspace:GetServerTimeNow()) > 1 then
		self.breaks += 1 -- it was running: the screen shows the break
	end
	AttackString.reset(self.chain)
	self.cut = self.count
	self.queued, self.queuedWith = nil, nil -- a press kept from before the hit is not made after it
end

-- The server's step for the player's attack number `tag` (Names.SwingStep): when that is the latest attack and the
-- server counted differently (it dropped an attack, or the network shook more than its slack), this client counts on
-- from the server's step and redraws the attack as that step. (An older attack's word, arriving after the next
-- press, is left alone.)
function OwnSwing.settle(self: Swing, tag: number, step: number)
	if not current(self, tag) or step == self.chain.step then
		return
	end
	self.chain.step = step
	local model, weapon = self.model, self.weapon
	if model and weapon then
		self.hooks.restep(model, self.last, weapon, step)
	end
end

-- The player's string as it stands at server time `now`, for the screen (StringHud.View): the last step taken, when
-- its weapon is ready again, whether a press now goes on with it (not with another weapon in hand than the string's:
-- that starts over), and how many running strings a hit has broken. `holding`: the weapon held now.
function OwnSwing.stringView(self: Swing, now: number, holding: string): { step: number, ready: number, live: boolean, breaks: number }
	local chain = self.chain
	local live = holding == self.weapon and AttackString.next(chain, STRING, now) > 1
	return { step = chain.step, ready = chain.ready, live = live, breaks = self.breaks }
end

-- Whether attack number `tag` of the player's character (Names.SwingTag) was drawn when pressed (every one this
-- client numbered was).
function OwnSwing.drawn(self: Swing, tag: number): boolean
	return tag >= 1 and tag <= self.count
end

return OwnSwing
