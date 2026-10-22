--!strict
-- Round flow (the only module that wires the services together):
--   Lobby -> Countdown -> Assign (seats, first word, theme) -> Talk (free talk, words pile up, host helps)
--   -> Result -> Countdown (quick rematch) ...
-- Rules live in the services: words in WordService, judging in JudgeService, theme/missions in MissionService,
-- mission votes in VoteService, spectators in SpectatorService, flying chairs in SeatService, voice routing in
-- VoiceService, score in Scores.
-- Nobody is eliminated for staying quiet; only saying one of your words launches you. (V3 bundle 2a: the V2 rules
-- still run here, with the V3 pool hall, flying-chair launch, stands and show camera; docs/DESIGN_V3.md.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent:WaitForChild("Match"))
local Net = require(script.Parent:WaitForChild("Net"))
local services = script.Parent:WaitForChild("services")
local WordService = require(services:WaitForChild("WordService"))
local JudgeService = require(services:WaitForChild("JudgeService"))
local MissionService = require(services:WaitForChild("MissionService"))
local VoteService = require(services:WaitForChild("VoteService"))
local SpectatorService = require(services:WaitForChild("SpectatorService"))
local SeatService = require(services:WaitForChild("SeatService"))
local VoiceService = require(services:WaitForChild("VoiceService"))
local Scores = require(services:WaitForChild("Scores"))

local RoundService = {}

local rng = Random.new() -- words, seats (missions get fresh generators every round, see runRound)

-- Alive participants are heard by everyone; ghosts and spectators only by each other.
local function refreshSpeakers()
	local ids = {}
	for _, player in Match.aliveList() do
		table.insert(ids, player.UserId)
	end
	VoiceService.setSpeakers(ids)
end

local function wordTexts(p: Match.Participant): { string }
	local list = {}
	for _, word in p.words do
		table.insert(list, word.text)
	end
	return list
end

local function roundOver(): boolean
	local alive = #Match.aliveList()
	return alive == 0 or (Match.startedWith >= 2 and alive <= 1)
end

-- reason: "said" (one of their words) | "died" (reset/fell) | "left" (quit the server)
local function eliminate(player: Player, reason: string, word: string?)
	local p = Match.participants[player]
	if not p or not p.alive then
		return
	end
	p.alive = false
	if Match.phase == "Talk" and roundOver() then
		Match.cutoffAt = math.min(Match.cutoffAt, Match.now()) -- the round is decided right now
	end
	local helper = if reason == "said" then Scores.creditAssist(player) else nil
	Net.toAll("Eliminated", {
		userId = player.UserId,
		name = player.DisplayName,
		reason = reason,
		word = word,
		words = wordTexts(p),
		assistName = if helper then helper.DisplayName else nil,
	})
	if reason ~= "left" then
		table.insert(Match.launches, os.clock()) -- eliminations that delay the next word
	end
	if reason == "said" then
		Match.saidCount += 1
		Match.holdHost(Config.AFTER_LAUNCH_QUIET)
		SeatService.fling(player, Match.roundId) -- back from the pool into the stands (onFlightOver)
	end
	refreshSpeakers()
	Match.broadcast()
	WordService.sendAll() -- the eliminated player may now see their own words
end

-- FLING_RETURN_SECONDS after a launch (docs/DESIGN_V3.md §10 step 4): undo the ragdoll, then back on the chair if
-- the player is still in this round's game, else into the stands. A flight from an older round, or of a character
-- the player no longer has, only gets undone.
local function onFlightOver(player: Player, roundId: any, character: Model)
	SeatService.endFling(player)
	if not player.Parent or player.Character ~= character or roundId ~= Match.roundId then
		return
	end
	if not (Match.phase == "Assign" or Match.phase == "Talk") then
		return
	end
	if not (Match.isAlive(player) and SeatService.reseat(player)) then
		SpectatorService.toStands(player)
	end
end

local function talking(myRound: number): () -> boolean
	return function()
		return Match.phase == "Talk" and Match.roundId == myRound and not roundOver() and Match.now() < Match.endsAt
	end
end

local function waitPhase(shouldStop: (() -> boolean)?)
	while Match.now() < Match.endsAt do
		if shouldStop and shouldStop() then
			return
		end
		task.wait(0.2)
	end
end

local function matchSeconds(players: number): number
	for _, step in Config.MATCH_TIME do
		if players <= step.upTo then
			return step.seconds
		end
	end
	return Config.MATCH_TIME[#Config.MATCH_TIME].seconds
end

local function shuffled(list: { Player }): { Player }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

local function resultText(): string
	local survivors = {}
	for player, p in Match.participants do
		if p.alive then
			table.insert(survivors, player)
			Scores.add(player, Config.SCORE_SURVIVE)
		end
	end
	local text
	if #survivors == 0 then
		text = "모두 탈락!"
	elseif #survivors == 1 and Match.startedWith >= 2 then
		local name = survivors[1].DisplayName
		text = if Match.saidCount > 0 then name .. " 최후의 1인!" else name .. " 기권승 (다른 참가자가 모두 나갔어요)"
	else
		local names = {}
		for _, player in survivors do
			table.insert(names, player.DisplayName)
		end
		text = table.concat(names, ", ") .. " 공동 생존!"
	end
	local best, bestScore = Scores.bestAssist()
	if best then
		text ..= string.format(" · 유도왕 %s (%d점)", best.DisplayName, bestScore)
	end
	return text
end

local function cleanup()
	JudgeService.setOpen(false)
	SeatService.releaseAll()
	VoiceService.setSpeakers(nil)
	SpectatorService.endRound()
	MissionService.clear()
	VoteService.clear()
	Match.resetRound()
end

local function runRound()
	-- Countdown (short right after a result, so friends can go again quickly).
	local rematch = os.clock() - Match.lastEndedAt < 20
	Match.setPhase("Countdown", if rematch then Config.REMATCH_COUNTDOWN else Config.LOBBY_COUNTDOWN, "곧 시작해요")
	waitPhase(function()
		return #Match.eligiblePlayers() < Config.MIN_PLAYERS
	end)
	local candidates = shuffled(Match.eligiblePlayers())
	if #candidates < Config.MIN_PLAYERS then
		return
	end
	while #candidates > Config.MAX_PLAYERS do
		table.remove(candidates)
	end

	-- Assign: seats, first word, theme.
	Match.roundId += 1
	local myRound = Match.roundId
	Match.resetRound()
	Scores.resetRound()
	local seated = SeatService.seatPlayers(candidates)
	for _, player in candidates do
		if seated[player] then
			Match.participants[player] = { player = player, words = {}, alive = true }
			local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
			humanoid.Died:Once(function()
				eliminate(player, "died")
			end)
		end
	end
	Match.startedWith = #Match.aliveList()
	WordService.assignFirst(rng)
	MissionService.setup(Random.new()) -- theme: never depends on the words or on earlier rounds
	SpectatorService.beginRound()
	refreshSpeakers()
	Match.setPhase("Assign", Config.ASSIGN_TIME, "내 금칙어는 나만 몰라요! 다른 사람이 말하게 만드세요")
	WordService.sendAll()
	waitPhase()

	-- Talk: free conversation; words pile up and the host helps only when it goes quiet.
	local seconds = matchSeconds(Match.startedWith)
	Match.talkStartedAt = Match.now()
	JudgeService.setOpen(true)
	Match.setPhase("Talk", seconds, Match.theme or "대화 시작")
	Match.cutoffAt = Match.endsAt -- decided at the latest when the time runs out (no polling gap at the end)
	local stillTalking = talking(myRound)
	task.spawn(WordService.runSchedule, seconds, stillTalking, rng)
	task.spawn(MissionService.run, seconds, stillTalking, Random.new(), function(spec)
		return VoteService.run(spec, stillTalking) -- (outcome, announce)
	end)
	waitPhase(roundOver)

	-- Settle: speech that began before the round was decided still counts once its text arrives, then judging
	-- closes. The phase stays Talk meanwhile, so the clients keep their recognizers on.
	Match.cutoffAt = math.min(Match.cutoffAt, Match.now(), Match.endsAt)
	JudgeService.settle(Match.cutoffAt)
	JudgeService.setOpen(false)
	-- The result waits for flights in progress (they land and go to the stands first).
	local flightsDeadline = os.clock() + Config.FLING_RETURN_SECONDS + 1
	while SeatService.anyFlying() and os.clock() < flightsDeadline do
		task.wait(0.1)
	end

	-- Result: everyone sees every word.
	local text = resultText()
	SeatService.releaseAll()
	VoiceService.setSpeakers(nil)
	VoteService.clear() -- a vote cut off by the end of the talk leaves no window behind
	Match.setPhase("Result", Config.RESULT_TIME, text)
	WordService.sendAll()
	waitPhase()
	cleanup()
	Match.lastEndedAt = os.clock()
end

local function onSync(player: Player)
	Net.to(player, "RoundState", Match.payload())
	if Match.phase ~= "Lobby" and Match.phase ~= "Countdown" then
		WordService.send(player)
		MissionService.send(player)
		VoteService.send(player)
	end
end

function RoundService.start()
	VoiceService.start()
	Scores.start()
	SpectatorService.start(SeatService.isFlying)
	VoteService.start()
	SeatService.init(onFlightOver)
	JudgeService.start(function(player, word)
		eliminate(player, "said", word)
	end, Scores.noteSpeech)
	Net.listen("Ready", function(player, isReady)
		local value = isReady == true
		if (Match.ready[player] == true) ~= value then -- repeats change nothing and send nothing
			Match.ready[player] = value
			Match.broadcast()
		end
	end)
	local lastSync: { [Player]: number } = {}
	Net.listen("Sync", function(player)
		local now = os.clock()
		if now - (lastSync[player] or -math.huge) >= Config.SYNC_COOLDOWN then
			lastSync[player] = now
			onSync(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSync[player] = nil
	end)
	-- Studio only (there is no speech-to-text in Studio; live servers ignore it): a seated player launches themselves
	-- and comes back to the chair, or with "out" is eliminated (launch, then the stands).
	Net.listen("DevFling", function(player, mode)
		if not (RunService:IsStudio() and Match.isAlive(player) and (Match.phase == "Assign" or Match.phase == "Talk")) then
			return
		end
		if mode == "out" then
			eliminate(player, "said", "테스트")
		else
			SeatService.fling(player, Match.roundId)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		eliminate(player, "left")
		Match.participants[player] = nil
		Match.ready[player] = nil
	end)

	task.spawn(function()
		while true do
			local shown = -1
			while #Match.eligiblePlayers() < Config.MIN_PLAYERS do
				local needed = Config.MIN_PLAYERS - #Match.eligiblePlayers()
				if needed ~= shown then
					shown = needed
					Match.setPhase("Lobby", 0, if Config.REQUIRE_VOICE_READY
						then string.format("마이크 준비된 플레이어 %d명 더 필요해요", needed)
						else string.format("플레이어 %d명 더 필요해요", needed))
				end
				task.wait(1)
			end
			local ok, err = xpcall(runRound, debug.traceback)
			if not ok then
				warn("[BannedWords] round crashed, recovering:", err)
				cleanup()
				Match.setPhase("Lobby", 3, "잠시 문제가 생겨서 다음 판을 준비해요")
				task.wait(3)
			end
		end
	end)
end

return RoundService
