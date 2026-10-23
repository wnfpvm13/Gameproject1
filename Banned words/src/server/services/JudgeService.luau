--!strict
-- Transcript intake and judging (bundle 6e): every alive participant is judged on everything they say during the
-- banned-word talk (RoundService opens it for the talk stage while speech judging is on, docs/DESIGN_V3.md §3, §6).
-- The client cannot prove a transcript is real speech (the owner accepted that limit); these checks only stop spam
-- and mix-ups.
--
-- Boundaries: the client sends the server-time range its speech began in, the latest time it may have ended (and
-- a text id), see Speech.luau.
--   - speech that may have begun before the talk (Match.talkStartedAt), or after its end (Match.cutoffAt: the talk's
--     end, or the moment the round was decided), is ignored;
--   - so is speech that may have gone on past cutoffAt + END_TOLERANCE (its words may come after the end);
--   - a word only counts if it was in effect for the whole range (unsure -> no launch).
-- End of the talk: settle() keeps judging open until every alive voice player's client says that its speech which
-- may still count has been sent (or SETTLE_MAX passes), so a sentence finished right at the end still counts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local Judge = require(shared:WaitForChild("Judge"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local JudgeService = {}

local open = false
local onHit: (Player, string) -> () = function() end
local recent: { [Player]: { number } } = {} -- os.clock() of recent transcripts (spam guard)
local seenTexts: { [Player]: { [number]: boolean } } = {}
local minuteCount, minuteStart, warnedThisMinute = 0, os.clock(), false
local settleKey = 0
local settled: { [Player]: boolean } = {}
-- Numbers of the talk now open, for the server console (the live test measures accuracy and the request limit; what
-- was said is never logged): transcripts received (repeats included), from how many players, judged inside the talk,
-- word matches (before RoundService drops some: a judgment already open, flying, ...), and the most transcripts this
-- server took in one fixed 60 s window (a window may span the talk before; a lower bound of the STT requests).
export type Stats = { transcripts: number, players: number, judged: number, hits: number, peakMinute: number }
local stats: Stats = { transcripts = 0, players = 0, judged = 0, hits = 0, peakMinute = 0 }
local speakers: { [Player]: boolean } = {}

-- Cuts at a character boundary (never mid-syllable); nil if the text is not valid UTF-8.
local function cleanText(text: string): string?
	if utf8.len(text) == nil then
		return nil
	end
	if #text <= Config.TRANSCRIPT_MAX_BYTES then
		return text
	end
	local cut = #text
	for position in utf8.codes(text) do
		if position - 1 > Config.TRANSCRIPT_MAX_BYTES then
			break
		end
		cut = position - 1
	end
	return string.sub(text, 1, cut)
end

-- At most TRANSCRIPT_BURST transcripts per TRANSCRIPT_BURST_WINDOW seconds per player (real STT is far slower).
local function underBurstLimit(player: Player): boolean
	local list = recent[player] or {}
	recent[player] = list
	local now = os.clock()
	while list[1] and now - list[1] > Config.TRANSCRIPT_BURST_WINDOW do
		table.remove(list, 1)
	end
	if #list >= Config.TRANSCRIPT_BURST then
		return false
	end
	table.insert(list, now)
	return true
end

-- Requests are experience-wide limited (1 + 5 x CCU per minute); log when this server gets close on its own.
local function countRequest()
	if os.clock() - minuteStart >= 60 then
		minuteCount, minuteStart, warnedThisMinute = 0, os.clock(), false
	end
	minuteCount += 1
	stats.peakMinute = math.max(stats.peakMinute, minuteCount)
	local limit = 1 + 5 * #Players:GetPlayers()
	if not warnedThisMinute and minuteCount > limit * 0.8 then
		warnedThisMinute = true
		warn(string.format("[BannedWords] %d transcripts this minute (STT limit for this CCU about %d)", minuteCount, limit))
	end
end

local function onTranscript(player: Player, text: any, earliest: any, latest: any, ended: any, textId: any)
	if not open or typeof(text) ~= "string" or not Match.isAlive(player) then
		return
	end
	-- The cheap checks first: how often, then how long (a huge text is not even read).
	if not underBurstLimit(player) or #text > Config.TRANSCRIPT_MAX_BYTES * 4 then
		return
	end
	local cleaned = cleanText(text)
	if not cleaned then
		return
	end
	countRequest()
	stats.transcripts += 1
	if not speakers[player] then
		speakers[player] = true
		stats.players += 1
	end
	-- A table key must be a real number: NaN would throw, and infinities or fractions are never real ids.
	if typeof(textId) == "number" and textId == textId and math.abs(textId) < math.huge and textId % 1 == 0 then
		local seen = seenTexts[player] or {}
		seenTexts[player] = seen
		if seen[textId] then
			return -- the same transcript twice
		end
		seen[textId] = true
	end

	-- The speech began somewhere in [from, to] and ended by endedBy. Nothing is clamped in the harsher direction:
	-- an earlier start or a later end can only make judging more lenient (a client could just as well not send it).
	if typeof(earliest) ~= "number" or typeof(latest) ~= "number" or typeof(ended) ~= "number"
		or earliest ~= earliest or latest ~= latest or ended ~= ended then
		return
	end
	local now = Match.now()
	local from = math.min(earliest, now)
	local to = math.clamp(latest, from, now)
	local endedBy = math.max(ended, to)
	if from < Match.talkStartedAt or to > Match.cutoffAt or endedBy > Match.cutoffAt + Config.END_TOLERANCE then
		return -- may have been spoken before the talk, after it ended, or well past that moment
	end
	stats.judged += 1
	local p = Match.participants[player]
	for _, word in p.words do
		if word.effectiveAt <= from and Judge.isConfirmed(word.text, cleaned, word.aliases) then
			stats.hits += 1
			onHit(player, word.text)
			return
		end
	end
end

-- hit(player, word): `player` said their banned word `word` in the talk (RoundService decides what follows).
function JudgeService.start(hit: (Player, string) -> ())
	onHit = hit
	Net.listen("Transcript", onTranscript)
	Net.listen("Settled", function(player, key)
		if key == settleKey then
			settled[player] = true
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		recent[player] = nil
		seenTexts[player] = nil
		settled[player] = nil
	end)
end

-- The talk ended at `cutoff`: blocks until every alive voice participant's client has sent its speech from before it
-- (at most SETTLE_MAX seconds; a notice if it takes a moment). Judging stays open meanwhile. Chat participants do
-- not transcribe, so they are not waited for.
function JudgeService.settle(cutoff: number)
	settleKey += 1
	table.clear(settled)
	Net.toAll("Settle", { key = settleKey, cutoff = cutoff })
	local started = os.clock()
	local noticed = false
	while os.clock() - started < Config.SETTLE_MAX do
		local pending = false
		for _, player in Match.aliveList() do
			local p = Match.participants[player]
			if not settled[player] and not (p and p.chat) then
				pending = true
				break
			end
		end
		if not pending then
			return
		end
		if not noticed and os.clock() - started >= Config.SETTLE_NOTICE_AFTER then
			noticed = true
			Net.notice(Config.TEXT.SETTLING)
		end
		task.wait(0.1)
	end
end

function JudgeService.setOpen(isOpen: boolean)
	open = isOpen
	if isOpen then
		table.clear(recent)
		table.clear(seenTexts) -- (text ids only matter within one talk)
		table.clear(speakers)
		stats = { transcripts = 0, players = 0, judged = 0, hits = 0, peakMinute = 0 }
	end
end

-- The numbers of the talk opened last (see Stats).
function JudgeService.stats(): Stats
	return table.clone(stats)
end

return JudgeService
