-- Content check (V3): run in Studio's Edit datamodel after installing the game (tools/install_game.luau).
-- Fixed texts never adapt to the secret words, so every text a player may read aloud must be safe for EVERY word:
-- no word-bank word (or alias) appears in any fixed UI text (Config.TEXT) (same rule as the judge: substring after
-- normalisation). The quiz questions and the one-word topics of bundle 4 get checked here too once they exist
-- (docs/DESIGN_V3.md §16). Returns "OK ..." or the list of problems. Re-run whenever Config.TEXT or WordBank.luau
-- changes.
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")

local Judge = require(RS.BannedWords.Judge)
local Config = require(RS.BannedWords.Config)
local WordBank = require(SSS.BannedWords.content.WordBank)

local problems = {}
local checked = 0
local words = WordBank.allEntries()

local function checkText(where: string, text: string)
	checked += 1
	for _, entry in words do
		if Judge.isConfirmed(entry.word, text, entry.aliases) then
			table.insert(problems, string.format("%s: \"%s\" contains word \"%s\"", where, text, entry.word))
		end
	end
end

for key, text in Config.TEXT do
	checkText("Config.TEXT." .. key, text)
end

if #problems == 0 then
	return string.format("OK: %d texts checked against %d words", checked, #words)
end
return string.format("%d problem(s):\n%s", #problems, table.concat(problems, "\n"))
