--!strict
-- Transcribes the local player's own mic. Roblox only runs AudioSpeechToText on clients, so every client
-- transcribes itself and the server judges. Voice starts disconnected (since 2026-01): AudioDeviceInput.Active
-- stays false until the player connects voice from the in-experience settings menu.
local Players = game:GetService("Players")

local Speech = {}

export type Status = "NoVoice" | "Disconnected" | "Muted" | "Listening" | "Speaking"

local input: AudioDeviceInput? = nil
local stt: AudioSpeechToText? = nil
local statusListeners: { (Status) -> () } = {}
local textListeners: { (string) -> () } = {}

function Speech.status(): Status
	if not input then
		return "NoVoice"
	elseif not input.Active then
		return "Disconnected"
	elseif input.Muted then
		return "Muted"
	elseif stt and stt.VoiceDetected then
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

function Speech.onText(fn: (string) -> ())
	table.insert(textListeners, fn)
end

function Speech.start(parent: Instance)
	local player = Players.LocalPlayer
	input = player:WaitForChild("AudioDeviceInput", 30) :: AudioDeviceInput?
	if not input then
		emitStatus()
		return
	end
	local recognizer = Instance.new("AudioSpeechToText")
	recognizer.Enabled = true
	recognizer.Parent = parent
	stt = recognizer
	local wire = Instance.new("Wire")
	wire.SourceInstance = input
	wire.TargetInstance = recognizer
	wire.Parent = recognizer

	recognizer:GetPropertyChangedSignal("Text"):Connect(function()
		local text = recognizer.Text
		if text == "" then
			return
		end
		recognizer.Text = ""
		for _, fn in textListeners do
			fn(text)
		end
	end)
	recognizer:GetPropertyChangedSignal("VoiceDetected"):Connect(emitStatus)
	input:GetPropertyChangedSignal("Active"):Connect(emitStatus)
	input:GetPropertyChangedSignal("Muted"):Connect(emitStatus)
	emitStatus()
end

return Speech
