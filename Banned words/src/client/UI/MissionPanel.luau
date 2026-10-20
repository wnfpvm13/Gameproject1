--!strict
-- The mission card (V2.1) in the bottom stack, centred under the ring (the side edges show the neighbours'
-- bubbles): theme · mission n/N, situation + problem, goal, the current condition (notice / vote follow-up),
-- the options (people argue about them before the vote opens), and a quiet-time topic line.
local Style = require(script.Parent:WaitForChild("Style"))

local MissionPanel = {}

local panel: Frame
local headerL: TextLabel
local bodyL: TextLabel
local goalL: TextLabel
local conditionL: TextLabel
local optionsL: TextLabel
local topicL: TextLabel
local hasMission = false
local compact = false
local COMPACT_BELOW = 560 -- viewport height (px) under which the card drops the goal and topic lines

local function row(order: number, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Size = UDim2.new(1, 0, 0, 0)
	l.Text = ""
	l.Parent = panel
	return l
end

local function refreshVisible()
	headerL.Visible = hasMission
	bodyL.Visible = hasMission
	goalL.Visible = hasMission and not compact
	optionsL.Visible = hasMission
	conditionL.Visible = hasMission and conditionL.Text ~= ""
	topicL.Visible = topicL.Text ~= "" and not (compact and hasMission)
	panel.Visible = hasMission or topicL.Visible
end

function MissionPanel.build()
	panel = Style.panel(Style.bottomStack(), Style.CARD, 0.08, 14)
	panel.LayoutOrder = 2
	panel.Size = UDim2.new(1, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = panel

	headerL = row(1, Style.BOLD, 14, Color3.fromRGB(200, 90, 40))
	bodyL = row(2, Style.BOLD, 17, Style.INK)
	goalL = row(3, Style.BOLD, 16, Color3.fromRGB(40, 110, 70))
	optionsL = row(4, Style.REGULAR, 15, Color3.fromRGB(70, 70, 90))
	conditionL = row(5, Style.BOLD, 16, Color3.fromRGB(190, 70, 30))
	topicL = row(6, Style.REGULAR, 15, Color3.fromRGB(90, 90, 100))

	-- Short (phone landscape) screens: smaller text, no goal/topic lines, so the stack stays low.
	local camera = workspace.CurrentCamera
	local function fit()
		compact = camera.ViewportSize.Y < COMPACT_BELOW
		bodyL.TextSize = if compact then 14 else 17
		conditionL.TextSize = if compact then 14 else 16
		optionsL.TextSize = if compact then 13 else 15
		headerL.TextSize = if compact then 12 else 14
		refreshVisible()
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	task.defer(fit)
end

-- info: the server's mission payload (situation, problem, goal, condition, index, total).
function MissionPanel.show(themeName: string?, info: any)
	hasMission = true
	headerL.Text = string.format("%s · 미션 %d/%d", themeName or "미션", info.index, info.total)
	bodyL.Text = info.situation .. " " .. info.problem
	goalL.Text = "목표: " .. info.goal
	optionsL.Text = "선택지: " .. table.concat(info.options, " / ")
	conditionL.Text = if info.condition then "📌 " .. info.condition else ""
	refreshVisible()
end

-- Quiet-time topic (stays until the next one).
function MissionPanel.setTopic(text: string)
	topicL.Text = "💬 이야깃거리: " .. text
	refreshVisible()
end

function MissionPanel.clear()
	hasMission = false
	conditionL.Text = ""
	topicL.Text = ""
	refreshVisible()
end

return MissionPanel
