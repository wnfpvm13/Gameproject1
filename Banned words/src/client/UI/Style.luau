--!strict
-- Shared look for every HUD panel: fonts, colours, the one ScreenGui, and small constructors. Owner 2026-10-25: the
-- whole UI in the sticker look of the owner's bell picture — light paper panels and bright yellow keys, each with a
-- thick dark outline, dark text; colour where it means something (my pick, right / wrong, a warning). (2026-10-24 it
-- was black panels, white text.)
local Players = game:GetService("Players")

local Style = {}

Style.BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
Style.REGULAR = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold)

Style.INK = Color3.fromRGB(34, 35, 38) -- text and every outline
Style.PAPER = Color3.fromRGB(255, 251, 240) -- panels
Style.PAPER_ALPHA = 0 -- panel background transparency
Style.KEY = Color3.fromRGB(255, 212, 59) -- a button that can be pressed (the bell's yellow)
Style.KEY_OFF = Color3.fromRGB(232, 228, 218) -- a button that cannot be pressed now
Style.PICK = Color3.fromRGB(255, 152, 31) -- my pick, a lit marker (orange)
Style.RIGHT = Color3.fromRGB(94, 209, 122) -- right / go (green)
Style.WRONG = Color3.fromRGB(255, 107, 107) -- wrong / out / danger (red)
-- (text colours are at least about 4.5:1 against the paper)
Style.FAINT = Color3.fromRGB(110, 104, 95) -- secondary text, the other choices once I picked one
Style.RED_TEXT = Color3.fromRGB(200, 40, 42) -- warnings on paper
Style.GREEN_TEXT = Color3.fromRGB(24, 120, 56) -- done / good news on paper
Style.ACCENT_TEXT = Color3.fromRGB(170, 85, 0) -- headings and next steps on paper (orange)
Style.OUTLINE = 3 -- pixels of the dark outline

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

-- Bottom-centre stack (the reaction bar, the presenter's sounds; the mission card sits above it). Panels are stacked
-- top to bottom.
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

-- Rounded corners and the thick dark outline (panels and buttons).
function Style.round(object: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Style.INK
	edge.Transparency = 0
	edge.Thickness = Style.OUTLINE
	edge.LineJoinMode = Enum.LineJoinMode.Round
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
	b.BackgroundColor3 = Style.KEY
	b.BackgroundTransparency = 0
	b.BorderSizePixel = 0
	b.FontFace = font
	b.TextSize = textSize
	b.TextColor3 = color or Style.INK
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
	return 80 + row * 30 -- (room for the outlines)
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

-- A line of text centred under the status board (row 0, 1, 2 ...): a paper pill as wide as its text (at most 92% of
-- the screen: a longer text gets smaller), gone while the text is empty.
local LINE_TEXT = 16
local LINE_MIN_TEXT = 11
function Style.line(row: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, Style.row(row))
	l.Size = UDim2.fromOffset(0, 22)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.BackgroundColor3 = Style.PAPER
	l.BackgroundTransparency = Style.PAPER_ALPHA
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
