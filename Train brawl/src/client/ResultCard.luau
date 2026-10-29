--!strict
-- The player's own round at its end (persona fix 5: no result screen; the testers asked how they did). While the
-- result shows (phase "Ended") and the player took part, a plate under the winner's name lists its knock-offs, home
-- runs, hits landed and how long it stayed on the trains (RoundStats), each number counting up as the card comes in.
-- The words are Words', the look UiStyle's.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local ResultCard = {}
ResultCard.__index = ResultCard

local WIDTH = 300
local ROW = 30
local TOP = 0.3 -- the big text's place (RoundHud), as a share of the screen height
local BELOW_BIG = 110 -- the card starts this far under it (clear of the winner and the note)
local COUNT_SECONDS = 0.6 -- the numbers count up this long

-- The summary shown (RoundStats.Summary).
export type Summary = { kos: number, homers: number, landed: number, seconds: number, played: boolean }

type Row = { name: TextLabel, value: TextLabel }
type Fields = { gui: ScreenGui, frame: Frame, rows: { Row }, shownAt: number?, summary: Summary? }
export type Card = typeof(setmetatable({} :: Fields, ResultCard))

function ResultCard.new(playerGui: Instance): Card
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlResult"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Size = UDim2.fromOffset(WIDTH, 8 + 30 + 4 * ROW + 10)
	UiStyle.plate(frame)
	frame.Visible = false
	frame.Parent = gui
	local title = UiStyle.label(frame, "Title", UDim2.fromOffset(WIDTH - 24, 28), 22, UiStyle.Gold)
	title.Position = UDim2.fromOffset(12, 8)
	title.Text = Words.ResultTitle
	local rows = {}
	for i = 1, 4 do
		local y = 8 + 30 + (i - 1) * ROW
		local name = UiStyle.label(frame, "Name", UDim2.fromOffset(150, ROW - 4), 20)
		name.Position = UDim2.fromOffset(18, y)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local value = UiStyle.label(frame, "Value", UDim2.fromOffset(110, ROW - 4), 22, UiStyle.Gold)
		value.Position = UDim2.fromOffset(WIDTH - 18 - 110, y)
		value.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(rows, { name = name, value = value })
	end
	local fields: Fields = { gui = gui, frame = frame, rows = rows, shownAt = nil, summary = nil }
	return setmetatable(fields, ResultCard)
end

-- Every frame. phase: the round's phase; summary: the player's round (RoundStats.summary).
function ResultCard.update(self: Card, phase: string, summary: Summary)
	if phase ~= "Ended" or not summary.played then
		self.frame.Visible = false
		self.shownAt = nil
		return
	end
	if not self.shownAt then
		self.shownAt = os.clock()
		self.summary = summary -- the numbers as the fight ended
		self.frame.Visible = true
		UiStyle.pop(self.frame, 1.12)
	end
	local y = math.max(Workspace.CurrentCamera.ViewportSize.Y * TOP, 130) + BELOW_BIG
	self.frame.Position = UDim2.new(0.5, 0, 0, y)
	local shown = self.summary or summary
	local share = math.clamp((os.clock() - (self.shownAt :: number)) / COUNT_SECONDS, 0, 1)
	for i, row in Words.resultRows(math.floor(shown.kos * share + 0.5), math.floor(shown.homers * share + 0.5), math.floor(shown.landed * share + 0.5), math.floor(shown.seconds * share)) do
		local labels = self.rows[i]
		if labels then
			labels.name.Text = row[1]
			labels.value.Text = row[2]
		end
	end
end

return ResultCard
