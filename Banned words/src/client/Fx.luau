--!strict
-- Effects: elimination (buzzer, red flash, confetti "펑" where the body vanishes) and floating emoji reactions.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BannedWords"):WaitForChild("Config"))

local Fx = {}

local CONFETTI = {
	Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 200, 70), Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(140, 230, 120), Color3.fromRGB(220, 130, 255),
}

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

local function anchorAt(position: Vector3, lifetime: number): Part
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Parent = workspace
	task.delay(lifetime, function()
		anchor:Destroy()
	end)
	return anchor
end

local function pop(position: Vector3)
	local anchor = anchorAt(position, 4)
	for _, color in CONFETTI do
		local bits = Instance.new("ParticleEmitter")
		bits.Color = ColorSequence.new(color)
		bits.Size = NumberSequence.new(0.35)
		bits.Lifetime = NumberRange.new(1, 1.8)
		bits.Speed = NumberRange.new(14, 28)
		bits.SpreadAngle = Vector2.new(180, 180)
		bits.Acceleration = Vector3.new(0, -30, 0)
		bits.RotSpeed = NumberRange.new(-300, 300)
		bits.Rotation = NumberRange.new(0, 360)
		bits.Shape = Enum.ParticleEmitterShape.Sphere
		bits.Rate = 0
		bits.Parent = anchor
		bits:Emit(14)
	end
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(245, 245, 245))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.5, 0.8)
	smoke.Speed = NumberRange.new(4, 8)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Rate = 0
	smoke.Parent = anchor
	smoke:Emit(10)
end

-- Someone said a word: buzzer + red flash now, confetti where the body vanishes.
function Fx.elimination(player: Player?)
	buzzer:Play()
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	task.delay(Config.LAUNCH_POP_TIME, function()
		pop(root.Position)
	end)
end

-- An emoji floats up from above the player's head and fades.
function Fx.reaction(player: Player?, emoji: string)
	local head = player and player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(2, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Text = emoji
	label.Parent = gui
	gui.Adornee = head
	gui.Parent = head
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	task.delay(1.7, function()
		gui:Destroy()
	end)
end

return Fx
