--!strict
-- Top-centre round status, voice connection banner and centre toasts (elimination / near miss).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BannedWords"):WaitForChild("Config"))

local Hud = {}

local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local REGULAR = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular)
local WHITE = Color3.fromRGB(240, 240, 245)
local GREY = Color3.fromRGB(170, 175, 185)
local RED = Color3.fromRGB(255, 110, 110)
local AMBER = Color3.fromRGB(255, 200, 90)
local GREEN = Color3.fromRGB(120, 220, 140)

local gui: ScreenGui
local statusL: TextLabel
local timerL: TextLabel
local aliveL: TextLabel
local voiceL: TextLabel
local toastL: TextLabel
local ghostL: TextLabel
local card: Frame
local cardTitleL: TextLabel
local cardQuestionL: TextLabel
local cardBar: Frame
local cardDeadline = 0

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.Text = ""
	local c = Instance.new("UITextSizeConstraint", l)
	c.MaxTextSize = size
	l.Parent = parent
	return l
end

function Hud.build()
	gui = Instance.new("ScreenGui")
	gui.Name = "BannedWordsHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local top = Instance.new("Frame")
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.new(0.5, 0, 0, 86)
	top.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	top.BackgroundTransparency = 0.2
	top.Parent = gui
	Instance.new("UICorner", top).CornerRadius = UDim.new(0, 14)
	local limit = Instance.new("UISizeConstraint", top)
	limit.MinSize = Vector2.new(300, 0)
	limit.MaxSize = Vector2.new(560, 200)

	statusL = label(top, BOLD, 26, WHITE)
	statusL.Position = UDim2.fromScale(0.04, 0.06)
	statusL.Size = UDim2.fromScale(0.92, 0.46)
	timerL = label(top, BOLD, 22, AMBER)
	timerL.Position = UDim2.fromScale(0.04, 0.55)
	timerL.Size = UDim2.fromScale(0.45, 0.38)
	timerL.TextXAlignment = Enum.TextXAlignment.Left
	aliveL = label(top, REGULAR, 20, GREY)
	aliveL.Position = UDim2.fromScale(0.51, 0.55)
	aliveL.Size = UDim2.fromScale(0.45, 0.38)
	aliveL.TextXAlignment = Enum.TextXAlignment.Right

	voiceL = label(gui, BOLD, 20, RED)
	voiceL.AnchorPoint = Vector2.new(0.5, 0)
	voiceL.Position = UDim2.new(0.5, 0, 0, 100)
	voiceL.Size = UDim2.new(0.6, 0, 0, 30)

	toastL = label(gui, BOLD, 48, WHITE)
	toastL.AnchorPoint = Vector2.new(0.5, 0.5)
	toastL.Position = UDim2.fromScale(0.5, 0.42)
	toastL.Size = UDim2.fromScale(0.8, 0.14)
	toastL.TextStrokeTransparency = 0.3
	toastL.TextTransparency = 1
	toastL.TextStrokeTransparency = 1

	ghostL = label(gui, BOLD, 20, Color3.fromRGB(170, 200, 255))
	ghostL.AnchorPoint = Vector2.new(0.5, 0)
	ghostL.Position = UDim2.new(0.5, 0, 0, 132)
	ghostL.Size = UDim2.new(0.6, 0, 0, 28)

	-- Question card: bottom centre, with a draining time bar.
	card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -24)
	card.Size = UDim2.new(0.55, 0, 0, 110)
	card.BackgroundColor3 = Color3.fromRGB(255, 248, 225)
	card.Visible = false
	card.Parent = gui
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
	local cardLimit = Instance.new("UISizeConstraint", card)
	cardLimit.MinSize = Vector2.new(320, 0)
	cardLimit.MaxSize = Vector2.new(640, 200)
	cardTitleL = label(card, BOLD, 22, Color3.fromRGB(200, 90, 40))
	cardTitleL.Position = UDim2.fromScale(0.04, 0.08)
	cardTitleL.Size = UDim2.fromScale(0.92, 0.3)
	cardQuestionL = label(card, BOLD, 30, Color3.fromRGB(40, 40, 50))
	cardQuestionL.Position = UDim2.fromScale(0.04, 0.38)
	cardQuestionL.Size = UDim2.fromScale(0.92, 0.38)
	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromScale(0.04, 0.82)
	barBack.Size = UDim2.fromScale(0.92, 0.08)
	barBack.BackgroundColor3 = Color3.fromRGB(230, 220, 195)
	barBack.Parent = card
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
	cardBar = Instance.new("Frame")
	cardBar.Size = UDim2.fromScale(1, 1)
	cardBar.BackgroundColor3 = Color3.fromRGB(240, 140, 60)
	cardBar.Parent = barBack
	Instance.new("UICorner", cardBar).CornerRadius = UDim.new(1, 0)
end

function Hud.showCard(targetName: string, isMe: boolean, question: string, deadline: number)
	cardTitleL.Text = if isMe then "나에게 질문! 두 마디 이상으로 대답하세요" else targetName .. "님에게 질문!"
	cardQuestionL.Text = question
	cardDeadline = deadline
	card.Visible = true
end

function Hud.hideCard()
	card.Visible = false
end

-- Called every frame: drains the card's time bar.
function Hud.tickCard(now: number, total: number)
	if not card.Visible then
		return
	end
	local left = cardDeadline - now
	if left <= 0 then
		card.Visible = false
		return
	end
	cardBar.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
end

-- One line under the status board explaining what I should be doing (ghost / guest / panelist).
function Hud.setRole(text: string)
	ghostL.Text = text
end

-- Mode vote during the countdown. Talk show is locked until enough ready players are in the server.
local voteFrame: Frame? = nil
local voteButtons: { [string]: TextButton } = {}
local talkshowAllowed = true
local IDLE_COLOR = Color3.fromRGB(40, 48, 64)
local PICKED_COLOR = Color3.fromRGB(240, 140, 60)
local LOCKED_COLOR = Color3.fromRGB(70, 72, 78)
local VOTE_LABELS = { classic = "클래식", talkshow = string.format("토크쇼 (%d명+)", Config.TALKSHOW_MIN_PLAYERS) }

function Hud.buildVote(onVote: (string) -> ())
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -24)
	frame.Size = UDim2.new(0.5, 0, 0, 64)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui
	local limit = Instance.new("UISizeConstraint", frame)
	limit.MinSize = Vector2.new(300, 0)
	limit.MaxSize = Vector2.new(460, 64)
	for i, choice in { "classic", "talkshow" } do
		local b = Instance.new("TextButton")
		b.Position = UDim2.new((i - 1) * 0.52, 0, 0, 0)
		b.Size = UDim2.new(0.48, 0, 1, 0)
		b.BackgroundColor3 = Color3.fromRGB(40, 48, 64)
		b.FontFace = BOLD
		b.TextColor3 = WHITE
		b.TextScaled = true
		b.Text = VOTE_LABELS[choice]
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 14)
		local c = Instance.new("UITextSizeConstraint", b)
		c.MaxTextSize = 24
		local pad = Instance.new("UIPadding", b)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		b.Activated:Connect(function()
			if choice == "talkshow" and not talkshowAllowed then
				return
			end
			onVote(choice)
			for other, button in voteButtons do
				if other == "talkshow" and not talkshowAllowed then
					continue
				end
				button.BackgroundColor3 = if other == choice then PICKED_COLOR else IDLE_COLOR
			end
		end)
		b.Parent = frame
		voteButtons[choice] = b
	end
	voteFrame = frame
end

function Hud.setVote(visible: boolean, counts: { classic: number, talkshow: number }?, readyCount: number?)
	if not voteFrame then
		return
	end
	voteFrame.Visible = visible
	if not visible then
		for _, button in voteButtons do
			button.BackgroundColor3 = IDLE_COLOR
		end
		return
	end
	talkshowAllowed = (readyCount or 0) >= Config.TALKSHOW_MIN_PLAYERS
	if counts then
		voteButtons.classic.Text = string.format("%s · %d표", VOTE_LABELS.classic, counts.classic)
		voteButtons.talkshow.Text = if talkshowAllowed
			then string.format("%s · %d표", VOTE_LABELS.talkshow, counts.talkshow)
			else string.format("토크쇼 · %d명부터", Config.TALKSHOW_MIN_PLAYERS)
	end
	if not talkshowAllowed then
		voteButtons.talkshow.BackgroundColor3 = LOCKED_COLOR
	end
	voteButtons.talkshow.AutoButtonColor = talkshowAllowed
end

-- Mic test in the lobby: what the player should do next to become ready.
local micTestL: TextLabel? = nil

function Hud.setMicTest(text: string, done: boolean)
	if not micTestL then
		local l = label(gui, BOLD, 20, AMBER)
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, 164)
		l.Size = UDim2.new(0.6, 0, 0, 28)
		micTestL = l
	end
	local l = micTestL :: TextLabel
	l.Text = text
	l.TextColor3 = if done then GREEN else AMBER
end

function Hud.setStatus(text: string)
	statusL.Text = text
end

function Hud.setTimer(seconds: number?)
	if not seconds then
		timerL.Text = ""
		return
	end
	local s = math.max(0, math.ceil(seconds))
	timerL.Text = string.format("%d:%02d", s // 60, s % 60)
	timerL.TextColor3 = if s <= 30 then RED else AMBER
end

function Hud.setAlive(alive: number, total: number)
	aliveL.Text = if total > 0 then string.format("생존 %d / %d", alive, total) else ""
end

function Hud.setVoice(status: string)
	if status == "NoVoice" then
		voiceL.Text = "음성 채팅을 쓸 수 없는 계정이에요 (만 13세 이상 + 연령 인증 필요)"
	elseif status == "Disconnected" then
		voiceL.Text = "음성 채팅 연결 필요 · 왼쪽 위 ≡ 메뉴(또는 ESC) → 설정 → 음성 채팅 연결"
	elseif status == "Muted" then
		voiceL.Text = "마이크가 꺼져 있어요"
	else
		voiceL.Text = ""
	end
end

function Hud.toast(text: string, kind: "elim" | "near" | "info")
	toastL.Text = text
	toastL.TextColor3 = if kind == "elim" then RED elseif kind == "near" then AMBER else GREEN
	toastL.TextTransparency = 0
	toastL.TextStrokeTransparency = 0.3
	local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2)
	TweenService:Create(toastL, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

return Hud
