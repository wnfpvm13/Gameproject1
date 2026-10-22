--!strict
-- Chat participants' messages stand out (docs/DESIGN_V3.md §7, owner decision 2026-10-22): their bubbles are bigger,
-- bold and yellow with a keyboard mark, and the chat window puts a coloured [채팅] before their name. All bubbles also
-- stay full size out to the far stands and float above our name + hearts tag. Who joins by chat comes from the server (player attribute BW_ChatMode). Only Roblox
-- chat is decorated: nobody's text is shown anywhere else (§11). These callbacks stop running if Platform Integrated
-- Chat is turned on (mandatory from May 2027, §7), and they need TextChatService (ChatVersion) in the place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))

local ChatLook = {}

local BUBBLE_COLOR = Color3.fromRGB(255, 214, 64)
local BUBBLE_TEXT_COLOR = Color3.fromRGB(30, 30, 36)
local BUBBLE_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local MARK = "⌨ " -- BubbleChatMessageProperties has no icon property, so the mark goes before the (filtered) text
local TAG_COLOR = "#F2A900" -- a deep yellow: the chat window sits over the bright white hall

local function fromChatter(message: TextChatMessage): boolean
	local source = message.TextSource
	local player = source and Players:GetPlayerByUserId(source.UserId)
	return player ~= nil and player:GetAttribute("BW_ChatMode") == true
end

function ChatLook.start()
	task.spawn(function()
		-- (Studio adds the default configuration to a place when it opens it; a Rojo-built place file may lack it.)
		local bubbles = TextChatService:WaitForChild("BubbleChatConfiguration", 10)
		if bubbles and bubbles:IsA("BubbleChatConfiguration") then
			bubbles.MinimizeDistance = Config.CHAT_BUBBLE_MINIMIZE_DISTANCE
			bubbles.MaxDistance = Config.CHAT_BUBBLE_MAX_DISTANCE
			bubbles.VerticalStudsOffset = Config.CHAT_BUBBLE_VERTICAL_OFFSET -- clear of our name + hearts tag
		else
			warn("[BannedWords] no BubbleChatConfiguration: chat bubbles keep Roblox's default distances")
		end
	end)
	-- (Each callback may be set in one place only; this module owns both.)
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		if not fromChatter(message) then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = string.format('<b><font color="%s">%s</font></b> %s', TAG_COLOR, Config.TEXT.CHAT_TAG, message.PrefixText)
		return properties
	end
	TextChatService.OnBubbleAdded = function(message: TextChatMessage, _adornee: Instance?): BubbleChatMessageProperties?
		if message.Text == "" or not fromChatter(message) then
			return nil
		end
		local properties = Instance.new("BubbleChatMessageProperties")
		properties.BackgroundColor3 = BUBBLE_COLOR
		properties.TextColor3 = BUBBLE_TEXT_COLOR
		properties.FontFace = BUBBLE_FONT
		properties.TextSize = Config.CHAT_BUBBLE_TEXT_SIZE
		properties.Text = MARK .. message.Text
		if message.Translation ~= "" then
			properties.Translation = MARK .. message.Translation -- viewers who see it translated get the mark too
		end
		return properties
	end
end

return ChatLook
