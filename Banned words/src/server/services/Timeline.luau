--!strict
-- The round's count and clock (docs/DESIGN_V3.md §2; owner 2026-10-24: a round is a number of games): ROUND_GAMES
-- games of main game, a time cap ROUND_MAX_SECONDS for missions (a mission that would not fit in the time left is not
-- started; when none fits, the final starts), and when the final is due: when the games are played or the time is up,
-- or as soon as FINAL_AT_ALIVE or fewer are left in a round begun with more than that (3 -> rounds of 4+).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))

local Timeline = {}

local startedAt = 0
local startedWith = 0
local gamesStarted = 0

-- The main game starts now with `players` participants.
function Timeline.begin(players: number)
	startedAt = os.clock()
	startedWith = players
	gamesStarted = 0
end

-- A main-game mission was played (one that had too few players to start does not count); returns how many so far.
function Timeline.gameStarted(): number
	gamesStarted += 1
	return gamesStarted
end

function Timeline.gamesLeft(): number
	return math.max(0, Config.ROUND_GAMES - gamesStarted)
end

function Timeline.left(): number
	return math.max(0, Config.ROUND_MAX_SECONDS - (os.clock() - startedAt))
end

-- Whether so few are left that the final starts at once (only in a round begun with more than FINAL_AT_ALIVE).
function Timeline.fewLeft(alive: number): boolean
	return startedWith > Config.FINAL_AT_ALIVE and alive <= Config.FINAL_AT_ALIVE
end

-- Whether the main game is over and the final should start, with `alive` participants left.
function Timeline.finalDue(alive: number): boolean
	return Timeline.gamesLeft() <= 0 or Timeline.left() <= 0 or Timeline.fewLeft(alive)
end

return Timeline
