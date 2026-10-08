--!strict
-- Semantic mapping for the Studio-imported Hornboar rigid rig.
-- The imported FBX is a MeshPart + Motor6D custom rig, not a runtime EditableMesh.
local Rig = {}

local JOINT_BY_PART: { [string]: string } = {
	Torso = "Spine",
	Head = "Head",
	FrontLeg_L_Upper = "FrontLeg_L",
	FrontLeg_R_Upper = "FrontLeg_R",
	FrontShin_L_Lower = "FrontShin_L",
	FrontShin_R_Lower = "FrontShin_R",
	BackLeg_L_Upper = "BackLeg_L",
	BackLeg_R_Upper = "BackLeg_R",
	BackShin_L_Lower = "BackShin_L",
	BackShin_R_Lower = "BackShin_R",
	Tail = "Tail",
}

function Rig.partBinding(name: string): string?
	if name == "RootPart" then return "Root" end
	if name == "Horn_Intact" or string.match(name, "^Horn_Intact[_.]%d+$") then return "HornIntact" end
	if name == "Horn_Broken" or string.match(name, "^Horn_Broken[_.]%d+$") then return "HornBroken" end
	return nil
end

function Rig.jointSemantic(motorName: string, parentName: string?): string?
	local byParent = parentName and JOINT_BY_PART[parentName]
	if byParent then return byParent end
	local base = string.gsub(motorName, "Motor6D$", "")
	return JOINT_BY_PART[base]
end

function Rig.requiredImportedParts(): { string }
	return {
		"RootPart", "Torso", "Head",
		"FrontLeg_L_Upper", "FrontLeg_R_Upper",
		"FrontShin_L_Lower", "FrontShin_R_Lower",
		"BackLeg_L_Upper", "BackLeg_R_Upper",
		"BackShin_L_Lower", "BackShin_R_Lower",
		"Horn_Intact", "Horn_Broken", "Tail",
	}
end

-- V2 uses a compact skinned rig. Bones and legacy Motor6Ds share pose semantics.
function Rig.boneSemantic(name: string): string?
	if name == "Torso" or name == "Spine" then return "Spine" end
	if name == "Root" or name == "Neck" or name == "Head" or name == "Tail" or name == "Horn" then return name end
	for _, prefix in { "FrontLeg_", "BackLeg_", "FrontShin_", "BackShin_" } do
		if name == prefix.."L" or name == prefix.."R" then return name end
	end
	return nil
end

return table.freeze(Rig)
