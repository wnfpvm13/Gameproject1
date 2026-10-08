--!strict
-- Readable temporary poses; no uploaded animation IDs are needed for native V1 rigs.
local Animation = {}
local Config = require(script.Parent.Parent.Config.HuntingConfig).Monster.Hornboar
function Animation.monster(state: string, attackType: string?, elapsed: number, phase: number, hitAge: number, hitKind: string?, heavy: boolean?, movementPhase: number?): any
	local pose: any = { Spine = { Pitch = 0, Yaw = 0, Roll = 0, Lift = 0 }, Head = { Pitch = 0, Yaw = 0, Roll = 0, Lift = 0 },
		Root = {}, Neck = {}, Horn = {}, Tail = { Yaw = math.sin(phase*2)*.05 },
		FrontShin_L = {}, FrontShin_R = {}, BackShin_L = {}, BackShin_R = {},
		FrontLeg_L = { Pitch = 0 }, FrontLeg_R = { Pitch = 0 }, BackLeg_L = { Pitch = 0 }, BackLeg_R = { Pitch = 0 } }
	local moving = state == "Roam" or state == "Chase" or (state == "Attack" and attackType == "Charge")
	if moving then
		local slow = state == "Roam"
		local cycle = movementPhase or phase*(if slow then 7 else 15)
		local offsets: { [string]: number } = if slow then { FrontLeg_L = 0, BackLeg_R = math.pi/2, FrontLeg_R = math.pi, BackLeg_L = math.pi*1.5 }
			else { FrontLeg_L = 0, BackLeg_R = 0, FrontLeg_R = math.pi, BackLeg_L = math.pi }
		for name, offset in offsets do
			local swing = math.sin(cycle+offset)
			pose[name].Pitch = swing*(if slow then .48 else .65)
			local shin = string.gsub(name,"Leg_","Shin_")
			pose[shin] = { Pitch = -pose[name].Pitch*.4+math.max(0,swing)*.32 }
		end
		-- Preserve exact opposing foreleg values across platforms (avoid sin(t+pi) rounding).
		pose.FrontLeg_R.Pitch = -pose.FrontLeg_L.Pitch
		pose.Spine.Lift = math.abs(math.sin(cycle))*0.10
	elseif state == "Idle" then
		pose.Spine.Lift = math.sin(phase*2.2)*0.045
		pose.Neck.Pitch, pose.Head.Yaw = math.sin(phase*1.7)*.025, math.sin(phase*.8)*.045
	end
	if state == "Alert" then pose.Head.Pitch = -0.20
	elseif state == "Windup" then
		local attack = Config.Attacks[attackType or "Headbutt"]
		local lower = math.clamp(elapsed/attack.Windup,0,1)
		pose.Head.Pitch, pose.Spine.Pitch, pose.Spine.Lift = -0.28*lower, -0.10*lower, -0.22*lower
		pose.Neck.Pitch = if attackType == "Charge" then -.14*lower else -.04*lower
		pose.FrontLeg_L.Pitch = math.sin(elapsed*18)*0.12
		pose.FrontShin_L.Pitch, pose.FrontShin_R.Pitch = .25*lower, .25*lower
	elseif state == "Attack" and attackType == "Headbutt" then pose.Head.Pitch = -math.sin(math.min(elapsed/Config.Attacks.Headbutt.Duration, 1)*math.pi)*0.5
	elseif state == "Attack" then pose.Head.Pitch, pose.Spine.Pitch = -0.17, -0.05
	elseif state == "Recover" then
		local attack = Config.Attacks[attackType or "Headbutt"]
		pose.Head.Pitch = 0.14*(1-math.clamp(elapsed/attack.Recover,0,1))
	elseif state == "Stagger" then pose.Spine.Roll = math.sin(elapsed*23)*0.18
	elseif state == "Dead" then
		pose.Spine.Roll, pose.Spine.Lift = math.min(elapsed/0.4, 1)*1.2, -math.min(elapsed/0.4, 1)*1.0
		pose.Head.Pitch = 0.30
		for _, prefix in { "Front", "Back" } do
			pose[prefix.."Leg_L"].Pitch, pose[prefix.."Leg_R"].Pitch = -.35, -.35
			pose[prefix.."Shin_L"].Pitch, pose[prefix.."Shin_R"].Pitch = .50, .50
		end
	end
	if state ~= "Dead" then
		local duration = if hitKind == "HornBreak" then 0.55 elseif heavy then 0.32 else 0.19
		if hitAge >= 0 and hitAge < duration then
			local recoil = math.sin(hitAge/duration*math.pi)
			local strong = heavy or hitKind == "HornBreak"
			pose.Spine.Roll += recoil*(if strong then 0.25 else 0.14)
			pose.Spine.Pitch += recoil*(if strong then -0.14 else -0.04)
			pose.Spine.Lift += recoil*(if strong then -0.16 else -0.025)
			pose.Head.Pitch += recoil*(if hitKind == "HornBreak" then -0.65 elseif hitKind == "HornHit" then -0.38 else -0.16)
			pose.Head.Yaw += recoil*(if hitKind == "HornHit" then 0.16 else 0.09)
		end
	end
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
