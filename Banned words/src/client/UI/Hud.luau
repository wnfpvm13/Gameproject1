--!strict
-- Status board at the top centre: phase + message, timer, my lives (hearts) and survivors. Kept short (64 px) so the
-- chair row under it stays visible.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hearts = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Hearts"))
local Style = require(script.Parent:WaitForChild("Style"))

local Hud = {}

local PHASE_TITLE = {
	Lobby = "대기 중",
	Countdown = "곧 시작",
	Assign = "자리 배정",
	Play = "본 경기", -- not "게임": a word-bank word, and players read this aloud
	Final = "결승",
	Result = "결과",
}

local statusL: TextLabel
local timerL: TextLabel
local aliveL: TextLabel
local livesL: TextLabel

function Hud.build()
	local top = Style.panel(Style.gui(), Style.PANEL, 0.2, 14)
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.new(0.5, 0, 0, 64)
	Style.limit(top, Vector2.new(320, 0), Vector2.new(580, 200))

	statusL = Style.label(top, Style.BOLD, 22, Style.WHITE)
	statusL.Position = UDim2.fromScale(0.04, 0.06)
	statusL.Size = UDim2.fromScale(0.92, 0.46)
	timerL = Style.label(top, Style.BOLD, 22, Style.AMBER)
	timerL.Position = UDim2.fromScale(0.04, 0.55)
	timerL.Size = UDim2.fromScale(0.28, 0.38)
	timerL.TextXAlignment = Enum.TextXAlignment.Left
	livesL = Style.label(top, Style.BOLD, 22, Style.WHITE)
	livesL.Position = UDim2.fromScale(0.32, 0.55)
	livesL.Size = UDim2.fromScale(0.36, 0.38)
	livesL.RichText = true
	aliveL = Style.label(top, Style.REGULAR, 20, Style.GREY)
	aliveL.Position = UDim2.fromScale(0.68, 0.55)
	aliveL.Size = UDim2.fromScale(0.28, 0.38)
	aliveL.TextXAlignment = Enum.TextXAlignment.Right
end

function Hud.setStatus(phase: string, message: string)
	statusL.Text = (PHASE_TITLE[phase] or phase) .. (if message ~= "" then " · " .. message else "")
end

function Hud.setTimer(seconds: number?)
	if not seconds then
		timerL.Text = ""
		return
	end
	local s = math.max(0, math.ceil(seconds))
	timerL.Text = string.format("%d:%02d", s // 60, s % 60)
	timerL.TextColor3 = if s <= 30 then Style.RED else Style.AMBER
end

function Hud.setAlive(alive: number, total: number)
	aliveL.Text = if total > 0 then string.format("생존 %d / %d", alive, total) else ""
end

-- nil hides it (not playing this round).
function Hud.setMyLives(lives: number?, max: number)
	livesL.Text = if lives then "내 목숨 " .. Hearts.text(lives, max) else ""
end

return Hud
