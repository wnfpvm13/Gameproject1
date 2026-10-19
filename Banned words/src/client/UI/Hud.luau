--!strict
-- Status board at the top centre: phase + message (+ my role), timer, survivors, and how many words I have
-- (never which). Kept short (64 px) so the far side of the ring stays visible under it.
local Style = require(script.Parent:WaitForChild("Style"))

local Hud = {}

local PHASE_TITLE = {
	Lobby = "대기 중",
	Countdown = "곧 시작",
	Assign = "금칙어 배정",
	Talk = "대화 중",
	Result = "결과",
}

local statusL: TextLabel
local timerL: TextLabel
local aliveL: TextLabel
local mineL: TextLabel

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
	mineL = Style.label(top, Style.BOLD, 20, Style.AMBER)
	mineL.Position = UDim2.fromScale(0.32, 0.55)
	mineL.Size = UDim2.fromScale(0.36, 0.38)
	aliveL = Style.label(top, Style.REGULAR, 20, Style.GREY)
	aliveL.Position = UDim2.fromScale(0.68, 0.55)
	aliveL.Size = UDim2.fromScale(0.28, 0.38)
	aliveL.TextXAlignment = Enum.TextXAlignment.Right
end

function Hud.setStatus(phase: string, message: string, myRole: string?)
	local text = (PHASE_TITLE[phase] or phase) .. (if message ~= "" then " · " .. message else "")
	if myRole then
		text ..= " · 내 역할: " .. myRole
	end
	statusL.Text = text
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

-- count = 0 hides it (not playing).
function Hud.setMyWords(count: number)
	mineL.Text = if count > 0 then string.format("내 금칙어 ??? × %d", count) else ""
end

return Hud
