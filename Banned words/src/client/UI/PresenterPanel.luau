--!strict
-- The presenter's controls (docs/DESIGN_V3.md §8; bundle 3, owner 2026-10-23):
--   - the "volunteer to present" button (row 3 under the status board), for anyone not playing the round;
--   - while I present: the mission menu (right side, open during the last seconds of free talk; recommended missions
--     marked) and the sound buttons (bottom centre).
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
local soundBar: Frame
local volunteered = false
local menuEndsAt = 0
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

-- onVolunteer(on), onPick(missionId), onSound(index): the player pressed one of the controls.
function PresenterPanel.build(onVolunteer: (boolean) -> (), onPick: (string) -> (), onSound: (number) -> ())
	onPickMission = onPick
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
	end
end

-- The mission menu (server time `endsAt`); a press picks and closes it.
function PresenterPanel.openMenu(options: { Option }, endsAt: number)
	for _, child in menuList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i, option in options do
		local label = if option.recommended then "★ " .. option.title .. " · " .. TEXT.PICK_RECOMMENDED else option.title
		local b = button(menuList, label, 240, 40)
		b.LayoutOrder = i
		b.TextColor3 = if option.recommended then Style.AMBER else Style.WHITE
		b.Activated:Connect(function()
			onPickMission(option.id)
			PresenterPanel.closeMenu()
		end)
	end
	menuEndsAt = endsAt
	menuFrame.Visible = true
	PresenterPanel.tick(workspace:GetServerTimeNow())
end

function PresenterPanel.closeMenu()
	menuFrame.Visible = false
end

-- Every frame: the countdown in the menu title.
function PresenterPanel.tick(now: number)
	if menuFrame.Visible then
		local left = math.max(0, math.ceil(menuEndsAt - now))
		menuTitle.Text = string.format("%s · %d", TEXT.PICK_MISSION, left)
	end
end

return PresenterPanel
