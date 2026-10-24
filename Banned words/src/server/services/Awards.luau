--!strict
-- Round awards on the result screen (owner 2026-10-24: failing should be fun too): the longest flight of the round
-- and who got through the most games without losing a life. Only this round; nothing is saved.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))

local Awards = {}

local farthest: { [Player]: number } = {} -- each player's longest flight this round (studs)
local survived: { [Player]: number } = {}

function Awards.beginRound()
	table.clear(farthest)
	table.clear(survived)
end

-- A flight came down `distance` studs from its chair.
function Awards.flight(player: Player, distance: number)
	farthest[player] = math.max(farthest[player] or 0, distance)
end

-- A game was played; `players` got through it without losing a life.
function Awards.gameOver(players: { Player })
	for _, player in players do
		survived[player] = (survived[player] or 0) + 1
	end
end

-- The names of the players with the highest count (ties share it), sorted, and that count.
local function best(counts: { [Player]: number }): ({ string }, number)
	local top = 0
	for player, count in counts do
		if player.Parent then
			top = math.max(top, count)
		end
	end
	local names = {}
	for player, count in counts do
		if player.Parent and count == top then
			table.insert(names, player.DisplayName)
		end
	end
	table.sort(names)
	return names, top
end

-- The lines for the result screen (none when nothing happened worth saying).
function Awards.lines(): { string }
	local lines = {}
	local flyers, distance = best(farthest) -- (among the players still here; ties share it)
	if distance > 0 then
		table.insert(lines, string.format(Config.TEXT.AWARD_FLIGHT, table.concat(flyers, ", "), distance * Config.STUDS_TO_METERS))
	end
	local names, top = best(survived)
	if top > 0 then
		table.insert(lines, string.format(Config.TEXT.AWARD_SURVIVOR, table.concat(names, ", "), top))
	end
	return lines
end

return Awards
