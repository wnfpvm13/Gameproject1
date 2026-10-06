--!strict
local Geometry = require(script.Parent.Parent.src.shared.Utilities.PartyHUDGeometry)

local function request(width: number, height: number): any
	return { Width = width, Height = height, Expanded = true, MemberCount = 4,
		TopbarBottom = 0, PlayerListEnabled = false, PlayerCount = 20, ChatBounds = {} }
end

local function safe(value: any, input: any)
	assert(value.Left >= 0 and value.Top >= 0)
	assert(value.Left + value.Width <= input.Width and value.Top + value.Height <= input.Height)
	for _, field in { "Left", "Top", "Width", "Height" } do
		assert(value[field] == value[field] and math.abs(value[field]) ~= math.huge)
	end
end

return function(): number
	local passed = 0
	local function check(callback: () -> ()) callback(); passed += 1 end
	check(function()
		local input = request(1200, 800)
		input.ChatBounds = { { Left = 0, Right = 400, Bottom = 500 } }
		local preference = Geometry.normalize(input, 300, 420, 80, 60)
		local manual = Geometry.dragPlacement(input, 300, 420, preference)
		safe(manual, input)
		assert(math.abs(manual.Left - 80) < 0.00001 and math.abs(manual.Top - 60) < 0.00001)
		assert(manual.Left + manual.Width <= 400 and manual.Top + manual.Height <= 500,
			"manual positioning must allow the whole HUD inside Chat")
		local automatic = Geometry.placement(input, 300, 420, preference)
		assert(automatic.Left >= 400 or automatic.Top >= 500,
			"the same preference must still avoid Chat during automatic placement")
	end)
	check(function()
		local input = request(1024, 700)
		input.PlayerListEnabled = true
		local preference = Geometry.normalize(input, 300, 420, 700, 30)
		local manual = Geometry.dragPlacement(input, 300, 420, preference)
		safe(manual, input)
		assert(math.abs(manual.Left - 700) < 0.00001 and math.abs(manual.Top - 30) < 0.00001,
			"manual positioning must allow the desktop PlayerList column")
		local automatic = Geometry.placement(input, 300, 420, preference)
		assert(automatic.Left + automatic.Width <= 680)
	end)
	check(function()
		local input = request(390, 300)
		input.TopbarBottom = 30
		for _, preference in { { X = -100, Y = -100 }, { X = 100, Y = 100 } } do
			local value = Geometry.dragPlacement(input, 88, 212, preference)
			safe(value, input)
			assert(value.Left >= 12 and value.Top >= 42)
			assert(value.Left + value.Width <= 378 and value.Top + value.Height <= 288,
				"the entire panel and its controls must stay in the essential safe area")
		end
		local oversized = Geometry.dragPlacement(input, 500, 500, { X = 1, Y = 1 })
		safe(oversized, input)
		assert(oversized.Width == 366 and oversized.Height == 246)
	end)
	check(function()
		local input = request(1200, 800)
		input.Expanded = false
		local measured = Geometry.measure(input)
		local preference = Geometry.normalize(input, measured.Width, measured.Height, 80, 80)
		local manual = Geometry.dragPlacement(input, measured.Width, measured.Height, preference)
		local refreshed = table.clone(input)
		refreshed.PlayerListEnabled = true
		refreshed.ChatBounds = { { Left = 0, Right = 500, Bottom = 600 } }
		assert(not Geometry.viewportChanged(input, refreshed))
		for _ = 1, 3 do
			local size = Geometry.measure(refreshed)
			local value = Geometry.dragPlacement(refreshed, size.Width, size.Height, manual.Position)
			assert(math.abs(value.Left - manual.Left) < 0.00001 and math.abs(value.Top - manual.Top) < 0.00001,
				"release and ordinary refreshes must not reapply CoreUI obstacles to a manual position")
		end
	end)
	check(function()
		local original = request(1200, 800)
		local preference = Geometry.normalize(original, 300, 420, 80, 60)
		local resized = request(390, 300)
		resized.TopbarBottom = 30
		resized.ChatBounds = { { Left = 0, Right = 195, Bottom = 150 } }
		resized.PlayerListEnabled, resized.Position = true, preference
		assert(Geometry.viewportChanged(original, resized))
		local automatic = Geometry.measure(resized)
		safe(automatic, resized)
		assert(automatic.Top >= 162 and automatic.Header == 44 and automatic.BodyHeight >= 44,
			"resize must restore an accessible automatic placement outside Chat")
	end)
	check(function()
		local original = request(1024, 700)
		local changed = table.clone(original)
		changed.TopbarBottom = 30
		assert(Geometry.viewportChanged(original, changed), "essential safe-area changes restore automatic placement")
		assert(not Geometry.viewportChanged(nil, original))
		assert(not Geometry.viewportChanged(original, table.clone(original)))
	end)
	check(function()
		local input = request(0, 0)
		local value = Geometry.dragPlacement(input, 300, 420, { X = math.huge, Y = 0 / 0 })
		safe(value, input)
		assert(value.Width == 0 and value.Height == 0 and value.Policy == "ManualSafeArea")
	end)
	return passed
end
