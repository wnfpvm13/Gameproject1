--!strict
-- Safe-area coordinates only: the caller converts public CoreUI rectangles.
-- PlayerList bounds are an estimate. On narrow screens the estimate cannot
-- consume the whole HUD; actual ChatBounds still take priority. A full-screen
-- chat rectangle has no non-overlapping solution and uses ChatSpaceFallback.
local Geometry = {}
local EDGE, GAP, HEADER, ROW = 12, 12, 44, 40
-- With 8px body insets, a 166px panel still fits three 44px actions.
local MIN_EXPANDED_WIDTH = 166
local LIST_WIDTH, LIST_HEADER, LIST_ROW, LIST_MAX_HEIGHT = 320, 52, 22, 450

export type Position = { X: number, Y: number }
export type ChatBounds = { Left: number, Right: number, Bottom: number, Top: number? }
export type Input = {
	Width: number, Height: number, Expanded: boolean,
	MemberCount: number?, TopbarBottom: number,
	PlayerListEnabled: boolean, PlayerCount: number,
	ChatBounds: { ChatBounds }?, Position: Position?,
}
type Rect = { Left: number, Top: number, Right: number, Bottom: number }
export type Placement = {
	Left: number, Top: number, Width: number, Height: number,
	Position: Position, Policy: string,
}

local function finite(value: number?): number
	if value == nil or value ~= value or math.abs(value) == math.huge then return 0 end
	return value
end

local function viewport(input: Input): Rect
	local width, height = math.max(0, finite(input.Width)), math.max(0, finite(input.Height))
	local horizontal, vertical = math.min(EDGE, width / 2), math.min(EDGE, height / 2)
	local bottom = height - vertical
	return { Left = horizontal, Top = math.clamp(finite(input.TopbarBottom) + vertical, vertical, bottom),
		Right = width - horizontal, Bottom = bottom }
end

local function normalized(base: Rect, width: number, height: number, left: number, top: number): Position
	local dx, dy = math.max(0, base.Right - base.Left - width), math.max(0, base.Bottom - base.Top - height)
	return {
		X = if dx > 0 then math.clamp((finite(left) - base.Left) / dx, 0, 1) else 0,
		Y = if dy > 0 then math.clamp((finite(top) - base.Top) / dy, 0, 1) else 0,
	}
end

function Geometry.normalize(input: Input, width: number, height: number, left: number, top: number): Position
	local base = viewport(input)
	return normalized(base, math.max(0, finite(width)), math.max(0, finite(height)), left, top)
end

local function slots(input: Input, base: Rect, width: number): ({ Rect }, string)
	local obstacles: { Rect } = {}
	local policy = "SafeArea"
	if input.PlayerListEnabled then
		if finite(input.Width) >= LIST_WIDTH + width + EDGE * 3 then
			table.insert(obstacles, {
				Left = finite(input.Width) - EDGE - LIST_WIDTH - GAP,
				Right = base.Right, Top = base.Top,
				Bottom = math.min(base.Bottom, math.max(base.Top, finite(input.TopbarBottom))
					+ math.min(LIST_MAX_HEIGHT, LIST_HEADER + math.max(0, finite(input.PlayerCount)) * LIST_ROW) + GAP),
			})
			policy = "PlayerListReservation"
		else
			policy = "CompactPlayerListFallback"
		end
	end
	for _, bounds in input.ChatBounds or {} do
		local left, right = finite(bounds.Left), finite(bounds.Right)
		local top, bottom = finite(bounds.Top), finite(bounds.Bottom)
		if right > left and bottom > top then
			table.insert(obstacles, { Left = left - GAP, Right = right + GAP, Top = top - GAP, Bottom = bottom + GAP })
		end
	end
	local result: { Rect } = { base }
	for _, obstacle in obstacles do
		local nextResult: { Rect } = {}
		local function add(left: number, top: number, right: number, bottom: number)
			if right > left and bottom > top then
				table.insert(nextResult, { Left = left, Top = top, Right = right, Bottom = bottom })
			end
		end
		for _, area in result do
			local left, right = math.max(area.Left, obstacle.Left), math.min(area.Right, obstacle.Right)
			local top, bottom = math.max(area.Top, obstacle.Top), math.min(area.Bottom, obstacle.Bottom)
			if right <= left or bottom <= top then
				add(area.Left, area.Top, area.Right, area.Bottom)
			else
				-- Overlapping free rectangles are intentional: a single panel is
				-- placed, so a maximal rectangle preserves useful scroll space.
				add(area.Left, area.Top, left, area.Bottom)
				add(right, area.Top, area.Right, area.Bottom)
				add(area.Left, area.Top, area.Right, top)
				add(area.Left, bottom, area.Right, area.Bottom)
			end
		end
		result = nextResult
	end
	return result, policy
end

local function choose(base: Rect, areas: { Rect }, width: number, height: number, minWidth: number,
	minHeight: number, position: Position?): (Placement?, boolean)
	local preference = position or { X = 1, Y = 0 }
	local targetLeft = base.Left + math.max(0, base.Right - base.Left - width) * math.clamp(finite(preference.X), 0, 1)
	local targetTop = base.Top + math.max(0, base.Bottom - base.Top - height) * math.clamp(finite(preference.Y), 0, 1)
	local best: Placement? = nil
	local bestLoss, bestDistance = math.huge, math.huge
	for _, area in areas do
		local actualWidth, actualHeight = math.min(width, area.Right - area.Left), math.min(height, area.Bottom - area.Top)
		if actualWidth >= minWidth and actualHeight >= minHeight then
			local left = math.clamp(targetLeft, area.Left, area.Right - actualWidth)
			local top = math.clamp(targetTop, area.Top, area.Bottom - actualHeight)
			-- Keep readable width before preserving surplus scrolling height.
			local loss = 10 * (width - actualWidth) / math.max(1, width) + (height - actualHeight) / math.max(1, height)
			local distance = (left - targetLeft) ^ 2 + (top - targetTop) ^ 2
			if loss < bestLoss or (loss == bestLoss and distance < bestDistance) then
				bestLoss, bestDistance = loss, distance
				best = { Left = left, Top = top, Width = actualWidth, Height = actualHeight,
					Position = normalized(base, actualWidth, actualHeight, left, top), Policy = "" }
			end
		end
	end
	return best, best ~= nil
end

local function fallback(base: Rect, width: number, height: number, position: Position?): Placement
	local actualWidth, actualHeight = math.min(width, base.Right - base.Left), math.min(height, base.Bottom - base.Top)
	local preference = position or { X = 1, Y = 0 }
	local left = base.Left + math.max(0, base.Right - base.Left - actualWidth) * math.clamp(finite(preference.X), 0, 1)
	local top = base.Top + math.max(0, base.Bottom - base.Top - actualHeight) * math.clamp(finite(preference.Y), 0, 1)
	return { Left = left, Top = top, Width = actualWidth, Height = actualHeight,
		Position = normalized(base, actualWidth, actualHeight, left, top), Policy = "ChatSpaceFallback" }
end

-- Manual coordinates may overlap Chat/PlayerList. Keep the whole panel inside
-- the essential viewport so the handle and expand control remain accessible.
function Geometry.dragPlacement(input: Input, width: number, height: number, position: Position?): Placement
	local result = fallback(viewport(input), math.max(0, finite(width)), math.max(0, finite(height)), position or input.Position)
	result.Policy = "ManualSafeArea"
	return result
end

function Geometry.viewportChanged(previous: Input?, current: Input): boolean
	if not previous then return false end
	local before, after = viewport(previous), viewport(current)
	return before.Left ~= after.Left or before.Top ~= after.Top
		or before.Right ~= after.Right or before.Bottom ~= after.Bottom
end

function Geometry.placement(input: Input, width: number, height: number, position: Position?): Placement
	local base = viewport(input)
	local desiredWidth, desiredHeight = math.max(0, finite(width)), math.max(0, finite(height))
	local areas, policy = slots(input, base, desiredWidth)
	local result: Placement? = choose(base, areas, desiredWidth, desiredHeight, math.min(desiredWidth, if input.Expanded then MIN_EXPANDED_WIDTH else 72),
		math.min(desiredHeight, if input.Expanded then 96 else 92), position or input.Position)
	if result then result.Policy = policy; return result end
	-- Small real chat slots are preferable to hiding the panel. The caller can
	-- render a scroller; a zero-sized startup viewport stays finite and safe.
	result = choose(base, areas, desiredWidth, desiredHeight, math.min(desiredWidth, 1), math.min(desiredHeight, 1), position or input.Position)
	if result then result.Policy = policy .. ":ConstrainedChatSpace"; return result end
	return fallback(base, desiredWidth, desiredHeight, position or input.Position)
end

function Geometry.measure(input: Input): any
	local base = viewport(input)
	local count = math.clamp(math.floor(math.max(0, finite(input.MemberCount))), 0, 4)
	local canvas = math.max(1, count) * ROW
	local expanded = input.Expanded
	local width = if expanded then math.min(300, base.Right - base.Left) else math.min(if finite(input.Width) >= 600 then 136 else 88, base.Right - base.Left)
	local height = if expanded then math.min(420, math.max(0, finite(input.Height)) * 0.7) else HEADER + canvas + 8
	local areas, policy = slots(input, base, width)
	local result = choose(base, areas, width, height, if expanded then MIN_EXPANDED_WIDTH else 72, if expanded then 96 else 92, input.Position)
	if expanded and not result then
		expanded = false
		width, height = math.min(88, base.Right - base.Left), HEADER + canvas + 8
		areas, policy = slots(input, base, width)
		policy ..= ":AutoCompact"
		result = choose(base, areas, width, height, 72, 92, input.Position)
	end
	if not result then
		result = Geometry.placement(input, width, height, input.Position)
		policy = result.Policy
	end
	assert(result)
	local header = math.min(HEADER, result.Height)
	local body = math.max(0, result.Height - header - 8)
	return {
		Left = result.Left, Top = result.Top, Width = result.Width, Height = result.Height,
		Header = header, BodyHeight = body, PortraitHeight = math.min(canvas, body),
		PortraitRowHeight = ROW, PortraitCanvasHeight = canvas,
		NamesVisible = result.Width >= 120, NeedsPortraitScroll = body < canvas,
		EffectiveExpanded = expanded, MemberCount = count, Policy = policy, Position = result.Position,
	}
end

function Geometry.actionRow(width: number, count: number): any
	width = math.max(0, finite(width))
	count = math.max(1, math.floor(finite(count)))
	local stacked = width / count - 3 < 88
	return { Stacked = stacked, ButtonHeight = 44, Gap = 4,
		ButtonWidth = if stacked then width else width / count - 3,
		Height = if stacked then count * 44 + (count - 1) * 4 else 44 }
end

function Geometry.finderCard(width: number): any
	width = math.max(0, finite(width))
	local compact = width < 180
	local inset = math.min(if compact then 4 else 8, width / 2)
	local gap = if compact then 6 else 8
	local buttonWidth = math.min(44, math.max(0, width - inset * 2))
	local buttonLeft = math.max(inset, width - inset - buttonWidth)
	local infoWidth = math.max(0, buttonLeft - inset - gap)
	local statusWidth = math.min(if compact then 44 else 52, infoWidth)
	local statusLeft = math.max(inset, buttonLeft - gap - statusWidth)
	local hostWidth = math.max(0, statusLeft - inset - 6)
	local countWidth = math.min(24, hostWidth)
	local countGap = if hostWidth >= countWidth + 4 then 4 else 0
	local nameWidth = math.max(0, hostWidth - countWidth - countGap)
	return {
		Height = 68, ButtonLeft = buttonLeft, ButtonTop = 23, ButtonWidth = buttonWidth, ButtonHeight = 44,
		InfoLeft = inset, InfoTop = 8, InfoWidth = infoWidth, InfoHeight = 20,
		HostTop = 35, HostHeight = 20, HostWidth = hostWidth, HostNameWidth = nameWidth,
		CountLeft = inset + nameWidth + countGap, CountTop = 35, CountWidth = countWidth, CountHeight = 20,
		StatusLeft = statusLeft, StatusTop = 35, StatusWidth = statusWidth, StatusHeight = 20,
	}
end

return table.freeze(Geometry)
