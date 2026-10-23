--!strict
-- Lays a cowboy down flat on a squashed roof (the "auto crouch": the train folds and the cowboy goes flat with it, so
-- both fit under a low bridge). Drawn on every client for every cowboy: the character's root joint is turned face
-- down the way the character faces and drawn lower, over the walking animation (tuned for R15 characters). set() says how far each cowboy lies down; the
-- joints are written in RunService.Stepped, after the Animator has written them for the frame (a value written in
-- RenderStepped is overwritten before it is drawn - seen in Studio). The root joint is a Motor6D on older rigs and
-- an AnimationConstraint on characters with Roblox's newer avatar joints; both have Transform.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))

local CowboyPose = {}

type Joint = Motor6D | AnimationConstraint

local function rootJoint(character: Model): Joint?
	local lower = character:FindFirstChild("LowerTorso")
	local joint = lower and lower:FindFirstChild("Root")
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
		return joint :: any
	end
	local torso = character:FindFirstChild("HumanoidRootPart")
	local r6 = torso and torso:FindFirstChild("RootJoint") -- R6 characters
	return if r6 and r6:IsA("Motor6D") then r6 else nil
end

-- How far each joint should lie down (0..1). A joint that goes back to 0 is put straight once (the animations may
-- not write the root joint every frame, so it is set outright, never added onto). A plain table (a weak one could
-- drop its Instance keys early); joints that leave the game are dropped in the loop below.
local wanted: { [Joint]: number } = {}

RunService.Stepped:Connect(function()
	local drop = Config.Cowboy.FlatDrop
	for joint, lie in wanted do
		if not joint:IsDescendantOf(workspace) then
			wanted[joint] = nil -- its character was removed
		else
			local transform = if lie <= 0
				then CFrame.identity
				else CFrame.new(0, -drop * lie, 0) * CFrame.Angles(-math.pi / 2 * lie, 0, 0)
			if lie <= 0 then
				wanted[joint] = nil
			end
			-- Both joint kinds have Transform; the type checker cannot write through the union.
			(joint :: any).Transform = transform
		end
	end
end)

-- amount: 0 standing, 1 lying flat. Call every frame for every cowboy.
function CowboyPose.set(character: Model?, amount: number)
	local joint = character and rootJoint(character)
	if not joint then
		return
	end
	if amount > 0 then
		wanted[joint] = math.min(amount, 1)
	elseif wanted[joint] then
		wanted[joint] = 0 -- put straight once in the next step
	end
end

return CowboyPose
