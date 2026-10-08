--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared.Config.Registry)
local Math = require(Shared.Utilities.HuntingMath)
local HitGeometry = require(Shared.Utilities.HuntingHitGeometry)
local Definition = require(Shared.Remotes.Definitions).Hunting
local HUD = require(script.Parent.HuntingHUD)
local Input = require(script.Parent.HuntingInputController)
local Animator = require(script.Parent.HuntingAnimator)
local LootVisual = require(script.Parent.HuntingLootVisual)
local HitFeedback = require(script.Parent.HuntingHitFeedback)
local CombatStyle = require(Shared.Config.CombatPresentationConfig)
local AnimationConfig = require(Shared.Config.HuntingAnimationConfig)
local Prediction = require(Shared.Utilities.CombatPrediction)
local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild(Definition.Folder, 30)
if not network then return end -- Actual Restaurant Place has no hunting runtime.
local intent = network:WaitForChild(Definition.Intent) :: RemoteEvent
local changed = network:WaitForChild(Definition.Changed) :: RemoteEvent
local stateRemote = network:WaitForChild(Definition.State) :: RemoteFunction
local monsters = workspace:WaitForChild("MonCookMonsters")
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local animator, visual = Animator.new(monsters), LootVisual.new()
local sequence = 0
local prediction = Prediction.new(Registry.Definitions, AnimationConfig.PredictionTimeout)
local hud: any
local input: any
local function point(v: Vector3): any return { X = v.X, Y = v.Y, Z = v.Z } end
local function send(kind: string)
	if not hud:CanAct() then return end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not root or not root:IsA("BasePart") or not humanoid then return end
	local facing = root.CFrame.LookVector
	if kind == "Dodge" and humanoid.MoveDirection.Magnitude > 0.1 then facing = humanoid.MoveDirection.Unit end
	local weapon = Registry.Definitions.Weapon.StarterCleaver
	local targetHint, distance = nil, if kind == "Heavy" then weapon.Heavy.Reach else weapon.Reach
	for _, model in monsters:GetChildren() do
		if not model:IsA("Model") or not model.PrimaryPart or (model:GetAttribute("BodyHP") or 0) <= 0 then continue end
		local definition = Registry.Definitions.Monster[model:GetAttribute("MonsterId")]
		if not definition then continue end
		local camera = workspace.CurrentCamera
		if camera then local _, onScreen = camera:WorldToViewportPoint(model.PrimaryPart.Position+Vector3.new(0,2.5,0)); if not onScreen then continue end end
		local target = HitGeometry.aimPoint(point(root.Position),point(facing),
			{ Position = point(model.PrimaryPart.Position), Facing = point(model.PrimaryPart.CFrame.LookVector), HornBroken = model:GetAttribute("HornBroken") },
			definition, distance, Registry.Definitions.Combat.Rules.AimAssistDegrees*2, Registry.Definitions.Combat.Rules.VerticalTolerance)
		if target then
			targetHint, distance = model:GetAttribute("EncounterId"), Math.distance(point(root.Position), target)
		end
	end
	local nextSequence = sequence+1
	local action = prediction:Plan(nextSequence, kind, workspace:GetServerTimeNow(), hud.State.WeaponId)
	if not action then return end
	sequence = nextSequence
	animator:Action(action)
	hud.State.Action = action
	hud:Refresh()
	intent:FireServer({ Sequence = sequence, AttackType = kind, Facing = point(facing), TargetHint = targetHint })
end
hud = HUD.new(playerGui, function(kind: string) input:Activate(kind) end)
input = Input.new({ PlayerGui = playerGui, Enabled = function() return hud:CanAct() end, OnAction = send })
changed.OnClientEvent:Connect(function(event: any)
	if type(event) ~= "table" then return end
	if event.Kind == "State" then
		local snapshot = event.State
		if type(snapshot) ~= "table" then return end
		if prediction.Pending and prediction.Action then snapshot.Action = prediction.Action end
		if not snapshot.Ready or snapshot.Location ~= "World" or snapshot.Traveling or (snapshot.Health or 0) <= 0 then
			prediction:Reset(); animator:Action(nil)
		end
		if not prediction.Pending then prediction.DodgeReadyAt = snapshot.DodgeReadyAt or 0 end
		hud:Render(snapshot)
	elseif event.Kind == "Loot" then
		-- The server has already committed; delay only the cosmetic until recoil/death begins.
		task.delay(if event.Receipt.Kind == "Dead" then CombatStyle.DeathFadeStart else 0.15, function()
			hud:Notice(event.Receipt); visual:Play(event.Receipt, event.Origin)
		end)
	elseif event.Kind == "PartBroken" then visual:Burst(event.Origin)
	elseif event.Kind == "Hit" then HitFeedback.play(event)
	elseif event.Kind == "ActionResult" then
		local handled, action = prediction:Resolve(event.Sequence, event.Result)
		if handled then
			animator:Action(action)
			hud.State.Action, hud.State.DodgeReadyAt = action, prediction.DodgeReadyAt
			hud:Refresh()
		end
	end
end)
local refreshedAt = 0
RunService.Heartbeat:Connect(function()
	local at = workspace:GetServerTimeNow()
	if prediction:Expire(at) then animator:Action(nil); hud.State.Action = nil end
	if at-refreshedAt >= 0.08 then refreshedAt = at; hud:Refresh() end
end)
player.CharacterRemoving:Connect(function() prediction:Reset(); animator:Action(nil) end)
task.spawn(function()
	for _ = 1, 20 do
		local ok, state = pcall(function() return stateRemote:InvokeServer() end)
		if ok and state then hud:Render(state); if state.Ready then return end end
		task.wait(0.5)
	end
end)
