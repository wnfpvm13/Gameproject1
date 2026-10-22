--!strict
-- Joining by text chat (docs/DESIGN_V3.md §7; owner decision 2026-10-23: voice accounts join by voice only). Each
-- player is checked once on the server when they join: does the account have voice
-- (VoiceChatService:IsVoiceEnabledForUserIdAsync) and may it chat (TextChatService:CanUserChatAsync)? Only accounts
-- without voice that may chat can choose chat, and not while their voice is ready or while they play in the round
-- being played. The choice is Match.chatJoin, public as the BW_ChatMode player attribute (ChatLook makes those
-- messages stand out). What a player may do is told to that player only ("ChatAccess"): whether an account may chat
-- says something about its restrictions, so other clients never get it.
-- Bundle 5 adds the rest of §7 here (delivery rules, the whisper block, judging chat).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local VoiceChatService = game:GetService("VoiceChatService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local ChatService = {}

-- checking: not known yet; yes: may join by chat; no: may not chat; voice: a voice account (joins by voice);
-- error: the chat permission check kept failing (no chat for now).
export type Access = "checking" | "yes" | "no" | "voice" | "error"

local access: { [Player]: Access } = {}

local function tell(player: Player)
	Net.to(player, "ChatAccess", { state = access[player] or "checking" })
end

local function setAccess(player: Player, state: Access)
	if player.Parent then -- not for a player who left meanwhile
		access[player] = state
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
	-- Studio: workspace attribute BW_ChatAccess forces the result (yes / no / voice / error), e.g. to try chat mode with
	-- a voice account (live servers ignore it).
	local forced = if RunService:IsStudio() then workspace:GetAttribute("BW_ChatAccess") else nil
	if forced == "yes" or forced == "no" or forced == "voice" or forced == "error" then
		setAccess(player, forced)
		return
	end
	-- A failed voice check counts as "no voice" (owner 2026-10-23); a chat participant's voice is off in rounds anyway.
	local _, hasVoice = ask("voice", player, function()
		return VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
	end)
	if not player.Parent then
		return -- left meanwhile
	elseif hasVoice then
		setAccess(player, "voice")
		return
	end
	local retries = 0
	while true do
		local ok, allowed = ask("chat permission", player, function()
			return TextChatService:CanUserChatAsync(player.UserId)
		end)
		if ok then
			setAccess(player, if allowed then "yes" else "no")
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
	-- Still failing: no chat on live servers; Studio test accounts may try chat mode anyway.
	setAccess(player, if RunService:IsStudio() then "yes" else "error")
end

local function setMode(player: Player, on: boolean)
	if on then
		Match.chatJoin[player] = true
	else
		Match.chatJoin[player] = nil
	end
	player:SetAttribute("BW_ChatMode", on)
end

function ChatService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	Players.PlayerAdded:Connect(check)
	Players.PlayerRemoving:Connect(function(player)
		access[player] = nil
	end)
end

-- Sends the player what they may do again (they asked for the whole state, e.g. right after joining).
function ChatService.sendAccess(player: Player)
	tell(player)
end

-- The player asks to join by chat (`on`) or to stop. `locked`: they play in the round being played, so their choice
-- holds until it is over. Joining needs an account without voice that may chat, and no voice ready. Returns whether
-- anything changed.
function ChatService.request(player: Player, on: boolean, locked: boolean): boolean
	if locked or (Match.chatJoin[player] == true) == on then
		return false
	end
	if on and (access[player] ~= "yes" or Match.ready[player]) then
		return false
	end
	setMode(player, on)
	return true
end

-- The player's voice is ready: they join by voice from now on (unless locked in the round being played). Returns
-- whether anything changed.
function ChatService.voiceReady(player: Player, locked: boolean): boolean
	if locked or not Match.chatJoin[player] then
		return false
	end
	setMode(player, false)
	return true
end

return ChatService
