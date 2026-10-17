-- Live STT test (client): shows a sentence, transcribes the player's own mic with AudioSpeechToText,
-- judges it with the shared Judge module and reports each result to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("SttLiveTest")
local Judge = require(shared:WaitForChild("Judge"))
local ITEMS = require(shared:WaitForChild("LiveTestItems"))
local resultEvent = shared:WaitForChild("SttResult")
local player = Players.LocalPlayer

local AUTO_NEXT_DELAY = 1.8
local COLLECT_WINDOW = 1.2 -- extra seconds to gather split transcripts after the first one
local NO_TEXT_AFTER_VOICE = 5

local platform = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and "mobile" or "desktop"

-- UI -------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SttLiveTestGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.fromScale(0.5, 0.08)
panel.Size = UDim2.fromScale(0.9, 0.62)
panel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
panel.BackgroundTransparency = 0.1
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local sizeLimit = Instance.new("UISizeConstraint", panel)
sizeLimit.MaxSize = Vector2.new(900, 640)

local white = Color3.fromRGB(240, 240, 245)
local grey = Color3.fromRGB(160, 165, 175)
local green = Color3.fromRGB(120, 220, 140)
local amber = Color3.fromRGB(255, 200, 90)
local red = Color3.fromRGB(255, 120, 120)

local function label(name, y, h, size, color, bold)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0.05, y)
	l.Size = UDim2.fromScale(0.9, h)
	l.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", if bold then Enum.FontWeight.Bold else Enum.FontWeight.Regular)
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.Text = ""
	local c = Instance.new("UITextSizeConstraint", l)
	c.MaxTextSize = size
	l.Parent = panel
	return l
end

local titleL = label("Title", 0.03, 0.07, 24, grey, true)
local progressL = label("Progress", 0.10, 0.06, 20, grey, false)
local guideL = label("Guide", 0.17, 0.06, 22, grey, false)
local sayL = label("Say", 0.24, 0.20, 56, white, true)
local wordL = label("Word", 0.45, 0.06, 22, amber, false)
local micL = label("Mic", 0.52, 0.06, 22, grey, false)
local heardL = label("Heard", 0.59, 0.10, 26, white, false)
local resultL = label("Result", 0.70, 0.08, 30, white, true)
titleL.Text = "금칙어 게임 Korean · 음성 인식 테스트"

local function button(text, x)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Position = UDim2.fromScale(x, 0.82)
	b.Size = UDim2.fromScale(0.28, 0.12)
	b.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
	b.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	b.TextColor3 = white
	b.TextScaled = true
	b.Text = text
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	local c = Instance.new("UITextSizeConstraint", b)
	c.MaxTextSize = 26
	local m = Instance.new("UISizeConstraint", b)
	m.MinSize = Vector2.new(96, 44)
	b.Parent = panel
	return b
end
local retryB = button("다시 읽기", 0.3)
local skipB = button("건너뛰기", 0.7)

-- Mic --------------------------------------------------------------------------
local input = player:WaitForChild("AudioDeviceInput", 20)
if not input then
	guideL.Text = "마이크를 찾지 못했어요. 음성 채팅이 켜진 계정인지 확인해 주세요."
	return
end
local stt = Instance.new("AudioSpeechToText")
stt.Enabled = true
stt.Parent = gui
local wire = Instance.new("Wire")
wire.SourceInstance = input
wire.TargetInstance = stt
wire.Parent = stt

-- Flow -------------------------------------------------------------------------
local idx = 1
local state = "listening" -- listening | judged | waiting_choice | finished
local texts = {}
local firstTextAt = nil
local lastVoiceEndAt = nil
local voiceSeenAt = nil
local token = 0
local counts = { CONFIRMED = 0, SUSPECT = 0, NONE = 0, EMPTY = 0 }

local function refreshMic()
	if input.Muted then
		micL.Text = "마이크 꺼짐 · 왼쪽 위 마이크 아이콘을 눌러 켜 주세요"
		micL.TextColor3 = red
	elseif stt.VoiceDetected then
		micL.Text = "● 말하는 중..."
		micL.TextColor3 = green
	else
		micL.Text = "듣고 있어요"
		micL.TextColor3 = grey
	end
end

local function showItem()
	token += 1
	texts, firstTextAt, lastVoiceEndAt, voiceSeenAt = {}, nil, nil, nil
	local item = ITEMS[idx]
	state = "listening"
	progressL.Text = string.format("%d / %d  ·  성공 %d  아슬 %d  실패 %d  빈 결과 %d", idx, #ITEMS, counts.CONFIRMED, counts.SUSPECT, counts.NONE, counts.EMPTY)
	guideL.Text = if item.kind == "single" then "이 단어 하나만 말해 주세요" else "아래 문장을 소리 내어 읽어 주세요"
	sayL.Text = item.say
	wordL.Text = "금칙어: " .. item.word
	heardL.Text = ""
	resultL.Text = ""
	retryB.Visible = true
	skipB.Visible = true
end

local function record(status, text, latency)
	local item = ITEMS[idx]
	counts[status] += 1
	resultEvent:FireServer({
		i = idx,
		word = item.word,
		say = item.say,
		kind = item.kind,
		text = text,
		status = status,
		latency = latency,
		platform = platform,
	})
end

local function finish()
	state = "finished"
	local judged = counts.CONFIRMED + counts.SUSPECT + counts.NONE + counts.EMPTY
	guideL.Text = "테스트 끝! 고마워요"
	sayL.Text = string.format("성공 %d / %d", counts.CONFIRMED, judged)
	wordL.Text = string.format("아슬아슬 %d · 실패 %d · 빈 결과 %d", counts.SUSPECT, counts.NONE, counts.EMPTY)
	heardL.Text = "결과는 서버에 저장됐어요. 이 화면을 캡처해 두셔도 좋아요."
	resultL.Text = ""
	retryB.Visible = false
	skipB.Visible = false
end

local function advance()
	idx += 1
	if idx > #ITEMS then
		finish()
	else
		showItem()
	end
end

local function judge()
	if state ~= "listening" then
		return
	end
	local item = ITEMS[idx]
	-- STT sometimes repeats the same sentence; keep unique pieces only.
	local unique, seen = {}, {}
	for _, t in texts do
		if not seen[t] then
			seen[t] = true
			table.insert(unique, t)
		end
	end
	local text = table.concat(unique, " ")
	local status = Judge.classify(item.word, text)
	local latency = if lastVoiceEndAt and firstTextAt then math.max(0, firstTextAt - lastVoiceEndAt) else -1
	state = "judged"
	heardL.Text = "들린 문장: " .. text
	if status == "CONFIRMED" then
		resultL.Text = "인식 성공"
		resultL.TextColor3 = green
	elseif status == "SUSPECT" then
		resultL.Text = "아슬아슬 (띄어쓰기만 다름)"
		resultL.TextColor3 = amber
	else
		resultL.Text = "금칙어를 못 잡았어요"
		resultL.TextColor3 = red
	end
	record(status, text, latency)
	local myToken = token
	task.delay(AUTO_NEXT_DELAY, function()
		if token == myToken and state == "judged" then
			advance()
		end
	end)
end

stt:GetPropertyChangedSignal("Text"):Connect(function()
	local t = stt.Text
	if t == "" then
		return
	end
	stt.Text = ""
	if state ~= "listening" then
		return
	end
	table.insert(texts, t)
	if not firstTextAt then
		firstTextAt = os.clock()
		local myToken = token
		task.delay(COLLECT_WINDOW, function()
			if token == myToken then
				judge()
			end
		end)
	end
end)

stt:GetPropertyChangedSignal("VoiceDetected"):Connect(function()
	refreshMic()
	if stt.VoiceDetected then
		voiceSeenAt = voiceSeenAt or os.clock()
		return
	end
	if state ~= "listening" then
		return
	end
	lastVoiceEndAt = os.clock()
	local myToken = token
	task.delay(NO_TEXT_AFTER_VOICE, function()
		if token == myToken and state == "listening" and #texts == 0 then
			state = "waiting_choice"
			heardL.Text = "목소리는 들렸는데 글자가 안 나왔어요"
			resultL.Text = "다시 읽기 또는 건너뛰기를 눌러 주세요"
			resultL.TextColor3 = grey
		end
	end)
end)
input:GetPropertyChangedSignal("Muted"):Connect(refreshMic)

retryB.Activated:Connect(function()
	if state ~= "finished" then
		showItem()
	end
end)
skipB.Activated:Connect(function()
	if state == "finished" then
		return
	end
	if (state == "listening" or state == "waiting_choice") and voiceSeenAt then
		-- voice heard but no text = the "empty" case we want to count; a skip without speaking is not recorded
		record("EMPTY", "", -1)
	end
	advance()
end)

refreshMic()
showItem()
