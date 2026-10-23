--!strict
-- The presenter's rescue (docs/DESIGN_V3.md §4; bundle 5b): an automatic hit (a banned word in chat) waits
-- RESCUE_SECONDS; the presenter may rescue it with "Rescue" (private servers: no limit). Then it is resolved either
-- way: rescued (only a new word) or not (the penalty). A second hit of the same player while one waits is merged into
-- it. Who is hit and what follows is RoundService's business (`resolve`); this module keeps the waiting hits, tells
-- the presenter, and checks the presses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local RescueService = {}

export type Hit = { player: Player, word: string, data: any, rescued: boolean, endsAt: number }

local waiting: { [Player]: Hit } = {}
local count = 0
local resolve: (Hit) -> () = function(_hit) end

-- Everything waiting, as the presenter's list: { { userId, word, endsAt } }.
local function list(): { { userId: number, word: string, endsAt: number } }
	local out = {}
	for player, hit in waiting do
		if not hit.rescued then
			table.insert(out, { userId = player.UserId, word = hit.word, endsAt = hit.endsAt })
		end
	end
	return out
end

local function tellPresenter()
	if Match.presenter then
		Net.to(Match.presenter, "Rescue", { hits = list() })
	end
end

-- onResolved(hit): the wait is over (hit.rescued says how).
function RescueService.start(onResolved: (Hit) -> ())
	resolve = onResolved
	Net.listen("Rescue", function(player, userId)
		if player ~= Match.presenter or typeof(userId) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(userId)
		local hit = target and waiting[target]
		if hit and not hit.rescued and Match.now() <= hit.endsAt then
			hit.rescued = true
			tellPresenter()
		end
	end)
end

-- A banned word was caught for `player`. Returns false if a hit of theirs is already waiting (merged into it).
function RescueService.hit(player: Player, word: string, data: any): boolean
	if waiting[player] then
		return false
	end
	local hit: Hit = { player = player, word = word, data = data, rescued = false, endsAt = Match.now() + Config.RESCUE_SECONDS }
	waiting[player] = hit
	count += 1
	tellPresenter()
	task.delay(Config.RESCUE_SECONDS, function()
		if waiting[player] ~= hit then
			return -- cleared (round over)
		end
		waiting[player] = nil
		count -= 1
		tellPresenter()
		resolve(hit)
	end)
	return true
end

-- Hits still waiting (the round's outcome waits for them, §2).
function RescueService.pending(): number
	return count
end

-- The presenter asked for the whole state again, or changed.
function RescueService.send()
	tellPresenter()
end

-- Round over: waiting hits are dropped.
function RescueService.endRound()
	table.clear(waiting)
	count = 0
	tellPresenter()
end

return RescueService
