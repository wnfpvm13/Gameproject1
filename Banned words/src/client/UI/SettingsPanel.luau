--!strict
-- Sound settings (bundle 11a, owner 2026-10-27: "소리조절을 설정칸을 만들어서 조절가능하게"; docs/BUNDLE11_2026-10-27.md):
-- a "설정" key on the status board's right edge opens a panel with two volumes, background music and game sounds,
-- 0-100 % in steps of Config.SETTINGS_STEP: [-] bar [+] and the percent; the bar takes a press or a drag. Voice chat
-- volume is Roblox's own (its menu), said in a line. Only draws: init.client applies and sends what changes.
local UserInputService = game:GetService("UserInputService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local SettingsPanel = {}

export type Settings = { music: number, effects: number }

local KEYS = { "music", "effects" }
local TITLES = { music = Config.TEXT.SETTINGS_MUSIC, effects = Config.TEXT.SETTINGS_EFFECTS }

local panel: Frame
local values: Settings = { music = Config.SETTINGS_DEFAULT.music, effects = Config.SETTINGS_DEFAULT.effects }
local fills: { [string]: Frame } = {}
local percents: { [string]: TextLabel } = {}
local changed: (Settings) -> () = function(_settings: Settings) end

local steps = math.round(1 / Config.SETTINGS_STEP)

local function draw()
	for _, key in KEYS do
		local value = values[key]
		fills[key].Size = UDim2.fromScale(value, 1)
		percents[key].Text = string.format("%d%%", math.round(value * 100))
	end
end

local function set(key: string, value: number)
	local stepped = math.clamp(math.round(value * steps) / steps, 0, 1)
	if stepped == values[key] then
		return
	end
	values = { music = values.music, effects = values.effects }
	values[key] = stepped
	draw()
	changed(values)
end

-- One volume row: its name, [-], the bar, [+], the percent.
local function row(parent: Frame, key: string, order: number)
	local line = Instance.new("Frame")
	line.Name = key
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, 0, 0, 72)
	line.LayoutOrder = order
	line.Parent = parent
	local name = Style.label(line, Style.BOLD, 20, Style.INK)
	name.Size = UDim2.new(1, 0, 0, 24)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = TITLES[key]
	local function key_(text: string, x: number, delta: number)
		local b = Style.button(Style.BOLD, 26)
		b.Text = text
		b.Size = UDim2.fromOffset(44, 44)
		b.AnchorPoint = Vector2.new(0, 0)
		b.Position = UDim2.new(x, if x > 0 then -44 - 56 else 0, 0, 28)
		b.Parent = line
		b.Activated:Connect(function()
			set(key, values[key] + delta)
		end)
	end
	key_("-", 0, -Config.SETTINGS_STEP)
	key_("+", 1, Config.SETTINGS_STEP)
	local bar = Style.panel(line, Style.KEY_OFF, 0, 8)
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(54, 38)
	bar.Size = UDim2.new(1, -54 - 54 - 56, 0, 24)
	bar.ClipsDescendants = true
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Style.KEY
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(values[key], 1)
	fill.Parent = bar
	fills[key] = fill
	local percent = Style.label(line, Style.BOLD, 20, Style.INK)
	percent.AnchorPoint = Vector2.new(1, 0)
	percent.Position = UDim2.new(1, 0, 0, 36)
	percent.Size = UDim2.fromOffset(52, 28)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percents[key] = percent
	-- A press on the bar sets the volume there; holding and moving keeps setting it.
	local dragging: InputObject? = nil
	local function at(x: number)
		local width = bar.AbsoluteSize.X
		if width > 0 then
			set(key, (x - bar.AbsolutePosition.X) / width)
		end
	end
	bar.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = input
			at(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or (kind == Enum.UserInputType.Touch and input == dragging) then
			at(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
		end
	end)
end

-- Builds the "설정" key on `board`'s right edge (the status board) and the panel; `onChange` gets every new pair of
-- volumes.
function SettingsPanel.build(board: GuiObject, onChange: (Settings) -> ())
	changed = onChange
	local open = Style.button(Style.BOLD, 18)
	open.Name = "SettingsKey"
	open.Text = Config.TEXT.SETTINGS
	open.AnchorPoint = Vector2.new(0.5, 0.5)
	open.Position = UDim2.fromScale(1, 0.5) -- (straddling the board's right edge)
	open.Size = UDim2.fromOffset(56, 44)
	open.ZIndex = 2
	open.Parent = board

	panel = Style.panel(Style.gui(), Style.PAPER, Style.PAPER_ALPHA, 16)
	panel.Name = "SettingsPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(380, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.ZIndex = 20
	panel.Visible = false
	Style.fitWidth(panel, 0.92, 380, 600)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = panel

	local title = Style.label(panel, Style.BOLD, 24, Style.ACCENT_TEXT)
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Text = Config.TEXT.SETTINGS_TITLE
	title.LayoutOrder = 1
	for i, key in KEYS do
		row(panel, key, 1 + i)
	end
	local note = Style.label(panel, Style.REGULAR, 16, Style.FAINT)
	note.Size = UDim2.new(1, 0, 0, 22)
	note.Text = Config.TEXT.SETTINGS_VOICE_NOTE
	note.LayoutOrder = 10
	local close = Style.button(Style.BOLD, 20)
	close.Text = Config.TEXT.SETTINGS_CLOSE
	close.Size = UDim2.fromOffset(140, 44)
	close.LayoutOrder = 11
	close.Parent = panel
	draw()

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
end

-- The volumes now (the saved ones came, or a change elsewhere).
function SettingsPanel.set(settings: Settings)
	values = { music = settings.music, effects = settings.effects }
	draw()
end

return SettingsPanel
