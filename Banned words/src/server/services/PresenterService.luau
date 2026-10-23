--!strict
-- The presenter (docs/DESIGN_V3.md §8; bundle 3, owner 2026-10-23): one volunteer runs a round from the podium. Who
-- presents: volunteers whose voice is ready (chat participants cannot present), the one who presented least so far
-- first, only when enough participants remain, and only after the checks: the presenter shares a voice chat group
-- with every voice participant (VoiceChatService:GetChatGroupsAsync), receives every chat participant's messages
-- (TextChatService:CanUsersChatAsync) and, on public servers, is nobody's Roblox friend. A check that fails to run
-- disqualifies on live servers; Studio allows it (GetChatGroupsAsync works only in Team Test there).
-- During a round the presenter picks the next mission in the last PRESENTER_PICK_SECONDS of free talk and, in the
-- one-word mission, who is launched (a menu of kind "judge"); a missed choice is made by the system (or a vote) and
-- PRESENTER_MISSES in a row hand the round to another presenter. The presenter also plays sound buttons and may step
-- down. A presenter who leaves or steps down is replaced by a volunteer who is not playing (not flying either, and
-- not someone who presented this round before), else the system runs the round. Who presents is Match.presenter;
-- RoundService is told of every change during a round (voices, stands).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local VoiceChatService = game:GetService("VoiceChatService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local PresenterService = {}

export type Option = { id: string, title: string, recommended: boolean }
export type Change = "left" | "misses" | "stepped down"
export type MenuKind = "pick" | "judge" -- the next mission / who the one-word mission launches

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_HEIGHT = 7.2

local rng = Random.new()
local volunteers: { [Player]: boolean } = {}
local presented: { [Player]: number } = {} -- rounds presented this session (the least goes first)
local lastVolunteer: { [Player]: number } = {}
local lastSound: { [number]: number } = {}
local misses = 0
local formers: { [Player]: boolean } = {} -- replaced this round: they watch until it is over (docs/DESIGN_V3.md §8)
local onChange: (Change, Player?, Player?) -> () = function(_reason, _old, _new) end
local unavailable: (Player) -> boolean = function(_player)
	return false
end
-- The open menu (one at a time).
local menu: { kind: MenuKind, options: { Option }, endsAt: number, picked: string? }? = nil

-- Runs one yielding check. Returns (ok, answer); a call that errors is reported and returns ok = false.
local function try<T>(what: string, call: () -> T): (boolean, T?)
	local ok, result = pcall(call)
	if not ok then
		warn("[BannedWords] presenter " .. what .. " check failed:", result)
		return false, nil
	end
	return true, result
end

-- A check that could not run: allowed in Studio only (docs/DESIGN_V3.md §8).
local function failedCheck(): boolean
	return RunService:IsStudio()
end

local function shareGroup(a: { string }, b: { string }): boolean
	for _, id in a do
		if table.find(b, id) then
			return true
		end
	end
	return false
end

-- One player's voice chat groups, or nil when the check fails. Asked one player at a time: the documentation calls
-- the answer "a sorted array of arrays" without saying it follows the order of the players given.
local function groupsOf(player: Player): { string }?
	local ok, answer = try("voice group", function()
		return VoiceChatService:GetChatGroupsAsync({ player })
	end)
	if not ok or typeof(answer) ~= "table" then
		return nil
	end
	local first = (answer :: any)[1]
	if typeof(first) == "table" then
		return first
	end
	return answer :: any -- (a flat list of ids)
end

-- Whether `candidate` shares a voice chat group with every one of `voice`; nil when a check failed.
local function sharesVoiceGroup(candidate: Player, voice: { Player }): boolean?
	local mine = groupsOf(candidate)
	if not mine then
		return nil
	end
	for _, player in voice do
		local theirs = groupsOf(player)
		if not theirs then
			return nil
		end
		if not shareGroup(mine, theirs) then
			return false
		end
	end
	return true
end

-- Whether `candidate` may present a round played by `participants`. Yields.
local function qualifies(candidate: Player, participants: { Player }): boolean
	local voice: { Player } = {}
	local chat: { Player } = {}
	for _, player in participants do
		table.insert(if Match.chatJoin[player] then chat else voice, player)
	end
	if #voice > 0 then
		local shares = sharesVoiceGroup(candidate, voice)
		if shares == false or (shares == nil and not failedCheck()) then
			return false
		end
	end
	for _, player in chat do
		local ok, reaches = try("chat", function()
			return TextChatService:CanUsersChatAsync(player.UserId, candidate.UserId)
		end)
		if (ok and reaches ~= true) or (not ok and not failedCheck()) then
			return false
		end
	end
	if Match.serverKind == "public" then
		for _, player in participants do
			local ok, friends = try("friend", function()
				return candidate:IsFriendsWithAsync(player.UserId)
			end)
			if (ok and friends == true) or (not ok and not failedCheck()) then
				return false
			end
		end
	end
	return true
end

-- A volunteer who could present now: still here, voice ready, not joining by chat. Looked at again after the checks,
-- which yield.
local function canPresent(player: Player): boolean
	local voiceReady = Match.ready[player] or not Config.REQUIRE_VOICE_READY
	return volunteers[player] == true and voiceReady and not Match.chatJoin[player] and player.Parent ~= nil
end

-- Volunteers who could present now, the least experienced first.
local function ready(from: { Player }): { Player }
	local list = {}
	for _, player in from do
		if canPresent(player) then
			table.insert(list, player)
		end
	end
	local order: { [Player]: number } = {}
	for _, player in list do
		order[player] = rng:NextNumber()
	end
	table.sort(list, function(a, b)
		local na, nb = presented[a] or 0, presented[b] or 0
		if na ~= nb then
			return na < nb
		end
		return order[a] < order[b]
	end)
	return list
end

local function lockMovement(player: Player, locked: boolean)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.UseJumpPower = false
		humanoid.WalkSpeed = if locked then Config.PRESENTER_WALK_SPEED else DEFAULT_WALK_SPEED
		humanoid.JumpHeight = if locked then 0 else DEFAULT_JUMP_HEIGHT
	end
end

local function closeMenu()
	if menu and Match.presenter then
		Net.to(Match.presenter, "PresenterMenu", { options = nil })
	end
	menu = nil
end

-- Puts the presenter behind the podium desk, facing the chairs, and keeps them there.
function PresenterService.place(player: Player)
	local hall = workspace:FindFirstChild("PoolHall")
	local podium = hall and hall:FindFirstChild("Podium") :: BasePart?
	local character = player.Character
	if podium and character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(podium.CFrame * CFrame.new(0, 3, 0))
	end
	lockMovement(player, true)
end

-- Hands the round to another volunteer who is not playing (out players and spectators; or to the system). Yields for
-- the checks; a round that ended meanwhile gets nobody and no change call.
local function replace(reason: Change)
	local old = Match.presenter
	local round = Match.roundId
	closeMenu()
	if old then
		lockMovement(old, false)
		formers[old] = true
	end
	Match.presenter = nil
	Match.presenterPending = true
	misses = 0
	local others: { Player } = {}
	for _, player in Players:GetPlayers() do
		if not formers[player] and not Match.isAlive(player) and not unavailable(player) then
			table.insert(others, player)
		end
	end
	local function stillOn(): boolean
		return Match.roundId == round and Match.inRound() and Match.presenter == nil
	end
	for _, candidate in ready(others) do
		if not stillOn() then
			break
		end
		-- The checks yield: the round, the volunteering and the flying are looked at again after them.
		if qualifies(candidate, Match.aliveList()) and stillOn() and canPresent(candidate) and not unavailable(candidate) then
			Match.presenter = candidate
			presented[candidate] = (presented[candidate] or 0) + 1
			PresenterService.place(candidate)
			break
		end
	end
	if Match.roundId == round then
		Match.presenterPending = false
		if Match.inRound() then
			onChange(reason, old, Match.presenter)
		end
	end
end

local function setVolunteer(player: Player, on: boolean)
	if on then
		volunteers[player] = true
	else
		volunteers[player] = nil
	end
	player:SetAttribute("BW_Volunteer", on)
	if not on and Match.presenter == player and Match.inRound() then
		task.spawn(function()
			replace("stepped down")
		end)
	end
end

-- changed(reason, old, new): the presenter changed during a round. isBusy(player): another service owns the player
-- now (flying), so they cannot take over.
function PresenterService.start(changed: (Change, Player?, Player?) -> (), isBusy: (Player) -> boolean)
	onChange = changed
	unavailable = isBusy
	Net.listen("Volunteer", function(player, on)
		if typeof(on) ~= "boolean" then
			return
		end
		local now = os.clock()
		if now - (lastVolunteer[player] or -math.huge) < Config.VOLUNTEER_COOLDOWN then
			return
		end
		lastVolunteer[player] = now
		if (volunteers[player] == true) ~= on then
			setVolunteer(player, on)
		end
	end)
	Net.listen("PresenterPick", function(player, id)
		if menu and player == Match.presenter and typeof(id) == "string" and not menu.picked and Match.now() <= menu.endsAt then
			for _, option in menu.options do
				if option.id == id then
					menu.picked = id
				end
			end
		end
	end)
	Net.listen("PresenterSound", function(player, index)
		if player ~= Match.presenter or not Match.inRound() or typeof(index) ~= "number" then
			return
		end
		if not Config.PRESENTER_SOUNDS[index] then
			return
		end
		local now = os.clock()
		if now - (lastSound[index] or -math.huge) >= Config.PRESENTER_SOUND_COOLDOWN then
			lastSound[index] = now
			Net.toAll("Sound", { index = index })
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		volunteers[player] = nil
		presented[player] = nil
		lastVolunteer[player] = nil
		formers[player] = nil
		if Match.presenter == player and Match.inRound() then
			task.spawn(function()
				replace("left")
			end)
		end
	end)
end

-- Round start: picks the presenter among `candidates` (the players about to be seated) and returns them, or nil
-- (the system runs the round). The presenter is not seated, so enough candidates must remain. Yields for the checks.
function PresenterService.choose(candidates: { Player }): Player?
	Match.presenter = nil
	misses = 0
	if #candidates - 1 < Config.MIN_PLAYERS then
		return nil
	end
	for _, candidate in ready(candidates) do
		local participants = {}
		for _, player in candidates do
			if player ~= candidate and #participants < Config.MAX_PLAYERS then
				table.insert(participants, player)
			end
		end
		if qualifies(candidate, participants) and canPresent(candidate) then
			Match.presenter = candidate
			presented[candidate] = (presented[candidate] or 0) + 1
			return candidate
		end
	end
	return nil
end

-- Opens a menu of `kind` to the presenter for `seconds` and waits. Returns the id they picked (or nil), and whether
-- they let the time run out (false when the presenter changed or `stop()` became true). A missed choice counts;
-- PRESENTER_MISSES in a row replace them.
function PresenterService.ask(kind: MenuKind, options: { Option }, seconds: number, stop: () -> boolean): (string?, boolean)
	local presenter = Match.presenter
	if not presenter or #options == 0 then
		return nil, false
	end
	local endsAt = os.clock() + seconds
	menu = { kind = kind, options = options, endsAt = Match.now() + seconds, picked = nil }
	Net.to(presenter, "PresenterMenu", { kind = kind, options = options, endsAt = Match.now() + seconds })
	while os.clock() < endsAt and menu and not menu.picked and Match.presenter == presenter and not stop() do
		task.wait(0.1)
	end
	local picked = if menu then menu.picked else nil
	if Match.presenter ~= presenter then
		return nil, false -- replaced meanwhile (the menu went with them)
	end
	closeMenu()
	if picked then
		misses = 0
		return picked, false
	end
	if stop() then
		return nil, false
	end
	misses += 1
	if misses >= Config.PRESENTER_MISSES then
		task.spawn(function()
			replace("misses")
		end)
	end
	return nil, true
end

-- The presenter asked for the whole state again: the open menu too.
function PresenterService.sendMenu(player: Player)
	if menu and player == Match.presenter then
		Net.to(player, "PresenterMenu", { kind = menu.kind, options = menu.options, endsAt = menu.endsAt })
	end
end

-- Round over: the presenter may move again and nobody presents until the next round's choice.
function PresenterService.endRound()
	closeMenu()
	if Match.presenter then
		lockMovement(Match.presenter, false)
	end
	Match.presenter = nil
	Match.presenterPending = false
	misses = 0
	table.clear(formers)
end

return PresenterService
