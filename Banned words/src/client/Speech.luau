--!strict
-- Transcribes the local player's own mic. Roblox only runs AudioSpeechToText on clients, so every client
-- transcribes itself and the server judges. Voice starts disconnected (since 2026-01): AudioDeviceInput.Active
-- stays false until the player connects voice from the in-experience settings menu.
--
-- STT requests count against an experience-wide limit (1 + 5 x CCU per minute), so the recognizer is only
-- enabled while it matters — see setEnabled: the mic test, and the banned-word talk while speech judging is on
-- (bundle 6e, docs/DESIGN_V3.md §3, §6).
local Players = game:GetService("Players")

local Speech = {}

export type Status = "NoVoice" | "Disconnected" | "Muted" | "Listening" | "Speaking"

local input: AudioDeviceInput? = nil
local stt: AudioSpeechToText? = nil
local statusListeners: { (Status) -> () } = {}
local textListeners: { (string, number, number, number, number) -> () } = {}
local unstableListeners: { () -> () } = {}

local startedAt = os.clock()
local INPUT_GRACE = 15 -- seconds to wait for the AudioDeviceInput before calling the account voice-less
local UNSTABLE_SEGMENTS = 3 -- speech segments in a row that produced no text -> "recognition looks unstable"

-- Speech segments: the open one (voice detected now), finished ones still waiting for their text, and expired ones
-- (no text within WAIT_LIMIT) whose text may still turn up late, each kept on its own for EXPIRED_KEEP seconds.
-- Results arrive in order, so a text belongs to the oldest unanswered segment or a later one. One utterance stays
-- one segment from voice-on to voice-off even when Roblox cuts it (~10 s pieces, each its own text): `used` counts
-- the texts it already got, and when it ends it is owed one text per possible piece (`slots`, from its full length).
-- Which segment a transcript belongs to is not always certain, so every transcript carries a start RANGE (the
-- earliest and latest server time its speech may have begun) and the latest time it may have ended. The server
-- uses a word against it only if the word was in effect for the whole range, and drops it if the speech may have
-- begun after the round was decided or went on past it
-- (unsure -> lenient: a missed word is better than an unfair launch).
-- The first text of a segment began at `from`; a later piece began somewhere after it, up to now / the end.
type Segment = { from: number, endedAt: number?, slots: number, used: number, lastCut: number }
local openSegment: Segment? = nil
local waiting: { Segment } = {}
local expired: { Segment } = {}
local nextTextId = 0 -- one id per transcript, so the server's duplicate check never drops a later piece
local lastTextAt = -math.huge -- server time of the latest transcript (a segment ended before it was not a miss)
local silentSegments = 0
local WAIT_LIMIT = 3 -- seconds a finished segment waits for its text (Roblox: usually < 0.5 s) before it expires
local EXPIRED_KEEP = 30 -- an expired segment may still claim a late text until this long after its end
local CUT_MIN = 8 -- speech shorter than this cannot have been cut (~10 s); longer speech gets a slot per CUT_MIN
local UNKNOWN_SPAN = 12 -- a text with no segment at all: its speech began within this many seconds

function Speech.status(): Status
	if not input then
		return if os.clock() - startedAt < INPUT_GRACE then "Disconnected" else "NoVoice"
	elseif not input.Active then
		return "Disconnected"
	elseif input.Muted then
		return "Muted"
	elseif stt and stt.Enabled and stt.VoiceDetected then
		return "Speaking"
	end
	return "Listening"
end

local function emitStatus()
	local s = Speech.status()
	for _, fn in statusListeners do
		fn(s)
	end
end

function Speech.onStatus(fn: (Status) -> ())
	table.insert(statusListeners, fn)
	fn(Speech.status())
end

-- fn(text, earliest, latest, ended, textId): the server-time range the speech began in and the latest time it
-- may have ended (word-boundary fairness, see the Segment comment); textId (one per transcript) lets the server drop
-- a duplicate without dropping a repeated sentence or a later piece of the same utterance.
function Speech.onText(fn: (string, number, number, number, number) -> ())
	table.insert(textListeners, fn)
end

function Speech.onUnstable(fn: () -> ())
	table.insert(unstableListeners, fn)
end

function Speech.isSpeaking(): boolean
	return stt ~= nil and stt.Enabled and stt.VoiceDetected
end

function Speech.setEnabled(on: boolean)
	if stt and stt.Enabled ~= on then
		stt.Enabled = on
		openSegment = nil
		table.clear(waiting)
		table.clear(expired)
		lastTextAt = -math.huge
		silentSegments = 0
		emitStatus()
	end
end

local function newSegment(from: number): Segment
	return { from = from, slots = 1, used = 0, lastCut = from }
end

-- Finished segments without (all) their texts after WAIT_LIMIT expire. One counts as a recognition miss only if no
-- text at all came after it ended (a spare slot of an earlier long segment may have taken its text).
-- Expired ones are forgotten EXPIRED_KEEP seconds after their end.
local function expire(now: number)
	while waiting[1] and now - (waiting[1].endedAt :: number) > WAIT_LIMIT do
		local segment = table.remove(waiting, 1) :: Segment
		table.insert(expired, segment)
		if segment.used == 0 and lastTextAt < (segment.endedAt :: number) then
			silentSegments += 1
			if silentSegments == UNSTABLE_SEGMENTS then
				for _, fn in unstableListeners do
					fn()
				end
			end
		end
	end
	while expired[1] and now - (expired[1].endedAt :: number) > EXPIRED_KEEP do
		table.remove(expired, 1)
	end
end

local function onVoiceDetected(recognizer: AudioSpeechToText)
	local now = workspace:GetServerTimeNow()
	if recognizer.VoiceDetected then
		openSegment = newSegment(now)
	elseif openSegment then
		local finished = openSegment
		finished.endedAt = now
		-- one text per possible ~10 s piece of the whole utterance, and always at least one more after the cuts
		finished.slots = math.max(finished.used + 1, 1 + math.floor((now - finished.from) / CUT_MIN))
		openSegment = nil
		table.insert(waiting, finished)
		task.delay(WAIT_LIMIT + 0.1, function()
			expire(workspace:GetServerTimeNow())
		end)
	end
	emitStatus()
end

-- The segment a transcript belongs to, when its speech began (a range) and the latest it may have ended:
--   1. finished segments with a slot left, the oldest first (expired before waiting): results arrive in order, so a
--      text belongs to the oldest unanswered segment or a later one, never to an earlier one;
--   2. none: the open segment (a ~10 s cut of a long monologue, counted on the same segment);
--   3. nothing at all: within the last UNKNOWN_SPAN seconds.
-- Every text began no earlier than its segment's start. The latest start is exact only for a one-piece segment;
-- a piece of a longer one (which piece is unsure once spare slots exist) gets its end, an open one now.
-- The result also covers every other segment the text might belong to (the other unanswered ones, an open one
-- that may have been cut), so a wrong guess can only make the judging more lenient.
local function claim(): (number, number, number, number) -- text id, earliest start, latest start, latest end
	local now = workspace:GetServerTimeNow()
	expire(now)
	nextTextId += 1
	lastTextAt = now
	local open = openSegment
	local list = if expired[1] then expired elseif waiting[1] then waiting else nil
	local taken: Segment
	local earliest, latest, ended
	if list then
		taken = list[1]
		taken.used += 1
		if taken.used >= taken.slots then
			table.remove(list, 1)
		end
		earliest, ended = taken.from, taken.endedAt :: number
		latest = if taken.slots == 1 then taken.from else ended
	elseif open then
		taken = open
		open.used += 1
		open.lastCut = now
		earliest, latest, ended = open.from, now, now
	else
		taken = newSegment(now - UNKNOWN_SPAN)
		earliest, latest, ended = now - UNKNOWN_SPAN, now, now
	end
	local function cover(segment: Segment)
		-- the text may be any piece of `segment`: only a finished one-piece segment surely began at its start
		local surelyAtStart = segment.used == 0 and segment.slots == 1 and segment.endedAt ~= nil
		earliest = math.min(earliest, segment.from)
		latest = math.max(latest, if surelyAtStart then segment.from else segment.endedAt or now)
		ended = math.max(ended, segment.endedAt or now)
	end
	for _, segment in expired do
		if segment ~= taken then
			cover(segment)
		end
	end
	for _, segment in waiting do
		if segment ~= taken then
			cover(segment)
		end
	end
	if open and taken ~= open and now - open.lastCut >= CUT_MIN then
		cover(open) -- it may have been cut already
	end
	return nextTextId, earliest, latest, ended
end

-- True while speech that the server may still judge has no text yet: begun by `cutoff` and ended (or, if still
-- going, not past) `endBy`. Speech going on longer is not judged anyway (see JudgeService).
local function hasPendingBefore(cutoff: number, endBy: number): boolean
	local now = workspace:GetServerTimeNow()
	expire(now)
	if openSegment and openSegment.from <= cutoff and now <= endBy then
		return true
	end
	for _, segment in waiting do
		if segment.from <= cutoff and (segment.endedAt :: number) <= endBy then
			return true
		end
	end
	return false
end

-- After the round is decided: returns once my speech that may still count (begun by `cutoff`, ended by `endBy`)
-- has its text or timed out, at most `maxWait` seconds, so the server can judge it before closing.
function Speech.waitSettled(cutoff: number, endBy: number, maxWait: number)
	local deadline = os.clock() + maxWait
	while os.clock() < deadline and stt ~= nil and stt.Enabled and hasPendingBefore(cutoff, endBy) do
		task.wait(0.1)
	end
end

-- `parent` must survive respawns (the client entry LocalScript in PlayerScripts does; PlayerGui may not).
-- The recognizer is created once; whenever the player's AudioDeviceInput appears or is replaced, it is re-wired.
function Speech.start(parent: Instance)
	local player = Players.LocalPlayer
	local recognizer = Instance.new("AudioSpeechToText")
	recognizer.Enabled = false
	recognizer.Parent = parent
	stt = recognizer
	recognizer:GetPropertyChangedSignal("Text"):Connect(function()
		local text = recognizer.Text
		if text == "" then
			return
		end
		recognizer.Text = ""
		silentSegments = 0
		local id, earliest, latest, ended = claim()
		for _, fn in textListeners do
			fn(text, earliest, latest, ended, id)
		end
	end)
	recognizer:GetPropertyChangedSignal("VoiceDetected"):Connect(function()
		onVoiceDetected(recognizer)
	end)

	local wire: Wire? = nil
	local inputConnections: { RBXScriptConnection } = {}
	local function attach(newInput: AudioDeviceInput?)
		for _, connection in inputConnections do
			connection:Disconnect()
		end
		table.clear(inputConnections)
		if wire then
			wire:Destroy()
			wire = nil
		end
		input = newInput
		if newInput then
			local w = Instance.new("Wire")
			w.SourceInstance = newInput
			w.TargetInstance = recognizer
			w.Parent = recognizer
			wire = w
			table.insert(inputConnections, newInput:GetPropertyChangedSignal("Active"):Connect(emitStatus))
			table.insert(inputConnections, newInput:GetPropertyChangedSignal("Muted"):Connect(emitStatus))
		end
		emitStatus()
	end

	player.ChildAdded:Connect(function(child)
		if child:IsA("AudioDeviceInput") then
			attach(child)
		end
	end)
	player.ChildRemoved:Connect(function(child)
		if child == input then
			attach(player:FindFirstChildOfClass("AudioDeviceInput"))
		end
	end)
	attach(player:FindFirstChildOfClass("AudioDeviceInput"))
	task.delay(INPUT_GRACE + 0.1, emitStatus)
end

return Speech
