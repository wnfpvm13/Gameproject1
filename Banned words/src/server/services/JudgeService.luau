--!strict
-- Transcript intake and judging. Every alive participant is judged on everything they say during the talk
-- (no turns). The client cannot prove a transcript is real speech; these checks only stop spam and mix-ups.
--
-- Boundaries: the client sends the server time its speech segment started (and a segment id).
--   - speech that started before the talk began, or after the round ended (Match.cutoffAt), is ignored;
--   - a word only counts against speech that started after the word took effect.
-- The claimed start is clamped to the last CHUNK_MAX seconds, so it can only make judging more lenient.
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
local onSpeech: (Player) -> () = function() end
local recent: { [Player]: { number } } = {} -- os.clock() of recent transcripts (spam guard)
local seenSegments: { [Player]: { [number]: boolean } } = {}
local lastPing: { [Player]: number } = {}
local minuteCount, minuteStart, warnedThisMinute = 0, os.clock(), false

local function markActive()
	Match.lastActivityAt = os.clock()
end

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
	local limit = 1 + 5 * #Players:GetPlayers()
	if not warnedThisMinute and minuteCount > limit * 0.8 then
		warnedThisMinute = true
		warn(string.format("[BannedWords] %d transcripts this minute (STT limit for this CCU about %d)", minuteCount, limit))
	end
end

local function onTranscript(player: Player, text: any, startedAt: any, segmentId: any)
	if not open or typeof(text) ~= "string" or not Match.isAlive(player) then
		return
	end
	local cleaned = cleanText(text)
	if not cleaned or not underBurstLimit(player) then
		return
	end
	countRequest()
	if typeof(segmentId) == "number" then
		local seen = seenSegments[player] or {}
		seenSegments[player] = seen
		if seen[segmentId] then
			return -- the same segment twice
		end
		seen[segmentId] = true
	end
	markActive()

	local now = Match.now()
	local segmentStart = if typeof(startedAt) == "number" and startedAt == startedAt then startedAt else now - Config.CHUNK_MAX
	segmentStart = math.clamp(segmentStart, now - Config.CHUNK_MAX, now)
	if segmentStart < Match.talkStartedAt or segmentStart > Match.cutoffAt then
		return -- spoken before the talk began or after the round was decided
	end
	onSpeech(player)
	local p = Match.participants[player]
	for _, word in p.words do
		if word.effectiveAt <= segmentStart and Judge.isConfirmed(word.text, cleaned, word.aliases) then
			onHit(player, word.text)
			return
		end
	end
end

-- The mic hears speech: counts as table activity for the assistant host (never used to judge anyone).
local function onVoicePing(player: Player)
	local clock = os.clock()
	if clock - (lastPing[player] or 0) < Config.VOICE_PING_INTERVAL * 0.5 then
		return
	end
	lastPing[player] = clock
	if open and Match.isAlive(player) then
		markActive()
	end
end

-- hit(player, word): a word was said. speech(player): a judged transcript arrived (assist tracking).
function JudgeService.start(hit: (Player, string) -> (), speech: (Player) -> ())
	onHit = hit
	onSpeech = speech
	Net.listen("Transcript", onTranscript)
	Net.listen("VoicePing", onVoicePing)
	Players.PlayerRemoving:Connect(function(player)
		recent[player] = nil
		seenSegments[player] = nil
		lastPing[player] = nil
	end)
end

function JudgeService.setOpen(isOpen: boolean)
	open = isOpen
	if isOpen then
		table.clear(recent)
		markActive()
	end
end

return JudgeService
