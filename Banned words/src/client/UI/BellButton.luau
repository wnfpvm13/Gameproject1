--!strict
-- The big bell button on screen (docs/DESIGN_V3.md §5.1; bundle 6b): shown while my seat bell is open, for every input
-- (on a phone the E prompt is small; a fast game wants a big target). A press asks the server to ring my bell.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local BellButton = {}

local button: TextButton

function BellButton.build(onRing: () -> ())
	button = Instance.new("TextButton")
	button.Name = "BellButton"
	button.LayoutOrder = 1 -- above the presenter's sounds and the reactions
	button.Size = UDim2.fromOffset(150, 64)
	button.BackgroundColor3 = Style.AMBER
	button.FontFace = Style.BOLD
	button.TextSize = 28
	button.TextColor3 = Style.PANEL
	button.Text = Config.TEXT.BELL_BUTTON
	button.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = button
	button.Activated:Connect(onRing)
	button.Parent = Style.bottomStack()
end

function BellButton.setVisible(visible: boolean)
	button.Visible = visible
end

return BellButton
