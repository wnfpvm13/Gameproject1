-- 금칙어 게임 Korean client entry point: HUD, word bubbles and transcript forwarding.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local remotes = ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Remotes")
local Hud = require(script:WaitForChild("Hud"))
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
FlatVoice.start()
Speech.onStatus(Hud.setVoice)
task.spawn(Speech.start, player:WaitForChild("PlayerGui"))

Speech.onText(function(text)
	if state.phase == "Talk" and isAlive(player.UserId) then
		remotes.Transcript:FireServer(text)
	end
end)

remotes.RoundState.OnClientEvent:Connect(function(newState)
	local previous = state.phase
	state = newState
	Hud.setStatus(PHASE_TITLE[state.phase] .. " · " .. state.message)
	Hud.setAlive(#state.alive, #state.participants)
	if state.phase == "Lobby" or (state.phase == "Countdown" and previous == "Result") then
		Billboards.clear()
	end
	if state.phase == "Talk" and previous ~= "Talk" then
		Hud.toast("대화 시작!", "info")
	end
	if state.phase == "Assign" or state.phase == "Talk" then
		Billboards.show(lastWords, state.alive)
	end
	ShowCamera.set(state.phase == "Assign" or state.phase == "Talk")
	applySeatLock()
end)

remotes.Words.OnClientEvent:Connect(function(words)
	lastWords = words
	Billboards.show(words, state.participants)
end)

remotes.Eliminated.OnClientEvent:Connect(function(info)
	Billboards.remove(info.userId)
	if info.reason == "said" then
		local who = if info.userId == player.UserId then "내가" else info.name .. "님이"
		Hud.toast(string.format("삐! %s 금칙어 \"%s\"를 말했어요", who, info.word), "elim")
	end
end)

remotes.Suspect.OnClientEvent:Connect(function(info)
	Hud.toast(string.format("아슬아슬! %s", info.name), "near")
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
	local remaining = state.endsAt - workspace:GetServerTimeNow()
	Hud.setTimer(if state.phase ~= "Lobby" and remaining > 0 then remaining else nil)
end)
