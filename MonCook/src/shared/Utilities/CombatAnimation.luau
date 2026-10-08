--!strict
-- Canonical full-body deltas and authored clip sampling. Server timing owns every phase.
local Animation = {}
local names = { "RootJoint", "Waist", "Neck", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "Grip",
	"RightHip", "LeftHip", "RightKnee", "LeftKnee", "RightAnkle", "LeftAnkle" }
local fields = { "Pitch", "Yaw", "Roll", "X", "Y", "Z" }
local function neutral(): any
	local result = {}; for _, name in names do result[name] = {} end; return result
end
local function blend(a: any, b: any, t: number): any
	local result = neutral()
	t = math.clamp(t, 0, 1); t = t*t*(3-2*t)
	for _, name in names do
		for _, field in fields do result[name][field] = (a[name][field] or 0)*(1-t)+(b[name][field] or 0)*t end
	end
	return result
end
function Animation.phase(elapsed: number, windup: number, window: number, recovery: number): (string, number)
	if elapsed < 0 or elapsed >= windup+window+recovery then return "None", 0 end
	if elapsed < windup then return "Windup", elapsed/windup end
	if elapsed <= windup+window then return "Hit", (elapsed-windup)/window end
	return "Recover", (elapsed-windup-window)/recovery
end
function Animation.player(kind: string?, combo: number, elapsed: number, windup: number, window: number, recovery: number): any
	local base = neutral()
	if not kind then return base end
	if kind == "Dodge" then
		local weight = if elapsed >= 0 and elapsed < windup then math.sin(elapsed/windup*math.pi) else 0
		base.RootJoint = { Pitch = weight*0.32, Y = -weight*0.17 }
		base.Waist, base.RightShoulder, base.LeftShoulder = { Pitch = weight*0.28 }, { Pitch = -weight*0.45 }, { Pitch = -weight*0.45 }
		base.RightHip, base.LeftHip = { Pitch = -weight*0.70 }, { Pitch = -weight*0.48 }
		base.RightKnee, base.LeftKnee = { Pitch = weight*0.90 }, { Pitch = weight*0.72 }
		base.RightAnkle, base.LeftAnkle = { Pitch = -weight*0.22 }, { Pitch = -weight*0.20 }
		return base
	end
	local phase, t = Animation.phase(elapsed, windup, window, recovery)
	if phase == "None" then return base end
	local prep, impact, finish = neutral(), neutral(), neutral()
	local overhead = kind == "Heavy" or combo == 3
	local direction = if combo == 2 then -1 else 1
	prep.RootJoint, prep.Waist = { Yaw = -direction*0.20, Pitch = -0.06, Z = 0.08 }, { Yaw = -direction*0.42, Pitch = -0.12 }
	prep.Neck = { Yaw = direction*0.30 }
	prep.RightShoulder = if overhead then { Pitch = -1.55, Roll = 0.25 } else { Pitch = -0.70, Yaw = -direction*0.72, Roll = direction*0.45 }
	prep.RightElbow = { Pitch = -0.58 }; prep.RightWrist = { Yaw = -direction*0.25 }
	prep.LeftShoulder = if kind == "Heavy" then { Pitch = -1.20, Yaw = 0.35, Roll = -0.22 } else { Pitch = -0.20, Roll = -0.15 }
	prep.LeftElbow = { Pitch = if kind == "Heavy" then -0.55 else -0.22 }
	local weight = if kind == "Heavy" then 1 elseif combo == 3 then 0.8 else 0.35
	prep.RootJoint.Y = -0.22*weight
	prep.RightHip, prep.LeftHip = { Pitch = -0.28*weight, Yaw = -direction*0.12 }, { Pitch = -0.48*weight, Yaw = -direction*0.10 }
	prep.RightKnee, prep.LeftKnee = { Pitch = 0.38*weight }, { Pitch = 0.65*weight }
	prep.RightAnkle, prep.LeftAnkle = { Pitch = -0.10*weight }, { Pitch = -0.16*weight }
	impact.RootJoint, impact.Waist = { Yaw = direction*0.12, Pitch = 0.12, Z = -0.15 }, { Yaw = direction*0.25, Pitch = if overhead then 0.30 else 0.12 }
	impact.Neck = { Pitch = -0.08, Yaw = -direction*0.20 }
	impact.RightShoulder = { Pitch = -0.95, Yaw = direction*0.22, Roll = direction*0.08 }
	impact.RightElbow = { Pitch = -0.06 }
	impact.LeftShoulder = if kind == "Heavy" then { Pitch = -0.88, Yaw = 0.22 } else { Pitch = -0.15, Roll = -0.30 }
	impact.LeftElbow = { Pitch = -0.10 }
	impact.Grip = { Pitch = if overhead then 0.25 else 0.08, Yaw = direction*0.15 }
	impact.RootJoint.Y = -0.09*weight
	impact.RightHip, impact.LeftHip = { Pitch = -0.34*weight, Yaw = direction*0.12 }, { Pitch = 0.15*weight, Yaw = direction*0.08 }
	impact.RightKnee, impact.LeftKnee = { Pitch = 0.52*weight }, { Pitch = 0.12*weight }
	impact.RightAnkle, impact.LeftAnkle = { Pitch = -0.18*weight }, { Pitch = -0.04*weight }
	finish.RootJoint, finish.Waist = { Yaw = direction*0.28, Pitch = 0.10 }, { Yaw = direction*0.48, Pitch = if overhead then 0.30 else 0.08 }
	finish.Neck = { Yaw = -direction*0.34 }
	finish.RightShoulder = if overhead then { Pitch = -0.35, Roll = -0.15 } else { Pitch = -0.40, Yaw = direction*0.85, Roll = -direction*0.48 }
	finish.RightElbow = { Pitch = -0.18 }
	finish.LeftShoulder = if kind == "Heavy" then { Pitch = -0.48, Yaw = 0.35 } else { Pitch = -0.08, Roll = -0.20 }
	finish.Grip = { Pitch = if overhead then 0.42 else 0.12, Yaw = direction*0.30 }
	finish.RootJoint.Y, finish.RootJoint.Z = -0.12*weight, -0.20*weight
	finish.RightHip, finish.LeftHip = { Pitch = -0.38*weight }, { Pitch = 0.18*weight }
	finish.RightKnee, finish.LeftKnee = { Pitch = 0.58*weight }, { Pitch = 0.10*weight }
	finish.RightAnkle, finish.LeftAnkle = { Pitch = -0.17*weight }, { Pitch = -0.03*weight }
	if phase == "Windup" then return blend(base, prep, t)
	elseif phase == "Hit" then return if t <= 0.5 then blend(prep, impact, t*2) else blend(impact, finish, (t-0.5)*2)
	else return blend(finish, base, t) end
end
return table.freeze(Animation)
