--!strict
-- The first-ride card: once per visit, a small plate at the left of the screen with the controls and the rules that
-- matter (Words.cardRows: how to attack with the control in use, the third hit in a row launches, low health flies
-- farther, crates hold weapons, falling off is out). It comes up with the player's first count-down on the trains and
-- fades a few seconds into that fight, so it is read while everyone is held still and never covers a later round. It
-- fades at once if the player goes out or the round ends first. It sits at the left under the round's plates, scaled
-- down on a small screen so it stays clear of the big centre text (RoundHud) and the health bar at the bottom.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))
local Workspace = game:GetService("Workspace")

local RideCard = {}
RideCard.__index = RideCard

local FIGHT_SECONDS = 8 -- it stays this long into the first fight
local FADE_SECONDS = 0.6
local ROW_HEIGHT = 28
local WIDTH = 380
local KEY_WIDTH = 150 -- the control column
local ROW_TEXT = 18 -- every row the same size (scaled text would shrink the long rows only)
local MIN_SCALE = 0.5
local LEFT = 16
local TOP = 70 -- under the round's plates (RoundHud, 12 to 60 down)
local CENTRE_ROOM = 80 -- the card's right edge stays this far left of the screen's middle (a count-down number is about 57 each side)
-- (The big text sits 30% down the screen, at least 130: RoundHud.)
local BOTTOM_ROOM = 100 -- and its bottom this far above the screen's bottom (the weapon name and health bar)

-- state: "waiting" (not shown yet), "shown", or "done" (shown once; never again this visit).
type Fields = { gui: ScreenGui, frame: Frame, state: string, hideAt: number }
export type Card = typeof(setmetatable({} :: Fields, RideCard))

-- The kind of control the player is using now: "touch", "gamepad" or "mouse".
local function control(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif last.Name:sub(1, 7) == "Gamepad" then
		return "gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "gamepad" -- a console before its first input
	end
	return "mouse"
end

function RideCard.new(playerGui: Instance): Card
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlRideCard"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui
	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.AnchorPoint = Vector2.new(0, 0)
	UiStyle.plate(frame, 12)
	frame.Parent = gui
	local fields: Fields = { gui = gui, frame = frame, state = "waiting", hideAt = 0 }
	return setmetatable(fields, RideCard)
end

-- Fills the card for the control in use.
local function fill(self: Card)
	for _, child in self.frame:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local title = UiStyle.label(self.frame, "Title", UDim2.fromOffset(WIDTH - 24, 28), 24, UiStyle.Gold)
	title.Position = UDim2.fromOffset(12, 8)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Words.CardTitle
	local rows = Words.cardRows(control())
	for i, row in rows do
		local y = 8 + 28 + 4 + (i - 1) * ROW_HEIGHT
		local key = UiStyle.label(self.frame, "Key", UDim2.fromOffset(KEY_WIDTH, ROW_HEIGHT - 4), 20, UiStyle.Gold)
		key.Position = UDim2.fromOffset(12, y)
		key.TextXAlignment = Enum.TextXAlignment.Left
		key.TextScaled = false
		key.TextSize = ROW_TEXT
		key.Text = row[1]
		local meaning = UiStyle.label(self.frame, "Meaning", UDim2.fromOffset(WIDTH - 24 - KEY_WIDTH - 8, ROW_HEIGHT - 4), 20)
		meaning.Position = UDim2.fromOffset(12 + KEY_WIDTH + 8, y)
		meaning.TextXAlignment = Enum.TextXAlignment.Left
		meaning.TextScaled = false
		meaning.TextSize = ROW_TEXT
		meaning.Text = row[2]
	end
	self.frame.Size = UDim2.fromOffset(WIDTH, 8 + 28 + 4 + #rows * ROW_HEIGHT + 10)
end

local function setFade(self: Card, transparency: number)
	self.frame.BackgroundTransparency = 0.18 + 0.82 * transparency
	local edge = self.frame:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Transparency = transparency
	end
	for _, child in self.frame:GetChildren() do
		if child:IsA("TextLabel") then
			UiStyle.fade(child, transparency)
		end
	end
end

-- Every frame. phase: the round phase (Names.Phase); aboard: the player is in this round.
function RideCard.update(self: Card, phase: string, aboard: boolean)
	local now = os.clock()
	if self.state == "waiting" then
		if aboard and (phase == "Countdown" or phase == "Fight") then
			self.state = "shown"
			self.hideAt = math.huge
			fill(self)
			setFade(self, 0)
			self.gui.Enabled = true
			-- Full size where it fits; on a small screen as big as the room left of the middle and above the bottom allows.
			local screen = Workspace.CurrentCamera.ViewportSize
			local wide = (screen.X / 2 - CENTRE_ROOM - LEFT) / WIDTH
			local tall = (screen.Y - BOTTOM_ROOM - TOP) / self.frame.Size.Y.Offset
			self.frame.Position = UDim2.fromOffset(LEFT, TOP)
			UiStyle.pop(self.frame, 1.08, math.clamp(math.min(wide, tall), MIN_SCALE, 1))
		end
		return
	elseif self.state ~= "shown" then
		return
	end
	if not aboard or (phase ~= "Countdown" and phase ~= "Fight") then
		self.hideAt = math.min(self.hideAt, now + FADE_SECONDS) -- out, or the round is over: fade now
	elseif self.hideAt == math.huge and phase == "Fight" then
		self.hideAt = now + FIGHT_SECONDS
	end
	local left = self.hideAt - now
	if left <= 0 then
		self.state = "done"
		self.gui.Enabled = false
		self.gui:Destroy()
	elseif left < FADE_SECONDS then
		setFade(self, 1 - left / FADE_SECONDS)
	end
end

return RideCard
