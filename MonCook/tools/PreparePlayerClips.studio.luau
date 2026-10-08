-- EDIT-mode Studio Command Bar: select an R15 rig before publishing these clips.
local storage=game:GetService("ReplicatedStorage")
local selected=game:GetService("Selection"):Get()
assert(#selected==1 and selected[1]:IsA("Model"),"Select one standard R15 rig")
local humanoid=selected[1]:FindFirstChildOfClass("Humanoid")
assert(humanoid and humanoid.RigType==Enum.HumanoidRigType.R15,"R15 required")
assert(not workspace:FindFirstChild("MonCookPlayerClipsForPublish"),"Publish folder already exists; inspect first")
local joints={};for _,object in selected[1]:GetDescendants() do
	if object:IsA("Motor6D") and object.Part1 then joints[object.Part1.Name]=object end
end
local folder=storage.Assets.Animations.PlayerCombat:Clone()
folder.Name="MonCookPlayerClipsForPublish"
for _,object in folder:GetDescendants() do
	if object:IsA("Pose") then
		local joint=joints[object.Name]
		if joint then local axes=joint.C0.Rotation;object.CFrame=axes:Inverse()*object.CFrame*axes end
	end
end
folder.Parent=workspace
game:GetService("Selection"):Set({folder})
print("5 R15 clips retargeted to selected rig. Preview/publish Basic1/2/3, Heavy, Dodge under the experience owner. Set IDs in HuntingAnimationConfig.Player.")
