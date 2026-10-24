--!strict
-- The knock-off feed: a short line under the round line at the top for each fighter knocked out by a home run or a
-- fall ("A → B 홈런!", "A → B 떨어뜨림", or "B 떨어짐" with nobody to credit). The newest is on top; a line fades after
-- Config.Feedback.FeedSeconds, and at most Config.Feedback.FeedLines show.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))

local FeedHud = {}
FeedHud.__index = FeedHud

local HOME_RUN_COLOR = Config.Feedback.Gold
local FALL_COLOR = Color3.fromRGB(235, 235, 235)
local LINE_HEIGHT = 22

type Line = { label: TextLabel, endsAt: number }
type Fields = { frame: Frame, lines: { Line } }
export type Feed = typeof(setmetatable({} :: Fields, FeedHud))

function FeedHud.new(playerGui: Instance): Feed
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlFeed"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local frame = Instance.new("Frame")
	frame.Name = "Lines"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 88) -- under the round line and the knock-off count
	frame.Size = UDim2.fromOffset(420, LINE_HEIGHT * Config.Feedback.FeedLines)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local fields: Fields = { frame = frame, lines = {} }
	return setmetatable(fields, FeedHud)
end

local function place(self: Feed)
	for i, line in self.lines do
		line.label.Position = UDim2.fromOffset(0, (i - 1) * LINE_HEIGHT)
	end
end

-- A knock-out: the victim's name, who gets the credit (nil = nobody) and how ("homerun" or "fall").
function FeedHud.add(self: Feed, victim: string, by: string?, how: string)
	local homeRun = how == "homerun"
	local text
	if by then
		text = string.format("%s → %s %s", by, victim, if homeRun then "홈런!" else "떨어뜨림")
	else
		text = string.format("%s %s", victim, if homeRun then "홈런!" else "떨어짐")
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, LINE_HEIGHT)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true -- long names shrink to fit instead of running off
	local most = Instance.new("UITextSizeConstraint")
	most.MaxTextSize = 18
	most.Parent = label
	label.TextColor3 = if homeRun then HOME_RUN_COLOR else FALL_COLOR
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = self.frame
	table.insert(self.lines, 1, { label = label, endsAt = os.clock() + Config.Feedback.FeedSeconds })
	while #self.lines > Config.Feedback.FeedLines do
		local oldest = table.remove(self.lines)
		if oldest then
			oldest.label:Destroy()
		end
	end
	place(self)
end

-- Every frame: old lines fade out and go.
function FeedHud.update(self: Feed)
	local now = os.clock()
	local changed = false
	for i = #self.lines, 1, -1 do
		local line = self.lines[i]
		local left = line.endsAt - now
		if left <= 0 then
			line.label:Destroy()
			table.remove(self.lines, i)
			changed = true
		elseif left < 0.5 then
			line.label.TextTransparency = 1 - left / 0.5
			line.label.TextStrokeTransparency = 0.4 + 0.6 * (1 - left / 0.5)
		end
	end
	if changed then
		place(self)
	end
end

return FeedHud
