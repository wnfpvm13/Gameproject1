--!strict
-- Joining by text chat (docs/DESIGN_V3.md §7). Owner 2026-10-25: voice chat is a must to play; whoever cannot or
-- will not speak may play by chat and still hears everyone ("말을 못하면 듣기라도"). So: each player is checked once on
-- the server when they join: does the account have voice (VoiceChatService:IsVoiceEnabledForUserIdAsync), and if so,
-- may it chat (TextChatService:CanUserChatAsync)? A voice account that may chat can choose chat ("말 대신 채팅":
-- its mic is off to the room in its round, VoiceService), at any time except while it plays in the round being played;
-- an account without voice only watches. The choice is Match.chatJoin, public as the BW_ChatMode player attribute
-- (ChatLook makes those messages stand out). What a player may do is told to that player only ("ChatAccess"): it says
-- something about the account's restrictions, so other clients never get it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local VoiceChatService = game:GetService("VoiceChatService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local ChatService = {}

-- checking: not known yet; voice: a voice account that may also play by chat; voiceOnly: a voice account that may not
-- chat (or whose chat check kept failing): it plays by voice; noVoice: no voice (or the voice check failed): it watches.
export type Access = "checking" | "voice" | "voiceOnly" | "noVoice"

local access: { [Player]: Access } = {}

local function tell(player: Player)
	Net.to(player, "ChatAccess", { state = access[player] or "checking" })
end

local function setMode(player: Player, on: boolean)
	if on then
		Match.chatJoin[player] = true
	else
		Match.chatJoin[player] = nil
	end
	player:SetAttribute("BW_ChatMode", on)
end

local function setAccess(player: Player, state: Access)
	if player.Parent then -- not for a player who left meanwhile
		access[player] = state
		-- (only a voice account counts as ready or plays by chat, Match.readyByVoice / readyByChat)
		if state == "voice" or state == "voiceOnly" then
			Match.voiceAccount[player] = true
		else
			Match.voiceAccount[player] = nil
		end
		if state == "noVoice" and Match.chatJoin[player] then
			setMode(player, false)
		end
		tell(player)
	end
end

-- Runs one yielding check. Returns (ok, answer); a failed call is reported and returns ok = false.
local function ask(what: string, player: Player, call: () -> boolean): (boolean, boolean)
	local ok, result = pcall(call)
	if not ok then
		warn("[BannedWords] " .. what .. " check failed for", player.UserId, result)
		return false, false
	end
	return true, result == true
end

local function check(player: Player)
	setAccess(player, "checking")
	-- Studio: workspace attribute BW_ChatAccess forces the result (voice / voiceOnly / noVoice), e.g. to see the
	-- watcher's screen (live servers ignore it).
	local studio = RunService:IsStudio()
	local forced = if studio then workspace:GetAttribute("BW_ChatAccess") else nil
	if forced == "voice" or forced == "voiceOnly" or forced == "noVoice" then
		setAccess(player, forced)
		return
	end
	-- The voice check is retried like the chat check; still failing counts as no voice (owner 2026-10-23). Studio has
	-- no voice at all (its test players play anyway, Config.REQUIRE_VOICE_READY), so there it goes on as a voice
	-- account and chat mode can be tried.
	local hasVoice = false
	local voiceTries = 0
	while true do
		local ok, answer = ask("voice", player, function()
			return VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
		end)
		if not player.Parent then
			return -- left meanwhile
		end
		if ok then
			hasVoice = answer
			break
		end
		voiceTries += 1
		local delay = Config.CHAT_CHECK_RETRIES[voiceTries]
		if not delay then
			break
		end
		task.wait(delay)
	end
	if not player.Parent then
		return
	elseif not hasVoice and not studio then
		setAccess(player, "noVoice")
		return
	end
	local retries = 0
	while true do
		local ok, allowed = ask("chat permission", player, function()
			return TextChatService:CanUserChatAsync(player.UserId)
		end)
		if ok then
			setAccess(player, if allowed then "voice" else "voiceOnly")
			return
		end
		retries += 1
		local delay = Config.CHAT_CHECK_RETRIES[retries]
		if not delay then
			break
		end
		task.wait(delay)
		if not player.Parent then
			return
		end
	end
	-- Still failing: voice only on live servers; Studio test accounts may try chat mode anyway.
	setAccess(player, if studio then "voice" else "voiceOnly")
end

function ChatService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	Players.PlayerAdded:Connect(check)
	Players.PlayerRemoving:Connect(function(player)
		access[player] = nil
		Match.voiceAccount[player] = nil
	end)
end

-- Sends the player what they may do again (they asked for the whole state, e.g. right after joining).
function ChatService.sendAccess(player: Player)
	tell(player)
end

-- The player asks to play by chat (`on`) or to stop. `locked`: they play in the round being played, so their choice
-- holds until it is over. Playing by chat needs a voice account that may chat and its voice connected (to hear
-- everyone; its mic may be on and tested too). The choice stays until they change it. Returns whether anything changed.
function ChatService.request(player: Player, on: boolean, locked: boolean): boolean
	if locked or (Match.chatJoin[player] == true) == on then
		return false
	end
	if on and (access[player] ~= "voice" or not (Match.voiceLinked[player] or not Config.REQUIRE_VOICE_READY)) then
		return false
	end
	setMode(player, on)
	return true
end

return ChatService
