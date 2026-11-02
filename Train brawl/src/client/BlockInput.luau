--!strict
-- The block control (decision 11's hold-to-block, persona fix 4): held down, the player blocks. Right mouse button or
-- F on a keyboard, LT / L2 on a gamepad, and a "막기" button left of the attack button on touch screens (in the same
-- look). Tells the server when it goes down and up (Names.BlockRemote); held() says whether it is held now, so the
-- player's own attack does not start while blocking. suspend() lets go of the block while the control is still held
-- (the attack control pressed while blocking: block, then strike back - Codex review 2026-11-02); it blocks again only
-- on a new press. (Bound as SwingInput is.)
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local BlockInput = {}
BlockInput.__index = BlockInput

local ACTION = "TrainBrawlBlock"

-- down: the inputs holding it now (a key and a mouse button may both be held); suspended: let go by suspend() until the
-- next press.
type Fields = { remote: RemoteEvent, down: { [string]: boolean }, sent: boolean, suspended: boolean }
export type Input = typeof(setmetatable({} :: Fields, BlockInput))

local function anyDown(self: Input): boolean
	return next(self.down) ~= nil and not self.suspended
end

function BlockInput.bind(remote: RemoteEvent): Input
	local fields: Fields = { remote = remote, down = {}, sent = false, suspended = false }
	local self = setmetatable(fields, BlockInput)
	local press: UIScale? = nil
	ContextActionService:BindActionAtPriority(ACTION, function(_, state: Enum.UserInputState, input: InputObject)
		local key = if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType.Name:sub(1, 7) == "Gamepad"
			then input.KeyCode.Name
			else input.UserInputType.Name
		if state == Enum.UserInputState.Begin then
			self.down[key] = true
			self.suspended = false -- a new press blocks again
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			self.down[key] = nil
		end
		local held = anyDown(self)
		if held ~= self.sent then
			self.sent = held
			self.remote:FireServer(held)
		end
		if press and input.UserInputType == Enum.UserInputType.Touch then
			press.Scale = if held then 0.9 else 1
		end
		return Enum.ContextActionResult.Pass -- the right button still turns the camera when the mouse is free
	end, true, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton2, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle(ACTION, Words.BlockButton)
	-- Left of the attack button, a little smaller (SwingInput's look).
	local button = ContextActionService:GetButton(ACTION)
	if button then
		button.Size = UDim2.fromOffset(72, 72)
		button.Position = UDim2.new(1, -196, 1, -212)
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
			title.TextSize = 20
			UiStyle.text(title)
		end
	end
	return self
end

-- Whether the block control is held now (and not let go by suspend()).
function BlockInput.held(self: Input): boolean
	return anyDown(self)
end

-- Lets go of the block now, though the control is still held, until it is pressed again.
function BlockInput.suspend(self: Input)
	self.suspended = true
	if self.sent then
		self.sent = false
		self.remote:FireServer(false)
	end
end

return BlockInput
