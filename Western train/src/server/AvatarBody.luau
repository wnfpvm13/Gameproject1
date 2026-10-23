--!strict
-- Builds the avatar the locomotive is made of: the player's head, body and clothes only - no accessories (owner
-- 2026-10-23), so hair, hats and 3D layered clothing are left out. Returns an R15 model with every joint removed and
-- every part anchored, so LocomotiveBuilder can place each part on its own. The Humanoid stays because Roblox only
-- draws classic shirts and pants on a model that has one; it is switched off so it never dies or shows a name.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartUtil = require(ReplicatedStorage:WaitForChild("WesternTrain"):WaitForChild("PartUtil"))

local AvatarBody = {}

local RIGID_ACCESSORIES = {
	"HatAccessory",
	"HairAccessory",
	"FaceAccessory",
	"NeckAccessory",
	"ShouldersAccessory",
	"FrontAccessory",
	"BackAccessory",
	"WaistAccessory",
}

-- The player's look without accessories. Test players in Studio have no web avatar, so they fall back to the
-- character's current look and then to the default look.
function AvatarBody.describe(player: Player): HumanoidDescription
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
	end)
	if not ok or not description then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		description = if humanoid then humanoid:GetAppliedDescription() else Instance.new("HumanoidDescription")
	end
	local desc = description :: HumanoidDescription
	for _, property in RIGID_ACCESSORIES do
		(desc :: any)[property] = ""
	end
	pcall(function()
		desc:SetAccessories({}, true) -- layered clothing and any rigid accessory left in the list
	end)
	return desc
end

-- An R15 model of that look, ready to be taken apart; nil if Roblox could not build it.
function AvatarBody.build(description: HumanoidDescription): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[WesternTrain] could not build the avatar: " .. tostring(model))
		return nil
	end
	local avatar = model :: Model
	-- Switch the Humanoid off before the neck joint goes, so it can never count as dead.
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutomaticScalingEnabled = false -- our part sizes must not be reset from the scale values
		humanoid.RequiresNeck = false
		humanoid.BreakJointsOnDeath = false
		humanoid.EvaluateStateMachine = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	-- Joints come as Motor6Ds (JointInstance) or, with the newer avatar joints, as AnimationConstraints and
	-- BallSocketConstraints (Constraint); all of them go, and so does any weld.
	for _, item in avatar:GetDescendants() do
		local joint = item:IsA("JointInstance") or item:IsA("Constraint") or item:IsA("WeldConstraint")
		if joint or item:IsA("Accessory") or item:IsA("BaseScript") then
			item:Destroy()
		end
	end
	for _, item in avatar:GetDescendants() do
		if item:IsA("BasePart") then
			PartUtil.ghost(item)
		end
	end
	local root = avatar:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Transparency = 1
	end
	return avatar
end

return AvatarBody
