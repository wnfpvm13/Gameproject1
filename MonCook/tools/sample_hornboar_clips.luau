local Motion = require("../src/shared/Utilities/HuntingAnimation")
local Config = require("../src/shared/Config/HuntingConfig").Monster.Hornboar
local function json(value)
	if type(value)=="number" then return tostring(value) end
	if type(value)=="string" then return string.format("%q",value) end
	local entries={};for k,v in value do table.insert(entries,json(tostring(k))..":"..json(v)) end;table.sort(entries)
	return "{"..table.concat(entries,",").."}"
end
local specs={
	Idle={State="Idle",Duration=2.8},Walk={State="Roam",Duration=1},Run={State="Chase",Duration=3/Config.MoveSpeed},
	Headbutt={State="Attack",Attack="Headbutt",Duration=Config.Attacks.Headbutt.Duration},
	ChargeTelegraph={State="Windup",Attack="Charge",Duration=Config.Attacks.Charge.Windup},
	Charge={State="Attack",Attack="Charge",Duration=Config.Attacks.Charge.Duration},
	Recovery={State="Recover",Attack="Charge",Duration=Config.Attacks.Charge.Recover},
	Hit={State="Idle",Reaction="LightHit",Duration=.19},HornBreak={State="Stagger",Reaction="HornBreak",Duration=.55},
	Death={State="Dead",Duration=Config.DeathDespawnSeconds},
}
local clips={}
for name,spec in specs do
	local frames={}
	for frame=0,math.ceil(spec.Duration*60) do
		local at=math.min(frame/60,spec.Duration)
		local speed=if name=="Walk" then Config.RoamSpeed elseif name=="Run" then Config.MoveSpeed elseif name=="Charge" then Config.Attacks.Charge.Speed else 0
		frames[tostring(frame)]=Motion.monster(spec.State,spec.Attack,at,at,if spec.Reaction then at else 100,spec.Reaction,spec.Reaction=="HornBreak",at*speed/3*math.pi*2)
	end
	if name=="Idle" or name=="Walk" or name=="Run" then frames[tostring(math.ceil(spec.Duration*60))]=frames["0"] end
	clips[name]={Duration=spec.Duration,Frames=frames}
end
print(json(clips))
