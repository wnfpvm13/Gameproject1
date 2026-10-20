--!strict
-- The short mission vote (bottom stack, above the mission card, V2.1): one button per option and a countdown. Only alive participants
-- can press (and change) a choice; everyone else sees it read-only. Counts appear only after it closes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local VotePanel = {}

local IDLE = Color3.fromRGB(40, 48, 64)
local PICKED = Color3.fromRGB(240, 140, 60)

local frame: Frame
local titleL: TextLabel
local buttonRow: Frame
local buttons: { [string]: TextButton } = {}
local onPick: (string, string) -> () = function() end
local voteKey: string? = nil
local endsAt = 0
local canVote = false
local hideAt = 0

function VotePanel.build(pick: (string, string) -> ())
	onPick = pick
	frame = Instance.new("Frame")
	frame.LayoutOrder = 1 -- above the mission card in the bottom stack
	frame.Size = UDim2.new(1, 0, 0, 92)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = Style.bottomStack()
	titleL = Style.label(frame, Style.BOLD, 20, Style.WHITE)
	titleL.Size = UDim2.new(1, 0, 0, 28)
	titleL.TextStrokeTransparency = 0.4
	buttonRow = Instance.new("Frame")
	buttonRow.BackgroundTransparency = 1
	buttonRow.Position = UDim2.new(0, 0, 0, 32)
	buttonRow.Size = UDim2.new(1, 0, 0, 60)
	buttonRow.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = buttonRow
end

local function clearButtons()
	for _, b in buttons do
		b:Destroy()
	end
	table.clear(buttons)
end

local function paint(picked: string?)
	for id, b in buttons do
		b.BackgroundColor3 = if id == picked then PICKED else IDLE
		b.AutoButtonColor = canVote
		b.TextTransparency = if canVote then 0 else 0.35
	end
end

-- info = { voteKey, options = { {id, text} }, endsAt }
function VotePanel.open(info: any, allowed: boolean)
	clearButtons()
	voteKey = info.voteKey
	endsAt = info.endsAt
	canVote = allowed
	hideAt = 0
	local width = 1 / math.max(#info.options, 1)
	for _, option in info.options do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(width, -8, 1, 0)
		b.BackgroundColor3 = IDLE
		b.BackgroundTransparency = 0.1
		b.FontFace = Style.BOLD
		b.TextColor3 = Style.WHITE
		b.TextScaled = true
		b.TextWrapped = true
		b.Text = option.text
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = b
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 20
		limit.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = b
		b.Activated:Connect(function()
			if canVote and voteKey == info.voteKey then
				onPick(info.voteKey, option.id)
				paint(option.id)
			end
		end)
		b.Parent = buttonRow
		buttons[option.id] = b
	end
	paint(nil)
	frame.Visible = true
end

-- Dead or not playing any more: buttons stay visible but stop working.
function VotePanel.setCanVote(allowed: boolean)
	if canVote ~= allowed then
		canVote = allowed
		paint(nil)
	end
end

-- info = { voteKey, outcome, counts = { [id] = n }, options }
function VotePanel.closed(info: any)
	if voteKey ~= nil and info.voteKey ~= voteKey then
		return -- a different vote is open
	end
	voteKey = nil
	clearButtons()
	local winner = "결정 못 함"
	for _, option in info.options do
		if option.id == info.outcome then
			winner = string.format("%s (%d표)", option.text, info.counts[option.id] or 0)
		end
	end
	titleL.Text = "투표 결과: " .. winner
	local left = if info.expiresAt then info.expiresAt - workspace:GetServerTimeNow() else Config.VOTE_RESULT_SECONDS
	hideAt = os.clock() + math.max(0, left)
	frame.Visible = true
end

-- Every frame: countdown while open, hide the result after a moment.
function VotePanel.tick(now: number)
	if not frame.Visible then
		return
	end
	if voteKey then
		local left = math.max(0, math.ceil(endsAt - now))
		titleL.Text = if canVote then string.format("투표! 고르세요 · %d초 (말하면서 해도 돼요)", left) else string.format("투표 중 · %d초", left)
	elseif hideAt > 0 and os.clock() >= hideAt then
		frame.Visible = false
		hideAt = 0
	end
end

function VotePanel.clear()
	voteKey = nil
	clearButtons()
	frame.Visible = false
end

return VotePanel
