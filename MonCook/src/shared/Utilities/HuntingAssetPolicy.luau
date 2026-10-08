--!strict
local Policy = {}
function Policy.ready(summary: any): (boolean, string?)
	if not summary or not summary.MarkedReady then return false, "Studio import acceptance pending" end
	if not summary.Root then return false, "RootPart missing" end
	if summary.Meshes < 4 or summary.Meshes > 7 then return false, "V2 requires 4-7 imported visual meshes" end
	if not summary.HornIntact or not summary.HornBroken then return false, "Horn variants missing" end
	for _, bone in { "Root", "Spine", "Neck", "Head", "FrontLeg_L", "FrontLeg_R", "BackLeg_L", "BackLeg_R",
		"FrontShin_L", "FrontShin_R", "BackShin_L", "BackShin_R", "Tail", "Horn" } do
		if not summary.Bones[bone] then return false, "Bone missing: "..bone end
	end
	return true, nil
end
return table.freeze(Policy)
