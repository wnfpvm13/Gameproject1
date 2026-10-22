--!strict
-- Getting ready (docs/DESIGN_V3.md §2, §7): the voice connection and mic test lines (rows 0 and 1 under the status
-- board), and a "join by chat" button (row 2) for accounts without voice that may chat (owner 2026-10-23: voice
-- accounts join by voice only). All of it is empty while I play, so nothing covers the chair row (a voice player
-- still sees a muted mic warning).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local MicPanel = {}

export type Ready = {
	status: string, -- Speech.status(): NoVoice / Disconnected / Muted / Listening / Speaking
	micTested: boolean,
	inMyRound: boolean, -- I play in the round being played
	readyCount: number?, -- players ready to play (voice or chat)
	chatAccess: string, -- from the server, to me only: checking / yes / no / voice / error
	chatMode: boolean, -- I join by chat (server attribute BW_ChatMode)
}

local TEXT = Config.TEXT
local voiceL: TextLabel
local testL: TextLabel
local chatButton: TextButton
local chatMode = false

-- onChat(on): the player pressed the chat button (join by chat, or stop).
function MicPanel.build(onChat: (boolean) -> ())
	voiceL = Style.line(0, Style.RED)
	testL = Style.line(1, Style.AMBER)
	chatButton = Instance.new("TextButton")
	chatButton.Name = "ChatJoin"
	chatButton.AnchorPoint = Vector2.new(0.5, 0)
	chatButton.Position = UDim2.new(0.5, 0, 0, Style.row(2) + 2)
	chatButton.Size = UDim2.fromOffset(240, 34)
	chatButton.BackgroundColor3 = Style.PANEL
	chatButton.BackgroundTransparency = 0.15
	chatButton.FontFace = Style.BOLD
	chatButton.TextSize = 18
	chatButton.TextColor3 = Style.AMBER
	chatButton.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = chatButton
	chatButton.Parent = Style.gui()
	chatButton.Activated:Connect(function()
		onChat(not chatMode)
	end)
end

-- The server found no voice on this account (chat checked instead): "connect voice" would ask for the impossible.
local function noVoiceAccount(r: Ready): boolean
	return r.chatAccess == "yes" or r.chatAccess == "no" or r.chatAccess == "error"
end

local function voiceLine(r: Ready): string
	if r.chatMode then
		return "" -- playing by chat: no voice nagging
	elseif r.status == "NoVoice" or (r.status == "Disconnected" and noVoiceAccount(r)) then
		return TEXT.VOICE_NONE
	elseif r.status == "Disconnected" then
		return TEXT.VOICE_CONNECT
	elseif r.status == "Muted" then
		return TEXT.VOICE_MUTED
	end
	return ""
end

-- Without a connected voice: what the chat check says I can do.
local function withoutVoice(r: Ready): string
	if r.chatAccess == "yes" then
		return TEXT.OR_CHAT
	elseif r.chatAccess == "checking" then
		return TEXT.CHAT_CHECKING
	elseif r.chatAccess == "error" then
		return TEXT.CHAT_CHECK_FAILED
	elseif r.chatAccess == "no" then
		return TEXT.NO_VOICE_NO_CHAT
	end
	return TEXT.CONNECT_TO_PLAY -- a voice account: connect voice
end

-- What the player should do next to take a seat (and whether that is done).
local function nextStep(r: Ready): (string, boolean)
	if r.inMyRound then
		return "", false
	elseif r.chatMode then
		return TEXT.CHAT_JOINED, true
	elseif r.status == "NoVoice" or r.status == "Disconnected" then
		return withoutVoice(r), false
	elseif r.status == "Muted" then
		return TEXT.MIC_ON, false
	elseif not r.micTested then
		return TEXT.MIC_TEST, false
	end
	local ready = if r.readyCount then string.format(TEXT.READY_COUNT, r.readyCount) else TEXT.READY
	return ready .. " · " .. TEXT.HEADSET_TIP, true
end

function MicPanel.set(r: Ready)
	chatMode = r.chatMode
	voiceL.Text = voiceLine(r)
	local text, done = nextStep(r)
	testL.Text = text
	testL.TextColor3 = if done then Style.GREEN else Style.AMBER
	local noVoice = r.status == "NoVoice" or r.status == "Disconnected"
	chatButton.Visible = not r.inMyRound and (r.chatMode or (r.chatAccess == "yes" and noVoice))
	chatButton.Text = if r.chatMode then TEXT.CHAT_CANCEL else TEXT.CHAT_JOIN
end

return MicPanel
