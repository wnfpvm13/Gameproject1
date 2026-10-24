--!strict
-- The player's own fall off the trains, shown as missing the train: while the feet are below the fall line, the
-- player's client lays its own character down and slides it backward with the ground (BodyMotion.drift): it lands on
-- the sand and is left behind (every client sees it, as the character's movement is the player's). That lasts until
-- the server takes it to the stands, far above; then it gets up there.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local BodyMotion = require(shared:WaitForChild("BodyMotion"))

local FallDrift = {}
FallDrift.__index = FallDrift

type Fields = { fallLine: number, drifting: CharacterParts.Body? }
export type Drift = typeof(setmetatable({} :: Fields, FallDrift))

function FallDrift.new(fallLine: number): Drift
	local fields: Fields = { fallLine = fallLine, drifting = nil }
	return setmetatable(fields, FallDrift)
end

-- Whether the player's character is lying behind the train right now (fallen, not yet in the stands).
function FallDrift.active(self: Drift): boolean
	return self.drifting ~= nil
end

-- Every frame (after KnockFlight, so the fall wins over getting up), for the player's own character (nil = none).
-- knocked: the character is still flying from a knock (KnockFlight gets it up when it lands, not this).
function FallDrift.update(self: Drift, model: Model?, knocked: boolean)
	local body = CharacterParts.body(model)
	local was = self.drifting
	if body and CharacterParts.feetY(body) < self.fallLine then
		self.drifting = body
		BodyMotion.drift(body)
	elseif was then
		self.drifting = nil
		if was.model.Parent and not knocked then
			BodyMotion.getUp(was)
		end
	end
end

return FallDrift
