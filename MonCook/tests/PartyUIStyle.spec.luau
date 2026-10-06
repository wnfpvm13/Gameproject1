--!strict
local Style = require(script.Parent.Parent.src.shared.Config.PartyUIStyle)

local function brightness(color: { number }): number
	return color[1] * 0.2126 + color[2] * 0.7152 + color[3] * 0.0722
end

local function saturation(color: { number }): number
	return math.max(color[1], color[2], color[3]) - math.min(color[1], color[2], color[3])
end

return function(): number
	local passed = 0
	local function check(callback: () -> ()) callback(); passed += 1 end
	check(function()
		assert(Style.buttonState(true, false, false) == "Normal")
		assert(Style.buttonState(true, true, false) == "Hover")
		assert(Style.buttonState(true, false, true) == "Pressed")
		assert(Style.buttonState(true, true, true) == "Pressed", "press must remain distinct from hover")
	end)
	check(function()
		for _, hovered in { false, true } do
			for _, pressed in { false, true } do assert(Style.buttonState(false, hovered, pressed) == "Disabled") end
		end
	end)
	check(function()
		for _, variant in { "Accent", "Subtle" } do
			local normal, hover, pressed = Style.button(variant, "Normal"), Style.button(variant, "Hover"), Style.button(variant, "Pressed")
			assert(brightness(hover.Color) > brightness(normal.Color), "hover must visibly lighten every button variant")
			assert(brightness(pressed.Color) < brightness(normal.Color), "press must visibly darken every button variant")
		end
	end)
	check(function()
		for _, variant in { "Accent", "Subtle" } do
			local normal, disabled = Style.button(variant, "Normal"), Style.button(variant, "Disabled")
			assert(saturation(disabled.Color) < saturation(normal.Color))
			assert(disabled.Transparency > normal.Transparency and disabled.TextTransparency > normal.TextTransparency)
		end
	end)
	check(function()
		for _, surface in Style.Theme.Surface do
			assert(surface.Transparency > 0 and surface.Transparency < 1, "game must remain visible through party surfaces")
			assert(surface.Color[1] > 0 and surface.Color[2] > 0 and surface.Color[3] > 0, "no solid black surfaces")
			assert(surface.Color[1] >= surface.Color[2] and surface.Color[2] >= surface.Color[3], "surfaces stay in the warm palette")
		end
		assert(brightness(Style.Theme.Surface.Panel.Color) < 100, "party HUD must remain darker than ordinary cream UI")
		assert(brightness(Style.Theme.Text.Primary) > brightness(Style.Theme.Surface.Panel.Color) + 150)
	end)
	check(function()
		for _, variant in { "Accent", "Subtle" } do
			for _, state in { "Normal", "Hover", "Pressed", "Disabled" } do
				local visual = Style.button(variant, state)
				assert(visual.Transparency >= 0 and visual.Transparency <= 1 and visual.TextTransparency >= 0 and visual.TextTransparency <= 1)
				for _, color in { visual.Color, visual.TextColor } do
					assert(#color == 3)
					for _, channel in color do assert(channel >= 0 and channel <= 255) end
				end
			end
		end
	end)
	check(function()
		assert(Style.button(nil, "Normal") == Style.button("Accent", "Normal"))
		assert(Style.button("Unknown", "Normal") == Style.button("Accent", "Normal"))
		assert(Style.button("Subtle", "Unknown") == Style.button("Subtle", "Normal"))
	end)
	check(function()
		local visual = Style.button("Accent", "Normal")
		assert(table.isfrozen(Style) and table.isfrozen(Style.Theme) and table.isfrozen(Style.Theme.Surface))
		assert(table.isfrozen(visual) and table.isfrozen(visual.Color) and table.isfrozen(Style.Theme.Text.Primary))
		local ok = pcall(function() visual.Color[1] = 0 end)
		assert(not ok, "a local button must not mutate the shared theme")
	end)
	check(function()
		assert(Style.Theme.Motion.ButtonSeconds > 0 and Style.Theme.Motion.ButtonSeconds <= 0.12, "input feedback must remain short")
	end)
	return passed
end
