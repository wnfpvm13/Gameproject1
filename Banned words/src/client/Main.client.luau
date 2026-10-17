-- 금칙어 게임 Korean client entry point: HUD, word bubbles and transcript forwarding.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local remotes = shared:WaitForChild("Remotes")
local Config = require(shared:WaitForChild("Config"))
local Judge = require(shared:WaitForChild("Judge"))
local Hud = require(script:WaitForChild("Hud"))
local Fx = require(script:WaitForChild("Fx"))
local Billboards = require(script:WaitForChild("Billboards"))
local Speech = require(script:WaitForChild("Speech"))
local ShowCamera = require(script:WaitForChild("ShowCamera"))
local FlatVoice = require(script:WaitForChild("FlatVoice"))

local player = Players.LocalPlayer

local PHASE_TITLE = {
	Lobby = "대기 중",
	Countdown = "곧 시작",
	Assign = "금칙어 배정",
	Talk = "대화 중",
	Result = "결과",
}

local state = { phase = "Lobby", endsAt = 0, participants = {}, alive = {}, message = "" }
local lastWords: { [string]: string } = {}

local function isAlive(userId: number): boolean
	return table.find(state.alive, userId) ~= nil
end

local function isParticipant(userId: number): boolean
	return table.find(state.participants, userId) ~= nil
end

local function setResetAllowed(allowed: boolean)
	pcall(function()
		StarterGui:SetCore("ResetButtonCallback", allowed)
	end)
end

-- Keep seated participants from jumping out of their chair during a round.
local function applySeatLock()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local locked = (state.phase == "Assign" or state.phase == "Talk") and isAlive(player.UserId)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not locked)
	setResetAllowed(not locked)
end

-- Voice readiness: connect voice, say anything once (mic test), then you can take a seat next round.
local micTested = false
local readySent: boolean? = nil

local function inMyRound(): boolean
	return (state.phase == "Assign" or state.phase == "Talk") and isParticipant(player.UserId)
end

local function updateReady()
	local status = Speech.status()
	local voiceOk = status == "Listening" or status == "Speaking"
	local isReady = micTested and voiceOk
	if isReady ~= readySent then
		readySent = isReady
		remotes.Ready:FireServer(isReady)
	end
	if inMyRound() then
		Hud.setMicTest("", true)
	elseif status == "NoVoice" then
		Hud.setMicTest("음성 채팅을 쓸 수 없는 계정이라 관전만 할 수 있어요", false)
	elseif status == "Disconnected" then
		Hud.setMicTest("음성을 연결하면 다음 판부터 참가할 수 있어요", false)
	elseif status == "Muted" then
		Hud.setMicTest("마이크를 켜 주세요", false)
	elseif not micTested then
		Hud.setMicTest("마이크 테스트 · 아무 말이나 해 보세요", false)
	else
		local count = state.readyCount
		Hud.setMicTest(if count then string.format("준비 완료! (준비된 사람 %d명)", count) else "준비 완료!", true)
	end
end

Hud.build()
Hud.buildVote(function(choice)
	remotes.Vote:FireServer(choice)
end)
Fx.init()
FlatVoice.start()
Speech.onStatus(function(status)
	Hud.setVoice(status)
	updateReady()
end)
task.spawn(Speech.start, player:WaitForChild("PlayerGui"))

-- Only alive participants (panelists and the guest) are judged; eliminated players and spectators just watch.
Speech.onText(function(text)
	if not micTested then
		micTested = true
		Hud.toast("마이크 확인 완료!", "info")
		updateReady()
	end
	if state.phase == "Talk" and isParticipant(player.UserId) and isAlive(player.UserId) then
		remotes.Transcript:FireServer(text)
	end
end)

remotes.RoundState.OnClientEvent:Connect(function(newState)
	local previous = state.phase
	state = newState
	Hud.setStatus(PHASE_TITLE[state.phase] .. " · " .. state.message)
	Hud.setAlive(state.panelAlive, state.panelTotal)
	Hud.setVote(state.phase == "Countdown", state.votes, state.readyCount)
	updateReady()
	if state.phase == "Lobby" or (state.phase == "Countdown" and previous == "Result") then
		Billboards.clear()
	end
	if state.phase == "Talk" and previous ~= "Talk" then
		Hud.toast("대화 시작!", "info")
	end
	local inRound = state.phase == "Assign" or state.phase == "Talk"
	if inRound then
		Billboards.show(lastWords, state.alive, state.guestId)
	end
	ShowCamera.set(inRound)

	local me = player.UserId
	local role = ""
	if inRound and me == state.guestId then
		role = "게스트 · 대화하며 패널의 금칙어를 말해 보세요. 날릴수록 점수! (단어 나열은 금지)"
	elseif inRound and isParticipant(me) and not isAlive(me) then
		role = "탈락 · 관전 중이에요 (내 목소리는 관전자끼리만 들려요)"
	elseif inRound and not isParticipant(me) then
		role = "관전 중 · 다음 판에 참가해요 (내 목소리는 관전자끼리만 들려요)"
	elseif inRound and state.mode == "talkshow" then
		role = "패널 · 힌트로 게스트가 남의 금칙어를 말하게! 직접 말하면 반칙"
	end
	Hud.setRole(role)
	if state.phase ~= "Talk" then
		Hud.hideCard()
	end
	applySeatLock()
end)

remotes.Words.OnClientEvent:Connect(function(words)
	lastWords = words
	Billboards.show(words, state.participants, state.guestId)
end)

remotes.Eliminated.OnClientEvent:Connect(function(info)
	local who = if info.userId == player.UserId then "내가" else info.name .. "님이"
	local whom = if info.userId == player.UserId then "내가" else info.name .. "님"
	local launched = info.reason == "said" or info.reason == "silent" or info.reason == "guest" or info.reason == "foul"
	if launched then
		Billboards.alarm(info.userId)
		Fx.elimination(Players:GetPlayerByUserId(info.userId))
		local text
		if info.reason == "said" then
			text = string.format("삐! %s 금칙어 \"%s\"%s 말했어요", who, info.word, Judge.josa(info.word, "을", "를"))
		elseif info.reason == "guest" then
			text = string.format("삐! 게스트 %s님이 \"%s\"%s 말해서 %s 날아가요", info.guestName or "", info.word, Judge.josa(info.word, "을", "를"), whom)
		elseif info.reason == "foul" then
			local said = info.saidWord or ""
			text = string.format("반칙! %s 남의 금칙어 \"%s\"%s 직접 말했어요", who, said, Judge.josa(said, "을", "를"))
		else
			text = string.format("삐! %s 질문에 대답하지 않았어요 (금칙어 \"%s\")", who, info.word)
		end
		if info.assistName then
			text ..= string.format("\n유도: %s +%d점", info.assistName, Config.SCORE_ASSIST)
		end
		Hud.toast(text, "elim")
	else
		Billboards.remove(info.userId)
	end
end)

remotes.Suspect.OnClientEvent:Connect(function(info)
	Hud.toast(string.format("아슬아슬! %s", info.name), "near")
end)

remotes.QuestionCard.OnClientEvent:Connect(function(info)
	Hud.showCard(info.name, info.userId == player.UserId, info.question, info.deadline)
end)

remotes.CardResult.OnClientEvent:Connect(function(info)
	Hud.hideCard()
	local who = if info.userId == player.UserId then "나" else info.name
	if info.outcome == "warn" then
		Hud.toast(string.format("경고! %s · 한 번 더 대답 안 하면 탈락", who), "near")
	elseif info.outcome == "unheard" then
		Hud.toast(string.format("%s · 목소리는 들렸는데 인식이 안 됐어요. 이번엔 넘어가요", who), "near")
	end
end)

remotes.Notice.OnClientEvent:Connect(function(info)
	Hud.toast(info.text, "near")
end)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	applySeatLock()
	ShowCamera.reapply()
	if state.phase == "Assign" or state.phase == "Talk" then
		Billboards.show(lastWords, state.alive, state.guestId)
	end
end)

local lastPing = 0
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local remaining = state.endsAt - now
	Hud.setTimer(if state.phase ~= "Lobby" and remaining > 0 then remaining else nil)
	Hud.tickCard(now, Config.QUESTION_ANSWER_TIME)
	-- Tell the server the mic hears speech, so a card missed by the recognizer is not counted as silence.
	if state.phase == "Talk" and isAlive(player.UserId) and Speech.isSpeaking() and now - lastPing >= Config.VOICE_PING_INTERVAL then
		lastPing = now
		remotes.VoicePing:FireServer()
	end
end)

-- Ask for the current state now that every handler is connected (late joiners miss earlier broadcasts).
remotes.Sync:FireServer()
