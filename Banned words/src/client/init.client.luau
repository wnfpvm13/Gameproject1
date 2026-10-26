-- 금칙어 게임 Korean client entry point: only wiring. Server events update State, then refresh() redraws
-- every part from State (HUD, head bubbles, camera, reaction bar, getting ready, presenter controls, recognizer on/off,
-- seat lock). The mission card shows what the server's "Mission" says.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local remotes = shared:WaitForChild("Remotes")
local Config = require(shared:WaitForChild("Config"))
local State = require(script:WaitForChild("State"))
local Speech = require(script:WaitForChild("Speech"))
local FlatVoice = require(script:WaitForChild("FlatVoice"))
local ShowCamera = require(script:WaitForChild("ShowCamera"))
local Bottles = require(script:WaitForChild("Bottles"))
local GetUp = require(script:WaitForChild("GetUp"))
local Billboards = require(script:WaitForChild("Billboards"))
local ChatLook = require(script:WaitForChild("ChatLook"))
local Fx = require(script:WaitForChild("Fx"))
local Bell = require(script:WaitForChild("Bell"))
local UI = script:WaitForChild("UI")
local Hud = require(UI:WaitForChild("Hud"))
local Toast = require(UI:WaitForChild("Toast"))
local MicPanel = require(UI:WaitForChild("MicPanel"))
local ReactionBar = require(UI:WaitForChild("ReactionBar"))
local PresenterPanel = require(UI:WaitForChild("PresenterPanel"))
local MissionPanel = require(UI:WaitForChild("MissionPanel"))
local BellButton = require(UI:WaitForChild("BellButton"))
local InviteButton = require(UI:WaitForChild("InviteButton"))

local player = Players.LocalPlayer
local readySent: boolean? = nil
local linkedSent: boolean? = nil -- (voice connected, muted or not: a chat player needs it to hear everyone)
local myFlightEndsAt = 0 -- os.clock(): while my own launch lasts I keep the show camera (I watch myself fly off)
local bellOpen = false -- the server has my seat bell open (bundle 6b)
local bellWindow = 0 -- the open window's number (sent back with my ring)
local bellRung = false -- I rang it this time (one ring each time it opens)
local bellRepeating = false -- the open window takes every press (red light): the button stays
-- A press now would lose (총잡이 결투's "ready…", 무궁화's red light): the bell button does not invite it (owner
-- 2026-10-25).
local bellTrap = false
local menuId = 0 -- the presenter menu now open (sent back with my pick)

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

-- Ready = voice connected + said something once. The recognizer runs for that mic test and, while I play by voice,
-- during the banned-word talk (speech judging, bundle 6e: requests are limited experience-wide, so not otherwise).
-- A voice account may play by chat instead and still hear everyone (§7, owner 2026-10-25; the server decides, tells
-- me alone what I may do ("ChatAccess") and everyone who plays by chat (attribute BW_ChatMode)); an account without
-- voice watches.
local function talkingByVoice(): boolean
	local talk = State.round.talk
	return (talk == "talk" or talk == "settle") and State.meAlive() and player:GetAttribute("BW_ChatMode") ~= true
end
local function refreshVoice()
	local status = Speech.status()
	local isReady = State.micTested and (status == "Listening" or status == "Speaking")
	local linked = status == "Muted" or status == "Listening" or status == "Speaking"
	if isReady ~= readySent or linked ~= linkedSent then
		readySent = isReady
		linkedSent = linked
		remotes.Ready:FireServer(isReady, linked)
	end
	Speech.setEnabled(not State.micTested or talkingByVoice())
	MicPanel.set({
		status = status,
		micTested = State.micTested,
		inMyRound = State.inRound() and (State.isParticipant(State.myId()) or State.mePresenting()),
		roundOn = State.inRound(),
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

local function nameOf(userId: number?): string
	local other = userId and Players:GetPlayerByUserId(userId)
	return if other then other.DisplayName else "?"
end

-- The seat bell and the bell button: open, and inviting a press (not while a press would lose).
local function refreshBell()
	local canRing = bellOpen and not bellRung and State.inRound() and State.meAlive() and os.clock() >= myFlightEndsAt
	Bell.set(canRing)
	BellButton.set(State.inRound() and State.meAlive() and not State.mePresenting() and os.clock() >= myFlightEndsAt,
		canRing, not bellTrap)
end

local function refresh()
	local round = State.round
	local me = State.myId()
	local presenting = State.mePresenting()
	Hud.setStatus(round.phase, round.message)
	Hud.setAlive(#round.alive, round.total)
	Hud.setMyLives(if State.inRound() and State.isParticipant(me) then State.livesOf(me) else nil, round.maxLives,
		if presenting then Config.TEXT.ME_PRESENTER else nil)
	ChatLook.setRaise(Billboards.render({
		show = bubbleTargets(),
		words = State.words,
		lives = round.lives,
		maxLives = round.maxLives,
		presenter = if State.inRound() then round.presenter else nil,
	}))
	-- (no round is being played and too few are ready: invite friends)
	InviteButton.set(not State.inRound() and not presenting and (round.readyCount or 0) < Config.INVITE_BELOW)
	local seated = (State.inRound() and State.meAlive()) or os.clock() < myFlightEndsAt
	ShowCamera.set(if presenting then "presenter" elseif seated then "show" else nil, round.total)
	ReactionBar.setVisible(not (State.inRound() and State.meAlive()) and not presenting)
	-- Anyone not playing the round may volunteer (an out player or a spectator can take over a round,
	-- docs/DESIGN_V3.md §8); the presenter steps down with the same button. Chat participants cannot present.
	local playing = State.inRound() and State.meAlive()
	local chatMode = player:GetAttribute("BW_ChatMode") == true
	PresenterPanel.setVolunteer(not playing and not chatMode, player:GetAttribute("BW_Volunteer") == true, presenting)
	PresenterPanel.setPresenting(presenting)
	-- The presenter's banned-word list during the banned-word talk (re-draw in its prep stage, ear judging in the talk).
	local wordMode = nil
	if presenting then
		wordMode = if round.talk == "prep" then "reroll" elseif round.talk == "talk" then "heard" else nil
	end
	local rows = {}
	if wordMode then
		for _, userId in round.alive do
			local entry = State.words[tostring(userId)]
			local word = if entry and entry.words then table.concat(entry.words, ", ") else ""
			if word ~= "" then
				table.insert(rows, { userId = userId, name = nameOf(userId), word = word })
			end
		end
	end
	PresenterPanel.setWords(rows, wordMode, round.serverKind == "public")
	refreshBell()
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
	remotes.PresenterPick:FireServer(id, menuId)
end, function(index)
	remotes.PresenterSound:FireServer(index)
end, function(mode, userId)
	if mode == "reroll" then
		remotes.Reroll:FireServer(userId)
	elseif mode == "rerollAll" then
		remotes.Reroll:FireServer("all")
	elseif mode == "start" then
		remotes.TalkStart:FireServer()
	else
		remotes.EarJudge:FireServer(userId)
	end
end, function(userId)
	remotes.Rescue:FireServer(userId)
end)
MissionPanel.build(function(questionId, choice)
	remotes.MissionAnswer:FireServer(questionId, choice)
end)
local function ringMyBell()
	if bellRepeating then
		remotes.Bell:FireServer(bellWindow) -- (the server counts at most a few a second)
	elseif not bellRung then
		bellRung = true
		remotes.Bell:FireServer(bellWindow)
		MissionPanel.rang(workspace:GetServerTimeNow()) -- (물병 세우기: my bar stops where I stopped it)
		refresh()
	end
end
Bell.start(ringMyBell)
BellButton.build(ringMyBell)
-- Roblox's invite prompt, where this player may send invites (it differs by platform and account). One at a time; when
-- Roblox answers, only if no round started meanwhile (review 2026-10-26).
local inviting = false
InviteButton.build(function()
	if inviting then
		return
	end
	inviting = true
	task.spawn(function()
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and can and not State.inRound() then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		elseif ok and not can then
			Toast.show(Config.TEXT.INVITE_UNAVAILABLE, "info")
		end
		inviting = false
	end)
end)
Fx.init()
FlatVoice.start()
GetUp.start()
ChatLook.start()
Speech.onStatus(function()
	refreshVoice()
end)
Speech.onText(function(text, earliest, latest, ended, textId)
	if not State.micTested then
		State.micTested = true
		Toast.show(Config.TEXT.MIC_TESTED, "info")
		refreshVoice()
		return
	end
	if talkingByVoice() then
		remotes.Transcript:FireServer(text, earliest, latest, ended, textId) -- (the server judges it, never shown)
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
-- (this LocalScript lives in PlayerScripts and survives respawns; a speech setup that fails on some device must not
-- stop the rest of the game from wiring up — review 2026-10-25)
local speechOk, speechError = pcall(Speech.start, script)
if not speechOk then
	warn("[BannedWords] speech setup failed:", speechError)
end

-- Server events.
local stateSeen = false -- the first state after joining only sets things up (no "it started" toast for late joiners)

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
		menuId = info.id or 0
		PresenterPanel.openMenu(info.options, info.endsAt, info.kind, info.note)
	else
		PresenterPanel.closeMenu()
	end
end)

remotes.Sound.OnClientEvent:Connect(function(info)
	Fx.presenterSound(info.index)
end)

-- The mission card (quiz, roulette, a word to everyone, votes). My buttons work while I am alive and not flying (it
-- is shown again when my flight starts and ends). It steps aside so the blast is seen (owner 2026-10-24): while I am
-- the one flying (until I am back), and while someone else's launch flies over a screen with nothing to do on it (a
-- result, the roulette, a vote) until the next screen comes.
local lastMission: { [string]: any } = { kind = "none" }
local othersLaunchHideUntil = 0
local function passiveScreen(payload: { [string]: any }): boolean
	local kind = payload.kind
	-- (a vote's screen stays while its result launches someone: a launch on it comes only once the vote is over, also
	-- when everyone voted early)
	return kind == nil or kind == "none" or kind == "roulette" or kind == "oneWordJudge" or kind == "brief"
		or kind == "nextPick" or kind == "vote" or string.sub(kind, -6) == "Result"
end
local function showMission()
	local payload = lastMission
	MissionPanel.setHidden(os.clock() < myFlightEndsAt or os.clock() < othersLaunchHideUntil)
	local names = {}
	for _, userId in payload.ids or {} do
		table.insert(names, nameOf(userId))
	end
	local canAnswer = State.inRound() and State.meAlive() and os.clock() >= myFlightEndsAt
	if (payload.kind == "oneWordJudge" or payload.kind == "nextPick") and State.mePresenting() then
		payload = { kind = "none" } -- the presenter picks in their own menu ("the presenter is choosing" is for the others)
	end
	MissionPanel.show(payload, canAnswer, names, State.myId())
end
-- I am flying (or waiting my turn in a chain) until `untilAt` (os.clock()): the round camera stays, my buttons and
-- the mission card wait; everything is looked at again once that time has passed (the latest deadline wins).
local function flyingUntil(untilAt: number)
	myFlightEndsAt = math.max(myFlightEndsAt, untilAt)
	refresh()
	showMission()
	task.delay(untilAt - os.clock() + 0.1, function()
		refresh()
		showMission()
	end)
end
-- 물병 세우기's bottles on their little tables (bundle 8b): set up at the first throw, flipped by each throw's result,
-- gone with the next game's screens.
local bottlesUp = false
local function bottlesFor(payload: { [string]: any })
	local kind = payload.kind
	if kind == "bottle" then
		if not bottlesUp or payload.throw == 1 then
			Bottles.setup(payload.ids or {})
			bottlesUp = true
		else
			Bottles.reset()
		end
	elseif kind == "bottleThrow" or kind == "bottleResult" then
		if not bottlesUp then -- (joined or resynced mid-game: the bottles first)
			Bottles.setup(payload.ids or {})
			bottlesUp = true
		end
		if kind == "bottleThrow" then
			local landed = payload.landed or {}
			for i, userId in payload.ids or {} do
				Bottles.flip(userId, landed[i] == true)
			end
		end
	elseif bottlesUp then
		Bottles.clear()
		bottlesUp = false
	end
end
-- The sounds of a screen's moments: only when it comes after the one before, and only right when it happens (a screen
-- sent again on Sync, or the first one a late joiner gets, stays quiet — review 2026-10-26).
local MOMENT_FRESH = 1.5 -- seconds after a roulette's start or a result in which they still sound
local function cueSounds(before: { [string]: any }, now: { [string]: any })
	Fx.ticking(now.kind == "bomb")
	if now.kind ~= "roulette" then
		Fx.stopRoll() -- (a roulette that ended or stopped takes its drum roll with it)
	end
	local serverNow = workspace:GetServerTimeNow()
	if now.kind == "quizResult" and before.kind == "quiz" and now.question == before.question then
		if typeof(now.right) == "table" and table.find(now.right, State.myId()) then
			Fx.cue("right") -- (the server counted my answer right: not one that arrived after the end)
		end
	elseif now.kind == "redLight" and now.light == "red" and before.kind == "redLight" and before.light ~= "red" then
		Fx.cue("whistle")
	elseif now.kind == "duel" and now.stage == "fire" and before.kind == "duel" and before.stage ~= "fire" then
		Fx.cue("fire")
	elseif now.kind == "roulette" and before.kind ~= "roulette" and typeof(now.startsAt) == "number"
		and typeof(now.spinSeconds) == "number" and serverNow - now.startsAt < MOMENT_FRESH then
		local left = now.startsAt + now.spinSeconds - serverNow
		if left > 0.5 then
			Fx.cue("roll", left)
		end
	elseif now.kind == "roundResult" and before.kind ~= "roundResult" and typeof(now.winners) == "table"
		and typeof(now.at) == "number" and serverNow - now.at < MOMENT_FRESH then
		local winners = {}
		for _, userId in now.winners do
			local winner = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
			if winner then
				table.insert(winners, winner)
			end
		end
		if #winners > 0 then
			Fx.celebrate(winners)
		end
	end
end

remotes.Mission.OnClientEvent:Connect(function(payload)
	cueSounds(lastMission, payload)
	lastMission = payload
	BellButton.setIcon(if payload.kind == "duel" then "gun" else "bell")
	bellTrap = (payload.kind == "duel" and payload.stage ~= "fire") or (payload.kind == "redLight" and payload.light == "red")
	refreshBell()
	othersLaunchHideUntil = 0
	bottlesFor(payload)
	showMission()
end)

-- To the presenter: banned words caught in chat waiting for a rescue (bundle 5b).
remotes.Rescue.OnClientEvent:Connect(function(info)
	local rows = {}
	for _, hit in info.hits or {} do
		table.insert(rows, { userId = hit.userId, name = nameOf(hit.userId), word = hit.word, endsAt = hit.endsAt })
	end
	PresenterPanel.setRescues(rows)
end)

-- The seat bells (bundle 6b): open to me or not; someone's bell rang (the ding and its light).
remotes.BellOpen.OnClientEvent:Connect(function(info)
	local window = info.id or 0
	if window ~= bellWindow then
		bellRung = false -- (a new window; the same one sent again on Sync keeps my ring)
	end
	bellWindow = window
	bellRepeating = info.repeating == true
	bellOpen = info.open == true and table.find(info.ids or {}, State.myId()) ~= nil
	refresh()
end)
remotes.BellRang.OnClientEvent:Connect(function(info)
	local who = Players:GetPlayerByUserId(info.userId)
	Fx.bellRang(if who then Bell.bellOf(who) else nil)
	MissionPanel.bellRang()
end)

-- The presenter pulled the podium lever (their launch follows).
remotes.Lever.OnClientEvent:Connect(function()
	Fx.lever()
end)

-- The banned words I may see (only during the banned-word talk; the server tells me my own word when it is over).
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
-- The last moment's line and when it came: a life-loss toast right after it keeps it on top (review 2026-10-26: "⏰ 시간
-- 초과! 민수" was replaced at once by the lives line, and the card steps aside while flying, so nobody read why).
local lastNotice, lastNoticeAt = "", 0
remotes.LifeLost.OnClientEvent:Connect(function(info)
	local lost, out, lines = {}, {}, {}
	local anyOut = false
	for _, entry in info.players do
		if entry.userId == State.myId() and typeof(entry.launchIn) == "number" then
			-- (my launch waits its turn in a chain: I keep the round camera until I am back, owner 2026-10-24)
			flyingUntil(os.clock() + entry.launchIn + Config.FLING_RETURN_SECONDS + 0.5)
		end
		Billboards.hit(entry.userId, entry.lives, State.round.maxLives, entry.out)
		anyOut = anyOut or entry.out
		if entry.userId == State.myId() and info.reason ~= "left" then
			table.insert(lines, if entry.out then Config.TEXT.MY_OUT
				elseif entry.lives <= 0 then Config.TEXT.MY_NO_LIVES
				else string.format(Config.TEXT.MY_LIFE_LOST, entry.lives))
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
	if info.reason == "afk" then
		local names = {}
		for _, entry in info.players do
			table.insert(names, entry.name)
		end
		Toast.show(string.format(Config.TEXT.AFK_OUT, table.concat(names, ", ")), "elim")
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
	if lastNotice ~= "" and os.clock() - lastNoticeAt < Config.NOTICE_KEEP_SECONDS then
		table.insert(lines, 1, lastNotice) -- (why it happened, then what it cost)
	end
	if anyOut then
		Fx.elimination(GuiService.ReducedMotionEnabled)
	end
	Toast.show(table.concat(lines, "\n"), if anyOut then "elim" else "near")
end)

remotes.Notice.OnClientEvent:Connect(function(info)
	lastNotice, lastNoticeAt = info.text, os.clock()
	Toast.show(info.text, "near")
end)

-- The banned-word talk ended: once my speech that may still count has been sent, say so (the settle stage waits).
remotes.Settle.OnClientEvent:Connect(function(info)
	task.spawn(function()
		Speech.waitSettled(info.cutoff, info.cutoff + Config.END_TOLERANCE, Config.SETTLE_MAX)
		remotes.Settled:FireServer(info.key)
	end)
end)

remotes.Reaction.OnClientEvent:Connect(function(info)
	Fx.reaction(Players:GetPlayerByUserId(info.userId), info.emoji)
end)

-- A flying chair fired (docs/DESIGN_V3.md §10): everyone sees the flap snap back and hears the bang.
remotes.Fling.OnClientEvent:Connect(function(info)
	if info.userId == State.myId() then
		flyingUntil(os.clock() + Config.FLING_RETURN_SECONDS + 0.5) -- (first: the round camera must be on before it shakes)
	end
	ShowCamera.widen(Config.FLING_RETURN_SECONDS + 0.5) -- (the whole row while anyone flies)
	Fx.fling(info)
	-- (shake and flash: not with the device's reduced motion setting)
	if not GuiService.ReducedMotionEnabled then
		local size = if typeof(info.size) == "number" then info.size else 1
		ShowCamera.shake(Config.SHAKE_STUDS * size, Config.SHAKE_SECONDS)
		if size >= Config.FLASH_FROM_SIZE then
			Fx.whiteFlash()
		end
	end
	if info.userId ~= State.myId() and passiveScreen(lastMission) then
		othersLaunchHideUntil = os.clock() + Config.FLING_RETURN_SECONDS
		showMission()
		task.delay(Config.FLING_RETURN_SECONDS + 0.05, showMission)
	end
end)

remotes.Splash.OnClientEvent:Connect(function(info)
	Fx.splash(info.position)
end)

-- Studio only: F costs me a life (for testing; the server ignores it on live servers).
if RunService:IsStudio() then
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F then
			remotes.DevFling:FireServer()
		end
	end)
end

-- Sitting down or getting up moves my bell prompt (it goes on the chair I sit on).
local function watchSeating(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Seated:Connect(function()
			refresh()
		end)
	end
end
if player.Character then
	task.spawn(watchSeating, player.Character)
end
player.CharacterAdded:Connect(function(character)
	task.spawn(watchSeating, character)
end)

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
	if State.round.phase == "Play" and State.round.games then
		Hud.setCount(State.round.game or 0, State.round.games)
	else
		Hud.setTimer(if State.round.phase ~= "Lobby" and remaining > 0 then remaining else nil)
	end
	PresenterPanel.tick(workspace:GetServerTimeNow())
	MissionPanel.tick(workspace:GetServerTimeNow())
end)

-- Ask for the current state now that every handler is connected (late joiners miss earlier broadcasts).
remotes.Sync:FireServer()
