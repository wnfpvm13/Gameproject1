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
local textListeners: { (string, number, number) -> () } = {}
local unstableListeners: { () -> () } = {}

local startedAt = os.clock()
local INPUT_GRACE = 15 -- seconds to wait for the AudioDeviceInput before calling the account voice-less
local UNSTABLE_SEGMENTS = 3 -- speech segments in a row that produced no text -> "recognition looks unstable"

-- Speech segments: the open one (voice detected now) and finished ones still waiting for their text.
-- Each transcript takes the oldest waiting segment's start time, so a late result never borrows the start
-- of the next sentence. A monologue cut at ~10 s gets a new open segment from the cut.
type Segment = { id: number, startedAt: number, endedAt: number? }
local openSegment: Segment? = nil
local waiting: { Segment } = {}
local nextSegmentId = 0
local silentSegments = 0
local WAIT_LIMIT = 3 -- seconds a finished segment may wait for its text (Roblox: usually < 0.5 s) before it is dropped
local CUT_ALLOWANCE = 1 -- a ~10 s cut is noticed when its text arrives; start the next piece this much earlier

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

-- fn(text, segmentStart, segmentId): segmentStart is the server time the speech began (word-boundary fairness),
-- segmentId lets the server drop a duplicate without dropping a repeated sentence.
function Speech.onText(fn: (string, number, number) -> ())
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
		silentSegments = 0
		emitStatus()
	end
end

local function newSegment(startedAt: number): Segment
	nextSegmentId += 1
	return { id = nextSegmentId, startedAt = startedAt }
end

local function onVoiceDetected(recognizer: AudioSpeechToText)
	local now = workspace:GetServerTimeNow()
	if recognizer.VoiceDetected then
		openSegment = newSegment(now)
	elseif openSegment then
		local finished = openSegment
		finished.endedAt = now
		openSegment = nil
		table.insert(waiting, finished)
		-- If no text shows up shortly, it was a recognition miss: drop it and count it.
		task.delay(WAIT_LIMIT, function()
			local index = table.find(waiting, finished)
			if index then
				table.remove(waiting, index)
			end
			if index and recognizer.Enabled then
				silentSegments += 1
				if silentSegments == UNSTABLE_SEGMENTS then
					for _, fn in unstableListeners do
						fn()
					end
				end
			end
		end)
	end
	emitStatus()
end

-- The segment a transcript belongs to: the oldest finished one still waiting, else the open one (a ~10 s cut).
local function takeSegment(): Segment
	local now = workspace:GetServerTimeNow()
	while waiting[1] and now - (waiting[1].endedAt or now) > WAIT_LIMIT do
		table.remove(waiting, 1)
	end
	if waiting[1] then
		return table.remove(waiting, 1) :: Segment
	end
	local open = openSegment
	if open then
		openSegment = newSegment(now - CUT_ALLOWANCE) -- the rest of the monologue starts at the cut
		return open
	end
	return newSegment(now - 10) -- unknown: assume the longest segment (lenient for new words)
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
		local segment = takeSegment()
		for _, fn in textListeners do
			fn(text, segment.startedAt, segment.id)
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
