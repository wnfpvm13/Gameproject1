--!strict
-- Readable temporary poses; no uploaded animation IDs are needed for native V1 rigs.
local Animation = {}
function Animation.monster(state: string, attackType: string?, elapsed: number, phase: number, hitAge: number): any
	local pose: any = { Spine = { Pitch = 0, Yaw = 0, Roll = 0, Lift = 0 }, Head = { Pitch = 0, Yaw = 0, Roll = 0, Lift = 0 },
		FrontLeg_L = { Pitch = 0 }, FrontLeg_R = { Pitch = 0 }, BackLeg_L = { Pitch = 0 }, BackLeg_R = { Pitch = 0 } }
	local moving = state == "Roam" or state == "Chase" or (state == "Attack" and attackType == "Charge")
	if moving then
		local stride = math.sin(phase*(if state == "Roam" then 7 else 15))*(if state == "Roam" then 0.38 else 0.65)
		pose.FrontLeg_L.Pitch, pose.BackLeg_R.Pitch = stride, stride
		pose.FrontLeg_R.Pitch, pose.BackLeg_L.Pitch = -stride, -stride
		pose.Spine.Lift = math.abs(math.sin(phase*12))*0.10
	elseif state == "Idle" then pose.Spine.Lift = math.sin(phase*2.2)*0.045 end
	if state == "Alert" then pose.Head.Pitch = -0.20
	elseif state == "Windup" then pose.Head.Pitch, pose.Spine.Pitch = 0.28, 0.10
	elseif state == "Attack" and attackType == "Headbutt" then pose.Head.Pitch = -math.sin(math.min(elapsed/0.3, 1)*math.pi)*0.5
	elseif state == "Attack" then pose.Head.Pitch, pose.Spine.Pitch = 0.17, 0.05
	elseif state == "Recover" then pose.Head.Pitch = 0.14
	elseif state == "Stagger" then pose.Spine.Roll = math.sin(elapsed*23)*0.18
	elseif state == "Dead" then
		pose.Spine.Roll, pose.Spine.Lift = math.min(elapsed/0.4, 1)*1.2, -math.min(elapsed/0.4, 1)*1.0
		pose.Head.Pitch = 0.30
	end
	if state ~= "Dead" and hitAge >= 0 and hitAge < 0.16 then pose.Spine.Roll += math.sin(hitAge/0.16*math.pi)*0.12 end
	return pose
end
function Animation.weapon(attackType: string?, combo: number, elapsed: number, duration: number): any
	if not attackType or attackType == "Dodge" or elapsed < 0 or elapsed > duration or duration <= 0 then return { Pitch = 0, Yaw = 0, Roll = 0 } end
	local t = math.clamp(elapsed/duration, 0, 1)
	local stroke = math.sin(t*math.pi)
	return if attackType == "Heavy" then { Pitch = -stroke*1.25, Yaw = 0, Roll = -stroke*0.25 }
		else { Pitch = -stroke*0.35, Yaw = stroke*(if combo%2 == 0 then -1 else 1)*0.85, Roll = stroke*0.35 }
end
return table.freeze(Animation)
