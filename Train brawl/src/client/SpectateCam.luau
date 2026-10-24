--!strict
-- Watching after being knocked out: while a fight runs and the player is out, the camera follows a fighter still on
-- the trains (the next one when that one falls); otherwise it follows the player's own character.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local SpectateCam = {}
SpectateCam.__index = SpectateCam

type Fields = { watching: Model? }
export type Cam = typeof(setmetatable({} :: Fields, SpectateCam))

function SpectateCam.new(): Cam
	local fields: Fields = { watching = nil }
	return setmetatable(fields, SpectateCam)
end

-- Every frame. watch: whether to watch others now; own: the player's character; fighters: models still in the round.
function SpectateCam.update(self: Cam, watch: boolean, own: Model?, fighters: { Model })
	local camera = Workspace.CurrentCamera
	local target: Model? = nil
	if watch then
		local current = self.watching
		if current and current.Parent and current:GetAttribute(Names.Alive) == true then
			target = current
		else
			target = fighters[1]
		end
	end
	self.watching = target
	local subject = CharacterParts.body(target or own)
	if subject and camera.CameraSubject ~= subject.humanoid then
		camera.CameraSubject = subject.humanoid
	end
end

return SpectateCam
