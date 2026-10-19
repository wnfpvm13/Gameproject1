--!strict
-- Forbidden words: first word at the start, then one more for everyone alive at WORD_STEPS (max 3 words),
-- and what each viewer may see. Nobody ever receives their own words while alive.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local WordBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("WordBank"))

local WordService = {}

local function addWord(p: Match.Participant, kind: "noun" | "habit", effectiveAt: number, rng: Random): boolean
	local entry = WordBank.draw(kind, Match.reservedTexts(), rng)
	if not entry then
		return false
	end
	table.insert(p.words, { text = entry.word, aliases = entry.aliases, effectiveAt = effectiveAt })
	return true
end

-- One noun per participant, none overlapping another.
function WordService.assignFirst(rng: Random)
	for _, p in Match.participants do
		addWord(p, "noun", 0, rng)
	end
end

-- What `viewer` sees: { [userId] = { words = {...} | nil (own, while alive), count = n } }.
-- Words become visible at their effective time, so nobody can steer toward a word before it counts.
function WordService.payloadFor(viewer: Player)
	local now = Match.now()
	local result = {}
	for player, p in Match.participants do
		local visible = {}
		for _, word in p.words do
			if word.effectiveAt <= now then
				table.insert(visible, word.text)
			end
		end
		local hidden = player == viewer and p.alive and Match.phase ~= "Result"
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

-- Runs alongside the talk: warns, then adds a word to everyone alive. `stillTalking()` stops it,
-- `onAdded()` runs after each new word (the host re-checks its cards).
-- A burst of eliminations (2+ in WORD_DELAY_WINDOW) pushes the step back, also after the warning, up to WORD_DELAY_MAX.
function WordService.runSchedule(talkSeconds: number, stillTalking: () -> boolean, onAdded: () -> (), rng: Random)
	local start = Match.now()
	for index, fraction in Config.WORD_STEPS do
		local wordCount = index + 1
		local effectiveAt = start + talkSeconds * fraction
		local delayed = 0
		local warned = false
		local lastCheck = os.clock()
		while true do
			if not stillTalking() then
				return
			end
			local burst = Match.recentLaunches(Config.WORD_DELAY_WINDOW) >= 2
			if burst and delayed < Config.WORD_DELAY_MAX and Match.now() >= effectiveAt - Config.WORD_WARNING then
				local step = os.clock() - lastCheck
				delayed += step
				effectiveAt += step
				if warned and math.floor(delayed) ~= math.floor(delayed - step) then
					Net.toAll("WordWarn", { at = effectiveAt, count = wordCount }) -- the countdown moves back (1/s)
				end
			end
			lastCheck = os.clock()
			if effectiveAt > Match.endsAt - Config.WORD_WARNING then
				if warned then
					Net.toAll("WordWarn", { at = 0, count = wordCount }) -- cancelled
				end
				return -- too close to the end to matter
			end
			if not warned and Match.now() >= effectiveAt - Config.WORD_WARNING then
				warned = true
				Net.toAll("WordWarn", { at = effectiveAt, count = wordCount })
			end
			if Match.now() >= effectiveAt then
				break -- checked above in this same step: still talking, no burst delay pending
			end
			task.wait(0.25)
		end
		local kind: "noun" | "habit" = if wordCount == 3 and rng:NextNumber() < Config.HABIT_WORD_CHANCE then "habit" else "noun"
		for _, p in Match.participants do
			if p.alive then
				addWord(p, kind, effectiveAt, rng)
			end
		end
		WordService.sendAll()
		onAdded()
		Net.notice(string.format("금칙어가 %d개가 됐어요! 머리 위를 다시 확인하세요", wordCount))
	end
end

return WordService
