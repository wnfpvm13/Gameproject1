--!strict
-- Shared match state plus small read helpers and the RoundState broadcast. No game rules: services read it,
-- and only RoundService (and LifeService for lives) changes phase, participants and lives.
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
	words: { Word }, -- banned words (none until bundle 5)
	alive: boolean, -- still in the game (lives left, or a finalist after everyone fell at once)
	lives: number,
	afkMisses: number, -- answer missions missed in a row
}

local Match = {
	phase = "Lobby", -- Lobby | Countdown | Assign | Play | Final | Result
	endsAt = 0,
	message = "",
	roundId = 0,
	serverKind = "public", -- "public" | "private" (docs/DESIGN_V3.md §3), set at each round start
	participants = {} :: { [Player]: Participant },
	startedWith = 0,
	ready = {} :: { [Player]: boolean },
	-- Speech judging and the V2 word schedule (JudgeService / WordService, back in phase 2 / bundle 5):
	talkStartedAt = math.huge, -- Match.now() when the talk began; speech from before it is ignored
	cutoffAt = math.huge, -- Match.now() when the round is decided; later speech is ignored
	lastActivityAt = 0, -- os.clock() of the last speech heard from an alive participant
	launches = {} :: { number }, -- os.clock() of each launch this round
	hostHeldUntil = 0, -- os.clock(): the word schedule waits until then
	nextWordWarnAt = math.huge, -- os.clock() of the next (public, scheduled) word warning
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

function Match.eligiblePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local placed = character ~= nil and character.Parent == workspace and character:FindFirstChild("HumanoidRootPart") ~= nil
		if humanoid and humanoid.Health > 0 and placed and (Match.ready[player] or not Config.REQUIRE_VOICE_READY) then
			table.insert(list, player)
		end
	end
	return list
end

-- The word schedule waits `seconds` before its next step (V2; WordService).
function Match.holdHost(seconds: number)
	Match.hostHeldUntil = math.max(Match.hostHeldUntil, os.clock() + seconds)
end

-- Launches in the last `seconds` (V2: the word schedule waits after a burst of launches).
function Match.recentLaunches(seconds: number): number
	local count = 0
	local now = os.clock()
	for _, at in Match.launches do
		if now - at <= seconds then
			count += 1
		end
	end
	return count
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
		readyCount = #Match.eligiblePlayers(),
		requireReady = Config.REQUIRE_VOICE_READY,
		serverKind = Match.serverKind,
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

-- A new status line within the same phase (a mission starting, free talk again).
function Match.setMessage(text: string)
	Match.message = text
	Match.broadcast()
end

-- Clears everything that belongs to one round.
function Match.resetRound()
	table.clear(Match.participants)
	table.clear(Match.launches)
	Match.startedWith = 0
	Match.talkStartedAt = math.huge
	Match.cutoffAt = math.huge
	Match.hostHeldUntil = 0
	Match.nextWordWarnAt = math.huge
end

return Match
