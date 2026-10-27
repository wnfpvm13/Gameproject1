--!strict
-- Difficulty modes (bundle 11b, owner 2026-10-27: "바보모드, 일반모드(고1수준), 똑똑이모드를 투표로"; docs/
-- BUNDLE11_2026-10-27.md): the players vote one at the start of each round. Here: the modes (id, name, one-line rule),
-- the vote's rule (Modes.decide) and the numbers a mode changes (Config.MODE_TUNING over Config). Shared: the server
-- plays by it, the client names the mode.
local Config = require(script.Parent:WaitForChild("Config"))

local Modes = {}

export type Entry = { id: string, title: string, brief: string }

Modes.DEFAULT = "normal"

-- In the vote's order.
Modes.LIST = {
	{ id = "easy", title = Config.TEXT.MODE_EASY, brief = Config.TEXT.MODE_EASY_BRIEF },
	{ id = "normal", title = Config.TEXT.MODE_NORMAL, brief = Config.TEXT.MODE_NORMAL_BRIEF },
	{ id = "hard", title = Config.TEXT.MODE_HARD, brief = Config.TEXT.MODE_HARD_BRIEF },
} :: { Entry }

-- The mode's name ("" for none).
function Modes.title(mode: string?): string
	for _, entry in Modes.LIST do
		if entry.id == mode then
			return entry.title
		end
	end
	return ""
end

-- `key`'s number in `mode`: its Config.MODE_TUNING entry, else Config's own.
function Modes.value(mode: string?, key: string): any
	local tuning = (Config.MODE_TUNING :: any)[mode or Modes.DEFAULT]
	local value = if tuning then tuning[key] else nil
	if value ~= nil then
		return value
	end
	return (Config :: any)[key]
end

-- The vote's result from the votes per mode id: the most votes; a tie with the normal mode in it is the normal mode,
-- another tie is drawn; no votes at all is the normal mode.
function Modes.decide(counts: { [string]: number }, rng: Random): string
	local best, tied = 0, {}
	for _, entry in Modes.LIST do
		local votes = counts[entry.id] or 0
		if votes > best then
			best, tied = votes, { entry.id }
		elseif votes == best and votes > 0 then
			table.insert(tied, entry.id)
		end
	end
	if best == 0 then
		return Modes.DEFAULT
	elseif #tied == 1 then
		return tied[1]
	elseif table.find(tied, Modes.DEFAULT) then
		return Modes.DEFAULT
	end
	return tied[rng:NextInteger(1, #tied)]
end

return Modes
