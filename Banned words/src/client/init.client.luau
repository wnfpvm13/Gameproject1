-- 금칙어 게임 Korean client entry point: only wiring. Server events update State, then refresh() redraws
-- every part from State (HUD, head bubbles, camera, reaction bar, getting ready, presenter controls, recognizer on/off,
-- seat lock).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local remotes = shared:WaitForChild("Remotes")
local Config = require(shared:WaitForChild("Config"))
local State = require(script:WaitForChild("State"))
local Speech = require(script:WaitForChild("Speech"))
local FlatVoice = require(script:WaitForChild("FlatVoice"))
local ShowCamera = require(script:WaitForChild("ShowCamera"))
local GetUp = require(script:WaitForChild("GetUp"))
local Billboards = require(script:WaitForChild("Billboards"))
local ChatLook = require(script:WaitForChild("ChatLook"))
local Fx = require(script:WaitForChild("Fx"))
local UI = script:WaitForChild("UI")
local Hud = require(UI:WaitForChild("Hud"))
local Toast = require(UI:WaitForChild("Toast"))
local MicPanel = require(UI:WaitForChild("MicPanel"))
local ReactionBar = require(UI:WaitForChild("ReactionBar"))
local PresenterPanel = require(UI:WaitForChild("PresenterPanel"))

local player = Players.LocalPlayer
local readySent: boolean? = nil
local myFlightEndsAt = 0 -- os.clock(): while my own launch lasts I keep the show camera (I watch myself fly off)

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

-- Ready = voice connected + said something once. The recognizer runs only for that mic test (docs/DESIGN_V3.md §2;
-- judging speech comes back in phase 2). Accounts without voice may join by chat instead (§7; the server decides,
-- tells me alone what I may do ("ChatAccess") and everyone who joins by chat (attribute BW_ChatMode)).
local function refreshVoice()
	local status = Speech.status()
	local isReady = State.micTested and (status == "Listening" or status == "Speaking")
	if isReady ~= readySent then
		readySent = isReady
		remotes.Ready:FireServer(isReady)
	end
	Speech.setEnabled(not State.micTested)
	MicPanel.set({
		status = status,
		micTested = State.micTested,
		inMyRound = State.inRound() and (State.isParticipant(State.myId()) or State.mePresenting()),
		readyCount = State.round.readyCount,
		chatAccess = State.chatAccess,
		chatMode = player:GetAttribute("BW_ChatMode") == true,
	})
end

-- Everyone on the chairs (and the presenter) gets a head bubble during a round, every participant in the result.
-- The presenter does not see their own (it would sit right in front of their camera).
local function bubbleTargets(): { number }
	if State.inRound() then
		local list = table.clone(State.round.alive)
		if State.round.presenter and not State.mePresenting() then
			table.insert(list, State.round.presenter)
		end
		return list
	elseif State.round.phase == "Result" then
		return State.round.participants
	end
	return {}
end

local function refresh()
	local round = State.round
	local me = State.myId()
	local presenting = State.mePresenting()
	Hud.setStatus(round.phase, round.message)
	Hud.setAlive(#round.alive, round.total)
	Hud.setMyLives(if State.inRound() and State.isParticipant(me) then State.livesOf(me) else nil, round.maxLives,
		if presenting then Config.TEXT.ME_PRESENTER else nil)
	Billboards.render({
		show = bubbleTargets(),
		words = State.words,
		lives = round.lives,
		maxLives = round.maxLives,
		presenter = if State.inRound() then round.presenter else nil,
	})
	local seated = (State.inRound() and State.meAlive()) or os.clock() < myFlightEndsAt
	ShowCamera.set(if presenting then "presenter" elseif seated then "show" else nil)
	ReactionBar.setVisible(not (State.inRound() and State.meAlive()) and not presenting)
	-- Anyone not playing the round may volunteer (an out player or a spectator can take over a round,
	-- docs/DESIGN_V3.md §8); the presenter steps down with the same button. Chat participants cannot present.
	local playing = State.inRound() and State.meAlive()
	local chatMode = player:GetAttribute("BW_ChatMode") == true
	PresenterPanel.setVolunteer(not playing and not chatMode, player:GetAttribute("BW_Volunteer") == true, presenting)
	PresenterPanel.setPresenting(presenting)
	refreshVoice()
	applySeatLock()
end

-- Build UI and systems.
Hud.build()
Toast.build()
MicPanel.build(function(on)
	remotes.ChatJoin:FireServer(on)
end)
ReactionBar.build(function(index)
	remotes.Reaction:FireServer(index)
end)
PresenterPanel.build(function(on)
	remotes.Volunteer:FireServer(on)
end, function(id)
	remotes.PresenterPick:FireServer(id)
end, function(index)
	remotes.PresenterSound:FireServer(index)
end)
Fx.init()
FlatVoice.start()
GetUp.start()
ChatLook.start()
Speech.onStatus(function()
	refreshVoice()
end)
Speech.onText(function()
	if not State.micTested then
		State.micTested = true
		Toast.show(Config.TEXT.MIC_TESTED, "info")
		refreshVoice()
	end
end)
player:GetAttributeChangedSignal("BW_ChatMode"):Connect(refresh)
player:GetAttributeChangedSignal("BW_Volunteer"):Connect(function()
	if player:GetAttribute("BW_Volunteer") == true then
		Toast.show(Config.TEXT.VOLUNTEERED, "info")
	end
	refresh()
end)
Speech.onUnstable(function()
	if not State.micTested then
		Toast.show(Config.TEXT.RECOGNITION_UNSTABLE, "near")
	end
end)
Speech.start(script) -- this LocalScript lives in PlayerScripts and survives respawns

-- Server events.
local stateSeen = false -- the first state after joining only sets things up (no "it started" toast for late joiners)
local function nameOf(userId: number?): string
	local other = userId and Players:GetPlayerByUserId(userId)
	return if other then other.DisplayName else "?"
end

-- The presenter the last toast named (or the round started with). While the server looks for a replacement
-- (`presenterPending`) nobody is named yet, so a change gets one toast with where it ended up.
local announcedPresenter: number? = nil

remotes.RoundState.OnClientEvent:Connect(function(round)
	local previous = State.round.phase
	local wasInRound = State.inRound()
	State.round = round
	if round.phase == "Lobby" or round.phase == "Countdown" then
		State.words = {}
	end
	if round.phase ~= previous and round.phase == "Assign" then
		announcedPresenter = round.presenter
	end
	if stateSeen and round.phase ~= previous then
		if round.phase == "Assign" and round.presenter then
			Toast.show(string.format(Config.TEXT.PRESENTER_NAMED, nameOf(round.presenter)), "info")
		elseif round.phase == "Play" then
			Toast.show(Config.TEXT.PLAY_START, "info")
		elseif round.phase == "Final" then
			Toast.show(Config.TEXT.FINAL, "near")
		elseif round.phase == "Result" then
			Toast.show(round.message, "info")
		end
	elseif stateSeen and wasInRound and State.inRound() and not round.presenterPending
		and round.presenter ~= announcedPresenter then
		-- The presenter changed during the round (left, missed picks, stepped down).
		announcedPresenter = round.presenter
		Toast.show(if round.presenter then string.format(Config.TEXT.PRESENTER_CHANGED, nameOf(round.presenter))
			else Config.TEXT.PRESENTER_NONE, "near")
	end
	stateSeen = true
	refresh()
end)

remotes.PresenterMenu.OnClientEvent:Connect(function(info)
	if info.options then
		PresenterPanel.openMenu(info.options, info.endsAt)
	else
		PresenterPanel.closeMenu()
	end
end)

remotes.Sound.OnClientEvent:Connect(function(info)
	Fx.presenterSound(info.index)
end)

remotes.Words.OnClientEvent:Connect(function(words)
	State.words = words
	refresh()
end)

remotes.ChatAccess.OnClientEvent:Connect(function(info)
	State.chatAccess = info.state
	refreshVoice()
end)

-- One event's lives lost (docs/DESIGN_V3.md §4): the bubbles pop, one toast names everyone (my own line first; when
-- everyone left fell at once, the last line says they play the final).
remotes.LifeLost.OnClientEvent:Connect(function(info)
	local lost, out, lines = {}, {}, {}
	local anyOut = false
	for _, entry in info.players do
		Billboards.hit(entry.userId, entry.lives, State.round.maxLives, entry.out)
		anyOut = anyOut or entry.out
		if entry.userId == State.myId() and info.reason ~= "left" then
			table.insert(lines, if entry.out then Config.TEXT.MY_OUT else string.format(Config.TEXT.MY_LIFE_LOST, entry.lives))
		elseif entry.out then
			table.insert(out, entry.name)
		else
			table.insert(lost, entry.name)
		end
	end
	if info.reason == "left" then
		Toast.show(string.format(Config.TEXT.LEFT, table.concat(out, ", ")), "near")
		return
	end
	if #lost > 0 then
		table.insert(lines, string.format(Config.TEXT.LIFE_LOST, table.concat(lost, ", ")))
	end
	if #out > 0 then
		table.insert(lines, string.format(Config.TEXT.OUT, table.concat(out, ", ")))
	end
	if info.final then
		table.insert(lines, Config.TEXT.TO_FINAL)
	end
	if anyOut then
		Fx.elimination()
	end
	Toast.show(table.concat(lines, "\n"), if anyOut then "elim" else "near")
end)

remotes.Notice.OnClientEvent:Connect(function(info)
	Toast.show(info.text, "near")
end)

remotes.Reaction.OnClientEvent:Connect(function(info)
	Fx.reaction(Players:GetPlayerByUserId(info.userId), info.emoji)
end)

-- A flying chair fired (docs/DESIGN_V3.md §10): everyone sees the flap snap back and hears the bang.
remotes.Fling.OnClientEvent:Connect(function(info)
	Fx.fling(info)
	if info.userId == State.myId() then
		myFlightEndsAt = os.clock() + Config.FLING_RETURN_SECONDS + 0.5
		refresh()
		task.delay(Config.FLING_RETURN_SECONDS + 0.6, refresh)
	end
end)

remotes.Splash.OnClientEvent:Connect(function(info)
	Fx.splash(info.position)
end)

-- Studio only: F costs me a life (there are no real missions yet; the server ignores it on live servers).
if RunService:IsStudio() then
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F then
			remotes.DevFling:FireServer()
		end
	end)
end

player.CharacterAdded:Connect(function()
	myFlightEndsAt = 0 -- a launch of my previous character is over
	task.wait(0.5)
	refresh()
	ShowCamera.reapply()
end)

-- Anyone's new character needs its bubble again (e.g. a participant back on the chair after a fall).
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

RunService.Heartbeat:Connect(function()
	local remaining = State.round.endsAt - workspace:GetServerTimeNow()
	Hud.setTimer(if State.round.phase ~= "Lobby" and remaining > 0 then remaining else nil)
	PresenterPanel.tick(workspace:GetServerTimeNow())
end)

-- Ask for the current state now that every handler is connected (late joiners miss earlier broadcasts).
remotes.Sync:FireServer()
