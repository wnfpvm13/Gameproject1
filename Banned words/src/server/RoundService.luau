--!strict
-- Round state machine: Lobby -> Countdown (mode vote) -> Assign -> Talk -> Result -> Lobby.
-- Transcripts come from each client's own AudioSpeechToText (the server cannot process audio) and are judged here.
--
-- Modes
--   classic  : saying your own word launches you (v2 word bank).
--   talkshow : KBS 위험한 초대 style. One guest on the raft knows no words and has none; when the guest says a
--              panelist's word that panelist flies. Panelists still fly for their own word, and saying another
--              panelist's word yourself is a foul (you fly). Guests may not read the word list out.
--
-- Only players who connected voice and passed the mic test sit down. Eliminated players and spectators just
-- watch: their voice only reaches other spectators (VoiceService), and their transcripts are ignored.
-- Question cards on a fixed schedule make quiet panelists speak.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local Judge = require(shared:WaitForChild("Judge"))
local WordBank = require(script.Parent:WaitForChild("WordBank"))
local SeatService = require(script.Parent:WaitForChild("SeatService"))
local VoiceService = require(script.Parent:WaitForChild("VoiceService"))
local Prompts = require(script.Parent:WaitForChild("Prompts"))

local RoundService = {}

type Participant = {
	player: Player,
	role: string, -- "panel" | "guest"
	word: string,
	aliases: { string },
	alive: boolean,
	lastSpokeAt: number,
	lastVoiceAt: number,
	strikes: number,
	cards: number,
	answers: { [string]: boolean },
}
type Card = { player: Player, answered: boolean, question: string, deadline: number }

local remotes: Folder
local phase = "Lobby"
local phaseEndsAt = 0
local message = ""
local mode = "classic"
local guest: Player? = nil
local participants: { [Player]: Participant } = {}
local startedWith = 0
local roundId = 0
local votes: { [Player]: string } = {}
local ready: { [Player]: boolean } = {}
local guestCounts: { [Player]: number } = {}
local guestHits = 0
local lastGuestHitAt = 0
local lastLaunchAt = 0
local lastTranscript: { [Player]: { at: number, text: string } } = {}
local lastVoicePing: { [Player]: number } = {}
local speechLog: { { player: Player, at: number } } = {}
local roundAssists: { [Player]: number } = {}
local activeCard: Card? = nil
local bankWords = WordBank.all()
local rng = Random.new()

local function remote(name: string): RemoteEvent
	return remotes:FindFirstChild(name) :: RemoteEvent
end

local function notice(text: string)
	remote("Notice"):FireAllClients({ text = text })
end

-- Panelists still in the game (the guest is never part of this list).
local function aliveList(): { Player }
	local list = {}
	for player, p in participants do
		if p.alive and p.role == "panel" then
			table.insert(list, player)
		end
	end
	return list
end

local function eligiblePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and (ready[player] or not Config.REQUIRE_VOICE_READY) then
			table.insert(list, player)
		end
	end
	return list
end

local function voteCounts(): { classic: number, talkshow: number }
	local counts = { classic = 0, talkshow = 0 }
	for _, choice in votes do
		counts[choice] += 1
	end
	return counts
end

local function statePayload()
	local ids, alive = {}, {}
	for player, p in participants do
		table.insert(ids, player.UserId)
		if p.alive then
			table.insert(alive, player.UserId)
		end
	end
	return {
		phase = phase,
		endsAt = phaseEndsAt,
		message = message,
		mode = mode,
		guestId = if guest then guest.UserId else nil,
		participants = ids,
		alive = alive,
		panelAlive = #aliveList(),
		panelTotal = startedWith,
		votes = voteCounts(),
		readyCount = #eligiblePlayers(),
		requireReady = Config.REQUIRE_VOICE_READY,
	}
end

local function broadcastState()
	remote("RoundState"):FireAllClients(statePayload())
end

-- Alive panelists and the guest are heard by everyone; everybody else only by fellow spectators.
local function refreshSpeakers()
	local ids = {}
	for player, p in participants do
		if p.alive then
			table.insert(ids, player.UserId)
		end
	end
	VoiceService.setSpeakers(ids)
end

local function setPhase(name: string, duration: number, text: string)
	phase = name
	phaseEndsAt = workspace:GetServerTimeNow() + duration
	message = text
	broadcastState()
end

-- Each panelist sees every other panelist's word; nobody gets their own, and the guest gets none.
local function sendWords(target: Player)
	local words = {}
	if not (participants[target] and participants[target].role == "guest") then
		for player, p in participants do
			if player ~= target and p.role == "panel" then
				words[tostring(player.UserId)] = p.word
			end
		end
	end
	remote("Words"):FireClient(target, words)
end

local function cardPayload(card: Card)
	return { userId = card.player.UserId, name = card.player.DisplayName, question = card.question, deadline = card.deadline }
end

local function addScore(player: Player, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("점수") :: IntValue?
	if value then
		value.Value += amount
	end
end

-- The most recent other alive panelist who spoke within the assist window.
local function assistFor(victim: Player): Player?
	local now = os.clock()
	for i = #speechLog, 1, -1 do
		local entry = speechLog[i]
		if now - entry.at > Config.ASSIST_WINDOW then
			break
		end
		local p = participants[entry.player]
		if entry.player ~= victim and p and p.role == "panel" and p.alive then
			return entry.player
		end
	end
	return nil
end

-- reason: "said" (own word) | "guest" (the guest said it) | "foul" (said another panelist's word) | "silent" | "died" | "left"
local function eliminate(player: Player, reason: string, saidWord: string?)
	local p = participants[player]
	if not p or not p.alive or p.role ~= "panel" then
		return
	end
	p.alive = false
	local helper = if reason == "said" or reason == "guest" then assistFor(player) else nil
	if helper then
		roundAssists[helper] = (roundAssists[helper] or 0) + Config.SCORE_ASSIST
		addScore(helper, Config.SCORE_ASSIST)
	end
	if reason == "guest" and guest then
		guestHits += 1
		addScore(guest, Config.SCORE_GUEST_HIT)
	end
	remote("Eliminated"):FireAllClients({
		userId = player.UserId,
		name = player.DisplayName,
		word = p.word,
		saidWord = saidWord,
		reason = reason,
		assistName = if helper then helper.DisplayName else nil,
		guestName = if reason == "guest" and guest then guest.DisplayName else nil,
	})
	if reason == "said" or reason == "silent" or reason == "guest" or reason == "foul" then
		lastLaunchAt = os.clock()
		SeatService.launch(player)
	end
	refreshSpeakers()
	broadcastState()
end

local function normalizedAnswer(text: string): string
	return (string.gsub(Judge.normalize(text), "%s", ""))
end

local function isValidAnswer(p: Participant, text: string): boolean
	return #Judge.eojeols(text) >= 2 and not p.answers[normalizedAnswer(text)]
end

local function judgeGuest(text: string)
	if os.clock() - lastGuestHitAt < Config.GUEST_HIT_COOLDOWN then
		return
	end
	-- Reading the word list out ("치킨 피자 라면...") does not count.
	local bankHits = 0
	for _, word in bankWords do
		if Judge.isConfirmed(word, text) then
			bankHits += 1
		end
	end
	if bankHits >= Config.GUEST_LIST_LIMIT then
		notice("나열 금지! 게스트는 단어를 줄줄이 읽으면 안 돼요")
		return
	end
	local hits = {}
	for player, p in participants do
		if p.alive and p.role == "panel" and Judge.isConfirmed(p.word, text, p.aliases) then
			table.insert(hits, player)
		end
	end
	if #hits == 0 then
		return
	end
	lastGuestHitAt = os.clock()
	for i, player in hits do
		if i > Config.GUEST_MAX_HITS_PER_SENTENCE then
			break
		end
		eliminate(player, "guest", participants[player].word)
	end
end

local function judgePanel(player: Player, p: Participant, text: string): boolean
	local verdict = Judge.classify(p.word, text, p.aliases)
	if verdict == "CONFIRMED" then
		eliminate(player, "said", p.word)
		return true
	end
	if mode == "talkshow" then
		for other, o in participants do
			if other ~= player and o.alive and o.role == "panel" and Judge.isConfirmed(o.word, text, o.aliases) then
				eliminate(player, "foul", o.word)
				return true
			end
		end
	end
	if verdict == "SUSPECT" then
		remote("Suspect"):FireAllClients({ userId = player.UserId, name = player.DisplayName })
	end
	return false
end

local function onTranscript(player: Player, text: any)
	if phase ~= "Talk" or typeof(text) ~= "string" then
		return
	end
	local p = participants[player]
	if not p or not p.alive then
		return -- spectators and eliminated players only watch
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
	p.lastSpokeAt = now
	if p.role == "guest" then
		judgeGuest(text)
		return
	end
	table.insert(speechLog, { player = player, at = now })
	if #speechLog > 64 then
		table.remove(speechLog, 1)
	end
	if judgePanel(player, p, text) then
		return
	end

	local card = activeCard
	if card and card.player == player and not card.answered and isValidAnswer(p, text) then
		card.answered = true
		p.answers[normalizedAnswer(text)] = true
		remote("CardResult"):FireAllClients({ userId = player.UserId, name = player.DisplayName, outcome = "ok" })
	end
end

-- The client pings while its mic hears speech; a missed card is forgiven if speech was heard (recognition failure).
local function onVoicePing(player: Player)
	local now = os.clock()
	if now - (lastVoicePing[player] or 0) < Config.VOICE_PING_INTERVAL * 0.5 then
		return
	end
	lastVoicePing[player] = now
	local p = participants[player]
	if p and p.alive then
		p.lastVoiceAt = now
	end
end

local function onReady(player: Player, isReady: any)
	ready[player] = isReady == true
	broadcastState()
end

local function onVote(player: Player, choice: any)
	if phase ~= "Countdown" or (choice ~= "classic" and choice ~= "talkshow") then
		return
	end
	votes[player] = choice
	broadcastState()
end

-- A client that just loaded asks for the current state (round events may have fired before it was listening).
local function onSync(player: Player)
	remote("RoundState"):FireClient(player, statePayload())
	if phase == "Assign" or phase == "Talk" then
		sendWords(player)
	end
	if activeCard then
		remote("QuestionCard"):FireClient(player, cardPayload(activeCard))
	end
end

local function roundOver(): boolean
	local alive = #aliveList()
	return alive == 0 or (startedWith >= 2 and alive <= 1) or (mode == "talkshow" and guest == nil)
end

local function talking(myRound: number): boolean
	return phase == "Talk" and roundId == myRound and not roundOver()
end

local function waitUntil(t: number, myRound: number): boolean
	while os.clock() < t do
		if not talking(myRound) then
			return false
		end
		task.wait(0.1)
	end
	return talking(myRound)
end

-- Question cards on a fixed schedule (from issue time): fewest cards first, then the quietest.
local function runCards(myRound: number)
	local lastTarget: Player? = nil
	local function interval(): number
		return math.clamp(Config.TALK_TIME / math.max(#aliveList() * 2, 1), Config.QUESTION_MIN_INTERVAL, Config.QUESTION_MAX_INTERVAL)
	end
	local nextAt = os.clock() + interval()
	while waitUntil(nextAt, myRound) do
		local alive = aliveList()
		table.sort(alive, function(a, b)
			local pa, pb = participants[a], participants[b]
			if pa.cards ~= pb.cards then
				return pa.cards < pb.cards
			end
			return pa.lastSpokeAt < pb.lastSpokeAt
		end)
		local target = alive[1]
		if target == lastTarget and #alive > 1 then
			target = alive[2]
		end
		lastTarget = target
		local issuedAt = os.clock()
		local p = participants[target]
		p.cards += 1
		local card: Card = {
			player = target,
			answered = false,
			question = Prompts.question(rng),
			deadline = workspace:GetServerTimeNow() + Config.QUESTION_ANSWER_TIME,
		}
		activeCard = card
		remote("QuestionCard"):FireAllClients(cardPayload(card))
		while os.clock() - issuedAt < Config.QUESTION_ANSWER_TIME and not card.answered and talking(myRound) and p.alive do
			task.wait(0.1)
		end
		activeCard = nil
		if p.alive and not card.answered and talking(myRound) then
			if p.lastVoiceAt >= issuedAt then
				-- The mic heard speech but no usable text arrived: recognition failure, not silence.
				remote("CardResult"):FireAllClients({ userId = target.UserId, name = target.DisplayName, outcome = "unheard" })
			else
				p.strikes += 1
				local out = p.strikes >= Config.QUESTION_STRIKES
				remote("CardResult"):FireAllClients({ userId = target.UserId, name = target.DisplayName, outcome = if out then "out" else "warn" })
				if out then
					eliminate(target, "silent")
				end
			end
		end
		nextAt = issuedAt + interval()
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

-- Majority vote; ties are random. Talk show needs a guest plus enough panelists.
local function chooseMode(playerCount: number): string
	if playerCount < Config.TALKSHOW_MIN_PLAYERS then
		return "classic"
	end
	local counts = voteCounts()
	if counts.talkshow > counts.classic then
		return "talkshow"
	elseif counts.classic > counts.talkshow then
		return "classic"
	end
	return if rng:NextInteger(0, 1) == 0 then "classic" else "talkshow"
end

-- The player who has been guest the fewest times (random among ties).
local function chooseGuest(players: { Player }): Player
	local best: { Player } = {}
	local fewest = math.huge
	for _, player in players do
		local count = guestCounts[player] or 0
		if count < fewest then
			fewest, best = count, { player }
		elseif count == fewest then
			table.insert(best, player)
		end
	end
	local chosen = best[rng:NextInteger(1, #best)]
	guestCounts[chosen] = fewest + 1
	return chosen
end

local function runRound()
	-- Countdown + mode vote (cancelled if ready players drop below the minimum).
	table.clear(votes)
	guest = nil
	mode = "classic"
	setPhase("Countdown", Config.LOBBY_COUNTDOWN, "곧 시작해요 · 모드를 투표하세요")
	waitPhase(function()
		return #eligiblePlayers() < Config.MIN_PLAYERS
	end)
	local players = eligiblePlayers()
	if #players < Config.MIN_PLAYERS then
		return
	end

	-- Mode, seats and words. At most MAX_PLAYERS take part (talk show = guest + up to MAX_PLAYERS - 1 panelists).
	roundId += 1
	for i = #players, 2, -1 do
		local j = rng:NextInteger(1, i)
		players[i], players[j] = players[j], players[i]
	end
	while #players > Config.MAX_PLAYERS do
		table.remove(players)
	end
	mode = chooseMode(#players)
	local panelCandidates = players
	if mode == "talkshow" then
		local chosen = chooseGuest(players)
		if SeatService.seatGuest(chosen) then
			guest = chosen
			panelCandidates = {}
			for _, player in players do
				if player ~= chosen then
					table.insert(panelCandidates, player)
				end
			end
		else
			mode = "classic"
		end
	end
	local seated = SeatService.seatPlayers(panelCandidates)
	local panel = {}
	for _, player in panelCandidates do
		if seated[player] then
			table.insert(panel, player)
		end
	end
	local entries = WordBank.draw(#panel, rng)
	table.clear(participants)
	table.clear(lastTranscript)
	table.clear(speechLog)
	table.clear(roundAssists)
	guestHits = 0
	lastGuestHitAt = 0
	lastLaunchAt = 0
	local function newParticipant(player: Player, role: string, word: string, aliases: { string }): Participant
		return {
			player = player,
			role = role,
			word = word,
			aliases = aliases,
			alive = true,
			lastSpokeAt = 0,
			lastVoiceAt = 0,
			strikes = 0,
			cards = 0,
			answers = {},
		}
	end
	for i, player in panel do
		local entry = entries[i]
		participants[player] = newParticipant(player, "panel", entry.word, entry.aliases)
		local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Died:Once(function()
			eliminate(player, "died")
		end)
	end
	if guest then
		local guestPlayer = guest
		participants[guestPlayer] = newParticipant(guestPlayer, "guest", "", {})
		local humanoid = (guestPlayer.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Died:Once(function()
			if guest == guestPlayer then
				guest = nil -- no talk show without its guest; roundOver() ends the round
			end
		end)
	end
	startedWith = #panel
	refreshSpeakers()
	local assignText = if guest
		then string.format("토크쇼! 게스트 %s님이 패널의 금칙어를 말하게 만드세요 (남의 금칙어를 직접 말하면 반칙)", guest.DisplayName)
		else "내 금칙어는 나만 몰라요! 다른 사람이 말하게 만드세요"
	setPhase("Assign", Config.ASSIGN_TIME, assignText)
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

	-- Grace: late transcripts still count for a moment, and the last launch lands before the result shows.
	local graceUntil = os.clock() + Config.END_GRACE
	while os.clock() < graceUntil or os.clock() - lastLaunchAt < Config.LAUNCH_FLIGHT_TIME + Config.DEATH_DELAY do
		task.wait(0.1)
	end

	-- Result: surviving panelists score, the guest's launches and the best assister are named.
	local winners = {}
	for player, p in participants do
		if p.alive and p.role == "panel" then
			table.insert(winners, player.DisplayName)
			addScore(player, Config.SCORE_SURVIVE)
		end
	end
	local result = if #winners == 0 then "모두 탈락!" else table.concat(winners, ", ") .. " 생존!"
	if guest then
		result ..= string.format(" · 게스트 %s %d명 날림", guest.DisplayName, guestHits)
	end
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
	VoiceService.setSpeakers(nil)
	setPhase("Result", Config.RESULT_TIME, result)
	local reveal = {}
	for player, p in participants do
		if p.role == "panel" then
			reveal[tostring(player.UserId)] = p.word
		end
	end
	remote("Words"):FireAllClients(reveal)
	waitPhase()
	table.clear(participants)
	guest = nil
	startedWith = 0
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
	remote("Vote").OnServerEvent:Connect(onVote)
	remote("Ready").OnServerEvent:Connect(onReady)
	remote("VoicePing").OnServerEvent:Connect(onVoicePing)
	remote("Sync").OnServerEvent:Connect(onSync)

	for _, player in Players:GetPlayers() do
		setupLeaderstats(player)
	end
	Players.PlayerAdded:Connect(setupLeaderstats)
	Players.PlayerRemoving:Connect(function(player)
		local p = participants[player]
		if p and p.role == "guest" then
			guest = nil -- the talk show cannot go on without its guest; roundOver() ends the round
		elseif p then
			eliminate(player, "left")
		end
		participants[player] = nil
		lastTranscript[player] = nil
		lastVoicePing[player] = nil
		roundAssists[player] = nil
		votes[player] = nil
		ready[player] = nil
		guestCounts[player] = nil
	end)

	task.spawn(function()
		while true do
			local shown = -1
			while #eligiblePlayers() < Config.MIN_PLAYERS do
				local needed = Config.MIN_PLAYERS - #eligiblePlayers()
				if needed ~= shown then
					shown = needed
					local waitText = if Config.REQUIRE_VOICE_READY
						then string.format("마이크 준비된 플레이어 %d명 더 필요해요", needed)
						else string.format("플레이어 %d명 더 필요해요", needed)
					setPhase("Lobby", 0, waitText)
				end
				task.wait(1)
			end
			runRound()
		end
	end)
end

return RoundService
