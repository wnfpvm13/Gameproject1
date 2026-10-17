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

Hud.build()
Hud.buildVote(function(choice)
	remotes.Vote:FireServer(choice)
end)
Fx.init()
FlatVoice.start()
Speech.onStatus(Hud.setVoice)
task.spawn(Speech.start, player:WaitForChild("PlayerGui"))

-- Eliminated participants keep sending too: as ghosts their speech counts toward assists.
Speech.onText(function(text)
	if state.phase == "Talk" and isParticipant(player.UserId) then
		remotes.Transcript:FireServer(text)
	end
end)

remotes.RoundState.OnClientEvent:Connect(function(newState)
	local previous = state.phase
	state = newState
	Hud.setStatus(PHASE_TITLE[state.phase] .. " · " .. state.message)
	Hud.setAlive(state.panelAlive, state.panelTotal)
	Hud.setVote(state.phase == "Countdown", state.votes)
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
		role = "게스트 · 대화하며 패널의 금칙어를 말해 보세요. 날릴수록 점수!"
	elseif state.phase == "Talk" and isParticipant(me) and not isAlive(me) then
		role = "유령 모드 · 계속 말해서 다른 사람을 날리면 점수!"
	elseif inRound and state.mode == "talkshow" and isAlive(me) then
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
	if info.outcome == "warn" then
		local who = if info.userId == player.UserId then "나" else info.name
		Hud.toast(string.format("경고! %s · 한 번 더 대답 안 하면 탈락", who), "near")
	end
end)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	applySeatLock()
	ShowCamera.reapply()
	if state.phase == "Assign" or state.phase == "Talk" then
		Billboards.show(lastWords, state.alive)
	end
end)

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local remaining = state.endsAt - now
	Hud.setTimer(if state.phase ~= "Lobby" and remaining > 0 then remaining else nil)
	Hud.tickCard(now, Config.QUESTION_ANSWER_TIME)
end)
