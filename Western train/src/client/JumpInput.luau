--!strict
-- The jump control: Space (the on-screen "점프" button on touch screens, A on a gamepad) makes the locomotive jump.
-- Calls onJump() on each press; whether a jump may start is the caller's call. The touch button can be greyed out
-- while a jump is not possible (flat, or already in the air).
local ContextActionService = game:GetService("ContextActionService")

local JumpInput = {}

local ACTION = "WesternTrainJump"
local BUTTON_TITLE = "점프"
local GREYED = 0.6 -- the touch button's transparency while a jump is not possible

export type Control = { setEnabled: (enabled: boolean) -> (), unbind: () -> () }

function JumpInput.bind(onJump: () -> ()): Control
	ContextActionService:BindActionAtPriority(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			onJump()
		end
		return Enum.ContextActionResult.Sink -- the hidden driver's own character must not jump
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle(ACTION, BUTTON_TITLE)
	local enabled = true
	return {
		setEnabled = function(now: boolean)
			if now == enabled then
				return
			end
			local button = ContextActionService:GetButton(ACTION)
			if button then -- none without a touch screen (or not made yet: tried again next time)
				button.ImageTransparency = if now then 0 else GREYED
				enabled = now
			end
		end,
		unbind = function()
			ContextActionService:UnbindAction(ACTION)
		end,
	}
end

return JumpInput
