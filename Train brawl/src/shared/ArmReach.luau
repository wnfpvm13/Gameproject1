--!strict
-- Puts a hand on a point by turning its arm's shoulder and elbow: a two-joint reach worked out in the upper torso's
-- space from the joints' own frames (CharacterParts.frames), the wrist left straight. SwingPose keeps the free hand on
-- a two-handed weapon's handle with it (the drawn poses turn only the weapon arm). Requires nothing.

local ArmReach = {}

-- An arm's joint frames: each joint's frame in the part it hangs from (0) and in the part it moves (1).
export type Arm = {
	shoulder0: CFrame,
	shoulder1: CFrame,
	elbow0: CFrame,
	elbow1: CFrame,
	wrist0: CFrame,
	wrist1: CFrame,
}

local MOST_BEND = math.rad(150)
local SIDE_BEND = math.rad(90) -- the bend the elbow's side is read at (a straight arm has its elbow on the line)

-- The hand's middle in the upper arm's space with the elbow bent `bend` radians (about its own X, as R15 elbows bend).
local function handAt(arm: Arm, bend: number): Vector3
	return (arm.elbow0 * CFrame.Angles(bend, 0, 0) * arm.elbow1:Inverse() * arm.wrist0 * arm.wrist1:Inverse()).Position
end

-- The part of `v` square to the unit vector `along`.
local function across(v: Vector3, along: Vector3): Vector3
	return v - along * v:Dot(along)
end

-- A unit vector square to the unit vector `along`, as near `want` as can be (any one when `want` lies along it).
local function squareTo(along: Vector3, want: Vector3): Vector3
	for _, try in { want, Vector3.xAxis, Vector3.zAxis } do
		local v = across(try, along)
		if v.Magnitude > 1e-4 then
			return v.Unit
		end
	end
	return Vector3.yAxis -- not reached: x and z cannot both lie along one line
end

-- The shoulder and elbow Transforms that put the hand's middle at `target` (in the upper torso's space), the elbow
-- bending toward `pole` (a direction in the same space; down and out for a hand held in front). A target out of
-- reach is reached for as far as the arm goes.
function ArmReach.solve(arm: Arm, target: Vector3, pole: Vector3): (CFrame, CFrame)
	-- Both seen from the shoulder joint: the target in its frame on the torso, the arm in its frame on the upper arm
	-- (the joint turns the one into the other about their shared middle).
	local want = arm.shoulder0:PointToObjectSpace(target)
	local wantPole = arm.shoulder0:VectorToObjectSpace(pole)
	local distance = want.Magnitude
	local function reach(bend: number): number
		return arm.shoulder1:PointToObjectSpace(handAt(arm, bend)).Magnitude
	end
	-- How far the elbow bends for that distance (the reach shrinks as it bends): halved until close.
	local lo, hi = 0, MOST_BEND
	if distance >= reach(0) then
		hi = 0
	elseif distance <= reach(MOST_BEND) then
		lo = MOST_BEND
	else
		for _ = 1, 20 do
			local mid = (lo + hi) / 2
			if reach(mid) > distance then
				lo = mid
			else
				hi = mid
			end
		end
	end
	local bend = (lo + hi) / 2
	local elbow = CFrame.Angles(bend, 0, 0)
	if distance < 1e-3 then
		return CFrame.identity, elbow
	end
	-- The arm as it is with that bend: the line to the hand and the elbow's hinge (its X) square to it.
	local hinge = arm.shoulder1:VectorToObjectSpace(arm.elbow0.RightVector)
	local elbowAt = arm.shoulder1:PointToObjectSpace(arm.elbow0.Position)
	local a1 = arm.shoulder1:PointToObjectSpace(handAt(arm, bend)).Unit
	local c1 = squareTo(a1, hinge)
	-- Which side of the line the elbow sits on, across both the line and the hinge: read with the elbow well bent (the
	-- side an elbow bends to is the arm's own; read straight, the elbow is on the line and the sign would flip).
	local bentLine = arm.shoulder1:PointToObjectSpace(handAt(arm, SIDE_BEND)).Unit
	local side = squareTo(bentLine, hinge):Cross(bentLine):Dot(elbowAt)
	-- Turned onto the target, the hinge square to the plane of the line and the pole, the elbow on the pole's side (a
	-- pole along the line: the hinge kept as near as it lies).
	local a2 = want.Unit
	local c2 = squareTo(a2, a2:Cross(wantPole))
	if a2:Cross(wantPole).Magnitude < 1e-4 then
		c2 = squareTo(a2, c1)
	end
	if (c2:Cross(a2):Dot(wantPole) > 0) ~= (side > 0) then
		c2 = -c2
	end
	local from = CFrame.fromMatrix(Vector3.zero, a1, c1:Cross(a1), c1)
	local to = CFrame.fromMatrix(Vector3.zero, a2, c2:Cross(a2), c2)
	return to * from:Inverse(), elbow
end

return ArmReach
