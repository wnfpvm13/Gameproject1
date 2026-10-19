--!strict
-- Shared look for every HUD panel: fonts, colours, the one ScreenGui, and small constructors.
local Players = game:GetService("Players")

local Style = {}

Style.BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
Style.HEAVY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
Style.REGULAR = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular)

Style.WHITE = Color3.fromRGB(240, 240, 245)
Style.GREY = Color3.fromRGB(170, 175, 185)
Style.RED = Color3.fromRGB(255, 110, 110)
Style.AMBER = Color3.fromRGB(255, 200, 90)
Style.GREEN = Color3.fromRGB(120, 220, 140)
Style.BLUE = Color3.fromRGB(170, 200, 255)
Style.PANEL = Color3.fromRGB(18, 22, 30)
Style.CARD = Color3.fromRGB(255, 248, 225)
Style.INK = Color3.fromRGB(40, 40, 50)

local gui: ScreenGui? = nil

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

-- A line of text centred under the status board (row 0, 1, 2 ...).
function Style.line(row: number, color: Color3): TextLabel
	local l = Style.label(Style.gui(), Style.BOLD, 20, color)
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, 78 + row * 26)
	l.Size = UDim2.new(0.7, 0, 0, 24)
	l.TextStrokeTransparency = 0.5
	return l
end

return Style
