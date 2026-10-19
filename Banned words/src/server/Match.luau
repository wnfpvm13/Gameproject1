--!strict
-- Shared match state plus small read helpers and the RoundState broadcast. No game rules: services read it,
-- and only RoundService changes phase and participants.
-- Times: `Match.now()` (server clock shared with clients) for anything sent over the network,
-- os.clock() for local intervals (activity, launches).
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
	words: { Word },
	role: string?,
	alive: boolean,
}

local Match = {
	phase = "Lobby", -- Lobby | Countdown | Assign | Talk | Result
	endsAt = 0,
	message = "",
	roundId = 0,
	participants = {} :: { [Player]: Participant },
	startedWith = 0,
	talkStartedAt = math.huge, -- Match.now() when Talk began; speech from before it is ignored
	cutoffAt = math.huge, -- Match.now() when the round was decided; speech that started later is ignored
	lastActivityAt = 0, -- os.clock() of the last speech heard from an alive participant
	launches = {} :: { number }, -- os.clock() of each launch this round
	saidCount = 0, -- launches for saying a word (tells a real win from a walkover)
	lastEndedAt = -math.huge, -- os.clock() when the last result finished (rematch countdown)
	ready = {} :: { [Player]: boolean },
	loading = {} :: { [Player]: boolean }, -- character being reloaded (not eligible until it is in place)
	theme = nil :: string?,
}

function Match.now(): number
	return workspace:GetServerTimeNow()
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

-- Every word in play this round (dead players' words too, so new words never overlap them).
function Match.wordsInPlay(): { string }
	local list = {}
	for _, p in Match.participants do
		for _, word in p.words do
			table.insert(list, word.text)
		end
	end
	return list
end

-- Texts a new word must not overlap: words in play plus the roles on everyone's name tag.
function Match.reservedTexts(): { string }
	local list = Match.wordsInPlay()
	for _, p in Match.participants do
		if p.role then
			table.insert(list, p.role)
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
		if humanoid and humanoid.Health > 0 and placed and not Match.loading[player] and (Match.ready[player] or not Config.REQUIRE_VOICE_READY) then
			table.insert(list, player)
		end
	end
	return list
end

-- Launches in the last `seconds` (the word schedule waits after a burst of eliminations).
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
	local ids, alive = {}, {}
	for player, p in Match.participants do
		table.insert(ids, player.UserId)
		if p.alive then
			table.insert(alive, player.UserId)
		end
	end
	return {
		phase = Match.phase,
		endsAt = Match.endsAt,
		message = Match.message,
		participants = ids,
		alive = alive,
		total = Match.startedWith,
		readyCount = #Match.eligiblePlayers(),
		requireReady = Config.REQUIRE_VOICE_READY,
		theme = Match.theme,
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

-- Clears everything that belongs to one round.
function Match.resetRound()
	table.clear(Match.participants)
	table.clear(Match.launches)
	Match.startedWith = 0
	Match.saidCount = 0
	Match.talkStartedAt = math.huge
	Match.cutoffAt = math.huge
	Match.theme = nil
end

return Match
