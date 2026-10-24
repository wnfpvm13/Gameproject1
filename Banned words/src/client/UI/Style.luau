--!strict
-- Shared look for every HUD panel: fonts, colours, the one ScreenGui, and small constructors. Owner 2026-10-24: clean,
-- black panels only a little see-through, white text, a thin light edge; colour only where it means something (right
-- / wrong, the timer running out, my pick).
local Players = game:GetService("Players")

local Style = {}

Style.BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
Style.REGULAR = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular)

Style.WHITE = Color3.fromRGB(245, 245, 247)
Style.GREY = Color3.fromRGB(160, 163, 170)
Style.RED = Color3.fromRGB(255, 96, 96)
Style.AMBER = Color3.fromRGB(255, 208, 92)
Style.GREEN = Color3.fromRGB(96, 208, 128)
Style.PANEL = Color3.fromRGB(0, 0, 0)
Style.PANEL_ALPHA = 0.3 -- panel background transparency
Style.BUTTON = Color3.fromRGB(44, 44, 48) -- a button on a panel (my pick turns it AMBER, right GREEN, wrong RED)
Style.EDGE_ALPHA = 0.85 -- the thin white edge of panels and buttons

local gui: ScreenGui? = nil
local stack: Frame? = nil

-- The single HUD ScreenGui (created on first use, survives respawns).
function Style.gui(): ScreenGui
	if not gui then
		local g = Instance.new("ScreenGui")
		g.Name = "BannedWordsHud"
		g.ResetOnSpawn = false
		g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- a panel's ZIndex lifts its whole subtree (the presenter's panels)
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

-- Rounded corners and the thin light edge (panels and buttons).
function Style.round(object: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.new(1, 1, 1)
	edge.Transparency = Style.EDGE_ALPHA
	edge.Thickness = 1
	edge.Parent = object
end

function Style.panel(parent: Instance, color: Color3, transparency: number, radius: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	Style.round(f, radius)
	f.Parent = parent
	return f
end

-- A button in the shared look (the caller sets its size, text and parent).
function Style.button(font: Font, textSize: number, color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Style.BUTTON
	b.BackgroundTransparency = 0.1
	b.BorderSizePixel = 0
	b.FontFace = font
	b.TextSize = textSize
	b.TextColor3 = color or Style.WHITE
	b.AutoButtonColor = true
	Style.round(b, 10)
	return b
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

-- Keeps `object` at most `fraction` of the screen wide (and `maxWidth` pixels), following the screen size.
function Style.fitWidth(object: GuiObject, fraction: number, maxWidth: number, maxHeight: number)
	local limit = Instance.new("UISizeConstraint")
	limit.Parent = object
	local function update()
		local camera = workspace.CurrentCamera
		local width = if camera then camera.ViewportSize.X * fraction else maxWidth
		limit.MaxSize = Vector2.new(math.max(120, math.min(maxWidth, width)), maxHeight)
	end
	update()
	local function watch()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	watch()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
end

-- A line of text centred under the status board (row 0, 1, 2 ...): a black pill as wide as its text (at most 92% of
-- the screen: a longer text gets smaller), gone while the text is empty.
local LINE_TEXT = 16
local LINE_MIN_TEXT = 11
function Style.line(row: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, Style.row(row))
	l.Size = UDim2.fromOffset(0, 22)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.BackgroundColor3 = Style.PANEL
	l.BackgroundTransparency = Style.PANEL_ALPHA
	l.BorderSizePixel = 0
	l.FontFace = Style.BOLD
	l.TextSize = LINE_TEXT
	l.TextColor3 = color
	l.Text = ""
	l.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = l
	Style.round(l, 11)
	Style.fitWidth(l, 0.92, 720, 22)
	local fitting = 0
	local function fit()
		fitting += 1
		local mine = fitting
		l.TextSize = LINE_TEXT
		task.defer(function() -- (TextFits is known after the layout)
			while mine == fitting and not l.TextFits and l.TextSize > LINE_MIN_TEXT do
				l.TextSize -= 1
				task.wait()
			end
		end)
	end
	l:GetPropertyChangedSignal("Text"):Connect(function()
		l.Visible = l.Text ~= ""
		fit()
	end)
	l:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if not l.TextFits then
			fit()
		end
	end)
	l.Parent = Style.gui()
	return l
end

return Style
