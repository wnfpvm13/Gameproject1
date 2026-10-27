--!strict
-- Beta measurements (owner 2026-10-24: decide what to build next from numbers): after each main-game mission, one
-- server console line (how it was chosen, the vote, players, lives lost, seconds), and on published servers Roblox
-- custom analytics events per player, sent when they happen (a player may leave before the game is over):
-- "MissionPlayed" at its start, "MissionLifeLost" at each life lost, with the mission id as custom field 1 (shown on
-- the Creator Dashboard, up to a day later). Nothing a player said or typed is recorded.
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Telemetry = {}

export type Game = {
	round: number,
	game: number, -- its number in the round
	mission: string, -- the mission id
	chosenBy: string, -- "vote" | "presenter" | "random"
	votes: { [string]: number }?, -- the vote's count per mission id
	players: { Player }, -- who played it (alive participants at its start)
	lost: { Player }, -- who lost a life in it
	seconds: number,
}

local function event(player: Player, name: string, mission: string)
	if RunService:IsStudio() then
		return -- (no analytics from Studio tests)
	end
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, name, 1, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = mission })
	end)
	if not ok then
		warn("[BannedWords] analytics:", err)
	end
end

local current = "" -- the mission being played (for the life events)

-- A main-game mission starts with `players`.
function Telemetry.gameStarted(players: { Player }, mission: string)
	current = mission
	for _, player in players do
		event(player, "MissionPlayed", mission)
	end
end

-- `player` lost a life in the mission being played (once per mission, RoundService checks).
function Telemetry.lifeLost(player: Player)
	if current ~= "" then
		event(player, "MissionLifeLost", current)
	end
end

-- The round's difficulty mode was voted (bundle 11b): its console line with the votes per mode.
function Telemetry.roundMode(round: number, mode: string, votes: { [string]: number })
	local parts = {}
	for id, count in votes do
		table.insert(parts, string.format("%s %d", id, count))
	end
	table.sort(parts)
	print(string.format("[BannedWords] stats round %d mode %s (%s)", round, mode, table.concat(parts, ", ")))
end

-- The mission is over: its console line (`entry`; nil when it had too few players to start).
function Telemetry.gameEnded(entry: Game?)
	current = ""
	if not entry then
		return
	end
	local votes = {}
	local counts: { [string]: number } = entry.votes or {}
	for id, count in counts do
		table.insert(votes, string.format("%s %d", id, count))
	end
	table.sort(votes)
	print(string.format("[BannedWords] stats round %d game %d %s: chosen by %s%s, %d players, %d lost a life, %.1f s",
		entry.round, entry.game, entry.mission, entry.chosenBy,
		if #votes > 0 then " (" .. table.concat(votes, ", ") .. ")" else "", #entry.players, #entry.lost, entry.seconds))
end

return Telemetry
