--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Animation = require(Shared.Utilities.HuntingAnimation)
local CombatAnimation = require(Shared.Utilities.CombatAnimation)
local RigMap = require(Shared.Utilities.ImportedHornboarRig)
local Style = require(Shared.Config.CombatPresentationConfig)
local Feedback = require(script.Parent.HuntingHitFeedback)
local Tracks = require(script.Parent.CombatTrackPlayer)
local AnimationConfig = require(Shared.Config.HuntingAnimationConfig)
local Animator = {}
Animator.__index = Animator

local function binding(object: Instance): string?
	local value = object:FindFirstChild("Binding")
	return if value and value:IsA("StringValue") then value.Value else nil
end
local function monsterJointName(joint: Motor6D): string?
	local tag = binding(joint)
	if tag and string.sub(tag, 1, 6) == "Joint:" then return string.sub(tag, 7) end
	return RigMap.jointSemantic(joint.Name, if joint.Parent then joint.Parent.Name else nil)
end
local function visualBinding(part: BasePart): string
	return binding(part) or RigMap.partBinding(part.Name) or "Visual"
end
local function transform(pose: any): CFrame
	return CFrame.new(pose.X or 0, (pose.Y or 0)+(pose.Lift or 0), pose.Z or 0)*CFrame.Angles(pose.Pitch or 0, pose.Yaw or 0, pose.Roll or 0)
end
local function jointName(joint: Motor6D): string
	local name = string.gsub(joint.Name, " ", "")
	return if name == "Root" then "RootJoint" elseif name == "CleaverGrip" then "Grip" else name
end

function Animator.new(folder: Instance): any
	local self: any = setmetatable({ Monsters = {}, Characters = {}, Applied = {}, LocalAction = nil }, Animator)
	local function added(model: Instance)
		if not model:IsA("Model") or not model:GetAttribute("EncounterId") then return end
		local entry: any = { Joints = {}, Bones = {}, BoneDeltas = {}, Visual = {}, Ready = false }
		self.Monsters[model] = entry
		for _, object in model:GetDescendants() do
			if object:IsA("Motor6D") then
				local name = monsterJointName(object)
				if name then entry.Joints[name] = object end
			elseif object:IsA("Bone") then
				local name = RigMap.boneSemantic(object.Name)
				if name then
					entry.Bones[name] = entry.Bones[name] or {}
					local root = model.PrimaryPart or model:FindFirstChild("RootPart")
					local axes = if root and root:IsA("BasePart") then root.CFrame.Rotation:Inverse()*object.WorldCFrame.Rotation else object.CFrame.Rotation
					table.insert(entry.Bones[name], { Bone = object, Axes = axes, InverseAxes = axes:Inverse() })
				end
			elseif object:IsA("MeshPart") then
				table.insert(entry.Visual, { Part = object, Binding = visualBinding(object) })
			end
		end
		entry.Ready = #entry.Visual > 0
		model:SetAttribute("ImportedMeshReady", entry.Ready)
		if not entry.Ready then
			warn("[MonCook Art] Imported Hornboar has no MeshPart visuals: " .. model.Name)
			model:SetAttribute("ImportedMeshUnavailable", true)
			local root = model.PrimaryPart or model:FindFirstChild("RootPart")
			if root and root:IsA("BasePart") then
				local gui = Instance.new("BillboardGui")
				gui.Name, gui.Adornee, gui.Size, gui.StudsOffset = "ImportedMeshFailure", root, UDim2.fromOffset(250,35), Vector3.new(0,7.2,0)
				local label = Instance.new("TextLabel")
				label.Size, label.BackgroundTransparency, label.Text, label.TextColor3 = UDim2.fromScale(1,1), 0.2, "Imported Hornboar Asset Missing · QA 보류", Color3.fromRGB(255,230,210)
				label.BackgroundColor3, label.Parent, gui.Parent = Color3.fromRGB(85,48,35), gui, model
			end
		end
	end
	self.Added = folder.ChildAdded:Connect(added)
	self.Removed = folder.ChildRemoved:Connect(function(model) self.Monsters[model] = nil end)
	for _, model in folder:GetChildren() do added(model) end
	self.Restore = RunService.PreAnimation:Connect(function()
		for joint, base in self.Applied do if joint.Parent then joint.Transform = base end end
		table.clear(self.Applied)
	end)
	self.Tick = RunService.PreSimulation:Connect(function()
		local at = workspace:GetServerTimeNow()
		for model, entry in self.Monsters do
			if not model.Parent then self.Monsters[model] = nil; continue end
			local state = model:GetAttribute("State") or "Idle"
			local lod = AnimationConfig.MonsterLOD
			local camera = workspace.CurrentCamera
			local root = model.PrimaryPart
			local distance = if camera and root then (camera.CFrame.Position-root.Position).Magnitude else 0
			local interval = if distance < lod.Near then 0 elseif distance < lod.Medium then 1/lod.MediumHz
				elseif distance < lod.Far then 1/lod.FarHz else 1/lod.SleepHz
			local hitAt = model:GetAttribute("LastHitAt")
			local broken = model:GetAttribute("HornBroken")
			local changed = entry.State ~= state or entry.HitAt ~= hitAt or entry.Broken ~= broken
			if not changed and at < (entry.NextUpdateAt or 0) then continue end
			entry.State, entry.HitAt, entry.Broken, entry.NextUpdateAt = state, hitAt, broken, at+interval
			local elapsed = math.max(0, at-(model:GetAttribute("StateStartedAt") or at))
			local hitAge = at-(model:GetAttribute("LastHitAt") or -math.huge)
			if root then
				local previous = entry.LastPosition or root.Position
				entry.Stride = (entry.Stride or 0)+(root.Position-previous).Magnitude/3.0*math.pi*2
				entry.LastPosition = root.Position
			end
			local pose = Animation.monster(state, model:GetAttribute("AttackType"), elapsed, at, hitAge, model:GetAttribute("LastHitKind"), model:GetAttribute("LastHitHeavy"), entry.Stride)
			for name, joint in entry.Joints do
				if pose[name] then joint.Transform = transform(pose[name]) end
			end
			for name, bones in entry.Bones do
				if not pose[name] then continue end
				local delta = transform(pose[name])
				if entry.BoneDeltas[name] == delta then continue end
				entry.BoneDeltas[name] = delta
				for _, binding in bones do
					binding.Bone.Transform = binding.InverseAxes*delta*binding.Axes
				end
			end
			local fade = if state == "Dead" then math.clamp((elapsed-Style.DeathFadeStart)/Style.DeathFadeSeconds, 0, 1) else 0
			if state == "Dead" and not entry.DeathShown then entry.DeathShown = true; Feedback.death(model) end
			for _, visual in entry.Visual do
				local visible = visual.Binding == "Visual" or (visual.Binding == "HornBroken" and model:GetAttribute("HornBroken"))
					or (visual.Binding == "HornIntact" and not model:GetAttribute("HornBroken"))
				visual.Part.LocalTransparencyModifier = if visible then fade else 1
			end
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then continue end
			local entry = self.Characters[character]
			if not entry then entry = { Joints = {}, Count = 0 }; self.Characters[character] = entry end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then Tracks.stop(entry); continue end
			if at >= (entry.ScanAt or 0) then
				entry.ScanAt = at+0.5; table.clear(entry.Joints)
				for _, object in character:GetDescendants() do
					if object:IsA("Motor6D") then entry.Joints[jointName(object)] = object end
				end
			end
			local kind = character:GetAttribute("HuntingAttack")
			local startAt, endAt = character:GetAttribute("HuntingAttackStart"), character:GetAttribute("HuntingAttackEnd")
			local combo = character:GetAttribute("HuntingCombo") or 0
			local hitStart, hitEnd = character:GetAttribute("HuntingHitStart"), character:GetAttribute("HuntingHitEnd")
			local action = if player == Players.LocalPlayer then self.LocalAction else nil
			local trackAction: any
			if action and at < action.EndAt then
				kind, startAt, endAt, combo = action.AttackType, action.StartedAt, action.EndAt, action.ComboIndex or 0
				hitStart, hitEnd = action.WindowStartAt, action.WindowEndAt
				trackAction = action
			end
			if not startAt or not endAt or at >= endAt or not kind then Tracks.stop(entry); continue end
			trackAction = trackAction or { AttackId = character:GetAttribute("HuntingAttackId"), AttackType = kind,
				StartedAt = startAt, EndAt = endAt, ComboIndex = combo }
			local playing = Tracks.update(character, entry, trackAction, at)
			local pose
			if kind == "Dodge" then pose = CombatAnimation.player(kind, combo, at-startAt, endAt-startAt, 0, 0)
			elseif hitStart and hitEnd then pose = CombatAnimation.player(kind, combo, at-startAt, hitStart-startAt, hitEnd-hitStart, endAt-hitEnd)
			else continue end
			for name, joint in entry.Joints do
				if not pose[name] then continue end
				if playing and name ~= "Grip" then continue end
				local base = joint.Transform; self.Applied[joint] = base
				local delta = transform(pose[name])
				local axes = joint.C0.Rotation
				joint.Transform = base*axes:Inverse()*delta*axes
			end
		end
		for character, entry in self.Characters do if not character.Parent then Tracks.destroy(entry); self.Characters[character] = nil end end
	end)
	return self
end
function Animator.Action(self: any, action: any) self.LocalAction = action end
return Animator
