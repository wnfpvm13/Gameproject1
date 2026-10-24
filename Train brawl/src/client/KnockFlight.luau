--!strict
-- The player's own character, knocked by a hit: held still a moment, then stiff and flying with the knock's velocity
-- (BodyMotion.launch), back on its feet once it has landed (BodyMotion.landed). The player's client moves its own
-- character, so the server sends the knock here (BatService) instead of applying it itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local BodyMotion = require(shared:WaitForChild("BodyMotion"))

local KnockFlight = {}
KnockFlight.__index = KnockFlight

type Fields = { body: CharacterParts.Body?, since: number? }
export type Flight = typeof(setmetatable({} :: Fields, KnockFlight))

function KnockFlight.new(): Flight
	local fields: Fields = { body = nil, since = nil }
	return setmetatable(fields, KnockFlight)
end

-- Knocks the character with this velocity.
function KnockFlight.knock(self: Flight, model: Model, velocity: Vector3)
	local body = CharacterParts.body(model)
	if not body then
		return
	end
	BodyMotion.launch(body, velocity)
	self.body = body
	self.since = os.clock()
end

-- Whether the character is flying from a knock right now.
function KnockFlight.flying(self: Flight): boolean
	return self.since ~= nil
end

-- Every frame: back on the feet once landed.
function KnockFlight.update(self: Flight)
	local body, since = self.body, self.since
	if not (body and since) then
		return
	end
	if not body.model.Parent or BodyMotion.landed(body, os.clock() - since) then
		self.since = nil
		self.body = nil
		if body.model.Parent then
			BodyMotion.getUp(body)
		end
	end
end

return KnockFlight
