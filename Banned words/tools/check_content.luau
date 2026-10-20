-- Content check (V2.1): run in Studio's Edit datamodel after installing the game (tools/install_game.luau).
-- Cards never adapt to the secret words, so every text a player may read aloud must be safe for EVERY word:
--   1. no word-bank word (or alias) appears in any theme name, role, mission text, option, notice, follow-up,
--      quiet-time event or topic (same rule as the judge: contiguous substring after normalisation);
--   2. every mission has its fields, 2-3 options, unique option ids, and a follow-up for each option + "undecided".
-- Returns "OK ..." or the list of problems. Re-run whenever Themes.luau or WordBank.luau changes.
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")

local Judge = require(RS.BannedWords.Judge)
local WordBank = require(SSS.BannedWords.content.WordBank)
local Themes = require(SSS.BannedWords.content.Themes)

local problems = {}
local checked = 0
local words = WordBank.allEntries()

local function checkText(where: string, text: string)
	checked += 1
	local plain = string.gsub(text, "{name}", "")
	for _, entry in words do
		if Judge.isConfirmed(entry.word, plain, entry.aliases) then
			table.insert(problems, string.format("%s: \"%s\" contains word \"%s\"", where, text, entry.word))
		end
	end
end

local function need(where: string, ok: boolean, what: string)
	if not ok then
		table.insert(problems, where .. ": " .. what)
	end
end

for _, theme in Themes.list do
	local t = theme.name
	checkText(t .. " name", theme.name)
	for _, role in theme.roles do
		checkText(t .. " role", role)
	end
	need(t, #theme.roles >= 10, "needs at least 10 roles (10 players)")
	for _, text in theme.events do
		checkText(t .. " event", text)
	end
	for _, text in theme.topics do
		checkText(t .. " topic", text)
	end
	need(t, #theme.missions >= 1, "has no missions")
	for _, mission in theme.missions do
		local m = t .. "/" .. tostring(mission.id)
		for _, field in { "situation", "problem", "goal", "notice" } do
			local value = (mission :: any)[field]
			need(m, type(value) == "string" and value ~= "", "missing " .. field)
			if type(value) == "string" then
				checkText(m .. " " .. field, value)
			end
		end
		need(m, #mission.options >= 2 and #mission.options <= 3, "needs 2-3 options")
		local ids = {}
		for _, option in mission.options do
			need(m, not ids[option.id], "duplicate option id " .. option.id)
			need(m, option.id ~= "undecided", "option id 'undecided' is reserved")
			ids[option.id] = true
			checkText(m .. " option", option.text)
			need(m, mission.followups[option.id] ~= nil, "no follow-up for option " .. option.id)
		end
		need(m, mission.followups.undecided ~= nil, "no 'undecided' follow-up")
		for key, text in mission.followups do
			need(m, key == "undecided" or ids[key] == true, "follow-up for unknown option " .. key)
			checkText(m .. " followup", text)
		end
	end
end
for _, text in Themes.general do
	checkText("general topic", text)
end

if #problems == 0 then
	return string.format("OK: %d texts checked against %d words", checked, #words)
end
return string.format("%d problem(s):\n%s", #problems, table.concat(problems, "\n"))
