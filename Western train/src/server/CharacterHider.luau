--!strict
-- Hides a player's own character while they play as the locomotive: invisible, anchored inside the boiler, no
-- collisions, no name tag. Parts that load later (hair, hats) are hidden as they arrive. restore() puts back what
-- was changed (used when the locomotive could not be built, so the player is not left invisible).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local PartUtil = require(shared:WaitForChild("PartUtil"))

local CharacterHider = {}

export type Hidden = { stop: () -> (), restore: () -> () }

type Saved = { transparency: number, anchored: boolean?, canCollide: boolean?, canTouch: boolean?, canQuery: boolean? }

function CharacterHider.hide(character: Model, at: CFrame): Hidden
	local saved: { [Instance]: Saved } = {}
	local function hide(item: Instance)
		if item:IsA("BasePart") then
			saved[item] = {
				transparency = item.Transparency,
				anchored = item.Anchored,
				canCollide = item.CanCollide,
				canTouch = item.CanTouch,
				canQuery = item.CanQuery,
			}
			item.Transparency = 1
			PartUtil.ghost(item)
		elseif item:IsA("Decal") then
			saved[item] = { transparency = item.Transparency }
			item.Transparency = 1
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local display = humanoid and humanoid.DisplayDistanceType
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for _, item in character:GetDescendants() do
		hide(item)
	end
	character:PivotTo(at)
	local connection = character.DescendantAdded:Connect(hide)
	local stopped = false
	-- CharacterAdded fires before Roblox puts the new character on its spawn (still unparented), so move it again once
	-- the character is in the world.
	task.defer(function()
		if not character.Parent and not stopped then
			character.AncestryChanged:Wait()
		end
		if not stopped and character.Parent then
			character:PivotTo(at)
		end
	end)

	local function stop()
		stopped = true
		connection:Disconnect()
	end
	local function restore()
		stop()
		for item, values in saved do
			if item:IsA("BasePart") then
				item.Transparency = values.transparency
				item.Anchored = values.anchored == true
				item.CanCollide = values.canCollide == true
				item.CanTouch = values.canTouch == true
				item.CanQuery = values.canQuery == true
			elseif item:IsA("Decal") then
				item.Transparency = values.transparency
			end
		end
		if humanoid and display then
			humanoid.DisplayDistanceType = display
		end
		-- Hidden, the character's middle sat on the rails; lift it so its feet stand there instead of in the ground.
		local box, size = character:GetBoundingBox()
		local lift = at.Position.Y - (box.Position.Y - size.Y / 2)
		if lift > 0 then
			character:PivotTo(character:GetPivot() + Vector3.new(0, lift, 0))
		end
	end
	return { stop = stop, restore = restore }
end

return CharacterHider
