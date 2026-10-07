--!strict
local Policy = require(script.Parent.Parent.src.shared.Utilities.HuntingAssetPolicy)
local Rig = require(script.Parent.Parent.src.shared.Utilities.ImportedHornboarRig)
local Motion = require(script.Parent.Parent.src.shared.Utilities.HuntingAnimation)
return function(): number
	local count=0
	local function check(test: () -> ()) test();count+=1 end
	local function summary(): any
		local bones={};for _,name in {"Root","Spine","Neck","Head","FrontLeg_L","FrontLeg_R","BackLeg_L","BackLeg_R","FrontShin_L","FrontShin_R","BackShin_L","BackShin_R","Tail","Horn"} do bones[name]=true end
		return {MarkedReady=true,Root=true,Meshes=5,HornIntact=true,HornBroken=true,Bones=bones}
	end
	check(function() assert(Policy.ready(summary())) end)
	check(function() local s=summary();s.MarkedReady=false;assert(not Policy.ready(s)) end)
	check(function() local s=summary();s.Root=false;assert(not Policy.ready(s)) end)
	check(function() local s=summary();s.Bones.Head=nil;assert(not Policy.ready(s)) end)
	check(function() local s=summary();s.HornBroken=false;assert(not Policy.ready(s)) end)
	check(function() local s=summary();s.Meshes=32;assert(not Policy.ready(s)) end)
	check(function() assert(Rig.boneSemantic("Head")=="Head" and Rig.boneSemantic("BackShin_R")=="BackShin_R" and Rig.boneSemantic("Unknown")==nil) end)
	check(function() assert(Rig.partBinding("Horn_Broken.001")=="HornBroken" and Rig.partBinding("Horn_Intact_1")=="HornIntact") end)
	check(function()
		local a=Motion.monster("Windup","Charge",0,0,100)
		local b=Motion.monster("Windup","Charge",1.25,1.25,100)
		assert(a.Head.Pitch==0 and b.Head.Pitch<0 and b.Spine.Lift<-.2 and b.Neck.Pitch<0)
	end)
	check(function()
		local a=Motion.monster("Roam",nil,0,0,100,nil,false,0)
		local b=Motion.monster("Roam",nil,0,100,100,nil,false,0)
		assert(a.FrontLeg_L.Pitch==b.FrontLeg_L.Pitch and a.BackLeg_R.Pitch==b.BackLeg_R.Pitch)
		local c=Motion.monster("Roam",nil,0,0,100,nil,false,math.pi/2)
		assert(c.FrontLeg_L.Pitch~=a.FrontLeg_L.Pitch)
	end)
	return count
end
