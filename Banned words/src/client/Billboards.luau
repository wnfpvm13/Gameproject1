--!strict
-- Head bubbles: name and lives (hearts) for every participant on the chairs, me included (the presenter's bubble says
-- "진행자" instead of hearts), and from bundle 5 the banned words above them: each other participant's visible words
-- (a new one flashes) and "???" for my own.
-- The V3 pool hall is white, so word cards carry a thick navy outline and the name sits on a navy pill.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local Hearts = require(shared:WaitForChild("Hearts"))

local Billboards = {}

local WORD_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local NAME_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local WIDTH = 4.6 -- studs; the flying chairs are 5 studs apart
local ROW = 1.0 -- studs per word row
local NAME_ROW = 0.9
local HEART_ROW = 0.8
local CARD_COLOR = Color3.fromRGB(255, 255, 255)
local NEW_COLOR = Color3.fromRGB(255, 225, 90)
local OUTLINE = Color3.fromRGB(22, 34, 64)
local NAME_PILL = Color3.fromRGB(0, 0, 0) -- (the HUD's black, owner 2026-10-24)
local HIDDEN = "???" -- my own words while I play

local GROW_SECONDS = 0.15 -- hit(): the pop grows, then settles back
local SETTLE_SECONDS = 0.35

export type View = {
	show: { number }, -- userIds that get a bubble
	words: { [string]: { words: { string }?, count: number } }, -- nil words = hidden (my own)
	lives: { [string]: number },
	maxLives: number,
	presenter: number?, -- the presenter's userId (their bubble shows the presenter tag)
}

type Bubble = { gui: BillboardGui, size: UDim2, hearts: TextLabel, words: { string }, layout: string }
local bubbles: { [number]: Bubble } = {}
local dying: { [number]: boolean } = {} -- bubbles of players just out, kept until their pop is over
local lastView: View? = nil -- drawn again when a pop is over (the round may show that player again by then)

local function removeBubble(userId: number)
	local bubble = bubbles[userId]
	if not bubble then
		return
	end
	-- Give the default name tag back once the bubble (which carried the name) is gone.
	local character = bubble.gui.Parent and bubble.gui.Parent.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
	bubble.gui:Destroy()
	bubbles[userId] = nil
end

local function wordRow(parent: Instance, text: string, order: number, fresh: boolean): Frame
	local row = Instance.new("Frame")
	row.Name = "Word" .. order
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 1, 0) -- resized by the caller
	row.BackgroundColor3 = if fresh then NEW_COLOR else CARD_COLOR
	row.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = row
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = OUTLINE
	stroke.Parent = row
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = WORD_FONT
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(30, 30, 36)
	label.Text = text
	label.Parent = row
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = label
	if fresh then
		task.delay(3, function()
			if row.Parent then
				TweenService:Create(row, TweenInfo.new(0.6), { BackgroundColor3 = CARD_COLOR }):Play()
			end
		end)
	end
	return row
end

-- (Re)builds one bubble: word rows (none, or "???" for hidden words), the name pill, the hearts. `previous` = the
-- words shown before, so a newly added word flashes.
local function build(player: Player, words: { string }, caption: string, previous: { string }?): Bubble?
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local wordsHeight = #words * ROW
	local total = wordsHeight + NAME_ROW + HEART_ROW
	local gui = Instance.new("BillboardGui")
	gui.Name = "WordBubble"
	gui.Size = UDim2.fromScale(WIDTH, total)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6 + total / 2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.LightInfluence = 0

	if #words > 0 then
		local list = Instance.new("Frame")
		list.Name = "Words"
		list.BackgroundTransparency = 1
		list.Size = UDim2.fromScale(1, wordsHeight / total)
		list.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0.04, 0)
		layout.Parent = list
		for i, text in words do
			local fresh = previous ~= nil and text ~= HIDDEN and not table.find(previous, text)
			local row = wordRow(list, text, i, fresh)
			row.Size = UDim2.new(1, 0, 1 / #words, -2)
		end
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Caption"
	nameLabel.BackgroundColor3 = NAME_PILL
	nameLabel.BackgroundTransparency = 0.3
	nameLabel.Position = UDim2.fromScale(0.1, wordsHeight / total + 0.02)
	nameLabel.Size = UDim2.fromScale(0.8, NAME_ROW / total - 0.02)
	nameLabel.FontFace = NAME_FONT
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Text = caption
	nameLabel.Parent = gui
	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0.5, 0)
	pillCorner.Parent = nameLabel
	local namePad = Instance.new("UIPadding")
	namePad.PaddingTop = UDim.new(0.12, 0)
	namePad.PaddingBottom = UDim.new(0.12, 0)
	namePad.PaddingLeft = UDim.new(0.06, 0)
	namePad.PaddingRight = UDim.new(0.06, 0)
	namePad.Parent = nameLabel

	local hearts = Instance.new("TextLabel")
	hearts.Name = "Hearts"
	hearts.BackgroundTransparency = 1
	hearts.Position = UDim2.fromScale(0.15, (wordsHeight + NAME_ROW) / total)
	hearts.Size = UDim2.fromScale(0.7, HEART_ROW / total)
	hearts.FontFace = NAME_FONT
	hearts.TextScaled = true
	hearts.RichText = true
	hearts.TextStrokeColor3 = OUTLINE
	hearts.TextStrokeTransparency = 0
	hearts.Parent = gui

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	gui.Adornee = head
	gui.Parent = head
	return { gui = gui, size = gui.Size, hearts = hearts, words = table.clone(words), layout = "" }
end

-- Draws exactly the bubbles in view.show (plus the ones of players just out, until their pop is over). A bubble is
-- rebuilt only when its words or name changed; new lives just change its hearts (so a running pop goes on).
-- Returns how many studs the tallest tag's word rows add (the chat bubbles go up by as much, ChatLook).
function Billboards.render(view: View): number
	lastView = view
	local tallest = 0
	local keep: { [number]: boolean } = {}
	for userId in dying do
		keep[userId] = true
	end
	for _, userId in view.show do
		local player = Players:GetPlayerByUserId(userId)
		local head = player and player.Character and player.Character:FindFirstChild("Head")
		if player and head and not dying[userId] then
			keep[userId] = true
			local key = tostring(userId)
			local entry = view.words[key]
			local words = if not entry then {} elseif entry.words then entry.words else { HIDDEN }
			tallest = math.max(tallest, #words * ROW)
			local caption = player.DisplayName
			local layout = table.concat(words, "|") .. "#" .. caption
			local bubble: Bubble? = bubbles[userId]
			if not bubble or bubble.layout ~= layout or bubble.gui.Parent ~= head then
				local previous = if bubble then bubble.words else nil
				removeBubble(userId)
				bubble = build(player, words, caption, previous)
				if bubble then
					bubble.layout = layout
					bubbles[userId] = bubble
				end
			end
			if bubble then
				bubble.hearts.Text = if userId == view.presenter
					then Config.TEXT.PRESENTER_TAG
					else Hearts.text(view.lives[key] or 0, view.maxLives)
			end
		end
	end
	for userId in bubbles do
		if not keep[userId] then
			removeBubble(userId)
		end
	end
	return tallest
end

-- Lost a life: the hearts show the lives left and the bubble pops. The bubble of a player who is out stays until the
-- pop is over; then the latest view is drawn again (it goes, unless the round still shows them, e.g. in the result).
function Billboards.hit(userId: number, lives: number, maxLives: number, out: boolean)
	local bubble = bubbles[userId]
	if not bubble then
		return
	end
	bubble.hearts.Text = Hearts.text(lives, maxLives)
	local gui = bubble.gui
	local size = bubble.size
	local grow = TweenService:Create(gui, TweenInfo.new(GROW_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(size.X.Scale * 1.35, size.Y.Scale * 1.35),
	})
	grow.Completed:Once(function()
		if gui.Parent then
			TweenService:Create(gui, TweenInfo.new(SETTLE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size }):Play()
		end
	end)
	grow:Play()
	if out then
		dying[userId] = true
		task.delay(GROW_SECONDS + SETTLE_SECONDS + 0.2, function()
			dying[userId] = nil
			if lastView then
				Billboards.render(lastView)
			end
		end)
	end
end

return Billboards
