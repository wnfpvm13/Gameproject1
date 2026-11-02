--!strict
-- The dodge roll control (decision 22): Q on a keyboard, B on a gamepad, and a "구르기" button left of the block button
-- on touch screens (in the same look; above the attack button it lay over the music button). A press calls `pressed`
-- (the player's own roll: OwnDodge).
-- show() puts the roll's cooldown on the touch button: dimmed with the seconds left, its name again when ready.
-- (Bound as SwingInput and BlockInput are.)
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local DodgeInput = {}
DodgeInput.__index = DodgeInput

local ACTION = "TrainBrawlDodge"

type Fields = { button: ImageButton?, title: TextLabel?, shown: number? }
export type Input = typeof(setmetatable({} :: Fields, DodgeInput))

function DodgeInput.bind(pressed: () -> ()): Input
	local fields: Fields = { button = nil, title = nil, shown = nil }
	local self = setmetatable(fields, DodgeInput)
	local press: UIScale? = nil
	ContextActionService:BindActionAtPriority(ACTION, function(_, state: Enum.UserInputState, input: InputObject)
		if press and input.UserInputType == Enum.UserInputType.Touch then
			press.Scale = if state == Enum.UserInputState.Begin then 0.9 else 1
		end
		if state == Enum.UserInputState.Begin then
			pressed()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle(ACTION, Words.DodgeButton)
	-- Left of the block button, its size (BlockInput's look): attack, block, roll in a row from the right.
	local button = ContextActionService:GetButton(ACTION)
	if button then
		button.Size = UDim2.fromOffset(72, 72)
		button.Position = UDim2.new(1, -282, 1, -212)
		button.Image = ""
		button.PressedImage = ""
		button.ImageTransparency = 1
		button.BackgroundColor3 = UiStyle.PlateColor
		button.BackgroundTransparency = 0.15
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = button
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = UiStyle.PlateEdge
		edge.Thickness = 3
		edge.Parent = button
		local scale = Instance.new("UIScale")
		scale.Parent = button
		press = scale
		local title = button:FindFirstChild("ActionTitle")
		if title and title:IsA("TextLabel") then
			title.TextSize = 18
			UiStyle.text(title)
			self.title = title
		end
		self.button = button
	end
	return self
end

-- The roll's cooldown on the touch button: `wait` seconds until the next roll may start (0: ready).
function DodgeInput.show(self: Input, wait: number)
	local button, title = self.button, self.title
	if not (button and title) then
		return
	end
	-- Tenths while cooling down (shown only when the text changes).
	local tenths = if wait > 0 then math.ceil(wait * 10) else 0
	if tenths == self.shown then
		return
	end
	self.shown = tenths
	title.Text = if tenths > 0 then string.format("%.1f", tenths / 10) else Words.DodgeButton
	button.BackgroundTransparency = if tenths > 0 then 0.5 else 0.15
	title.TextTransparency = if tenths > 0 then 0.3 else 0
end

return DodgeInput
