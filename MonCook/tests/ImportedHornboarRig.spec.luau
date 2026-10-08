--!strict
local Rig = require(script.Parent.Parent.src.shared.Utilities.ImportedHornboarRig)

return function(): number
	local passed = 0
	local function check(callback: () -> ()) callback(); passed += 1 end
	check(function() assert(Rig.partBinding("RootPart") == "Root") end)
	check(function() assert(Rig.partBinding("Horn_Intact") == "HornIntact") end)
	check(function() assert(Rig.partBinding("Horn_Broken") == "HornBroken") end)
	check(function() assert(Rig.partBinding("Torso") == nil) end)
	check(function() assert(Rig.jointSemantic("TorsoMotor6D", "Torso") == "Spine") end)
	check(function() assert(Rig.jointSemantic("FrontLeg_L_UpperMotor6D", "FrontLeg_L_Upper") == "FrontLeg_L") end)
	check(function() assert(Rig.jointSemantic("BackShin_R_LowerMotor6D", nil) == "BackShin_R") end)
	check(function()
		local required = Rig.requiredImportedParts()
		assert(table.find(required, "RootPart") and table.find(required, "Horn_Intact") and table.find(required, "Horn_Broken"))
	end)
	return passed
end
