--!strict
-- How the game's screen text and plates look, in one place: one heavy font, warm cream text with a dark brown outline,
-- dark rounded plates, and a short bounce when a number changes. The font matters for Korean: Roblox draws Hangul with
-- a fallback that has a single Regular face, so a one-weight font such as FredokaOne leaves the Korean thin beside
-- chunky digits (a "mixed font" line), while Montserrat Black (the old GothamBlack) draws the Korean bold too (Studio
-- check, 2026-10-25). The outline is a darker colour, never the text's own (a same-colour stroke turns letters into
-- blobs). Shared so every client part can use it (client parts do not require each other); also styles the server's
-- crate tags.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))

local UiStyle = {}

UiStyle.Font = Font.fromEnum(Enum.Font.GothamBlack)
UiStyle.Cream = Color3.fromRGB(255, 246, 228)
UiStyle.Gold = Config.Feedback.Gold
UiStyle.Red = Color3.fromRGB(255, 96, 72)
UiStyle.Outline = Color3.fromRGB(46, 26, 14)
UiStyle.PlateColor = Color3.fromRGB(40, 27, 19)
UiStyle.PlateEdge = Color3.fromRGB(122, 84, 50)

local POP_SECONDS = 0.28

-- The outline (or plate edge) under `gui`, made once.
local function stroke(gui: GuiObject, color: Color3, thickness: number, mode: Enum.ApplyStrokeMode): UIStroke
	local found = gui:FindFirstChildOfClass("UIStroke")
	local line = if found then found else Instance.new("UIStroke")
	line.ApplyStrokeMode = mode
	line.Color = color
	line.Thickness = thickness
	line.LineJoinMode = Enum.LineJoinMode.Round
	line.Parent = gui
	return line
end

-- Gives a text label or button the game's look: the font, `color` (cream when nil) and a dark outline `outline`
-- pixels thick (2 when nil).
function UiStyle.text(label: TextLabel | TextButton, color: Color3?, outline: number?)
	local text = label :: any -- the same text properties on either class
	text.FontFace = UiStyle.Font
	text.TextColor3 = color or UiStyle.Cream
	text.TextStrokeTransparency = 1 -- the UIStroke is the outline
	stroke(label, UiStyle.Outline, outline or 2, Enum.ApplyStrokeMode.Contextual)
end

-- A new transparent text label in the game's look, filling `size` (text scaled to fit, at most `most` pixels high).
function UiStyle.label(parent: Instance, name: string, size: UDim2, most: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = ""
	UiStyle.text(label, color)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = most
	limit.Parent = label
	label.Parent = parent
	return label
end

-- Makes `frame` a dark rounded plate with a lighter wooden edge (for the round's numbers and the first-ride card).
function UiStyle.plate(frame: Frame, radius: number?)
	frame.BackgroundColor3 = UiStyle.PlateColor
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel = 0
	local corner = frame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = frame
	stroke(frame, UiStyle.PlateEdge, 2, Enum.ApplyStrokeMode.Border)
end

-- A quick bounce: `gui` jumps to `scale` times its resting size (1.3 when nil) and settles back to resting at `rest`
-- times its size (1 when nil; text cannot be set above 100 pixels, so bigger text is a scaled-up label).
function UiStyle.pop(gui: GuiObject, scale: number?, rest: number?)
	local found = gui:FindFirstChildOfClass("UIScale")
	local size = if found then found else Instance.new("UIScale")
	size.Parent = gui
	local settle = rest or 1
	size.Scale = settle * (scale or 1.3)
	TweenService:Create(size, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = settle }):Play()
end

-- Sets how see-through a styled text label is, its outline with it (0 = solid, 1 = gone).
function UiStyle.fade(label: TextLabel | TextButton, transparency: number)
	local text = label :: any -- the same text properties on either class
	text.TextTransparency = transparency
	local line = label:FindFirstChildOfClass("UIStroke")
	if line then
		line.Transparency = transparency
	end
end

return UiStyle
