--!strict
-- The player's own round at its end (persona fix 5: no result screen; the testers asked how they did). While the
-- result shows (phase "Ended") and the player took part, a plate under the winner's name lists its knock-offs, home
-- runs, hits landed and how long it stayed on the trains (RoundStats), each number counting up as the card comes in,
-- with the titles it earned this round in gold under the heading (persona fix 8: Words.Titles), and - when someone else
-- won - the winner's tickets left and knock-offs over the player's own (2026-10-31: a tester still in at the end could
-- not tell why another won; time up ranks tickets, then knock-offs: RoundRules).
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
export type Standing = { name: string, tickets: number, kos: number }
export type Summary = {
	kos: number,
	homers: number,
	landed: number,
	seconds: number,
	played: boolean,
	titles: { string },
	highlights: { string },
	pressed: number,
	rival: Standing?,
	mine: Standing?,
}

local TITLE_ROW = 26
local VERSUS_ROW = 24 -- the winner's line and the player's

type Row = { name: TextLabel, value: TextLabel }
type Fields = { gui: ScreenGui, frame: Frame, titles: TextLabel, rows: { Row }, versus: { TextLabel }, shownAt: number?, summary: Summary? }
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
	local earned = UiStyle.label(frame, "Titles", UDim2.fromOffset(WIDTH - 24, TITLE_ROW - 2), 20, UiStyle.Gold)
	earned.Position = UDim2.fromOffset(12, 8 + 28)
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
	local versus = {}
	for i = 1, 2 do
		local line = UiStyle.label(frame, "Versus", UDim2.fromOffset(WIDTH - 36, VERSUS_ROW - 4), 18, if i == 1 then UiStyle.Gold else UiStyle.Cream)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Visible = false
		table.insert(versus, line)
	end
	local fields: Fields = { gui = gui, frame = frame, titles = earned, rows = rows, versus = versus, shownAt = nil, summary = nil }
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
		-- The titles, when earned, and the player's highlights take a row under the heading and push the numbers down.
		local names = {}
		for _, key in summary.titles do
			table.insert(names, Words.Titles[key] or key)
		end
		for _, line in summary.highlights do
			table.insert(names, line)
		end
		local extra = if #names > 0 then TITLE_ROW else 0
		self.titles.Text = table.concat(names, "   ")
		self.titles.Visible = #names > 0
		for i, labels in self.rows do
			local y = 8 + 30 + extra + (i - 1) * ROW
			labels.name.Position = UDim2.fromOffset(18, y)
			labels.value.Position = UDim2.fromOffset(WIDTH - 18 - 110, y)
		end
		-- The winner over the player, under the numbers, when someone else won.
		local rival, mine = summary.rival, summary.mine
		local below = 0
		if rival and mine then
			below = 6 + 2 * VERSUS_ROW
			self.versus[1].Text = Words.standing(rival.name, rival.tickets, rival.kos)
			self.versus[2].Text = Words.standing(Words.Me, mine.tickets, mine.kos)
		end
		for i, line in self.versus do
			line.Visible = below > 0
			line.Position = UDim2.fromOffset(18, 8 + 30 + extra + 4 * ROW + 6 + (i - 1) * VERSUS_ROW)
		end
		self.frame.Size = UDim2.fromOffset(WIDTH, 8 + 30 + extra + 4 * ROW + below + 10)
	end
	local y = math.max(Workspace.CurrentCamera.ViewportSize.Y * TOP, 130) + BELOW_BIG
	self.frame.Position = UDim2.new(0.5, 0, 0, y)
	local shown = self.summary or summary
	local share = math.clamp((os.clock() - (self.shownAt :: number)) / COUNT_SECONDS, 0, 1)
	for i, row in Words.resultRows(math.floor(shown.kos * share + 0.5), math.floor(shown.homers * share + 0.5), math.floor(shown.landed * share + 0.5), math.floor(shown.seconds * share), shown.pressed) do
		local labels = self.rows[i]
		if labels then
			labels.name.Text = row[1]
			labels.value.Text = row[2]
		end
	end
end

return ResultCard
