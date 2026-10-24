--!strict
-- The round on screen: one line at the top (waiting, the count-down, how many are left and the time, the winner, or
-- "out, watching") and the player's knock-offs under it. Reads the Workspace round attributes each frame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local RoundHud = {}
RoundHud.__index = RoundHud

type Fields = { gui: ScreenGui, main: TextLabel, small: TextLabel }
export type Hud = typeof(setmetatable({} :: Fields, RoundHud))

local function label(parent: Instance, name: string, y: number, height: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, y)
	text.Size = UDim2.fromOffset(520, height)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Text = ""
	text.Parent = parent
	return text
end

function RoundHud.new(playerGui: Instance): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlHud"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local fields: Fields = { gui = gui, main = label(gui, "Main", 12, 44), small = label(gui, "Small", 58, 24) }
	return setmetatable(fields, RoundHud)
end

-- Every frame. now: server time; standing: "in" (still in the round), "out" (knocked out of it) or "watching"
-- (came in during it); kos: the player's knock-offs.
function RoundHud.update(self: Hud, now: number, standing: string, kos: number)
	local phase = Workspace:GetAttribute(Names.Phase)
	local endsAt = PartUtil.number(Workspace, Names.PhaseEndsAt) or 0
	local left = math.max(0, math.ceil(endsAt - now))
	local count = PartUtil.number(Workspace, Names.AliveCount) or 0
	local text, small = "", ""
	if phase == "Countdown" then
		text = tostring(math.max(1, left))
	elseif phase == "Fight" then
		if standing == "in" then
			text = string.format("남은 사람 %d · %d:%02d", count, left // 60, left % 60)
			small = string.format("떨어뜨린 수 %d", kos)
		elseif standing == "out" then
			text = string.format("탈락! 관전 중 · 남은 사람 %d", count)
		else
			text = string.format("관전 중 · 다음 판부터 · 남은 사람 %d", count)
		end
	elseif phase == "Ended" then
		local winner = Workspace:GetAttribute(Names.Winner)
		text = if typeof(winner) == "string" and winner ~= "" then winner .. " 승리!" else "무승부!"
	else
		-- The server starts when enough are in (sandbags count in Studio practice).
		local solo = RunService:IsStudio() and Workspace:GetAttribute(Names.Solo) == true
		local enough = #Players:GetPlayers() + (if solo then Config.Sandbag.Count else 0) >= Config.Round.MinPlayers
		text = if enough then "대기 중 · 곧 다음 판" else "다른 사람을 기다리는 중"
	end
	if self.main.Text ~= text then
		self.main.Text = text
	end
	if self.small.Text ~= small then
		self.small.Text = small
	end
end

return RoundHud
