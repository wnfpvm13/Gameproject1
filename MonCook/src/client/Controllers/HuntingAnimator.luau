--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Animation = require(Shared.Utilities.HuntingAnimation)
local Style = require(Shared.Config.HuntingUIStyle)
local Animator = {}
Animator.__index = Animator
local function binding(object: Instance): string?
	local value = object:FindFirstChild("Binding")
	return if value and value:IsA("StringValue") then value.Value else nil
end
local function transform(pose: any): CFrame
	return CFrame.new(0, pose.Lift or 0, 0)*CFrame.Angles(pose.Pitch or 0, pose.Yaw or 0, pose.Roll or 0)
end
function Animator.new(folder: Instance): any
	local self: any = setmetatable({ Monsters = {}, Weapons = {}, LocalAction = nil }, Animator)
	local function added(model: Instance)
		if not model:IsA("Model") or not model:GetAttribute("EncounterId") then return end
		local joints, visual = {}, {}
		for _, object in model:GetDescendants() do
			local tag = binding(object)
			if object:IsA("Motor6D") and tag and string.sub(tag, 1, 6) == "Joint:" then joints[string.sub(tag, 7)] = object
			elseif object:IsA("BasePart") and (tag == "Visual" or tag == "HornIntact" or tag == "HornBroken") then table.insert(visual, { Part = object, Binding = tag }) end
		end
		local flash = Instance.new("Highlight")
		flash.Name, flash.Adornee, flash.FillColor, flash.FillTransparency = "LocalHitFlash", model, Color3.new(Style.Gold[1], Style.Gold[2], Style.Gold[3]), 0.6
		flash.OutlineTransparency, flash.Enabled, flash.Parent = 1, false, model
		self.Monsters[model] = { Joints = joints, Visual = visual, Flash = flash }
	end
	self.Added = folder.ChildAdded:Connect(added)
	self.Removed = folder.ChildRemoved:Connect(function(model)
		local entry = self.Monsters[model]
		if entry then entry.Flash:Destroy(); self.Monsters[model] = nil end
	end)
	for _, model in folder:GetChildren() do added(model) end
	self.Tick = RunService.PreSimulation:Connect(function()
		local at = workspace:GetServerTimeNow()
		for model, entry in self.Monsters do
			if not model.Parent then self.Monsters[model] = nil; continue end
			local state = model:GetAttribute("State") or "Idle"
			local elapsed = math.max(0, at-(model:GetAttribute("StateStartedAt") or at))
			local hitAge = at-(model:GetAttribute("LastHitAt") or -math.huge)
			local pose = Animation.monster(state, model:GetAttribute("AttackType"), elapsed, at, hitAge)
			for name, joint in entry.Joints do joint.Transform = transform(pose[name] or {}) end
			entry.Flash.Enabled = state ~= "Dead" and hitAge >= 0 and hitAge < 0.16
			if state == "Dead" then
				local fade = math.clamp((elapsed-1.0)/1.0, 0, 1)
				for _, visual in entry.Visual do
					local visible = visual.Binding == "Visual" or (visual.Binding == "HornBroken" and model:GetAttribute("HornBroken"))
						or (visual.Binding == "HornIntact" and not model:GetAttribute("HornBroken"))
					visual.Part.LocalTransparencyModifier = if visible then fade else 1
				end
			end
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then continue end
			local joint = self.Weapons[character]
			if not joint or not joint.Parent then joint = character:FindFirstChild("CleaverGrip", true); self.Weapons[character] = joint end
			if not joint or not joint:IsA("Motor6D") then continue end
			local startAt, endAt, kind, combo = character:GetAttribute("HuntingAttackStart"), character:GetAttribute("HuntingAttackEnd"), character:GetAttribute("HuntingAttack"), character:GetAttribute("HuntingCombo") or 0
			local action = if player == Players.LocalPlayer then self.LocalAction else nil
			if action and at < action.EndAt then startAt, endAt, kind, combo = action.StartedAt, action.EndAt, action.AttackType, action.ComboIndex or 0 end
			joint.Transform = if startAt and endAt then transform(Animation.weapon(kind, combo, at-startAt, endAt-startAt)) else CFrame.identity
		end
		for character in self.Weapons do if not character.Parent then self.Weapons[character] = nil end end
	end)
	return self
end
function Animator.Action(self: any, action: any) self.LocalAction = action end
return Animator
