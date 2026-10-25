--!strict
-- A dynamite burst on this client, at the server's word (Names.BlastRemote, WeaponService): a boom, a bright ball that
-- swells to the blast's width and fades, and a puff of smoke. Drawn only: nothing here collides or is seen by
-- raycasts.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local PartUtil = require(shared:WaitForChild("PartUtil"))
local SoundBank = require(shared:WaitForChild("SoundBank"))

local ExplosionShow = {}

local FLASH_SECONDS = 0.35
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

-- A burst at `at`, `radius` wide.
function ExplosionShow.play(at: Vector3, radius: number)
	local ball = PartUtil.decor("Blast", Vector3.new(2, 2, 2), CFrame.new(at), Color3.fromRGB(255, 196, 90), Enum.Material.Neon, Workspace, Enum.PartType.Ball)
	ball.Transparency = 0.1
	SoundBank.play("Blast", ball)
	local grow = TweenService:Create(ball, TweenInfo.new(FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	})
	grow:Play()
	local attachment = Instance.new("Attachment")
	attachment.Parent = ball
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE_TEXTURE
	smoke.Enabled = false
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Speed = NumberRange.new(8, 16)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Drag = 3
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 7) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 84, 80), Color3.fromRGB(190, 180, 170))
	smoke.Parent = attachment
	smoke:Emit(24)
	Debris:AddItem(ball, 2.6) -- after the boom has rung out
end

return ExplosionShow
