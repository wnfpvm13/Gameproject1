--!strict
-- What the assistant host shows: a topic card on the left edge (clear of the mobile thumbstick bottom-left and
-- the chat top-left), an event banner and the new-word countdown over the centre table (the emptiest part of
-- the seated view). The theme and my role are in the status board (Hud).
local TweenService = game:GetService("TweenService")

local Style = require(script.Parent:WaitForChild("Style"))

local HostPanel = {}

local EVENT_SECONDS = 7

local topicCard: Frame
local topicL: TextLabel
local eventL: TextLabel
local warnL: TextLabel
local warnAt = 0
local warnCount = 0

function HostPanel.build()
	local gui = Style.gui()

	topicCard = Style.panel(gui, Style.CARD, 0.05, 14)
	topicCard.AnchorPoint = Vector2.new(0, 0.5)
	topicCard.Position = UDim2.new(0, 16, 0.5, 0)
	topicCard.Size = UDim2.new(0.26, 0, 0, 84)
	topicCard.Visible = false
	Style.limit(topicCard, Vector2.new(220, 0), Vector2.new(360, 120))
	local title = Style.label(topicCard, Style.BOLD, 16, Color3.fromRGB(200, 90, 40))
	title.Position = UDim2.fromScale(0.06, 0.06)
	title.Size = UDim2.fromScale(0.88, 0.3)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "이야깃거리"
	topicL = Style.label(topicCard, Style.BOLD, 22, Style.INK)
	topicL.Position = UDim2.fromScale(0.06, 0.38)
	topicL.Size = UDim2.fromScale(0.88, 0.56)
	topicL.TextXAlignment = Enum.TextXAlignment.Left

	eventL = Style.label(gui, Style.HEAVY, 30, Style.AMBER)
	eventL.AnchorPoint = Vector2.new(0.5, 0.5)
	eventL.Position = UDim2.fromScale(0.5, 0.62)
	eventL.Size = UDim2.new(0.7, 0, 0, 44)
	eventL.TextStrokeTransparency = 0.3
	eventL.TextTransparency = 1
	eventL.TextStrokeTransparency = 1

	warnL = Style.label(gui, Style.HEAVY, 36, Style.RED)
	warnL.AnchorPoint = Vector2.new(0.5, 0.5)
	warnL.Position = UDim2.fromScale(0.5, 0.71)
	warnL.Size = UDim2.new(0.7, 0, 0, 48)
	warnL.TextStrokeTransparency = 0.3
end

function HostPanel.showTopic(text: string)
	topicL.Text = text
	topicCard.Visible = true
end

function HostPanel.showEvent(text: string)
	eventL.Text = "📢 " .. text
	eventL.TextTransparency = 0
	eventL.TextStrokeTransparency = 0.3
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, EVENT_SECONDS)
	TweenService:Create(eventL, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

function HostPanel.warnWord(at: number, count: number)
	warnAt = at
	warnCount = count
end

-- Every frame: the new-word countdown.
function HostPanel.tick(now: number)
	local left = warnAt - now
	warnL.Text = if left > 0 then string.format("%d초 뒤 금칙어가 %d개로 늘어나요!", math.ceil(left), warnCount) else ""
end

-- A card on screen now contains a word in play (a new word was added): take it down.
function HostPanel.hide(which: string)
	if which == "topic" then
		topicCard.Visible = false
	else
		eventL.TextTransparency = 1
		eventL.TextStrokeTransparency = 1
	end
end

function HostPanel.clear()
	topicCard.Visible = false
	eventL.TextTransparency = 1
	eventL.TextStrokeTransparency = 1
	warnAt = 0
end

return HostPanel
