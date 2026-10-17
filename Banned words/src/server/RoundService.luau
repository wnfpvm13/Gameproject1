--!strict
-- Round state machine: Lobby -> Countdown -> Assign -> Talk -> Result -> Lobby.
-- Transcripts come from each client's own AudioSpeechToText (the server cannot process audio) and are judged here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local Judge = require(shared:WaitForChild("Judge"))
local WordBank = require(script.Parent:WaitForChild("WordBank"))
local SeatService = require(script.Parent:WaitForChild("SeatService"))

local RoundService = {}

type Participant = { player: Player, word: string, aliases: { string }, alive: boolean, eliminatedAt: number? }

local remotes: Folder
local phase = "Lobby"
local phaseEndsAt = 0
local message = ""
local participants: { [Player]: Participant } = {}
local startedWith = 0
local lastTranscript: { [Player]: { at: number, text: string } } = {}
local rng = Random.new()

local function remote(name: string): RemoteEvent
	return remotes:FindFirstChild(name) :: RemoteEvent
end

local function aliveCount(): number
	local n = 0
	for _, p in participants do
		if p.alive then
			n += 1
		end
	end
	return n
end

local function broadcastState()
	local ids, alive = {}, {}
	for player, p in participants do
		table.insert(ids, player.UserId)
		if p.alive then
			table.insert(alive, player.UserId)
		end
	end
	remote("RoundState"):FireAllClients({
		phase = phase,
		endsAt = phaseEndsAt,
		message = message,
		participants = ids,
		alive = alive,
	})
end

local function setPhase(name: string, duration: number, text: string)
	phase = name
	phaseEndsAt = workspace:GetServerTimeNow() + duration
	message = text
	broadcastState()
end

-- Each client gets every participant's word except its own (own word never leaves the server).
local function sendWords(target: Player)
	local words = {}
	for player, p in participants do
		if player ~= target then
			words[tostring(player.UserId)] = p.word
		end
	end
	remote("Words"):FireClient(target, words)
end

local function eliminate(player: Player, reason: string)
	local p = participants[player]
	if not p or not p.alive then
		return
	end
	p.alive = false
	p.eliminatedAt = os.clock()
	remote("Eliminated"):FireAllClients({ userId = player.UserId, name = player.DisplayName, word = p.word, reason = reason })
	if reason == "said" then
		SeatService.launch(player)
	end
	broadcastState()
end

local function onTranscript(player: Player, text: any)
	if phase ~= "Talk" or typeof(text) ~= "string" then
		return
	end
	local p = participants[player]
	if not p or not p.alive then
		return
	end
	text = string.sub(text, 1, Config.TRANSCRIPT_MAX_LEN)
	local now = os.clock()
	local last = lastTranscript[player]
	if last and now - last.at < Config.TRANSCRIPT_MIN_INTERVAL then
		return
	end
	if last and last.text == text and now - last.at < Config.DUPLICATE_WINDOW then
		return
	end
	lastTranscript[player] = { at = now, text = text }

	local verdict = Judge.classify(p.word, text, p.aliases)
	if verdict == "CONFIRMED" then
		eliminate(player, "said")
	elseif verdict == "SUSPECT" then
		remote("Suspect"):FireAllClients({ userId = player.UserId, name = player.DisplayName })
	end
end

local function waitPhase(shouldStop: (() -> boolean)?)
	while workspace:GetServerTimeNow() < phaseEndsAt do
		if shouldStop and shouldStop() then
			return
		end
		task.wait(0.2)
	end
end

local function eligiblePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			table.insert(list, player)
		end
	end
	return list
end

local function roundOver(): boolean
	local alive = aliveCount()
	return alive == 0 or (startedWith >= 2 and alive <= 1)
end

local function runRound()
	-- Countdown (cancelled if players drop below the minimum).
	setPhase("Countdown", Config.LOBBY_COUNTDOWN, "곧 시작해요")
	waitPhase(function()
		return #eligiblePlayers() < Config.MIN_PLAYERS
	end)
	local players = eligiblePlayers()
	if #players < Config.MIN_PLAYERS then
		return
	end

	-- Assign seats and words.
	for i = #players, 2, -1 do
		local j = rng:NextInteger(1, i)
		players[i], players[j] = players[j], players[i]
	end
	while #players > Config.MAX_PLAYERS do
		table.remove(players)
	end
	local seated = SeatService.seatPlayers(players)
	local seatedPlayers = {}
	for _, player in players do
		if seated[player] then
			table.insert(seatedPlayers, player)
		end
	end
	local entries = WordBank.draw(#seatedPlayers, rng)
	table.clear(participants)
	table.clear(lastTranscript)
	for i, player in seatedPlayers do
		local entry = entries[i]
		participants[player] = { player = player, word = entry.word, aliases = entry.aliases, alive = true }
		local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Died:Once(function()
			eliminate(player, "died")
		end)
	end
	startedWith = #seatedPlayers
	setPhase("Assign", Config.ASSIGN_TIME, "내 금칙어는 나만 몰라요! 다른 사람이 말하게 만드세요")
	for _, player in Players:GetPlayers() do
		sendWords(player)
	end
	waitPhase()

	-- Talk.
	setPhase("Talk", Config.TALK_TIME, "대화 시작!")
	waitPhase(roundOver)

	-- Result.
	local winners = {}
	for player, p in participants do
		if p.alive then
			table.insert(winners, player.DisplayName)
		end
	end
	local result = if #winners == 0 then "모두 탈락! 무승부" else table.concat(winners, ", ") .. " 승리!"
	SeatService.releaseAll()
	setPhase("Result", Config.RESULT_TIME, result)
	local reveal = {}
	for player, p in participants do
		reveal[tostring(player.UserId)] = p.word
	end
	remote("Words"):FireAllClients(reveal)
	waitPhase()
	table.clear(participants)
end

function RoundService.start(remoteFolder: Folder)
	remotes = remoteFolder
	SeatService.init()
	remote("Transcript").OnServerEvent:Connect(onTranscript)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			broadcastState()
			if phase == "Assign" or phase == "Talk" then
				sendWords(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if participants[player] then
			eliminate(player, "left")
			participants[player] = nil
		end
		lastTranscript[player] = nil
	end)

	task.spawn(function()
		while true do
			local needed = Config.MIN_PLAYERS - #eligiblePlayers()
			if needed > 0 then
				setPhase("Lobby", 0, string.format("플레이어 %d명 더 필요해요", needed))
				repeat
					task.wait(1)
				until #eligiblePlayers() >= Config.MIN_PLAYERS
			end
			runRound()
		end
	end)
end

return RoundService
