--!strict
-- The squash control: hold S (the on-screen "납작" button on touch screens, B on a gamepad) to fold the locomotive
-- flat; let go to spring back. Calls onChange(true/false) once per change. Each input is tracked on its own, so the
-- locomotive stays flat while any of them is held; losing window focus lets go of all of them.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local SquashInput = {}

local ACTION = "WesternTrainSquash"
local BUTTON_TITLE = "납작"

-- Returns a function that removes the control.
function SquashInput.bind(onChange: (boolean) -> ()): () -> ()
	local held: { [any]: boolean } = {} -- key codes, or the InputObject of a touch
	local down = false
	local function refresh()
		local now = next(held) ~= nil
		if now ~= down then
			down = now
			onChange(now)
		end
	end
	ContextActionService:BindActionAtPriority(ACTION, function(_, state: Enum.UserInputState, input: InputObject)
		local key: any = if input.UserInputType == Enum.UserInputType.Touch then input else input.KeyCode
		if state == Enum.UserInputState.Begin then
			held[key] = true
		elseif state == Enum.UserInputState.End then
			held[key] = nil
		elseif state == Enum.UserInputState.Cancel then
			table.clear(held)
		end
		refresh()
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.S, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle(ACTION, BUTTON_TITLE)
	local focusLost = UserInputService.WindowFocusReleased:Connect(function()
		table.clear(held)
		refresh()
	end)
	return function()
		ContextActionService:UnbindAction(ACTION)
		focusLost:Disconnect()
		table.clear(held)
		refresh()
	end
end

return SquashInput
