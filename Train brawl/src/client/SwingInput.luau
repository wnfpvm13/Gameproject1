--!strict
-- The swing control: click (the on-screen attack button on touch screens, R2 on a gamepad). Calls onSwing(mouse) on
-- each press (mouse: it was a mouse click); whether a swing may start is the caller's call.
-- (The binding follows Western train's JumpInput.)
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local SwingInput = {}

local ACTION = "TrainBrawlSwing"

-- Returns a function that removes the control.
function SwingInput.bind(onSwing: (mouse: boolean) -> ()): () -> ()
	local press: UIScale? = nil -- the touch button's press, once it is made
	ContextActionService:BindActionAtPriority(ACTION, function(_, state: Enum.UserInputState, input: InputObject)
		if state == Enum.UserInputState.Begin then
			onSwing(input.UserInputType == Enum.UserInputType.MouseButton1)
		end
		if press and input.UserInputType == Enum.UserInputType.Touch then
			press.Scale = if state == Enum.UserInputState.Begin then 0.9 else 1
		end
		return Enum.ContextActionResult.Pass -- clicks still reach the camera and the GUI
	end, true, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(ACTION, Words.AttackButton)
	-- A big button where the thumb rests, above the jump button, in the game's look (a dark plate with a wooden edge and
	-- bold text) instead of Roblox's grey circle, pressing in a little when touched.
	local button = ContextActionService:GetButton(ACTION)
	if button then
		button.Size = UDim2.fromOffset(90, 90)
		button.Position = UDim2.new(1, -110, 1, -230)
		button.Image = ""
		button.PressedImage = ""
		button.ImageTransparency = 1 -- Roblox swaps its own pressed image in on a touch
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
			title.TextSize = 22 -- the default is small for a button this big
			UiStyle.text(title)
		end
	end
	return function()
		ContextActionService:UnbindAction(ACTION)
	end
end

return SwingInput
