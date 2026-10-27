--!strict
-- Getting ready (docs/DESIGN_V3.md §2, §7): the voice connection and mic test lines (rows 0 and 1 under the status
-- board), and a "play by chat instead" button (row 2) for voice accounts that may chat (owner 2026-10-25: voice is a
-- must to play; whoever cannot speak plays by chat and still hears everyone; an account without voice watches). All
-- of it is empty while I play, so nothing covers the chair row (a voice player still sees a muted mic warning).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local MicPanel = {}

export type Ready = {
	status: string, -- Speech.status(): NoVoice / Disconnected / Muted / Listening / Speaking
	micTested: boolean,
	inMyRound: boolean, -- I play in the round being played
	roundOn: boolean, -- a round is being played (without me: I join the next one)
	readyCount: number?, -- players ready to play (voice or chat)
	chatAccess: string, -- from the server, to me only: checking / voice / voiceOnly / noVoice
	chatMode: boolean, -- I join by chat (server attribute BW_ChatMode)
}

local TEXT = Config.TEXT
local voiceL: TextLabel
local testL: TextLabel
local chatButton: TextButton
local chatMode = false

-- onChat(on): the player pressed the chat button (join by chat, or stop).
function MicPanel.build(onChat: (boolean) -> ())
	voiceL = Style.line(0, Style.RED_TEXT)
	testL = Style.line(1, Style.ACCENT_TEXT)
	chatButton = Style.button(Style.BOLD, 18)
	chatButton.Name = "ChatJoin"
	chatButton.AnchorPoint = Vector2.new(0.5, 0)
	chatButton.Position = UDim2.new(0.5, 0, 0, Style.row(2) + 2)
	chatButton.Size = UDim2.fromOffset(240, 34)
	chatButton.Visible = false
	chatButton.ZIndex = 5 -- (stays reachable where a mission card may reach it on a short phone screen)
	chatButton.Parent = Style.gui()
	chatButton.Activated:Connect(function()
		onChat(not chatMode)
	end)
end

-- The server found no voice on this account: it can only watch.
local function noVoiceAccount(r: Ready): boolean
	return r.chatAccess == "noVoice"
end

-- My voice is connected (muted or not): I can hear everyone, so I may play by chat.
local function voiceLinked(r: Ready): boolean
	return r.status == "Muted" or r.status == "Listening" or r.status == "Speaking"
end

local function voiceLine(r: Ready): string
	if r.status == "NoVoice" or noVoiceAccount(r) then
		return if r.chatMode then "" else TEXT.VOICE_NONE
	elseif r.status == "Disconnected" then
		return TEXT.VOICE_CONNECT -- (also when playing by chat: without voice I would hear nobody)
	elseif r.status == "Muted" and not r.chatMode then
		return TEXT.VOICE_MUTED
	end
	return ""
end

-- What the player should do next to take a seat (and whether that is done).
local function nextStep(r: Ready): (string, boolean)
	if r.inMyRound then
		return "", false
	elseif noVoiceAccount(r) then
		return TEXT.NO_VOICE_WATCH, false
	elseif r.status == "NoVoice" or r.status == "Disconnected" then
		return TEXT.CONNECT_TO_PLAY, false
	elseif r.chatMode then
		return if r.roundOn then TEXT.READY_NEXT_ROUND else TEXT.CHAT_JOINED, true
	elseif r.status == "Muted" then
		return TEXT.MIC_ON, false
	elseif not r.micTested then
		return TEXT.MIC_TEST, false
	elseif r.chatAccess == "checking" then
		return TEXT.CHAT_CHECKING, false -- (ready by voice once the server knows the account has voice)
	end
	if r.roundOn then
		return TEXT.READY_NEXT_ROUND, true -- (review 2026-10-25: ready but watching said nothing about why)
	end
	local ready = if r.readyCount then string.format(TEXT.READY_COUNT, r.readyCount) else TEXT.READY
	return ready .. " · " .. TEXT.HEADSET_TIP, true
end

-- The lower edge (pixels from the top) of the getting-ready line and the chat button under the board, or nil while
-- neither shows (the mission card goes under them, bundle 12).
function MicPanel.bottom(): number?
	local bottom: number? = nil
	for _, item in { testL, chatButton } :: { GuiObject } do
		if item.Visible then
			bottom = math.max(bottom or 0, item.AbsolutePosition.Y + item.AbsoluteSize.Y)
		end
	end
	return bottom
end

function MicPanel.set(r: Ready)
	chatMode = r.chatMode
	voiceL.Text = voiceLine(r)
	local text, done = nextStep(r)
	testL.Text = text
	testL.TextColor3 = if done then Style.GREEN_TEXT else Style.ACCENT_TEXT
	-- (offered to a voice account that may chat once its voice is connected — to hear everyone; while playing by chat,
	-- to stop)
	-- (Studio has no voice: there the server does not ask for it either, Config.REQUIRE_VOICE_READY)
	chatButton.Visible = not r.inMyRound and (r.chatMode or (r.chatAccess == "voice"
		and (voiceLinked(r) or not Config.REQUIRE_VOICE_READY)))
	chatButton.Text = if r.chatMode then TEXT.CHAT_CANCEL else TEXT.CHAT_JOIN
end

return MicPanel
