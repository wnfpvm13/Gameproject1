-- 금칙어 게임 Korean client entry point: only wiring. Server events update State, then refresh() redraws
-- every part from State (HUD panels, bubbles, camera, reaction bar, recognizer on/off, seat lock).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local remotes = shared:WaitForChild("Remotes")
local Config = require(shared:WaitForChild("Config"))
local Judge = require(shared:WaitForChild("Judge"))
local State = require(script:WaitForChild("State"))
local Speech = require(script:WaitForChild("Speech"))
local FlatVoice = require(script:WaitForChild("FlatVoice"))
local RingCamera = require(script:WaitForChild("RingCamera"))
local Billboards = require(script:WaitForChild("Billboards"))
local Fx = require(script:WaitForChild("Fx"))
local UI = script:WaitForChild("UI")
local Hud = require(UI:WaitForChild("Hud"))
local Toast = require(UI:WaitForChild("Toast"))
local MicPanel = require(UI:WaitForChild("MicPanel"))
local HostPanel = require(UI:WaitForChild("HostPanel"))
local ReactionBar = require(UI:WaitForChild("ReactionBar"))

local player = Players.LocalPlayer
local readySent: boolean? = nil

-- Seated players cannot jump out or reset during a round.
local function applySeatLock()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local locked = State.inRound() and State.meAlive()
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not locked)
	pcall(function()
		StarterGui:SetCore("ResetButtonCallback", not locked)
	end)
end

-- Ready = voice connected + said something once. The recognizer runs only for the mic test and while I play.
local function refreshVoice()
	local status = Speech.status()
	local isReady = State.micTested and (status == "Listening" or status == "Speaking")
	if isReady ~= readySent then
		readySent = isReady
		remotes.Ready:FireServer(isReady)
	end
	Speech.setEnabled(not State.micTested or (State.round.phase == "Talk" and State.meAlive()))
	MicPanel.setVoice(status)
	MicPanel.setTest(status, State.micTested, State.inRound() and State.isParticipant(State.myId()), State.round.readyCount)
end

local function bubbleTargets(): { number }
	local phase = State.round.phase
	local list = {}
	if phase == "Assign" or phase == "Talk" then
		for _, id in State.round.alive do
			if id ~= State.myId() then
				table.insert(list, id)
			end
		end
	elseif phase == "Result" then
		list = State.round.participants
	end
	return list
end

local function refresh()
	local round = State.round
	local playing = State.inRound() and State.meAlive()
	Hud.setStatus(round.phase, round.message, if playing then State.roleOf(State.myId()) else nil)
	Hud.setAlive(#round.alive, round.total)
	Hud.setMyWords(if State.inRound() and State.meAlive() then State.myWordCount() else 0)
	Billboards.render({ show = bubbleTargets(), words = State.words, roleOf = State.roleOf })
	RingCamera.set(State.inRound() and State.meAlive())
	ReactionBar.setVisible(not (State.inRound() and State.meAlive()))
	refreshVoice()
	applySeatLock()
end

-- Build UI and systems.
Hud.build()
Toast.build()
MicPanel.build()
HostPanel.build()
ReactionBar.build(function(index)
	remotes.Reaction:FireServer(index)
end)
Fx.init()
FlatVoice.start()
Speech.onStatus(function()
	refreshVoice()
end)
Speech.onText(function(text, startedAt, segmentId)
	if not State.micTested then
		State.micTested = true
		Toast.show("마이크 확인 완료!", "info")
		refreshVoice()
		return
	end
	if State.round.phase == "Talk" and State.meAlive() then
		remotes.Transcript:FireServer(text, startedAt, segmentId)
	end
end)
Speech.onUnstable(function()
	if State.inRound() and State.meAlive() then
		Toast.show("음성 인식이 불안정해요 · 마이크와 이어폰을 확인해 주세요", "near")
	end
end)
Speech.start(script) -- this LocalScript lives in PlayerScripts and survives respawns

-- Server events.
remotes.RoundState.OnClientEvent:Connect(function(round)
	local previous = State.round.phase
	State.round = round
	if round.phase == "Lobby" or round.phase == "Countdown" then
		State.words = {}
		State.theme = nil
		if previous ~= round.phase then
			HostPanel.clear()
		end
	end
	if round.phase == "Talk" and previous ~= "Talk" then
		Toast.show("대화 시작! 다른 사람의 금칙어를 말하게 만드세요", "info")
	end
	refresh()
end)

remotes.Words.OnClientEvent:Connect(function(words)
	State.words = words
	refresh()
end)

remotes.Host.OnClientEvent:Connect(function(info)
	if info.kind == "theme" then
		State.theme = info
		Toast.show(info.situation, "info")
	elseif info.kind == "topic" then
		HostPanel.showTopic(info.text)
	elseif info.kind == "event" then
		HostPanel.showEvent(info.text)
	elseif info.kind == "hide" then
		HostPanel.hide(info.which)
	elseif info.kind == "clear" then
		State.theme = nil
		HostPanel.clear()
	end
	refresh()
end)

remotes.WordWarn.OnClientEvent:Connect(function(info)
	HostPanel.warnWord(info.at, info.count)
end)

remotes.Eliminated.OnClientEvent:Connect(function(info)
	local isMe = info.userId == State.myId()
	if info.reason == "said" then
		Billboards.alarm(info.userId)
		Fx.elimination(Players:GetPlayerByUserId(info.userId))
		local who = if isMe then "내가" else info.name .. "님이"
		local word = info.word or ""
		local text = string.format("삐! %s 금칙어 \"%s\"%s 말했어요", who, word, Judge.josa(word, "을", "를"))
		if isMe and info.words and #info.words > 1 then
			text ..= "\n내 금칙어: " .. table.concat(info.words, ", ")
		end
		if info.assistName then
			text ..= string.format("\n유도: %s +%d점", info.assistName, Config.SCORE_ASSIST)
		end
		Toast.show(text, "elim")
	elseif info.reason == "left" then
		Toast.show(info.name .. "님이 나갔어요", "near")
	end
end)

remotes.Notice.OnClientEvent:Connect(function(info)
	Toast.show(info.text, "near")
end)

remotes.Reaction.OnClientEvent:Connect(function(info)
	Fx.reaction(Players:GetPlayerByUserId(info.userId), info.emoji)
end)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	RingCamera.reapply()
end)

-- Anyone's new character needs its bubble again (e.g. the last one launched respawns during the result).
local function watchCharacters(other: Player)
	other.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 5)
		task.wait(0.3)
		refresh()
	end)
end
for _, other in Players:GetPlayers() do
	watchCharacters(other)
end
Players.PlayerAdded:Connect(watchCharacters)

local lastPing = 0
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local remaining = State.round.endsAt - now
	Hud.setTimer(if State.round.phase ~= "Lobby" and remaining > 0 then remaining else nil)
	HostPanel.tick(now)
	-- Tells the host the table is not quiet even when the recognizer misses speech (never used to judge).
	if State.round.phase == "Talk" and State.meAlive() and Speech.isSpeaking() and now - lastPing >= Config.VOICE_PING_INTERVAL then
		lastPing = now
		remotes.VoicePing:FireServer()
	end
end)

-- Ask for the current state now that every handler is connected (late joiners miss earlier broadcasts).
remotes.Sync:FireServer()
