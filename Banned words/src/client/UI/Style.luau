--!strict
-- Shared look for every HUD panel: fonts, colours, the one ScreenGui, and small constructors.
local Players = game:GetService("Players")

local Style = {}

Style.BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
Style.REGULAR = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular)

Style.WHITE = Color3.fromRGB(240, 240, 245)
Style.GREY = Color3.fromRGB(170, 175, 185)
Style.RED = Color3.fromRGB(255, 110, 110)
Style.AMBER = Color3.fromRGB(255, 200, 90)
Style.GREEN = Color3.fromRGB(120, 220, 140)
Style.PANEL = Color3.fromRGB(18, 22, 30)

local gui: ScreenGui? = nil
local stack: Frame? = nil

-- The single HUD ScreenGui (created on first use, survives respawns).
function Style.gui(): ScreenGui
	if not gui then
		local g = Instance.new("ScreenGui")
		g.Name = "BannedWordsHud"
		g.ResetOnSpawn = false
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		gui = g
	end
	return gui :: ScreenGui
end

-- Bottom-centre stack (the reaction bar now; the mission and vote panels of bundle 4 go above it). Panels are
-- stacked top to bottom.
function Style.bottomStack(): Frame
	if not stack then
		local f = Instance.new("Frame")
		f.Name = "BottomStack"
		f.AnchorPoint = Vector2.new(0.5, 1)
		f.Position = UDim2.new(0.5, 0, 1, -12)
		f.Size = UDim2.new(0.46, 0, 0, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		f.BackgroundTransparency = 1
		f.Parent = Style.gui()
		local c = Instance.new("UISizeConstraint")
		c.MinSize = Vector2.new(300, 0)
		c.MaxSize = Vector2.new(560, 600)
		c.Parent = f
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		layout.Padding = UDim.new(0, 6)
		layout.Parent = f
		stack = f
	end
	return stack :: Frame
end

function Style.label(parent: Instance, font: Font, maxSize: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.Text = ""
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
	l.Parent = parent
	return l
end

function Style.panel(parent: Instance, color: Color3, transparency: number, radius: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = f
	f.Parent = parent
	return f
end

function Style.limit(frame: GuiObject, min: Vector2, max: Vector2)
	local c = Instance.new("UISizeConstraint")
	c.MinSize = min
	c.MaxSize = max
	c.Parent = frame
end

-- The top (pixels) of row 0, 1, 2 ... under the status board.
function Style.row(row: number): number
	return 78 + row * 26
end

-- A line of text centred under the status board (row 0, 1, 2 ...).
function Style.line(row: number, color: Color3): TextLabel
	local l = Style.label(Style.gui(), Style.BOLD, 20, color)
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, Style.row(row))
	l.Size = UDim2.new(0.7, 0, 0, 24)
	l.TextStrokeTransparency = 0.5
	return l
end

return Style
