--!strict
-- Transcribes the local player's own mic. Roblox only runs AudioSpeechToText on clients, so every client
-- transcribes itself and the server judges. Voice starts disconnected (since 2026-01): AudioDeviceInput.Active
-- stays false until the player connects voice from the in-experience settings menu.
--
-- STT requests count against an experience-wide limit (1 + 5 x CCU per minute), so the recognizer is only
-- enabled while it matters (mic test, and alive participants during the talk) — see setEnabled.
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

-- Speech segments: the open one (voice detected now), finished ones still waiting for their text, expired ones
-- (no text within WAIT_LIMIT) whose text may still turn up late, and `lost`: expired ones older than LATE_KEEP,
-- merged into one, kept for the next text (results arrive in order: after one more text theirs can never come).
-- Which segment a transcript belongs to is not always certain, so every transcript carries a start RANGE (the
-- earliest and latest server time its speech may have begun) and the latest time it may have ended. The server
-- uses a word against it only if the word was in effect for the whole range, and drops it if the speech may have
-- begun after the round was decided or went on past it
-- (unsure -> lenient: a missed word is better than an unfair launch).
-- [from, to]: when the speech began. An open piece after a ~10 s cut keeps the monologue's start as `from`
-- (`to` = when the piece began), so a long monologue never looks younger than it is.
type Segment = { id: number, from: number, to: number, endedAt: number? }
local openSegment: Segment? = nil
local waiting: { Segment } = {}
local expired: { Segment } = {}
local lost: Segment? = nil
local nextSegmentId = 0
local silentSegments = 0
local WAIT_LIMIT = 3 -- seconds a finished segment waits for its text (Roblox: usually < 0.5 s) before it expires
local LATE_KEEP = 5 -- seconds an expired segment stays a candidate on its own before it is merged into `lost`
local LOST_KEEP = 60 -- `lost` is dropped this long after its last end (no result is a minute late)
local CUT_MIN = 8 -- an open piece younger than this cannot have been cut (~10 s) yet
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

-- fn(text, earliest, latest, ended, segmentId): the server-time range the speech began in and the latest time it
-- may have ended (word-boundary fairness, see the Segment comment); segmentId lets the server drop a duplicate
-- without dropping a repeated sentence.
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
		lost = nil
		silentSegments = 0
		emitStatus()
	end
end

local function newSegment(from: number, to: number): Segment
	nextSegmentId += 1
	return { id = nextSegmentId, from = from, to = to }
end

-- Finished segments without a text after WAIT_LIMIT expire (each one counts as a recognition miss); expired ones
-- older than LATE_KEEP merge into `lost`.
local function expire(now: number)
	while waiting[1] and now - (waiting[1].endedAt :: number) > WAIT_LIMIT do
		table.insert(expired, table.remove(waiting, 1) :: Segment)
		silentSegments += 1
		if silentSegments == UNSTABLE_SEGMENTS then
			for _, fn in unstableListeners do
				fn()
			end
		end
	end
	while expired[1] and now - (expired[1].endedAt :: number) > WAIT_LIMIT + LATE_KEEP do
		local old = table.remove(expired, 1) :: Segment
		local merged = lost
		if merged then
			merged.from = math.min(merged.from, old.from)
			merged.to = math.max(merged.to, old.to)
			merged.endedAt = math.max(merged.endedAt :: number, old.endedAt :: number)
		else
			lost = old
		end
	end
	local merged = lost
	if merged and now - (merged.endedAt :: number) > LOST_KEEP then
		lost = nil
	end
end

local function onVoiceDetected(recognizer: AudioSpeechToText)
	local now = workspace:GetServerTimeNow()
	if recognizer.VoiceDetected then
		openSegment = newSegment(now, now)
	elseif openSegment then
		local finished = openSegment
		finished.endedAt = now
		openSegment = nil
		table.insert(waiting, finished)
		task.delay(WAIT_LIMIT + 0.1, function()
			expire(workspace:GetServerTimeNow())
		end)
	end
	emitStatus()
end

-- The segment a transcript belongs to, when its speech began (a range) and the latest it may have ended:
--   1. finished segments without a text yet, the oldest first (lost, expired, waiting): results arrive in order,
--      so a text belongs to the oldest unanswered segment or a later one, never to an earlier one;
--   2. none: the open segment (a ~10 s cut of a long monologue); the rest of it keeps the monologue's start;
--   3. nothing at all: within the last UNKNOWN_SPAN seconds.
-- The result also covers every other segment the text might belong to (the other unanswered ones, an open one
-- that may have been cut), so a wrong guess can only make the judging more lenient.
local function claim(): (number, number, number, number) -- segment id, earliest start, latest start, latest end
	local now = workspace:GetServerTimeNow()
	expire(now)
	local open = openSegment
	local taken: Segment
	if lost then
		taken = lost :: Segment
		lost = nil
	elseif expired[1] then
		taken = table.remove(expired, 1) :: Segment
	elseif waiting[1] then
		taken = table.remove(waiting, 1) :: Segment
	elseif open then
		taken = open
		openSegment = newSegment(open.from, now)
	else
		taken = newSegment(now - UNKNOWN_SPAN, now)
	end
	local earliest, latest, ended = taken.from, taken.to, taken.endedAt or now
	local function cover(segment: Segment)
		earliest = math.min(earliest, segment.from)
		latest = math.max(latest, segment.to)
		ended = math.max(ended, segment.endedAt or now)
	end
	for _, segment in expired do
		cover(segment)
	end
	for _, segment in waiting do
		cover(segment)
	end
	if open and taken ~= open and now - open.to >= CUT_MIN then
		cover(open) -- it may have been cut already
	end
	return taken.id, earliest, latest, ended
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
