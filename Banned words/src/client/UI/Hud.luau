--!strict
-- Status board at the top centre: phase + message, timer, my lives (hearts) and survivors. Kept short (64 px) so the
-- chair row under it stays visible.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local modeL: TextLabel -- the round's difficulty mode, a tag on the board's top edge (bundle 11b)
local timerL: TextLabel
local aliveL: TextLabel
local livesL: TextLabel

-- Returns the board (the sound settings key sits on its right edge, bundle 11a).
function Hud.build(): Frame
	local top = Style.panel(Style.gui(), Style.PAPER, Style.PAPER_ALPHA, 14)
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, Style.BOARD_TOP)
	top.Size = UDim2.new(0.5, 0, 0, Style.BOARD_HEIGHT)
	-- (smaller on a phone, with the mode tag and the settings key on it; the rows under it follow: Style.row)
	local scale = Instance.new("UIScale")
	scale.Scale = Style.BOARD_SCALE
	scale.Parent = top
	-- (at most the screen less 250 px each side where Roblox's player list sits open at the top right — a small PC window,
	-- review 2026-10-25; a phone keeps it folded, so the board keeps its width there — and 30 px more for the settings
	-- key that sticks out of its right edge, bundle 11a)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(320, 0)
	limit.Parent = top
	local function fit()
		local camera = workspace.CurrentCamera
		local phone = Style.PHONE
		local width = if not camera then 580 elseif phone then camera.ViewportSize.X * 0.6 else camera.ViewportSize.X - 560
		local board = math.clamp(width, 320, 580)
		limit.MaxSize = Vector2.new(board, 200)
		-- (a PC window too narrow for even the smallest board: it moves left until the key's right end, 28 px past the
		-- board, stops 250 px from the screen's edge — review 2026-10-27)
		local shift = 0
		if camera and not phone then
			local viewport = camera.ViewportSize.X
			shift = math.min(0, (viewport - 250) - (viewport / 2 + board / 2 + 28))
			-- (but never off the left edge: on a very narrow window the board wins over the player list's room)
			shift = math.max(shift, 8 - (viewport / 2 - board / 2))
		end
		top.Position = UDim2.new(0.5, shift, 0, Style.BOARD_TOP)
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
	-- (30 px kept free at each end of the top line and at the right of the second: the settings key sits there)
	statusL.Position = UDim2.new(0.04, 30, 0.06, 0)
	statusL.Size = UDim2.new(0.92, -60, 0.46, 0)
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
	aliveL.Size = UDim2.new(0.28, -30, 0.38, 0)
	aliveL.TextXAlignment = Enum.TextXAlignment.Right
	-- (on the top edge, mostly above it: the board's two lines stay as they are)
	modeL = Instance.new("TextLabel")
	modeL.Name = "Mode"
	modeL.AnchorPoint = Vector2.new(0.5, 1)
	modeL.Position = UDim2.fromOffset(0, 5) + UDim2.fromScale(0.5, 0)
	modeL.Size = UDim2.fromOffset(0, 20)
	modeL.AutomaticSize = Enum.AutomaticSize.X
	modeL.BackgroundColor3 = Style.KEY
	modeL.BorderSizePixel = 0
	modeL.FontFace = Style.BOLD
	modeL.TextSize = 14
	modeL.TextColor3 = Style.INK
	modeL.Text = ""
	modeL.Visible = false
	modeL.ZIndex = 2
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = modeL
	Style.round(modeL, 10)
	modeL.Parent = top
	return top
end

-- The round's mode name, or nil / "" for none (between rounds).
function Hud.setMode(text: string?)
	modeL.Text = text or ""
	modeL.Visible = modeL.Text ~= ""
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
