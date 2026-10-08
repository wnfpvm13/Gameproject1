--!strict
-- Local presentation after persisted personal grants. No pickup/hit/reward remotes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared.Config.Registry)
local Style = require(Shared.Config.HuntingUIStyle)
local Math = require(Shared.Utilities.HuntingMath)
local Visual = {}
Visual.__index = Visual
function Visual.new(): any return setmetatable({ Active = {}, Count = 0 }, Visual) end
function Visual.Burst(self: any, origin: any)
	if not Math.point(origin) then return end
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Position = "LocalHornBreak", Vector3.new(0.1, 0.1, 0.1), Vector3.new(origin.X, origin.Y+3, origin.Z)
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.Transparency = true, false, false, false, 1
	anchor.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture, emitter.Rate, emitter.Lifetime, emitter.Speed = "rbxasset://textures/particles/sparkles_main.dds", 0, NumberRange.new(0.3, 0.6), NumberRange.new(3, 7)
	emitter.Color = ColorSequence.new(Color3.fromRGB(246, 221, 149), Color3.fromRGB(87, 215, 197))
	emitter.SpreadAngle, emitter.Parent = Vector2.new(180, 180), anchor
	emitter:Emit(12); Debris:AddItem(anchor, 1)
end
function Visual.Play(self: any, receipt: any, origin: any)
	if not Math.point(origin) then return end
	local templates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Ingredients")
	for index, item in receipt.Items do
		if self.Count >= Style.MaxLootVisuals then break end
		local definition = Registry.Definitions.Ingredient[item.IngredientId]
		local template = if definition and definition.AssetId then templates:FindFirstChild(definition.AssetId) else nil
		if not template or not template:IsA("Model") then continue end
		local model = template:Clone()
		model.Name = "PersonalLootVisual"
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false end
		end
		local start = Vector3.new(origin.X+(index-1)*0.55, origin.Y+3, origin.Z)
		model:PivotTo(CFrame.new(start)); model.Parent = workspace
		self.Count += 1
		local at = workspace:GetServerTimeNow()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.clamp((workspace:GetServerTimeNow()-at)/Style.LootVisualSeconds, 0, 1)
			local character = Players.LocalPlayer.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local destination = if root and root:IsA("BasePart") then root.Position else start
			local position = start:Lerp(destination, t*t)+Vector3.new(0, math.sin(t*math.pi)*1.4, 0)
			model:PivotTo(CFrame.new(position)*CFrame.Angles(0, t*math.pi*2, 0))
			for _, part in model:GetDescendants() do if part:IsA("BasePart") then part.LocalTransparencyModifier = math.clamp((t-0.55)/0.45, 0, 1) end end
			if t >= 1 then connection:Disconnect(); model:Destroy(); self.Count -= 1 end
		end)
	end
end
return Visual
