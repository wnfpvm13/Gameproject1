--!strict
-- Word bubbles above heads: each other alive participant's words (up to 3, newest flashes) and name.
-- My own bubble is never drawn while I play (the HUD shows "??? × n"); in the result everyone's words show.
-- The V3 pool hall is white, so the cards carry a thick navy outline and the name sits on a navy pill.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Billboards = {}

local WORD_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local NAME_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local WIDTH = 4.6 -- studs; the flying chairs are 5 studs apart
local ROW = 1.0 -- studs per word row
local NAME_ROW = 0.9
local CARD_COLOR = Color3.fromRGB(255, 255, 255)
local NEW_COLOR = Color3.fromRGB(255, 225, 90)
local OUTLINE = Color3.fromRGB(22, 34, 64)
local NAME_PILL = Color3.fromRGB(22, 34, 64)

local ALARM_SECONDS = 1.2

type Bubble = { gui: BillboardGui, words: { string }, signature: string }
local bubbles: { [number]: Bubble } = {}
local dying: { [number]: boolean } = {} -- red alarm playing; render() leaves these alone

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

-- (Re)builds one bubble. `previous` = the words shown before, so a newly added word flashes.
local function build(player: Player, words: { string }, caption: string, previous: { string }?): Bubble?
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local rows = math.max(#words, 1)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WordBubble"
	gui.Size = UDim2.fromScale(WIDTH, rows * ROW + NAME_ROW)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6 + (rows * ROW + NAME_ROW) / 2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.LightInfluence = 0

	local list = Instance.new("Frame")
	list.Name = "Words"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, (rows * ROW) / (rows * ROW + NAME_ROW))
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.04, 0)
	layout.Parent = list
	local shown = if #words > 0 then words else { "?" }
	for i, text in shown do
		local fresh = previous ~= nil and #words > 0 and not table.find(previous, text)
		local row = wordRow(list, text, i, fresh)
		row.Size = UDim2.new(1, 0, 1 / rows, -2)
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Caption"
	nameLabel.BackgroundColor3 = NAME_PILL
	nameLabel.BackgroundTransparency = 0.1
	nameLabel.Position = UDim2.fromScale(0.1, list.Size.Y.Scale + 0.03)
	nameLabel.Size = UDim2.fromScale(0.8, 1 - list.Size.Y.Scale - 0.03)
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

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	gui.Adornee = head
	gui.Parent = head
	return { gui = gui, words = table.clone(words), signature = "" }
end

export type View = {
	show: { number }, -- userIds that get a bubble
	words: { [string]: { words: { string }?, count: number } },
}

-- Draws exactly the bubbles in view.show; rebuilds a bubble only when its content changed.
function Billboards.render(view: View)
	local keep: { [number]: boolean } = {}
	for userId in dying do
		keep[userId] = true
	end
	for _, userId in view.show do
		if dying[userId] then
			continue
		end
		local player = Players:GetPlayerByUserId(userId)
		local entry = view.words[tostring(userId)]
		if player and entry and entry.words then
			keep[userId] = true
			local caption = player.DisplayName
			local signature = table.concat(entry.words, "|") .. "#" .. caption
			local existing = bubbles[userId]
			local head = player.Character and player.Character:FindFirstChild("Head")
			if not existing or existing.signature ~= signature or existing.gui.Parent ~= head then
				local previous = if existing then existing.words else nil
				removeBubble(userId)
				local bubble = build(player, entry.words, caption, previous)
				if bubble then
					bubble.signature = signature
					bubbles[userId] = bubble
				end
			end
		end
	end
	for userId in bubbles do
		if not keep[userId] then
			removeBubble(userId)
		end
	end
end

-- Elimination: the bubble turns red and swells for ALARM_SECONDS, then disappears.
function Billboards.alarm(userId: number)
	local bubble = bubbles[userId]
	if not bubble then
		return
	end
	dying[userId] = true
	task.delay(ALARM_SECONDS, function()
		dying[userId] = nil
		if bubbles[userId] == bubble then
			removeBubble(userId)
		end
	end)
	for _, row in (bubble.gui:FindFirstChild("Words") :: Frame):GetChildren() do
		if row:IsA("Frame") then
			row.BackgroundColor3 = Color3.fromRGB(230, 40, 40)
			local label = row:FindFirstChild("Text") :: TextLabel
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
	local size = bubble.gui.Size
	TweenService:Create(bubble.gui, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(size.X.Scale * 1.5, size.Y.Scale * 1.5),
	}):Play()
end

function Billboards.clear()
	table.clear(dying)
	for userId in bubbles do
		removeBubble(userId)
	end
end

return Billboards
