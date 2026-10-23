--!strict
-- Banned words (V3, docs/DESIGN_V3.md §6; bundle 5a): one word per participant, a speech habit (진짜, 대박 ...) with
-- HABIT_WORD_CHANCE drawn for each player on their own (a kind shared by everyone could be read off the others'
-- heads), never overlapping another word in play. A word is replaced after it was said, or by the presenter's re-draw;
-- a new word also avoids `avoid` (the running mission's screen texts, the talk's topic). What each viewer may see:
-- everyone's words, except an alive participant's own (shown as hidden; shown in the solo speech test build,
-- Config.SHOW_OWN_WORD). Words exist only during the banned-word talk
-- (bundle 6a: RoundService assigns them in its prep stage and clears them after it); this module only keeps them in
-- Match.participants.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Judge = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Judge"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local WordBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("WordBank"))

local WordService = {}

local DRAW_TRIES = 20 -- words tried before giving up on one that avoids the screen texts

-- The words in play except `player`'s own (theirs is being replaced).
local function takenBy(except: Player?): { string }
	local list = {}
	for player, p in Match.participants do
		if player ~= except then
			for _, word in p.words do
				table.insert(list, word.text)
			end
		end
	end
	return list
end

-- A word for one player: their own kind draw, not overlapping `taken`, not inside any `avoid` text.
local function draw(taken: { string }, avoid: { string }?, rng: Random): WordBank.Entry?
	local kind: "noun" | "habit" = if rng:NextNumber() < Config.HABIT_WORD_CHANCE then "habit" else "noun"
	local blocked = table.clone(taken)
	for _ = 1, DRAW_TRIES do
		local entry = WordBank.draw(kind, blocked, rng)
		if not entry then
			return nil
		end
		local clean = true
		local texts: { string } = avoid or {}
		local forms = table.clone(entry.aliases)
		table.insert(forms, entry.word)
		for _, text in texts do
			for _, form in forms do
				if string.find(Judge.normalize(text), Judge.normalize(form), 1, true) then
					clean = false
				end
			end
		end
		if clean then
			return entry
		end
		table.insert(blocked, entry.word) -- try another
	end
	return nil
end

-- The talk's prep stage: one word for each alive participant, none inside `avoid` (the topic) when that can be done
-- (any old words are dropped). They count from `startJudging` on.
function WordService.assign(rng: Random, avoid: { string }?)
	for _, p in Match.participants do
		table.clear(p.words)
	end
	for _, p in Match.participants do
		if p.alive then
			local entry = draw(takenBy(nil), avoid, rng) or draw(takenBy(nil), nil, rng)
			if entry then
				table.insert(p.words, { text = entry.word, aliases = entry.aliases, effectiveAt = math.huge })
			end
		end
	end
end

-- The talk begins: every word counts from `at` (Match.now()).
function WordService.startJudging(at: number)
	for _, p in Match.participants do
		for _, word in p.words do
			word.effectiveAt = at
		end
	end
end

-- `player` gets a new word (said theirs, or the presenter re-drew it). Returns false if none could be drawn (the old
-- one stays).
function WordService.replace(player: Player, avoid: { string }?, rng: Random): boolean
	local p = Match.participants[player]
	if not p then
		return false
	end
	local old = {}
	for _, word in p.words do
		table.insert(old, word.text)
	end
	local taken = takenBy(player)
	for _, text in old do
		table.insert(taken, text) -- never the same word again
	end
	-- If nothing avoids the screen texts, a new word still beats keeping the one just said.
	local entry = draw(taken, avoid, rng) or draw(taken, nil, rng)
	if not entry then
		return false
	end
	table.clear(p.words)
	table.insert(p.words, { text = entry.word, aliases = entry.aliases, effectiveAt = Match.now() })
	return true
end

-- Everyone's words go (after the talk, between rounds).
function WordService.clear()
	for _, p in Match.participants do
		table.clear(p.words)
	end
end

-- What `viewer` sees: { [userId] = { words = {...} | nil (own, while playing), count = n } }.
function WordService.payloadFor(viewer: Player)
	local result = {}
	for player, p in Match.participants do
		local visible = {}
		for _, word in p.words do
			table.insert(visible, word.text)
		end
		local hidden = player == viewer and p.alive and Match.phase ~= "Result" and #visible > 0 -- (no word: nothing to hide)
			and not Config.SHOW_OWN_WORD
		result[tostring(player.UserId)] = { words = if hidden then nil else visible, count = #visible }
	end
	return result
end

function WordService.send(player: Player)
	Net.to(player, "Words", WordService.payloadFor(player))
end

function WordService.sendAll()
	for _, player in Players:GetPlayers() do
		WordService.send(player)
	end
end

return WordService
