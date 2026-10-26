--!strict
-- Status board at the top centre: phase + message, timer, my lives (hearts) and survivors. Kept short (64 px) so the
-- chair row under it stays visible.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
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
	local top = Style.panel(Style.gui(), Style.PAPER, Style.PAPER_ALPHA, 14)
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.new(0.5, 0, 0, 64)
	-- (at most the screen less 250 px each side where Roblox's player list sits open at the top right — a small PC window,
	-- review 2026-10-25; a phone keeps it folded, so the board keeps its width there)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(320, 0)
	limit.Parent = top
	local function fit()
		local camera = workspace.CurrentCamera
		local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local width = if not camera then 580 elseif phone then camera.ViewportSize.X * 0.6 else camera.ViewportSize.X - 500
		limit.MaxSize = Vector2.new(math.clamp(width, 320, 580), 200)
	end
	fit()
	local watched: Camera? = nil
	local function watch()
		local camera = workspace.CurrentCamera
		if camera and camera ~= watched then
			watched = camera
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
			fit()
		end
	end
	watch()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)

	statusL = Style.label(top, Style.BOLD, 22, Style.INK)
	statusL.Position = UDim2.fromScale(0.04, 0.06)
	statusL.Size = UDim2.fromScale(0.92, 0.46)
	timerL = Style.label(top, Style.BOLD, 22, Style.INK)
	timerL.Position = UDim2.fromScale(0.04, 0.55)
	timerL.Size = UDim2.fromScale(0.28, 0.38)
	timerL.TextXAlignment = Enum.TextXAlignment.Left
	livesL = Style.label(top, Style.BOLD, 22, Style.INK)
	livesL.Position = UDim2.fromScale(0.32, 0.55)
	livesL.Size = UDim2.fromScale(0.36, 0.38)
	livesL.RichText = true
	aliveL = Style.label(top, Style.REGULAR, 20, Style.FAINT)
	aliveL.Position = UDim2.fromScale(0.68, 0.55)
	aliveL.Size = UDim2.fromScale(0.28, 0.38)
	aliveL.TextXAlignment = Enum.TextXAlignment.Right
end

-- The message alone, or the phase's name when there is none (review 2026-10-25: "본 경기 · 본 경기 시작!", "결승 ·
-- 결승 퀴즈 · …" said the same thing twice).
function Hud.setStatus(phase: string, message: string)
	statusL.Text = if message ~= "" then message else PHASE_TITLE[phase] or phase
end

function Hud.setTimer(seconds: number?)
	if not seconds then
		timerL.Text = ""
		return
	end
	local s = math.max(0, math.ceil(seconds))
	timerL.Text = string.format("%d:%02d", s // 60, s % 60)
	timerL.TextColor3 = if s <= 30 then Style.RED_TEXT else Style.INK
end

-- The main game's count instead of a clock ("미션 3/6", owner 2026-10-24).
function Hud.setCount(game: number, games: number)
	timerL.Text = string.format(Config.TEXT.GAME_COUNT, math.max(1, game), games)
	timerL.TextColor3 = Style.INK
end

function Hud.setAlive(alive: number, total: number)
	aliveL.Text = if total > 0 then string.format("생존 %d / %d", alive, total) else ""
end

-- nil hides it (not playing this round); `role` shows instead of the hearts (the presenter).
function Hud.setMyLives(lives: number?, max: number, role: string?)
	livesL.Text = if role then role elseif lives then "내 목숨 " .. Hearts.text(lives, max) else ""
end

return Hud
