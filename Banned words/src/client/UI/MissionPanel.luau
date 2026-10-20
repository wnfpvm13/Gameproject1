--!strict
-- The mission card (V2.1) in the bottom stack, centred under the ring (the side edges show the neighbours' bubbles).
-- A new mission opens big for CARD_OPEN_SECONDS (theme · mission n/N · title, situation + problem, goal, options,
-- condition, "talk freely" hint), then folds to the title plus the current condition / decision so it does not
-- cover the table. Tapping the card opens or folds it. A quiet-time topic line sits at the bottom.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local MissionPanel = {}

local COMPACT_BELOW = 560 -- viewport height (px) under which the open card drops the goal, hint and topic lines

local panel: TextButton
local headerL: TextLabel
local bodyL: TextLabel
local goalL: TextLabel
local optionsL: TextLabel
local conditionL: TextLabel
local decisionL: TextLabel
local hintL: TextLabel
local topicL: TextLabel
local info: any = nil -- last mission payload
local themeName: string? = nil
local openUntil = 0
local pinned = false
local compact = false
local shownOpen: boolean? = nil

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

local function isOpen(): boolean
	return pinned or os.clock() < openUntil
end

-- Fills the texts for the open or folded view and shows only the rows that view uses.
local function render()
	local open = isOpen()
	shownOpen = open
	local hasMission = info ~= nil
	if hasMission then
		if open then
			headerL.Text = string.format("%s · 미션 %d/%d · %s", themeName or "미션", info.index, info.total, info.title)
		else
			headerL.Text = string.format("%s  (미션 %d/%d · 눌러서 펼치기)", info.title, info.index, info.total)
		end
		bodyL.Text = info.situation .. " " .. info.problem
		goalL.Text = "목표: " .. info.goal
		optionsL.Text = "선택지: " .. table.concat(info.options, " / ")
		conditionL.Text = if info.condition then "📌 " .. info.condition else ""
		decisionL.Text = if info.decision then "✅ 결정: " .. info.decision else ""
	end
	headerL.Visible = hasMission
	bodyL.Visible = hasMission and open
	goalL.Visible = hasMission and not (open and compact)
	optionsL.Visible = hasMission and open
	conditionL.Visible = hasMission and conditionL.Text ~= ""
	decisionL.Visible = hasMission and decisionL.Text ~= ""
	hintL.Visible = hasMission and open and not compact
	topicL.Visible = topicL.Text ~= "" and not (compact and hasMission and open)
	panel.Visible = hasMission or topicL.Visible
end

function MissionPanel.build()
	panel = Instance.new("TextButton") -- the whole card is tappable (open / fold)
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.BackgroundColor3 = Style.CARD
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	panel.Parent = Style.bottomStack()
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
	decisionL = row(6, Style.BOLD, 15, Color3.fromRGB(40, 110, 70))
	hintL = row(7, Style.REGULAR, 13, Color3.fromRGB(120, 120, 130))
	hintL.Text = Config.TEXT.FREE_TALK
	topicL = row(8, Style.REGULAR, 15, Color3.fromRGB(90, 90, 100))

	panel.Activated:Connect(function()
		pinned = not isOpen()
		openUntil = 0
		render()
	end)

	-- Short (phone landscape) screens: smaller text and fewer lines on the open card.
	local camera = workspace.CurrentCamera
	local function fit()
		compact = camera.ViewportSize.Y < COMPACT_BELOW
		bodyL.TextSize = if compact then 14 else 17
		conditionL.TextSize = if compact then 14 else 16
		optionsL.TextSize = if compact then 13 else 15
		headerL.TextSize = if compact then 12 else 14
		render()
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	task.defer(fit)
end

-- payload: the server's mission card (index, total, title, situation, problem, goal, options, condition, decision).
function MissionPanel.show(theme: string?, payload: any)
	local isNew = info == nil or info.index ~= payload.index or info.title ~= payload.title
	info = payload
	themeName = theme
	if isNew then
		pinned = false
		openUntil = os.clock() + Config.CARD_OPEN_SECONDS
	end
	render()
end

-- Quiet-time topic (stays until the next one).
function MissionPanel.setTopic(text: string)
	topicL.Text = "💬 이야깃거리: " .. text
	render()
end

-- Every frame: fold the card once its open time is over.
function MissionPanel.tick()
	if info and shownOpen ~= isOpen() then
		render()
	end
end

function MissionPanel.clear()
	info = nil
	pinned = false
	openUntil = 0
	topicL.Text = ""
	render()
end

return MissionPanel
