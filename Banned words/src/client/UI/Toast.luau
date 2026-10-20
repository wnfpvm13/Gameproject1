--!strict
-- Big centre toast (elimination, warnings, info) that fades out by itself.
local TweenService = game:GetService("TweenService")

local Style = require(script.Parent:WaitForChild("Style"))

local Toast = {}

local toastL: TextLabel

function Toast.build()
	toastL = Style.label(Style.gui(), Style.BOLD, 46, Style.WHITE)
	toastL.AnchorPoint = Vector2.new(0.5, 0.5)
	toastL.Position = UDim2.fromScale(0.5, 0.4)
	toastL.Size = UDim2.fromScale(0.8, 0.14)
	toastL.TextTransparency = 1
	toastL.TextStrokeTransparency = 1
end

function Toast.show(text: string, kind: "elim" | "near" | "info")
	toastL.Text = text
	toastL.TextColor3 = if kind == "elim" then Style.RED elseif kind == "near" then Style.AMBER else Style.GREEN
	toastL.TextTransparency = 0
	toastL.TextStrokeTransparency = 0.3
	local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.4)
	TweenService:Create(toastL, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

return Toast
