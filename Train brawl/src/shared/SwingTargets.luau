--!strict
-- Who a swing hits: every other fighter whose middle is in the cone in front of the swinger (BatMath.inCone with
-- Config.Bat's height and angle, and the reach given). The server judges with it (reach plus the network slack,
-- BatService) and the swinger's own client shows its hits at once with it (plain reach, OwnSwing).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local BatMath = require(shared:WaitForChild("BatMath"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local SwingTargets = {}

-- The bodies of the fighters a swing by `swinger` (its body) hits right now.
function SwingTargets.find(swinger: CharacterParts.Body, fighters: { Model }, reach: number): { CharacterParts.Body }
	local b = Config.Bat
	local from, facing = swinger.root.Position, swinger.root.CFrame.LookVector
	local hit = {}
	for _, model in fighters do
		local target = if model ~= swinger.model then CharacterParts.body(model) else nil
		if target then
			local at = target.root.Position
			if BatMath.inCone(from.X, from.Y, from.Z, facing.X, facing.Z, at.X, at.Y, at.Z, reach, b.HeightReach, b.HalfAngle) then
				table.insert(hit, target)
			end
		end
	end
	return hit
end

return SwingTargets
