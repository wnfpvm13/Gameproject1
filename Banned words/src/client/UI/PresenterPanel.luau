--!strict
-- The presenter's controls (docs/DESIGN_V3.md §8; bundle 3, owner 2026-10-23):
--   - the "volunteer to present" button (row 3 under the status board), for anyone not playing the round;
--   - while I present: the mission menu (right side, open during the last seconds of free talk; recommended missions
--     marked), the same menu for "who flies" after a one-word mission (bundle 4b: tap a name, then "날려!"), the
--     sound buttons (bottom centre), and on private servers the banned-word list (left side, bundle 5a): every alive
--     player with their word and a button, "다시 뽑기" during the assignment, "🔔 들었다" during the round;
--   - a banned word caught in chat (bundle 5b): a red banner at the top, "name · 'word' · seconds left" and "🛟 구제".
-- It only shows what it is told and reports presses; the server checks every one of them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local PresenterPanel = {}

export type Option = { id: string, title: string, recommended: boolean }

local TEXT = Config.TEXT
local volunteerButton: TextButton
local menuFrame: Frame
local menuTitle: TextLabel
local menuList: Frame
local flingButton: TextButton
local soundBar: Frame
local wordFrame: Frame
local wordList: ScrollingFrame
local wordKey = "" -- what the list shows now (rebuilt only when it changes)
local rescueFrame: Frame
local rescueRows: { { label: TextLabel, endsAt: number, text: string } } = {}
local onRescue: (number) -> () = function(_userId) end
local onWordAction: (string, number) -> () = function(_mode, _userId) end
local volunteered = false
local menuEndsAt = 0
local menuKind = "pick"
local selected: string? = nil -- the name tapped in a "judge" menu
local onPickMission: (string) -> () = function(_id) end

local function button(parent: Instance, text: string, width: number, height: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, height)
	b.BackgroundColor3 = Style.PANEL
	b.BackgroundTransparency = 0.15
	b.FontFace = Style.BOLD
	b.TextSize = 18
	b.TextColor3 = Style.WHITE
	b.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	b.Parent = parent
	return b
end

export type WordRow = { userId: number, name: string, word: string }

-- onVolunteer(on), onPick(missionId), onSound(index), onWord(mode, userId) ("reroll" / "heard"), onRescueHit(userId):
-- the player pressed one of the controls.
function PresenterPanel.build(onVolunteer: (boolean) -> (), onPick: (string) -> (), onSound: (number) -> (),
	onWord: (string, number) -> (), onRescueHit: (number) -> ())
	onPickMission = onPick
	onWordAction = onWord
	onRescue = onRescueHit
	volunteerButton = button(Style.gui(), TEXT.VOLUNTEER, 240, 34)
	volunteerButton.Name = "Volunteer"
	volunteerButton.AnchorPoint = Vector2.new(0.5, 0)
	volunteerButton.Position = UDim2.new(0.5, 0, 0, Style.row(3) + 12) -- under the chat button (row 2, 34 px)
	volunteerButton.TextColor3 = Style.AMBER
	volunteerButton.Visible = false
	volunteerButton.Activated:Connect(function()
		onVolunteer(not volunteered)
	end)

	menuFrame = Style.panel(Style.gui(), Style.PANEL, 0.15, 14)
	menuFrame.Name = "MissionMenu"
	menuFrame.AnchorPoint = Vector2.new(1, 0.5)
	menuFrame.Position = UDim2.new(1, -16, 0.5, 0)
	menuFrame.Size = UDim2.fromOffset(260, 0)
	menuFrame.AutomaticSize = Enum.AutomaticSize.Y
	menuFrame.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = menuFrame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = menuFrame
	menuTitle = Style.label(menuFrame, Style.BOLD, 20, Style.AMBER)
	menuTitle.Size = UDim2.new(1, 0, 0, 26)
	menuTitle.LayoutOrder = 0
	menuList = Instance.new("Frame")
	menuList.BackgroundTransparency = 1
	menuList.Size = UDim2.fromScale(1, 0)
	menuList.AutomaticSize = Enum.AutomaticSize.Y
	menuList.LayoutOrder = 1
	menuList.Parent = menuFrame
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = menuList
	flingButton = button(menuFrame, TEXT.FLING_BUTTON, 240, 48)
	flingButton.Name = "Fling"
	flingButton.LayoutOrder = 2
	flingButton.BackgroundColor3 = Style.RED
	flingButton.TextSize = 24
	flingButton.Visible = false
	flingButton.Activated:Connect(function()
		if menuKind == "judge" and selected then
			onPickMission(selected)
			PresenterPanel.closeMenu()
		end
	end)

	soundBar = Instance.new("Frame")
	soundBar.Name = "SoundBar"
	soundBar.LayoutOrder = 2 -- above the (hidden while presenting) reaction bar
	soundBar.Size = UDim2.fromOffset(96 * #Config.PRESENTER_SOUNDS, 44)
	soundBar.BackgroundTransparency = 1
	soundBar.Visible = false
	soundBar.Parent = Style.bottomStack()
	local soundLayout = Instance.new("UIListLayout")
	soundLayout.FillDirection = Enum.FillDirection.Horizontal
	soundLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	soundLayout.Padding = UDim.new(0, 6)
	soundLayout.Parent = soundBar
	for index, entry in Config.PRESENTER_SOUNDS do
		local b = button(soundBar, (TEXT :: any)[entry.text] or entry.text, 90, 44)
		b.Activated:Connect(function()
			onSound(index)
		end)
	end

	wordFrame = Style.panel(Style.gui(), Style.PANEL, 0.15, 14)
	wordFrame.Name = "WordList"
	wordFrame.AnchorPoint = Vector2.new(0, 0.5)
	wordFrame.Position = UDim2.new(0, 16, 0.55, 0)
	wordFrame.Size = UDim2.fromOffset(300, 0)
	wordFrame.AutomaticSize = Enum.AutomaticSize.Y
	wordFrame.Visible = false
	local wordPad = Instance.new("UIPadding")
	wordPad.PaddingTop = UDim.new(0, 8)
	wordPad.PaddingBottom = UDim.new(0, 8)
	wordPad.PaddingLeft = UDim.new(0, 8)
	wordPad.PaddingRight = UDim.new(0, 8)
	wordPad.Parent = wordFrame
	local wordLayout = Instance.new("UIListLayout")
	wordLayout.SortOrder = Enum.SortOrder.LayoutOrder
	wordLayout.Padding = UDim.new(0, 6)
	wordLayout.Parent = wordFrame
	local wordTitle = Style.label(wordFrame, Style.BOLD, 18, Style.AMBER)
	wordTitle.Size = UDim2.new(1, 0, 0, 22)
	wordTitle.Text = TEXT.WORDS_TITLE
	wordTitle.LayoutOrder = 0
	-- Scrolls when ten names do not fit a short screen (the list's height is set in setWords).
	wordList = Instance.new("ScrollingFrame")
	wordList.BackgroundTransparency = 1
	wordList.BorderSizePixel = 0
	wordList.ScrollBarThickness = 6
	wordList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	wordList.CanvasSize = UDim2.new()
	wordList.Size = UDim2.fromScale(1, 0)
	wordList.LayoutOrder = 1
	wordList.Parent = wordFrame
	local listLayout2 = Instance.new("UIListLayout")
	listLayout2.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout2.Padding = UDim.new(0, 4)
	listLayout2.Parent = wordList

	rescueFrame = Instance.new("Frame")
	rescueFrame.Name = "Rescues"
	rescueFrame.BackgroundTransparency = 1
	rescueFrame.AnchorPoint = Vector2.new(0.5, 0)
	rescueFrame.Position = UDim2.new(0.5, 0, 0, Style.row(4) + 24) -- (under the volunteer / step-down button)
	rescueFrame.Size = UDim2.fromOffset(360, 0)
	rescueFrame.AutomaticSize = Enum.AutomaticSize.Y
	rescueFrame.Parent = Style.gui()
	local rescueLayout = Instance.new("UIListLayout")
	rescueLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rescueLayout.Padding = UDim.new(0, 4)
	rescueLayout.Parent = rescueFrame
end

export type RescueRow = { userId: number, name: string, word: string, endsAt: number }

-- Banned words caught in chat waiting for my rescue (while I present); an empty list clears the banner.
function PresenterPanel.setRescues(rows: { RescueRow })
	for _, child in rescueFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(rescueRows)
	for i, row in rows do
		local line = Style.panel(rescueFrame, Style.RED, 0.1, 10)
		line.Size = UDim2.new(1, 0, 0, 40)
		line.LayoutOrder = i
		local label = Style.label(line, Style.BOLD, 18, Style.WHITE)
		label.Size = UDim2.new(1, -124, 1, 0)
		label.Position = UDim2.fromOffset(10, 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		local text = row.name .. " · '" .. row.word .. "'"
		label.Text = text
		local save = button(line, TEXT.RESCUE_BUTTON, 108, 32)
		save.AnchorPoint = Vector2.new(1, 0.5)
		save.Position = UDim2.new(1, -6, 0.5, 0)
		save.TextSize = 16
		save.Activated:Connect(function()
			onRescue(row.userId)
		end)
		table.insert(rescueRows, { label = label, endsAt = row.endsAt, text = text })
	end
end

-- The banned-word list (private servers, while I present): `mode` "reroll" (assignment) or "heard" (round), nil
-- hides it.
function PresenterPanel.setWords(rows: { WordRow }, mode: string?)
	wordFrame.Visible = mode ~= nil and #rows > 0
	if not mode then
		return
	end
	local parts = { mode }
	for _, row in rows do
		table.insert(parts, row.userId .. ":" .. row.name .. ":" .. row.word)
	end
	local key = table.concat(parts, "|")
	local camera = workspace.CurrentCamera
	local room = if camera then camera.ViewportSize.Y * 0.5 else 300
	wordList.Size = UDim2.new(1, 0, 0, math.min(#rows * 40, math.max(room, 120))) -- (each refresh: the window may change)
	if key == wordKey then
		return
	end
	wordKey = key
	for _, child in wordList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, row in rows do
		local line = Instance.new("Frame")
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0, 36)
		line.LayoutOrder = i
		line.Parent = wordList
		local label = Style.label(line, Style.BOLD, 18, Style.WHITE)
		label.Size = UDim2.new(1, -112, 1, 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = row.name .. " · " .. row.word
		local action = button(line, if mode == "reroll" then TEXT.WORDS_REROLL else TEXT.WORDS_HEARD, 104, 32)
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.fromScale(1, 0.5)
		action.TextSize = 16
		action.BackgroundColor3 = if mode == "reroll" then Style.PANEL else Style.RED
		action.Activated:Connect(function()
			onWordAction(mode, row.userId)
		end)
	end
end

-- The volunteer button: shown when I may volunteer (not playing the round), labelled by my current choice; while I
-- present it is how I step down.
function PresenterPanel.setVolunteer(visible: boolean, on: boolean, presenting: boolean)
	volunteered = on
	volunteerButton.Visible = visible
	volunteerButton.Text = if presenting then TEXT.STEP_DOWN elseif on then TEXT.VOLUNTEER_CANCEL else TEXT.VOLUNTEER
end

-- While I present: the sound buttons.
function PresenterPanel.setPresenting(on: boolean)
	soundBar.Visible = on
	if not on then
		PresenterPanel.closeMenu()
		if #rescueRows > 0 then
			PresenterPanel.setRescues({}) -- (a banner left from when I presented)
		end
	end
end

-- A menu (server time `endsAt`). "pick" (the next mission): a press picks and closes it. "judge" (who flies): a press
-- selects a name, "날려!" sends it.
function PresenterPanel.openMenu(options: { Option }, endsAt: number, kind: string?)
	for _, child in menuList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	menuKind = kind or "pick"
	selected = nil
	local judging = menuKind == "judge"
	local nameButtons: { [string]: TextButton } = {}
	for i, option in options do
		local label = if option.recommended then "★ " .. option.title .. " · " .. TEXT.PICK_RECOMMENDED else option.title
		local b = button(menuList, label, 240, 40)
		b.LayoutOrder = i
		b.TextColor3 = if option.recommended then Style.AMBER else Style.WHITE
		nameButtons[option.id] = b
		b.Activated:Connect(function()
			if not judging then
				onPickMission(option.id)
				PresenterPanel.closeMenu()
				return
			end
			selected = option.id
			for id, other in nameButtons do
				other.BackgroundColor3 = if id == option.id then Style.AMBER else Style.PANEL
				other.TextColor3 = if id == option.id then Style.PANEL else Style.WHITE
			end
			flingButton.AutoButtonColor = true
			flingButton.BackgroundTransparency = 0
		end)
	end
	flingButton.Visible = judging
	flingButton.AutoButtonColor = false
	flingButton.BackgroundTransparency = 0.6 -- dim until a name is selected
	menuEndsAt = endsAt
	menuFrame.Visible = true
	PresenterPanel.tick(workspace:GetServerTimeNow())
end

function PresenterPanel.closeMenu()
	menuFrame.Visible = false
end

-- Every frame: the countdown in the menu title and on the rescue banner.
function PresenterPanel.tick(now: number)
	for _, row in rescueRows do
		row.label.Text = string.format("%s · %d", row.text, math.max(0, math.ceil(row.endsAt - now)))
	end
	if menuFrame.Visible then
		local left = math.max(0, math.ceil(menuEndsAt - now))
		menuTitle.Text = string.format("%s · %d", if menuKind == "judge" then TEXT.JUDGE_PICK else TEXT.PICK_MISSION, left)
	end
end

return PresenterPanel
