--!strict
-- Finding the parts of a character (players' and sandbags', R15 or R6) that the brawl needs: its root and Humanoid,
-- the hand that holds the bat, the shoulder joint that swings it, and how high its feet are. Requires nothing.

local CharacterParts = {}

export type Body = { model: Model, root: BasePart, humanoid: Humanoid }
export type Joint = Motor6D | AnimationConstraint

-- The root part and Humanoid of a character, or nil while it is incomplete.
function CharacterParts.body(model: Model?): Body?
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		return { model = model, root = root, humanoid = humanoid }
	end
	return nil
end

-- The hand (R15) or arm (R6) that holds the bat.
function CharacterParts.batHand(model: Model): BasePart?
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	return if hand and hand:IsA("BasePart") then hand else nil
end

-- The right shoulder joint, which swings the bat: a Motor6D on older rigs, an AnimationConstraint on characters with
-- Roblox's newer avatar joints (both have Transform).
function CharacterParts.shoulder(model: Model): Joint?
	local upper = model:FindFirstChild("RightUpperArm")
	local joint = upper and upper:FindFirstChild("RightShoulder")
	if not joint then
		local torso = model:FindFirstChild("Torso")
		joint = torso and torso:FindFirstChild("Right Shoulder")
	end
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
		return joint :: any
	end
	return nil
end

-- The feet's height (world Y). An R6 HipHeight leaves out its 2-stud legs; an R15 one includes them.
function CharacterParts.feetY(body: Body): number
	local legs = if body.humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	return body.root.Position.Y - body.root.Size.Y / 2 - body.humanoid.HipHeight - legs
end

return CharacterParts
