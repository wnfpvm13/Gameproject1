--!strict
-- Every player's body the same: Roblox's standard body parts at every fighter's scales (Config.Body, the practice
-- bots' too), moving with the standard animations (owner 2026-10-27: the bodies stay R15 and are made alike, "since we hit each other, the bodies taking the
-- hits should be the same"). Hits are judged between root parts, but the root's height, the feet, the bumping and how a
-- blow looks to land all follow the body; and the drawn poses (SwingPose) blend over what the Animator plays, so an
-- equipped animation pack (ninja, zombie...) would bend them. The head (with its face), clothes, hair and accessories
-- stay. (For the published game the place's Avatar Settings should match: R15 only, the same height and collider,
-- accessory and clothing limits.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))

local AvatarRules = {}

-- The description fields set: the scales every fighter has (Config.Body), the standard torso and limbs and no
-- animation of the avatar's own (0: Roblox's standard one).
local BODY_PARTS = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local ANIMATIONS = { "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation" }

-- Gives the character in the world with `humanoid` the standard body (nothing when it already has it, or when Roblox
-- cannot read or apply its description). Returns whether it changed anything.
local function standardize(model: Model, humanoid: Humanoid): boolean
	local read, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if not read or not description then
		return false
	end
	local changed = false
	local fields = description :: any
	for name, value in Config.Body.Scales do
		if math.abs(fields[name] - value) > 1e-3 then
			fields[name] = value
			changed = true
		end
	end
	for _, list in { BODY_PARTS, ANIMATIONS } do
		for _, name in list do
			if fields[name] ~= 0 then
				fields[name] = 0
				changed = true
			end
		end
	end
	if not changed then
		return false
	end
	local applied, problem = pcall(function()
		humanoid:ApplyDescriptionAsync(description)
	end)
	if not applied then
		warn("[TrainBrawl] could not make " .. model.Name .. "'s body standard: " .. tostring(problem))
	end
	return applied
end

-- Makes `model`'s body the standard one with the standard animations (yields) and marks it Names.BodyReady (rounds
-- take only such players: nobody fights in an avatar's own body that arrives late). Also marked when Roblox cannot
-- read or apply its description - a warning, not a player kept out of every round. A description is applied only to
-- a character in the world (Roblox refuses it before: "DataModel was not available"), so this waits for that a moment
-- (and gives up unmarked). Returns whether it changed anything.
function AvatarRules.apply(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	local deadline = os.clock() + 5
	while not model:IsDescendantOf(Workspace) and os.clock() < deadline do
		task.wait()
	end
	if not model:IsDescendantOf(Workspace) then
		return false
	end
	local changed = standardize(model, humanoid)
	model:SetAttribute(Names.BodyReady, true)
	return changed
end

return AvatarRules
