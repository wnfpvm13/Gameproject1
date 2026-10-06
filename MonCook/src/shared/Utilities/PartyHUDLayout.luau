--!strict
-- Pure screen-space layout. A PlayerList reservation is an estimate, never a
-- reason to hide essential controls on a narrow screen. CoreUI enablement is
-- not proof that its responsive/overlay panel is currently visible.
local Layout = {}
local LIST_WIDTH, LIST_HEADER, LIST_ROW, LIST_MAX_HEIGHT = 320, 52, 22, 450
local MIN_USABLE_PANEL = 108 -- compact 28px heading + 70px scroll viewport + padding

export type ChatBounds = { Left: number, Right: number, Bottom: number }
export type Input = {
	Width: number, Height: number, TopbarBottom: number,
	PlayerListEnabled: boolean, PlayerCount: number,
	ChatBounds: { ChatBounds }, Expanded: boolean,
}

function Layout.calculate(input: Input): any
	local top = math.max(12, input.TopbarBottom + 12)
	local right = 12
	local width = math.max(0, math.min(320, input.Width - 24))
	local policy = "SafeArea"
	if input.PlayerListEnabled then
		local besideList = input.Width - LIST_WIDTH - 36
		if besideList >= 180 then
			right += LIST_WIDTH + 12
			width = math.min(width, besideList)
			policy = "BesidePlayerList"
		else
			width = math.min(width, 240)
			local belowList = math.max(top, math.min(input.Height, LIST_MAX_HEIGHT, LIST_HEADER + input.PlayerCount * LIST_ROW) + 12)
			if input.Height - belowList - 12 >= MIN_USABLE_PANEL then
				top, policy = belowList, "BelowPlayerList"
			else
				-- Keep a working compact HUD when the estimated list column would
				-- consume the screen. Actual topbar/chat rectangles still apply.
				policy = "CompactFallback"
			end
		end
	end
	local left, edge = input.Width - right - width, input.Width - right
	for _, bounds in input.ChatBounds do
		if left < bounds.Right + 12 and edge > bounds.Left - 12 then top = math.max(top, bounds.Bottom + 12) end
	end
	local remaining = math.max(0, input.Height - top - 12)
	local height = if input.Expanded then math.min(500, input.Height * 0.7, remaining) else math.min(74, remaining)
	local smallHeader = input.Expanded and height < 160
	local header = if smallHeader then 28 else 74
	return {
		Top = top, Right = right, Width = width, Height = height, Header = header,
		SmallHeader = smallHeader, BodyHeight = math.max(0, height - header - 10),
		Policy = policy,
	}
end

return table.freeze(Layout)
