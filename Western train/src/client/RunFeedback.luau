--!strict
-- Crash feedback in the world, on this client, for any locomotive: stars circling above its face for a while (the
-- cartoon "seeing stars"). Each call looks after itself and cleans up when the time is up or the locomotive is gone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local RunFeedback = {}

function RunFeedback.stars(locomotive: Model, seconds: number)
	local avatar = PartUtil.avatarOf(locomotive)
	local head = avatar and avatar:FindFirstChild(Names.AvatarHead)
	if not (head and head:IsA("BasePart")) then
		return
	end
	local c = Config.Run.Stars
	local stars = {}
	for i = 1, c.Count do
		local star = PartUtil.ghostBlock("Star", Vector3.new(c.Size, c.Size, c.Size), c.Color, Enum.Material.Neon, Workspace)
		star.Shape = Enum.PartType.Ball
		stars[i] = star
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local age = os.clock() - started
		if age > seconds or not head.Parent then
			connection:Disconnect()
			for _, star in stars do
				star:Destroy()
			end
			return
		end
		local centre = head.Position + Vector3.new(0, head.Size.Y / 2 + c.Lift, 0)
		local spin = age * c.TurnsPerSecond * 2 * math.pi
		for i, star in stars do
			local a = spin + (i - 1) * 2 * math.pi / c.Count
			local bob = math.sin(age * 9 + i) * 0.15
			star.CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * c.Radius, bob, math.sin(a) * c.Radius))
		end
	end)
end

return RunFeedback
