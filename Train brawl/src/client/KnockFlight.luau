--!strict
-- The player's own character, hit: a light hit flinches it (BodyMotion.stagger: no swinging, walking or jumping for its
-- stun - HitRules.stun - and never less than a stun still running);
-- a launch or smash sends it flying (BodyMotion.launch), back on its feet once it has landed (BodyMotion.landed). The
-- player's client moves its own character, so the server sends the hit here (WeaponService) instead of applying it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local BodyMotion = require(shared:WaitForChild("BodyMotion"))

local KnockFlight = {}
KnockFlight.__index = KnockFlight

-- flying: launched (lying down until it lands) rather than flinching; stunUntil: when a flinch's stun ends (os.clock).
type Fields = { body: CharacterParts.Body?, since: number?, flying: boolean, stunUntil: number }
export type Flight = typeof(setmetatable({} :: Fields, KnockFlight))

function KnockFlight.new(): Flight
	local fields: Fields = { body = nil, since = nil, flying = false, stunUntil = 0 }
	return setmetatable(fields, KnockFlight)
end

-- A hit of this kind ("light", "launch" or "smash") with this velocity on the character; `stun`: a light hit's stun.
function KnockFlight.hit(self: Flight, model: Model, velocity: Vector3, kind: string, stun: number)
	local body = CharacterParts.body(model)
	if not body then
		return
	end
	-- The server sends a light hit only after a launch's unhittable moment, so it always counts (even if this screen
	-- still shows the flight: it ends it).
	local launched = kind ~= "light"
	local now = os.clock()
	self.stunUntil = if launched then 0 elseif self.since and not self.flying then math.max(self.stunUntil, now + stun) else now + stun
	if launched then
		BodyMotion.launch(body, velocity, kind)
	else
		BodyMotion.stagger(body, velocity, self.stunUntil - now)
	end
	self.body = body
	self.since = now
	self.flying = launched
end

-- Whether the character is flinching or flying from a hit right now (no swinging then).
function KnockFlight.stunned(self: Flight): boolean
	return self.since ~= nil
end

-- Whether the character is flying from a launch right now (lying down).
function KnockFlight.launched(self: Flight): boolean
	return self.since ~= nil and self.flying
end

-- Every frame: a flinch ends after its stun; a flight once landed.
function KnockFlight.update(self: Flight)
	local body, since = self.body, self.since
	if not (body and since) then
		return
	end
	local elapsed = os.clock() - since
	-- Taken to the stands mid-flight (a home run): stop there instead of sliding on with the flight's speed.
	local inStands = body.root.Position.Y > Config.Arena.WaitingRoomHeight - Config.Arena.StandsMargin
	if inStands then
		body.root.AssemblyLinearVelocity = Vector3.zero
	end
	local over = inStands or (if self.flying then BodyMotion.landed(body, elapsed) else os.clock() >= self.stunUntil)
	if not body.model.Parent or over then
		local wasFlying = self.flying
		self.since = nil
		self.body = nil
		self.flying = false
		if body.model.Parent and wasFlying then
			BodyMotion.getUp(body)
		end
	end
end

return KnockFlight
