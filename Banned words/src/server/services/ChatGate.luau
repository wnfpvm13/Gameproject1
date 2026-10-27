--!strict
-- The chat gate (docs/DESIGN_V3.md §7; bundle 5b): the server side of every TextChannel. While a guarded round is on
-- (RoundService decides: from the assignment to the result, when banned words play), messages from anyone who is not
-- an alive participant (the presenter, out players, spectators, late joiners) are not delivered to alive participants,
-- and whispers are off (the /w command and the whisper channels), so nobody can tell a player their word. While
-- someone has the floor (bundle 6b, any game), alive participants receive only that player's messages. Every
-- message an alive participant sends is handed on once (by MessageId) for judging. The delivery callback runs for each
-- receiver and must never yield: it decides, and judges each message once without yielding. Bundle 9c: during a
-- guarded round a message holding a word hidden from its receiver (the word over their own head) is not delivered to
-- them (the rule comes from RoundService: `hides`).
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Match = require(script.Parent.Parent:WaitForChild("Match"))

local ChatGate = {}

local CHANNEL_WARN_AFTER = 30 -- seconds without TextChannels before a warning

local guarded = false
local floorHolder: Player? = nil -- has the floor now: alive participants receive only their messages
local seen: { [string]: boolean } = {} -- MessageIds already handed on (cleared each round)
local onMessage: (Player, string) -> () = function(_player, _text) end
local hides: (Player, string) -> boolean = function(_receiver, _text)
	return false
end
-- Bundle 12: a quiz answer typed in chat (MissionRunner decides and counts it once per message) goes to nobody but its
-- sender, guarded round or not.
local answerLine: (Player, string) -> boolean = function(_sender, _text)
	return false
end
local answerOf: { [string]: boolean } = {} -- MessageId -> was it an answer (decided once)
local answerOfBefore: { [string]: boolean } = {} -- the ones decided before (kept one more turn: never forgotten mid-delivery)
local answersKept = 0

local function playerOf(source: Instance?): Player?
	local untyped: any = source
	if not untyped then
		return nil
	end
	local ok, userId = pcall(function()
		return untyped.UserId
	end)
	return if ok and typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function isWhisper(channel: Instance): boolean
	return string.sub(channel.Name, 1, 10) == "RBXWhisper"
end

-- The delivery rule for one message (its `text`) to one receiver (pure, so it can be tested without TextChatService).
function ChatGate.shouldDeliver(channel: Instance, sender: Player?, receiver: Player?, text: string?): boolean
	if sender == nil or receiver == nil or sender == receiver then
		return true
	end
	if floorHolder and sender ~= floorHolder and Match.isAlive(receiver) then
		return false -- (no one talks over the floor, e.g. telling the answer in the bell quiz)
	end
	if not guarded then
		return true
	end
	if text then
		local ok, hidden = pcall(hides, receiver, text)
		if not ok or hidden then
			return false -- (their own word, which they must not see yet; a check that broke keeps the line from them)
		end
	end
	if isWhisper(channel) then
		return false
	end
	return Match.isAlive(sender) or not Match.isAlive(receiver)
end

-- An alive participant's message, once per MessageId. Judged right here, at the moment the server received it (the
-- stage and the word in effect then, §7); the handler never yields, and an error in it must not stop the chat.
function ChatGate.received(messageId: string, sender: Player?, text: string)
	if not guarded or sender == nil or seen[messageId] or not Match.isAlive(sender) then
		return
	end
	seen[messageId] = true
	local ok, err = pcall(function(): any
		onMessage(sender, text)
		return nil -- one return value, so the type checker reads pcall's results as (ok, error)
	end)
	if not ok then
		warn("[BannedWords] chat judging failed:", err)
	end
end

local function watch(channel: Instance)
	if not channel:IsA("TextChannel") then
		return
	end
	local textChannel = channel :: TextChannel
	textChannel.ShouldDeliverCallback = function(message: TextChatMessage, target: TextSource): boolean
		local sender = playerOf(message.TextSource)
		local receiver = playerOf(target)
		ChatGate.received(message.MessageId, sender, message.Text)
		-- (a quiz answer: counted once, whoever this call is for, and only its sender sees it; bundle 12)
		if sender and ChatGate.isAnswer(message.MessageId, sender, message.Text) and receiver ~= sender then
			return false
		end
		return ChatGate.shouldDeliver(textChannel, sender, receiver, message.Text)
	end
end

local function setWhisperCommand(on: boolean)
	local commands = TextChatService:FindFirstChild("TextChatCommands")
	local whisper = commands and commands:FindFirstChild("RBXWhisperCommand")
	if whisper and whisper:IsA("TextChatCommand") then
		whisper.Enabled = on
	end
end

-- Whether the message is a quiz answer (asked once per MessageId: the first call counts it; never yields).
function ChatGate.isAnswer(messageId: string, sender: Player, text: string): boolean
	local known = answerOf[messageId]
	if known == nil then
		known = answerOfBefore[messageId]
	end
	if known ~= nil then
		return known
	end
	local ok, result = pcall(answerLine, sender, text)
	local answer = ok and result == true
	if answersKept >= 500 then -- (only the last moments matter: a message is decided within one delivery)
		answerOfBefore = answerOf
		answerOf = {}
		answersKept = 0
	end
	answerOf[messageId] = answer
	answersKept += 1
	return answer
end

-- handle(player, text): an alive participant wrote `text` during a guarded round. hidesWord(receiver, text): `text`
-- holds a word `receiver` must not see (never yields). answer(sender, text): the line is a quiz answer, counted (never
-- yields; bundle 12).
function ChatGate.start(handle: (Player, string) -> (), hidesWord: ((Player, string) -> boolean)?,
	answer: ((Player, string) -> boolean)?)
	onMessage = handle
	if hidesWord then
		hides = hidesWord
	end
	if answer then
		answerLine = answer
	end
	task.spawn(function()
		-- The channels are made at run time (TextChatService): look until they are there, however late.
		local channels = TextChatService:FindFirstChild("TextChannels")
		local waited = 0
		while not channels do
			task.wait(1)
			waited += 1
			if waited == CHANNEL_WARN_AFTER then
				warn("[BannedWords] still no TextChannels: chat rules and judging wait (is ChatVersion TextChatService?)")
			end
			channels = TextChatService:FindFirstChild("TextChannels")
		end
		for _, channel in channels:GetChildren() do
			watch(channel)
		end
		channels.ChildAdded:Connect(watch) -- whisper channels appear when someone whispers
		setWhisperCommand(not guarded) -- (the commands may have appeared after a round began)
	end)
end

-- The floor: `player` speaks, alive participants receive only their messages; nil ends it.
function ChatGate.setFloor(player: Player?)
	floorHolder = player
end

-- Round start / end: the rules on (true) or off.
function ChatGate.setGuard(on: boolean)
	guarded = on
	table.clear(seen)
	setWhisperCommand(not on)
end

return ChatGate
