--!strict
-- Who a punch or a swing hits: every other fighter whose middle is in the cone in front of the attacker
-- (BatMath.inCone with Config.Attack's height, and the weapon's reach and angle). The server judges with it (reach plus
-- the network slack, WeaponService) and the attacker's own client shows its hits at once with it (plain reach,
-- OwnSwing).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local BatMath = require(shared:WaitForChild("BatMath"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local SwingTargets = {}

-- The bodies of the fighters an attack by `swinger` (its body) hits right now: within `reach` and `halfAngle` degrees
-- either side of `facing` (default: where the swinger's root faces).
function SwingTargets.find(swinger: CharacterParts.Body, fighters: { Model }, reach: number, facing: Vector3?, halfAngle: number?): { CharacterParts.Body }
	local from = swinger.root.Position
	local aim = facing or swinger.root.CFrame.LookVector
	local hit = {}
	for _, model in fighters do
		local target = if model ~= swinger.model then CharacterParts.body(model) else nil
		if target then
			local at = target.root.Position
			if BatMath.inCone(from.X, from.Y, from.Z, aim.X, aim.Z, at.X, at.Y, at.Z, reach, Config.Attack.HeightReach, halfAngle or 60) then
				table.insert(hit, target)
			end
		end
	end
	return hit
end

return SwingTargets
