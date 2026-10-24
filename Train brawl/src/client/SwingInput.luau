--!strict
-- The swing control: click (the on-screen "때리기" button on touch screens, R2 on a gamepad). Calls onSwing() on each
-- press; whether a swing may start is the caller's call.
-- (The binding follows Western train's JumpInput.)
local ContextActionService = game:GetService("ContextActionService")

local SwingInput = {}

local ACTION = "TrainBrawlSwing"
local BUTTON_TITLE = "때리기"

-- Returns a function that removes the control.
function SwingInput.bind(onSwing: () -> ()): () -> ()
	ContextActionService:BindActionAtPriority(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			onSwing()
		end
		return Enum.ContextActionResult.Pass -- clicks still reach the camera and the GUI
	end, true, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(ACTION, BUTTON_TITLE)
	-- A big button where the thumb rests, above the jump button.
	local button = ContextActionService:GetButton(ACTION)
	if button then
		button.Size = UDim2.fromOffset(90, 90)
		button.Position = UDim2.new(1, -110, 1, -230)
		local title = button:FindFirstChild("ActionTitle")
		if title and title:IsA("TextLabel") then
			title.TextSize = 22 -- the default is small for a button this big
			title.Font = Enum.Font.GothamBold
		end
	end
	return function()
		ContextActionService:UnbindAction(ACTION)
	end
end

return SwingInput
