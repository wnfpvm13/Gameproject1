--!strict
-- Finding the parts of a character (players' and sandbags', R15 or R6) that the brawl needs: its root and Humanoid,
-- the hand that holds a weapon and where in it the weapon is gripped, the joints the drawn poses turn (R15) and their
-- frames, and how high its feet are. Requires nothing.

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

-- The hand (R15) or arm (R6) that holds a weapon.
function CharacterParts.weaponHand(model: Model): BasePart?
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	return if hand and hand:IsA("BasePart") then hand else nil
end

-- Where a weapon is gripped, in the hand's own space: in the fist, tipped 15 degrees down, its length along -Z (ahead
-- of the fist). WeaponGear puts weapons there; SwingPose finds a two-handed weapon's second grip from it.
function CharacterParts.grip(hand: BasePart): CFrame
	return CFrame.new(0, -hand.Size.Y * 0.3, 0) * CFrame.Angles(math.rad(-15), 0, 0)
end

-- Each R15 joint the drawn poses turn, by name, and the part that holds it.
local JOINT_PARTS: { [string]: string } = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftKnee = "LeftLowerLeg",
	RightWrist = "RightHand",
	LeftWrist = "LeftHand",
}

-- The R15 joints of a character found by name (a Motor6D on older rigs, an AnimationConstraint on characters with
-- Roblox's newer avatar joints: both have Transform); missing ones are left out (an R6 body has none of them).
function CharacterParts.joints(model: Model): { [string]: Joint }
	local found: { [string]: Joint } = {}
	for name, partName in JOINT_PARTS do
		local part = model:FindFirstChild(partName)
		local joint = part and part:FindFirstChild(name)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			found[name] = joint :: any
		end
	end
	return found
end

-- A joint's two frames: where it sits in the part it hangs from and in the part it moves (a Motor6D's C0 and C1, an
-- AnimationConstraint's attachments); the moved part is at from * C0 * Transform * C1:Inverse(). nil when an
-- attachment is missing.
function CharacterParts.frames(joint: Joint): (CFrame?, CFrame?)
	if joint:IsA("Motor6D") then
		return joint.C0, joint.C1
	end
	local constraint = joint :: AnimationConstraint
	local a0, a1 = constraint.Attachment0, constraint.Attachment1
	if a0 and a1 then
		return a0.CFrame, a1.CFrame
	end
	return nil, nil
end

-- The feet's height (world Y). An R6 HipHeight leaves out its 2-stud legs; an R15 one includes them.
function CharacterParts.feetY(body: Body): number
	local legs = if body.humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	return body.root.Position.Y - body.root.Size.Y / 2 - body.humanoid.HipHeight - legs
end

return CharacterParts
