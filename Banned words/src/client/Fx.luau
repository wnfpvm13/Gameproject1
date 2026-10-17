--!strict
-- Elimination effects (KBS 위험한 초대 flying-chair style): buzzer, red screen flash, splash when the body hits the water.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BannedWords"):WaitForChild("Config"))

local Fx = {}

local flash: Frame
local buzzer: Sound

function Fx.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BannedWordsFx"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	buzzer = Instance.new("Sound")
	buzzer.Name = "Buzzer"
	buzzer.SoundId = Config.SOUND_BUZZER
	buzzer.Volume = 0.6
	buzzer.Parent = SoundService
end

local function redFlash()
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

local function splashAt(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Parent = workspace

	local drops = Instance.new("ParticleEmitter")
	drops.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	drops.LightEmission = 0.3
	drops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	drops.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	drops.Lifetime = NumberRange.new(0.7, 1.2)
	drops.Speed = NumberRange.new(22, 38)
	drops.SpreadAngle = Vector2.new(28, 28)
	drops.Acceleration = Vector3.new(0, -70, 0)
	drops.EmissionDirection = Enum.NormalId.Top
	drops.Rate = 0
	drops.Parent = anchor
	drops:Emit(70)

	local sound = Instance.new("Sound")
	sound.SoundId = Config.SOUND_SPLASH
	sound.Volume = 0.9
	sound.RollOffMaxDistance = 400
	sound.Parent = anchor
	sound:Play()

	task.delay(4, function()
		anchor:Destroy()
	end)
end

-- Called when anyone is launched: buzzer + red flash now, splash where the body lands.
function Fx.elimination(player: Player?)
	buzzer:Play()
	redFlash()
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local map = workspace:FindFirstChild("PoolMap")
	local center = map and map:FindFirstChild("PoolCenter") :: BasePart?
	local waterY = if center then center.Position.Y else -1.5
	task.delay(Config.LAUNCH_FLIGHT_TIME, function()
		local p = if root.Parent then root.Position else Vector3.zero
		splashAt(Vector3.new(p.X, waterY, p.Z))
	end)
end

return Fx
