--!strict
-- Round state machine: Lobby -> Countdown -> Assign -> Talk -> Result -> Lobby.
-- Transcripts come from each client's own AudioSpeechToText (the server cannot process audio) and are judged here.
-- During Talk, question cards force quiet players to speak; eliminated players stay in as "ghosts" whose speech
-- still counts toward assists (the last other speaker before an elimination scores).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local Judge = require(shared:WaitForChild("Judge"))
local WordBank = require(script.Parent:WaitForChild("WordBank"))
local SeatService = require(script.Parent:WaitForChild("SeatService"))
local Prompts = require(script.Parent:WaitForChild("Prompts"))

local RoundService = {}

type Participant = {
	player: Player,
	word: string,
	aliases: { string },
	alive: boolean,
	lastSpokeAt: number,
	strikes: number,
	lastAnswer: string?,
}
type Card = { player: Player, answered: boolean }

local remotes: Folder
local phase = "Lobby"
local phaseEndsAt = 0
local message = ""
local participants: { [Player]: Participant } = {}
local startedWith = 0
local roundId = 0
local lastTranscript: { [Player]: { at: number, text: string } } = {}
local speechLog: { { player: Player, at: number } } = {}
local roundAssists: { [Player]: number } = {}
local activeCard: Card? = nil
local rng = Random.new()

local function remote(name: string): RemoteEvent
	return remotes:FindFirstChild(name) :: RemoteEvent
end

local function aliveList(): { Player }
	local list = {}
	for player, p in participants do
		if p.alive then
			table.insert(list, player)
		end
	end
	return list
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

local function addScore(player: Player, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("점수") :: IntValue?
	if value then
		value.Value += amount
	end
end

-- The most recent other participant (alive or ghost) who spoke within the assist window.
local function assistFor(victim: Player): Player?
	local now = os.clock()
	for i = #speechLog, 1, -1 do
		local entry = speechLog[i]
		if now - entry.at > Config.ASSIST_WINDOW then
			break
		end
		if entry.player ~= victim and participants[entry.player] then
			return entry.player
		end
	end
	return nil
end

local function eliminate(player: Player, reason: string)
	local p = participants[player]
	if not p or not p.alive then
		return
	end
	p.alive = false
	local helper = if reason == "said" then assistFor(player) else nil
	if helper then
		roundAssists[helper] = (roundAssists[helper] or 0) + Config.SCORE_ASSIST
		addScore(helper, Config.SCORE_ASSIST)
	end
	remote("Eliminated"):FireAllClients({
		userId = player.UserId,
		name = player.DisplayName,
		word = p.word,
		reason = reason,
		assistName = if helper then helper.DisplayName else nil,
	})
	if reason == "said" or reason == "silent" then
		SeatService.launch(player)
	end
	broadcastState()
end

local function isValidAnswer(p: Participant, text: string): boolean
	return #Judge.eojeols(text) >= 2 and text ~= p.lastAnswer
end

local function onTranscript(player: Player, text: any)
	if phase ~= "Talk" or typeof(text) ~= "string" then
		return
	end
	local p = participants[player]
	if not p then
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
	table.insert(speechLog, { player = player, at = now })
	if #speechLog > 64 then
		table.remove(speechLog, 1)
	end
	p.lastSpokeAt = now
	if not p.alive then
		return -- ghosts only feed the assist log
	end

	local verdict = Judge.classify(p.word, text, p.aliases)
	if verdict == "CONFIRMED" then
		eliminate(player, "said")
		return
	elseif verdict == "SUSPECT" then
		remote("Suspect"):FireAllClients({ userId = player.UserId, name = player.DisplayName })
	end

	local card = activeCard
	if card and card.player == player and not card.answered and isValidAnswer(p, text) then
		card.answered = true
		p.lastAnswer = text
		remote("CardResult"):FireAllClients({ userId = player.UserId, name = player.DisplayName, outcome = "ok" })
	end
end

local function roundOver(): boolean
	local alive = #aliveList()
	return alive == 0 or (startedWith >= 2 and alive <= 1)
end

local function talking(myRound: number): boolean
	return phase == "Talk" and roundId == myRound and not roundOver()
end

-- Question cards: the quietest alive player gets a question and must answer in two or more words.
local function runCards(myRound: number)
	local lastTarget: Player? = nil
	while talking(myRound) do
		local interval = math.clamp(Config.TALK_TIME / math.max(#aliveList() * 2, 1), Config.QUESTION_MIN_INTERVAL, Config.QUESTION_MAX_INTERVAL)
		task.wait(interval)
		if not talking(myRound) then
			return
		end
		local alive = aliveList()
		table.sort(alive, function(a, b)
			return participants[a].lastSpokeAt < participants[b].lastSpokeAt
		end)
		local target = alive[1]
		if target == lastTarget and #alive > 1 then
			target = alive[2]
		end
		lastTarget = target
		local card: Card = { player = target, answered = false }
		activeCard = card
		remote("QuestionCard"):FireAllClients({
			userId = target.UserId,
			name = target.DisplayName,
			question = Prompts.question(rng),
			deadline = workspace:GetServerTimeNow() + Config.QUESTION_ANSWER_TIME,
		})
		local started = os.clock()
		while os.clock() - started < Config.QUESTION_ANSWER_TIME and not card.answered and talking(myRound) do
			local p = participants[target]
			if not (p and p.alive) then
				break
			end
			task.wait(0.1)
		end
		activeCard = nil
		local p = participants[target]
		if p and p.alive and not card.answered and talking(myRound) then
			p.strikes += 1
			local out = p.strikes >= Config.QUESTION_STRIKES
			remote("CardResult"):FireAllClients({ userId = target.UserId, name = target.DisplayName, outcome = if out then "out" else "warn" })
			if out then
				eliminate(target, "silent")
			end
		end
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
	roundId += 1
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
	table.clear(speechLog)
	table.clear(roundAssists)
	for i, player in seatedPlayers do
		local entry = entries[i]
		participants[player] = {
			player = player,
			word = entry.word,
			aliases = entry.aliases,
			alive = true,
			lastSpokeAt = 0,
			strikes = 0,
		}
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

	-- Talk (question cards run alongside).
	local now = os.clock()
	for _, p in participants do
		p.lastSpokeAt = now + rng:NextNumber() -- random tie-break for the first card
	end
	setPhase("Talk", Config.TALK_TIME, "대화 주제: " .. Prompts.topic(rng))
	task.spawn(runCards, roundId)
	waitPhase(roundOver)

	-- Result: survivors score, the round's best assister is named.
	local winners = {}
	for player, p in participants do
		if p.alive then
			table.insert(winners, player.DisplayName)
			addScore(player, Config.SCORE_SURVIVE)
		end
	end
	local result = if #winners == 0 then "모두 탈락! 무승부" else table.concat(winners, ", ") .. " 승리!"
	local best, bestScore = nil, 0
	for player, score in roundAssists do
		if score > bestScore then
			best, bestScore = player, score
		end
	end
	if best then
		result ..= string.format(" · 유도왕 %s (%d점)", best.DisplayName, bestScore)
	end
	activeCard = nil
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

local function setupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local score = Instance.new("IntValue")
	score.Name = "점수"
	score.Parent = stats
	stats.Parent = player
end

function RoundService.start(remoteFolder: Folder)
	remotes = remoteFolder
	SeatService.init()
	remote("Transcript").OnServerEvent:Connect(onTranscript)

	for _, player in Players:GetPlayers() do
		setupLeaderstats(player)
	end
	Players.PlayerAdded:Connect(function(player)
		setupLeaderstats(player)
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
		roundAssists[player] = nil
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
