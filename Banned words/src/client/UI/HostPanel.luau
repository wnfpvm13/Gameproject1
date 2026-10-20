--!strict
-- Short centre texts from the assistant host: the event banner and the new-word countdown, over the centre
-- table (the emptiest part of the seated view: far chairs sit above it, neighbours at the screen edges).
-- The mission card and topic line live in MissionPanel (bottom stack); theme and my role in the status board.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local HostPanel = {}

local eventL: TextLabel
local warnL: TextLabel
local warnAt = 0
local warnCount = 0

function HostPanel.build()
	local gui = Style.gui()
	eventL = Style.label(gui, Style.HEAVY, 28, Style.AMBER)
	eventL.AnchorPoint = Vector2.new(0.5, 0.5)
	eventL.Position = UDim2.fromScale(0.5, 0.52)
	eventL.Size = UDim2.new(0.6, 0, 0, 40)
	eventL.TextTransparency = 1
	eventL.TextStrokeTransparency = 1

	warnL = Style.label(gui, Style.HEAVY, 32, Style.RED)
	warnL.AnchorPoint = Vector2.new(0.5, 0.5)
	warnL.Position = UDim2.fromScale(0.5, 0.6)
	warnL.Size = UDim2.new(0.6, 0, 0, 42)
	warnL.TextStrokeTransparency = 0.3
end

-- expiresAt (server time) is shared, so a late joiner only sees what is left of it.
function HostPanel.showEvent(text: string, expiresAt: number?)
	local left = if expiresAt then expiresAt - workspace:GetServerTimeNow() else Config.EVENT_SHOW_SECONDS
	if left <= 0.2 then
		return
	end
	eventL.Text = "📢 " .. text
	eventL.TextTransparency = 0
	eventL.TextStrokeTransparency = 0.3
	local fade = math.min(0.8, left)
	local info = TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, left - fade)
	TweenService:Create(eventL, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

function HostPanel.warnWord(at: number, count: number)
	warnAt = at
	warnCount = count
end

-- Every frame: the new-word countdown. Both texts stay just above the bottom stack (on short phone screens the
-- stack reaches higher than 60 %).
function HostPanel.tick(now: number)
	local viewport = workspace.CurrentCamera.ViewportSize.Y
	local stackTop = Style.bottomStack().AbsolutePosition.Y
	local warnY = math.min(viewport * 0.6, stackTop - 28)
	warnL.Position = UDim2.new(0.5, 0, 0, warnY)
	eventL.Position = UDim2.new(0.5, 0, 0, math.min(viewport * 0.52, warnY - 40))
	local left = warnAt - now
	warnL.Text = if left > 0 then string.format("%d초 뒤 금칙어가 %d개로 늘어나요!", math.ceil(left), warnCount) else ""
end

function HostPanel.clear()
	eventL.TextTransparency = 1
	eventL.TextStrokeTransparency = 1
	warnAt = 0
end

return HostPanel
