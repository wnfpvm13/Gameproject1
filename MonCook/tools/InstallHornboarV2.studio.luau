-- Run in Studio's EDIT-mode Command Bar after importing/uploading the V2 FBX.
-- Select the imported Model. Review this script before pasting it; it clones
-- the selection and refuses to overwrite an existing V2 template.
local Selection = game:GetService("Selection")
local storage = game:GetService("ReplicatedStorage")
local selected = Selection:Get()
assert(#selected==1 and selected[1]:IsA("Model"), "Select exactly one uploaded V2 FBX model")
local target = storage:WaitForChild("Assets"):WaitForChild("Monsters")
assert(not target:FindFirstChild("MON_Hornboar_V2"), "V2 exists: inspect it before replacing")
local model = selected[1]:Clone()
model.Name = "MON_Hornboar_V2"
local rootBone: Bone? = nil
local meshes = {}
for _, object in model:GetDescendants() do
	if object:IsA("MeshPart") then table.insert(meshes, object)
	elseif object:IsA("Bone") and object.Name=="Root" then rootBone=object end
end
assert(#meshes>=4 and #meshes<=7 and rootBone, "Require compact skinned V2 (4-7 meshes and Root Bone)")
for _, part in meshes do assert(part.MeshId~="", "Mesh upload missing: "..part.Name) end
local existingRoot = model:FindFirstChild("RootPart")
local root = if existingRoot and existingRoot:IsA("BasePart") then existingRoot else Instance.new("Part")
if not existingRoot then root.Name, root.Size, root.CFrame = "RootPart", Vector3.new(.2,.2,.2), (rootBone :: Bone).WorldCFrame end
root.Anchored, root.Transparency, root.CanCollide, root.CanTouch, root.CanQuery = true, 1, false, false, false
root.Parent, model.PrimaryPart = model, root
local function tag(object: Instance, value: string)
	local binding = object:FindFirstChild("Binding") or Instance.new("StringValue")
	assert(binding:IsA("StringValue")); binding.Name, binding.Value, binding.Parent = "Binding", value, object
end
tag(root,"Root")
local intact, broken = 0, 0
local attached = {}
for _, object in model:GetDescendants() do
	if object:IsA("JointInstance") and object.Part0 and object.Part1 then attached[object.Part1] = true
	elseif object:IsA("WeldConstraint") and object.Part0 and object.Part1 then attached[object.Part1] = true end
end
for _, part in meshes do
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false,false,false,false,true
	local binding = if string.match(part.Name,"^Horn_Intact") then "HornIntact"
		elseif string.match(part.Name,"^Horn_Broken") then "HornBroken" else "Visual"
	tag(part,binding)
	if binding=="HornIntact" then intact+=1 elseif binding=="HornBroken" then broken+=1 end
	part.Transparency=if binding=="HornBroken" then 1 else 0
	if not attached[part] then
		local weld=Instance.new("WeldConstraint"); weld.Name="VisualRootWeld"
		weld.Part0,weld.Part1,weld.Parent=root,part,part
	end
end
assert(intact>0 and broken>0,"Imported horn names must preserve intact/broken variants")
local policy=require(storage.Shared.Utilities.HuntingAssetPolicy)
local bones={};for _,object in model:GetDescendants() do if object:IsA("Bone") then bones[object.Name]=true end end
local ready,reason=policy.ready({MarkedReady=true,Root=true,Meshes=#meshes,HornIntact=intact>0,HornBroken=broken>0,Bones=bones})
assert(ready,reason)
-- Bind only after structural checks. Appearance/animation acceptance is still manual.
model:SetAttribute("HornboarV2Ready",true)
model:SetAttribute("SourceTriangles",2966)
model:SetAttribute("StudioVisualQA","Pending")
model:PivotTo(CFrame.new(0,0,0))
model.Parent=target
Selection:Set({model})
print("Installed V2 runtime candidate. Save this model as art/runtime/Monsters/MON_Hornboar_V2.rbxm, then run the QA checklist.")
