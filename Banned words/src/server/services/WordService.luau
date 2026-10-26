--!strict
-- Banned words (V3, docs/DESIGN_V3.md §6; bundle 5a): one word per participant, a speech habit (진짜, 대박 ...) with
-- HABIT_WORD_CHANCE drawn for each player on their own (a kind shared by everyone could be read off the others'
-- heads), never overlapping another word in play. A word is replaced after it was said, or by the presenter's re-draw;
-- a new word also avoids `avoid` (the running mission's screen texts, the talk's topic). What each viewer may see:
-- everyone's words, except an alive participant's own (shown as hidden; shown in the solo speech test build,
-- Config.SHOW_OWN_WORD). Words exist only during the banned-word talk
-- (bundle 6a: RoundService assigns them in its prep stage and clears them after it); this module only keeps them in
-- Match.participants. Bundle 9c (머리 위 스무고개): a mission may put up its own words instead (`place`), each owner
-- seeing theirs once it is known to them; and while any word is hidden from its owner, a chat line holding it must not
-- reach them (`hides`, for the chat gate).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Judge = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Judge"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local WordBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("WordBank"))
local WordAliases = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("WordAliases"))

local WordService = {}

local DRAW_TRIES = 20 -- words tried before giving up on one that avoids the screen texts

local shownToOwner: { [Player]: boolean } = {} -- a mission's words their owners may see (스무고개: right, or out of it)

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
	table.clear(shownToOwner)
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

-- A mission's own words over the heads (머리 위 스무고개, bundle 9c): `words` by player (any other word goes); an owner
-- sees theirs only once they are in `known`. They are never judged (only the talk judges words).
function WordService.place(words: { [Player]: string }, known: { [Player]: boolean })
	for player, p in Match.participants do
		table.clear(p.words)
		local text = words[player]
		if text then
			-- (its other forms too: "경찰" must not reach the owner of 경찰관, review 2026-10-25)
			table.insert(p.words, { text = text, aliases = table.clone(WordAliases[text] or {}), effectiveAt = math.huge })
		end
	end
	shownToOwner = table.clone(known)
end

-- Everyone's words go (after the talk or a mission's words, between rounds).
function WordService.clear()
	for _, p in Match.participants do
		table.clear(p.words)
	end
	table.clear(shownToOwner)
end

-- Whether `player`'s own words are hidden from them now: alive and playing, not the result, not known to them.
local function hiddenFromOwner(player: Player, p: Match.Participant): boolean
	return p.alive and Match.phase ~= "Result" and #p.words > 0 and not Config.SHOW_OWN_WORD and not shownToOwner[player]
end

-- Whether a chat line `text` holds a word hidden from `receiver` (their own): then it must not reach them.
function WordService.hides(receiver: Player, text: string): boolean
	local p = Match.participants[receiver]
	if not p or not hiddenFromOwner(receiver, p) then
		return false
	end
	for _, word in p.words do
		if Judge.chatHit(word.text, text, word.aliases) then
			return true
		end
	end
	return false
end

-- What `viewer` sees: { [userId] = { words = {...} | nil (own, while playing), count = n } }.
function WordService.payloadFor(viewer: Player)
	local result = {}
	for player, p in Match.participants do
		local visible = {}
		for _, word in p.words do
			table.insert(visible, word.text)
		end
		local hidden = player == viewer and hiddenFromOwner(player, p) -- (no word: nothing to hide)
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
