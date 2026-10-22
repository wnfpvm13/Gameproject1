--!strict
-- Emoji reaction buttons for players who are out and spectators (bottom of the bottom stack). The server rate-limits and broadcasts them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local ReactionBar = {}

local bar: Frame

function ReactionBar.build(onPick: (number) -> ())
	bar = Instance.new("Frame")
	bar.LayoutOrder = 3 -- bottom of the stack, under the mission card
	bar.Size = UDim2.new(0, 64 * #Config.REACTIONS, 0, 56)
	bar.BackgroundTransparency = 1
	bar.Visible = false
	bar.Parent = Style.bottomStack()
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = bar
	for index, emoji in Config.REACTIONS do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 56, 0, 56)
		b.BackgroundColor3 = Style.PANEL
		b.BackgroundTransparency = 0.25
		b.Text = emoji
		b.TextScaled = true
		b.FontFace = Style.BOLD
		b.TextColor3 = Style.WHITE
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = b
		b.Activated:Connect(function()
			onPick(index)
		end)
		b.Parent = bar
	end
end

function ReactionBar.setVisible(visible: boolean)
	bar.Visible = visible
end

return ReactionBar
