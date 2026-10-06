--!strict
local Geometry = require(script.Parent.Parent.src.shared.Utilities.PartyHUDGeometry)

local function request(width: number, height: number, expanded: boolean): any
	return { Width = width, Height = height, Expanded = expanded, MemberCount = 4,
		TopbarBottom = 0, PlayerListEnabled = false, PlayerCount = 20, ChatBounds = {} }
end

local function safe(value: any, input: any)
	assert(value.Left >= 0 and value.Top >= 0 and value.Width >= 0 and value.Height >= 0)
	assert(value.Left + value.Width <= input.Width and value.Top + value.Height <= input.Height)
	for _, field in { "Left", "Top", "Width", "Height" } do
		assert(value[field] == value[field] and math.abs(value[field]) ~= math.huge)
	end
end

local function avoids(value: any, bounds: any)
	assert(value.Left >= bounds.Right or value.Left + value.Width <= bounds.Left
		or value.Top >= bounds.Bottom or value.Top + value.Height <= (bounds.Top or 0), "HUD intersects a real chat rectangle")
end

return function(): number
	local passed = 0
	local function check(callback: () -> ()) callback(); passed += 1 end
	check(function()
		local input = request(390, 700, false)
		local value = Geometry.measure(input)
		safe(value, input)
		assert(value.Width == 88 and value.Header == 44 and not value.EffectiveExpanded)
		assert(value.PortraitRowHeight == 40 and value.PortraitCanvasHeight == 160)
		assert(value.PortraitHeight == 160 and value.Height == 212 and not value.NamesVisible)
	end)
	check(function()
		local input = request(390, 700, false)
		input.MemberCount = 0
		local value = Geometry.measure(input)
		assert(value.MemberCount == 0 and value.Height >= 88, "empty HUD still exposes its expand control")
		assert(value.Header == 44 and value.PortraitCanvasHeight == 40)
	end)
	check(function()
		local input = request(1024, 700, false)
		input.MemberCount = 17
		local value = Geometry.measure(input)
		assert(value.MemberCount == 4 and value.PortraitCanvasHeight == 160)
		assert(value.Width == 136 and value.NamesVisible)
	end)
	check(function()
		local input = request(390, 700, false)
		local preference = Geometry.normalize(input, 88, 212, -500, 5000)
		assert(preference.X == 0 and preference.Y == 1)
		local value = Geometry.placement(input, 88, 212, preference)
		safe(value, input)
		assert(value.Left == 12 and value.Top + value.Height == 688)
		preference = Geometry.normalize(input, 88, 212, 5000, -500)
		value = Geometry.placement(input, 88, 212, preference)
		assert(value.Left + value.Width == 378 and value.Top == 12)
	end)
	check(function()
		local desktop = request(1200, 800, true)
		local preference = Geometry.normalize(desktop, 300, 420, 770, 290)
		assert(preference.X >= 0 and preference.X <= 1 and preference.Y >= 0 and preference.Y <= 1)
		local resized = request(390, 300, true)
		resized.Position = preference
		local value = Geometry.measure(resized)
		safe(value, resized)
		assert(value.Width == 300 and value.Height == 210 and value.BodyHeight >= 44)
		assert(math.abs(value.Position.X - preference.X) < 0.00001 and math.abs(value.Position.Y - preference.Y) < 0.00001)
	end)
	check(function()
		local input = request(390, 300, false)
		input.TopbarBottom = 30
		local value = Geometry.placement(input, 88, 212, { X = 1, Y = -10 })
		safe(value, input)
		assert(value.Top >= 42 and value.Left + value.Width == 378)
	end)
	check(function()
		local input = request(1024, 700, true)
		input.PlayerListEnabled = true
		local value = Geometry.measure(input)
		safe(value, input)
		assert(value.Left + value.Width <= 680, "default HUD must avoid the estimated desktop PlayerList column")
		assert(value.Top == 12 and value.Width == 300 and value.Height == 420)
		assert(value.Policy == "PlayerListReservation")
	end)
	check(function()
		local input = request(390, 700, false)
		input.PlayerListEnabled = true
		input.ChatBounds = { { Left = 0, Right = 195, Bottom = 260 } }
		local value = Geometry.measure(input)
		safe(value, input); avoids(value, input.ChatBounds[1])
		assert(value.Top == 12 and value.Width == 88 and value.Height == 212)
		assert(value.Policy == "CompactPlayerListFallback", "a full-height list estimate cannot erase a narrow HUD")
	end)
	check(function()
		local input = request(390, 300, true)
		input.PlayerListEnabled = true
		input.ChatBounds = { { Left = 0, Right = 195, Bottom = 150 } }
		local value = Geometry.measure(input)
		safe(value, input); avoids(value, input.ChatBounds[1])
		assert(value.EffectiveExpanded and value.Top >= 162 and value.Header == 44)
		assert(value.Height >= 96 and value.BodyHeight >= 44)
	end)
	check(function()
		local input = request(390, 200, false)
		local value = Geometry.measure(input)
		safe(value, input)
		assert(value.NeedsPortraitScroll and value.PortraitCanvasHeight == 160)
		assert(value.PortraitHeight < value.PortraitCanvasHeight and value.Header == 44)
	end)
	check(function()
		local input = request(170, 300, true)
		local value = Geometry.measure(input)
		safe(value, input)
		assert(not value.EffectiveExpanded and value.Width == 88 and value.Height == 212)
		assert(string.find(value.Policy, "AutoCompact", 1, true) ~= nil)
	end)
	check(function()
		local input = request(390, 300, true)
		input.PlayerListEnabled = true
		input.ChatBounds = { { Left = 0, Right = 195, Bottom = 240 } }
		local value = Geometry.measure(input)
		safe(value, input); avoids(value, input.ChatBounds[1])
		assert(value.EffectiveExpanded and value.Width >= 166 and value.Left >= 207,
			"a usable narrow column must still allow the HUD to expand beside chat")
		assert((value.Width - 16) / 3 - 3 >= 44 and value.BodyHeight >= 44,
			"narrow expansion keeps each three-way result action at a usable touch width")
	end)
	check(function()
		local input = request(390, 300, false)
		input.ChatBounds = { { Left = 0, Right = 390, Bottom = 300 } }
		local value = Geometry.measure(input)
		safe(value, input)
		assert(value.Policy == "ChatSpaceFallback" and value.Height > 0,
			"an impossible full-screen obstacle must report its fallback instead of returning an invisible HUD")
	end)
	check(function()
		local input = request(0, 0, true)
		local value = Geometry.measure(input)
		safe(value, input)
		assert(value.Width == 0 and value.Height == 0 and value.Header == 0)
		local preference = Geometry.normalize(input, 300, 420, math.huge, 0 / 0)
		assert(preference.X == 0 and preference.Y == 0, "initial zero viewport must not persist NaN positions")
	end)
	check(function()
		for _, width in { 188, 240, 300 } do
			local card = Geometry.finderCard(width)
			assert(card.Height == 68 and card.ButtonWidth >= 44 and card.ButtonHeight >= 44)
			assert(card.ButtonLeft + card.ButtonWidth <= width - 8)
			assert(card.StatusLeft + card.StatusWidth < card.ButtonLeft, "Join belongs to the right of the status")
			assert(card.ButtonTop + card.ButtonHeight / 2 == card.StatusTop + card.StatusHeight / 2,
				"Join must align with the recruiting status row")
			assert(card.ButtonTop + card.ButtonHeight <= card.Height)
			assert(card.InfoWidth >= 100 and card.HostWidth > 0, "narrow card keeps an ellipsized host line and visible status")
			assert(card.CountWidth == 24 and card.HostNameWidth > 0)
			assert(card.CountLeft + card.CountWidth < card.StatusLeft and card.CountTop == card.HostTop)
		end
		local compactCard = Geometry.finderCard(150)
		assert(compactCard.CountWidth == 24 and compactCard.HostNameWidth > 0 and compactCard.StatusWidth >= 44,
			"the narrow expanded column must preserve count and recruiting status before truncating the host")
	end)
	check(function()
		local input = request(390, 700, false)
		input.ChatBounds = { { Left = 0, Right = 195, Bottom = 220 }, { Left = 0, Right = 195, Top = 220, Bottom = 270 } }
		local value = Geometry.placement(input, 88, 212, { X = 0, Y = 0 })
		safe(value, input)
		for _, bounds in input.ChatBounds do avoids(value, bounds) end
		assert(value.Left >= 207, "a drag preference inside chat must resolve to a usable clear slot")
	end)
	check(function()
		local input = request(1024, 700, true)
		input.PlayerListEnabled = true
		input.ChatBounds = { { Left = 0, Right = 400, Bottom = 220 } }
		local value = Geometry.measure(input)
		safe(value, input); avoids(value, input.ChatBounds[1])
		assert(value.Left + value.Width <= 680 and value.Top >= 232)
		assert(value.EffectiveExpanded and value.BodyHeight >= 44)
	end)
	check(function()
		for _, count in { 2, 3 } do
			local row = Geometry.actionRow(150, count)
			assert(row.Stacked and row.ButtonWidth == 150 and row.ButtonHeight == 44,
				"narrow Ready/Invite/result labels need a full-width touch target")
			assert(row.Height >= count * 44 and row.Gap >= 4)
		end
	end)
	check(function()
		for _, count in { 2, 3 } do
			local row = Geometry.actionRow(284, count)
			assert(not row.Stacked and row.Height == 44 and row.ButtonWidth >= 88,
				"wide panels should preserve compact side-by-side actions")
		end
	end)
	return passed
end
