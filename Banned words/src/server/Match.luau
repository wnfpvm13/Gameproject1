--!strict
-- Shared match state plus small read helpers and the RoundState broadcast. No game rules: services read it,
-- and only RoundService changes phase and participants (LifeService the lives, ChatService the chat choice,
-- PresenterService the presenter).
-- Times: `Match.now()` (server clock shared with clients) for anything sent over the network,
-- os.clock() for local intervals.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Net = require(script.Parent:WaitForChild("Net"))

export type Word = {
	text: string,
	aliases: { string },
	effectiveAt: number, -- Match.now() from which saying it counts (0 = from the start of the talk)
}

export type Participant = {
	player: Player,
	words: { Word }, -- banned words (only during the banned-word talk, docs/DESIGN_V3.md §6)
	alive: boolean, -- still in the game (lives left, or a finalist after everyone fell at once)
	lives: number,
	afkMisses: number, -- answer missions missed in a row
	chat: boolean, -- plays by text chat this round (docs/DESIGN_V3.md §7; their voice is off until the result)
}

local Match = {
	phase = "Lobby", -- Lobby | Countdown | Assign | Play | Final | Result
	endsAt = 0,
	message = "",
	roundId = 0,
	serverKind = "public", -- "public" | "private" (docs/DESIGN_V3.md §3), set at each round start
	voiceJudging = false, -- speech judging of banned words is on (Config.VOICE_JUDGING; Studio: BW_VoiceJudging), set at
	-- each round start; the banned-word talk is played only then (owner 2026-10-23)
	talk = nil :: string?, -- the banned-word talk's stage: "prep" | "talk" | "settle" (nil: no talk, no words)
	presenter = nil :: Player?, -- runs this round from the podium (PresenterService decides who; nil = the system)
	presenterPending = false, -- a replacement is being looked for (clients wait before naming who presents)
	participants = {} :: { [Player]: Participant },
	startedWith = 0,
	game = 0, -- the main game's mission being briefed or played, 1..Config.ROUND_GAMES (0 before the first)
	ready = {} :: { [Player]: boolean }, -- voice connected + mic test passed (the client says so)
	voiceLinked = {} :: { [Player]: boolean }, -- voice connected, muted or not (the client says so, with "Ready")
	voiceAccount = {} :: { [Player]: boolean }, -- the server found voice on the account (ChatService, owner 2026-10-25)
	chatJoin = {} :: { [Player]: boolean }, -- plays by text chat instead (ChatService decides who may)
	-- Speech judging (JudgeService, bundle 6e; the talk stage sets them, the settle stage ends them):
	talkStartedAt = math.huge, -- Match.now() when the talk began; speech from before it is ignored
	cutoffAt = math.huge, -- Match.now() when the round is decided; later speech is ignored
}

function Match.now(): number
	return workspace:GetServerTimeNow()
end

-- A round is being played (seats taken): Assign, Play or Final.
function Match.inRound(): boolean
	return Match.phase == "Assign" or Match.phase == "Play" or Match.phase == "Final"
end

function Match.isAlive(player: Player): boolean
	local p = Match.participants[player]
	return p ~= nil and p.alive
end

function Match.aliveList(): { Player }
	local list = {}
	for player, p in Match.participants do
		if p.alive then
			table.insert(list, player)
		end
	end
	return list
end

-- Every word in play this round (out players' words too, so new words never overlap them).
function Match.wordsInPlay(): { string }
	local list = {}
	for _, p in Match.participants do
		for _, word in p.words do
			table.insert(list, word.text)
		end
	end
	return list
end

-- Plays by voice: a voice account (the server's check) whose client says voice is connected and the mic was heard.
-- A client cannot make an account without voice ready (owner 2026-10-25: voice is a must; Codex 9a P1).
function Match.readyByVoice(player: Player): boolean
	return Match.ready[player] == true and Match.voiceAccount[player] == true
end

-- Plays by chat: chose it, and its voice is connected (to hear everyone, owner 2026-10-25).
function Match.readyByChat(player: Player): boolean
	return Match.chatJoin[player] == true and Match.voiceLinked[player] == true and Match.voiceAccount[player] == true
end

function Match.eligiblePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local placed = character ~= nil and character.Parent == workspace and character:FindFirstChild("HumanoidRootPart") ~= nil
		local joined = Match.readyByVoice(player) or Match.readyByChat(player) or not Config.REQUIRE_VOICE_READY
		if humanoid and humanoid.Health > 0 and placed and joined then
			table.insert(list, player)
		end
	end
	return list
end

function Match.payload()
	local ids, alive, lives = {}, {}, {}
	for player, p in Match.participants do
		table.insert(ids, player.UserId)
		if p.alive then
			table.insert(alive, player.UserId)
		end
		lives[tostring(player.UserId)] = p.lives
	end
	return {
		phase = Match.phase,
		endsAt = Match.endsAt,
		message = Match.message,
		participants = ids,
		alive = alive,
		lives = lives, -- userId string -> lives left
		maxLives = Config.LIVES,
		total = Match.startedWith,
		game = Match.game,
		games = Config.ROUND_GAMES,
		readyCount = #Match.eligiblePlayers(),
		requireReady = Config.REQUIRE_VOICE_READY,
		serverKind = Match.serverKind,
		talk = Match.talk,
		presenter = if Match.presenter then Match.presenter.UserId else nil,
		presenterPending = Match.presenterPending,
	}
end

function Match.broadcast()
	Net.toAll("RoundState", Match.payload())
end

function Match.setPhase(name: string, duration: number, text: string)
	Match.phase = name
	Match.endsAt = Match.now() + duration
	Match.message = text
	Match.broadcast()
end

-- A new status line within the same phase (a mission starting, the next game).
function Match.setMessage(text: string)
	Match.message = text
	Match.broadcast()
end

-- Clears everything that belongs to one round.
function Match.resetRound()
	table.clear(Match.participants)
	Match.startedWith = 0
	Match.game = 0
	Match.presenter = nil
	Match.presenterPending = false
	Match.talk = nil
	Match.talkStartedAt = math.huge
	Match.cutoffAt = math.huge
end

return Match
