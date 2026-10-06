--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Style = require(ReplicatedStorage:WaitForChild("Shared").Config.CombatPresentationConfig)
local Feedback = {}
function Feedback.play(event: any)
	local p = event.Origin
	if type(p) ~= "table" then return end
	local origin = Vector3.new(p.X, p.Y, p.Z)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") and (root.Position-origin).Magnitude > Style.FeedbackDistance then return end
	local horn, heavy = event.Part == "Horn", event.Heavy == true
	local values = if horn then Style.HornColor elseif heavy then Style.HeavyColor else Style.BodyColor
	local holder = Instance.new("Part")
	holder.Name, holder.Size, holder.CFrame, holder.Transparency = "LocalConfirmedHit", Vector3.new(0.1, 0.1, 0.1), CFrame.new(origin), 1
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Parent = true, false, false, false, workspace
	local sound = Instance.new("Sound")
	sound.SoundId, sound.PlaybackSpeed = if horn then Style.HornSound else Style.BodySound, if horn then Style.HornPitch else Style.BodyPitch
	sound.Volume, sound.RollOffMaxDistance, sound.Parent = if heavy then Style.HeavyVolume else Style.LightVolume, 35, holder
	sound:Play()
	local count = if heavy then 9 elseif horn then 6 else 4
	for index = 1, count do
		local angle = index*math.pi*2/count
		local direction = Vector3.new(math.cos(angle), math.sin(angle), if horn then -0.25 else 0)
		local spark = Instance.new("Part")
		spark.Name, spark.Anchored, spark.CanCollide, spark.CanQuery, spark.CanTouch = "HitSpark", true, false, false, false
		spark.Material, spark.Color = Enum.Material.Neon, Color3.new(values[1], values[2], values[3])
		spark.Size = if horn then Vector3.new(0.08, 0.08, if heavy then 0.9 else 0.6) else Vector3.new(0.14, 0.14, if heavy then 0.7 else 0.42)
		spark.CFrame, spark.Parent = CFrame.lookAt(origin+direction*0.18, origin+direction), holder
		TweenService:Create(spark, TweenInfo.new(Style.SparkSeconds), { CFrame = spark.CFrame+direction*(if heavy then 1.7 else 0.9), Transparency = 1 }):Play()
	end
	Debris:AddItem(holder, 1.2)
end
function Feedback.death(model: Model)
	local root = model.PrimaryPart
	if not root then return end
	local attachment = Instance.new("Attachment"); attachment.Position, attachment.Parent = Vector3.new(0,2.5,0), root
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color, particles.LightEmission = ColorSequence.new(Color3.fromRGB(255,227,155)), 0.35
	particles.Lifetime, particles.Speed, particles.Rate = NumberRange.new(.6,1.1), NumberRange.new(1,3), 0
	particles.SpreadAngle, particles.Size, particles.Transparency = Vector2.new(180,180), NumberSequence.new(.20), NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})
	particles.Parent = attachment; particles:Emit(18); Debris:AddItem(attachment,1.4)
end
return Feedback
