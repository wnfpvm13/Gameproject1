--!strict
-- The big bell button on screen (docs/DESIGN_V3.md §5.1; bundle 6b). Owner 2026-10-25: always on the right side of
-- the screen while I play, drawn as the sticker bell (Config.IMAGES.BELL); in 총잡이 결투 it is the gun
-- (Config.IMAGES.GUN) and a press fires. While my seat bell is open the picture is bright and breathes, and a press
-- asks the server to ring it — at the touch or click itself (bundle 8b: Activated fires on release, a phone would
-- always be a tap late against the E key in the timing games; Activated is kept for gamepads, but not for the same
-- press). While it is not open the picture rests a little faded and a press only wiggles it (no ding: it must not
-- sound like a real ring). Until the picture has loaded, a "🔔" stands in for it. Owner 2026-10-25 (bundle 9c): while
-- a press would lose (총잡이 결투's "ready…", 무궁화's red light) the bell stays open but does not invite a press: it
-- rests faded and still.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local BellButton = {}

local SIZE = 116 -- pixels
local RESTING = 0.35 -- the picture's transparency while the bell is not open
local BREATH = 1.08 -- how big it grows while it waits for a press

local button: ImageButton
local breath: UIScale
local breathing: Tween? = nil
local live = false
local inviting = false

local function wiggle()
	button.Rotation = -16
	TweenService:Create(button, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 })
		:Play()
end

-- onRing(): my bell is open, ring it (the server decides).
function BellButton.build(onRing: () -> ())
	button = Instance.new("ImageButton")
	button.Name = "BellButton"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -18, 0.6, 0)
	button.Size = UDim2.fromOffset(SIZE, SIZE)
	button.BackgroundTransparency = 1
	button.Image = Config.IMAGES.BELL
	button.ScaleType = Enum.ScaleType.Fit
	button.ImageTransparency = RESTING -- (closed until the first window opens)
	button.Visible = false
	button.ZIndex = 4
	breath = Instance.new("UIScale")
	breath.Parent = button
	local standIn = Instance.new("TextLabel")
	standIn.Name = "StandIn"
	standIn.BackgroundTransparency = 1
	standIn.Size = UDim2.fromScale(1, 1)
	standIn.Text = "🔔"
	standIn.TextScaled = true
	standIn.Visible = not button.IsLoaded
	standIn.Parent = button
	button:GetPropertyChangedSignal("IsLoaded"):Connect(function()
		standIn.Visible = not button.IsLoaded
	end)
	local function press()
		wiggle()
		if live then
			onRing()
		end
	end
	local pointerDown = false -- a click or touch pressed on its way down; its Activated (on the way up) is the same press
	button.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch)
			and input.UserInputState == Enum.UserInputState.Begin then
			pointerDown = true
			press()
		end
	end)
	button.Activated:Connect(function()
		if pointerDown then
			pointerDown = false
		else
			press() -- (a gamepad's press)
		end
	end)
	button.Parent = Style.gui()
end

-- `visible`: I play (seated, on the ground); `canRing`: my seat bell is open and I have not rung it yet; `invite`: a
-- press now is welcome (false while it would lose: then the open bell looks like a closed one, but a press still rings).
function BellButton.set(visible: boolean, canRing: boolean, invite: boolean)
	button.Visible = visible
	local look = canRing and invite
	if canRing == live and look == inviting then
		return
	end
	live = canRing
	inviting = look
	button.ImageTransparency = if look then 0 else RESTING
	if breathing then
		breathing:Cancel()
		breathing = nil
	end
	breath.Scale = 1
	if look then
		local tween = TweenService:Create(breath, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = BREATH })
		tween:Play()
		breathing = tween
	end
end

-- The picture: the bell, or the gun in 총잡이 결투 (a press fires).
function BellButton.setIcon(icon: "bell" | "gun")
	button.Image = if icon == "gun" then Config.IMAGES.GUN else Config.IMAGES.BELL
end

return BellButton
