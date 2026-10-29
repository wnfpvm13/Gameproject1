--!strict
-- The round's rules as pure functions (decision 11's tickets mode): who wins when the time runs out. Requires nothing.

local RoundRules = {}

-- A fighter still in when the time runs out: its name, tickets left, knock-offs and combat health.
export type Standing = { name: string, tickets: number, kos: number, health: number }

-- Whether `a` ranks above `b`: more tickets left, then more knock-offs, then more health.
local function above(a: Standing, b: Standing): boolean
	if a.tickets ~= b.tickets then
		return a.tickets > b.tickets
	elseif a.kos ~= b.kos then
		return a.kos > b.kos
	end
	return a.health > b.health
end

-- The winners among `list` when the time runs out: whoever ranks first (tickets, then knock-offs, then health), all of
-- them when several are tied on all three (a shared win), in the order given. None for an empty list.
function RoundRules.winners(list: { Standing }): { string }
	local best: Standing? = nil
	for _, standing in list do
		if not best or above(standing, best) then
			best = standing
		end
	end
	local names = {}
	if best then
		for _, standing in list do
			if not above(best, standing) then
				table.insert(names, standing.name)
			end
		end
	end
	return names
end

-- A knock-off for the home-run streaks of `streaks` (who has hit how many home runs in a row since last falling
-- themselves, persona fix 8): `victim` fell (its streak ends), and when it was a home run by `by`, that one's streak
-- grows. Returns `by`'s streak after it (0 when it was not a home run).
function RoundRules.homerunStreak(streaks: { [any]: number }, victim: any, by: any?, how: string): number
	streaks[victim] = nil
	if how ~= "homerun" or by == nil then
		return 0
	end
	local streak = (streaks[by] or 0) + 1
	streaks[by] = streak
	return streak
end

-- Wins in a row after a round (persona fix 8): of `entrants` (who took part), the one `winner` (nil: no single
-- winner) adds one to its run, everyone else's run ends. Returns the winner's run (0 without one).
function RoundRules.winStreak(runs: { [any]: number }, entrants: { any }, winner: any?): number
	for _, entrant in entrants do
		if entrant ~= winner then
			runs[entrant] = nil
		end
	end
	if winner == nil then
		return 0
	end
	local run = (runs[winner] or 0) + 1
	runs[winner] = run
	return run
end

-- What a fall (or a home run) leaves a fighter who had `tickets`: the tickets left, and whether that was the last one
-- (out of the round) or the fighter comes back.
function RoundRules.afterFall(tickets: number): (number, boolean)
	local left = math.max(0, tickets - 1)
	return left, left <= 0
end

return RoundRules
