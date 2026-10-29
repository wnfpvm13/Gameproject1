--!strict
-- The knock-off feed: a short line under the round's plates at the top for each fighter knocked off by a home run or a
-- fall (Words.feed: "A → B 홈런!", "A → B 하차" for a last ticket, "A → B 떨어뜨림" for a fall with one to spare, or
-- "B 하차" with nobody to credit). The newest is on
-- top; a line fades after Config.Feedback.FeedSeconds, and at most Config.Feedback.FeedLines show.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local FeedHud = {}
FeedHud.__index = FeedHud

local HOME_RUN_COLOR = Config.Feedback.Gold
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
	frame.Position = UDim2.new(0.5, 0, 0, 96) -- under the round's plates and status line (RoundHud)
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

-- A knock-off: the victim's name, who gets the credit (nil = nobody), how ("homerun" or "fall") and whether it was the
-- victim's last ticket (out).
function FeedHud.add(self: Feed, victim: string, by: string?, how: string, out: boolean)
	-- Text scaled to fit: long names shrink instead of running off.
	local label = UiStyle.label(self.frame, "Line", UDim2.new(1, 0, 0, LINE_HEIGHT), 18, if how == "homerun" then HOME_RUN_COLOR else nil)
	label.Text = Words.feed(victim, by, how, out)
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
			UiStyle.fade(line.label, 1 - left / 0.5)
		end
	end
	if changed then
		place(self)
	end
end

return FeedHud
