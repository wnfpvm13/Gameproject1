--!strict
-- Centre toast (elimination, warnings, info) on a paper pill that fades out by itself; the kind colours the text.
local TweenService = game:GetService("TweenService")

local Style = require(script.Parent:WaitForChild("Style"))

local Toast = {}

local toastL: TextLabel
local edge: UIStroke
local fading: { Tween } = {}

function Toast.build()
	toastL = Instance.new("TextLabel")
	toastL.AnchorPoint = Vector2.new(0.5, 0.5)
	toastL.Position = UDim2.fromScale(0.5, 0.36)
	toastL.Size = UDim2.fromOffset(0, 0)
	toastL.AutomaticSize = Enum.AutomaticSize.XY
	toastL.BackgroundColor3 = Style.PAPER
	toastL.BorderSizePixel = 0
	toastL.FontFace = Style.BOLD
	toastL.TextSize = 24
	toastL.TextWrapped = true -- (grows with the text up to the size limit, then wraps)
	toastL.Text = ""
	Style.fitWidth(toastL, 0.9, 560, 400) -- (narrower on a small screen)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 22)
	pad.PaddingRight = UDim.new(0, 22)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = toastL
	Style.round(toastL, 14)
	edge = toastL:FindFirstChildOfClass("UIStroke") :: UIStroke
	toastL.BackgroundTransparency = 1
	toastL.TextTransparency = 1
	edge.Transparency = 1
	toastL.Parent = Style.gui()
end

-- Under the mission card when one shows (`top`: its lower edge, bundle 12: the card sits at the top now), else at
-- its own place a little above the middle.
function Toast.place(top: number?)
	if top then
		toastL.AnchorPoint = Vector2.new(0.5, 0)
		toastL.Position = UDim2.new(0.5, 0, 0, top + 10)
	else
		toastL.AnchorPoint = Vector2.new(0.5, 0.5)
		toastL.Position = UDim2.fromScale(0.5, 0.36)
	end
end

function Toast.show(text: string, kind: "elim" | "near" | "info")
	for _, tween in fading do
		tween:Cancel()
	end
	toastL.Text = text
	toastL.TextColor3 = if kind == "elim" then Style.RED_TEXT elseif kind == "near" then Style.INK else Style.GREEN_TEXT
	toastL.TextTransparency = 0
	toastL.BackgroundTransparency = Style.PAPER_ALPHA
	edge.Transparency = 0
	local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.4)
	fading = {
		TweenService:Create(toastL, info, { TextTransparency = 1, BackgroundTransparency = 1 }),
		TweenService:Create(edge, info, { Transparency = 1 }),
	}
	for _, tween in fading do
		tween:Play()
	end
end

return Toast
