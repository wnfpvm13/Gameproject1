--!strict
-- Presentation-only theme. RGB data stays engine-independent for CLI validation.
export type RGB = { number }
export type Surface = { read Color: RGB, read Transparency: number }
export type ButtonVisual = { read Color: RGB, read Transparency: number, read TextColor: RGB, read TextTransparency: number }

local function rgb(red: number, green: number, blue: number): RGB
	return table.freeze({ red, green, blue })
end

local function surface(color: RGB, transparency: number): Surface
	local value: Surface = { Color = color, Transparency = transparency }
	table.freeze(value)
	return value
end

local text = table.freeze({
	Primary = rgb(250, 244, 233), Muted = rgb(218, 204, 184), Accent = rgb(239, 199, 124),
	Ready = rgb(177, 226, 180), Waiting = rgb(245, 211, 146), Stayed = rgb(216, 201, 184),
})

local PartyUIStyle = {}
local surfaces: { [string]: Surface } = {
	Panel = surface(rgb(61, 53, 48), 0.16),
	Card = surface(rgb(78, 68, 59), 0.24),
	Portrait = surface(rgb(110, 94, 71), 0.12),
	Badge = surface(rgb(60, 52, 46), 0.14),
	DragHandle = surface(rgb(158, 141, 111), 0.55),
}
table.freeze(surfaces)
PartyUIStyle.Theme = table.freeze({
	Surface = surfaces,
	Text = text,
	Scrollbar = rgb(173, 148, 109),
	Motion = table.freeze({ ButtonSeconds = 0.08 }),
})

local function button(color: RGB, transparency: number, textColor: RGB, textTransparency: number): ButtonVisual
	local value: ButtonVisual = { Color = color, Transparency = transparency, TextColor = textColor, TextTransparency = textTransparency }
	table.freeze(value)
	return value
end

local variants: { [string]: { [string]: ButtonVisual } } = {
	Accent = {
		Normal = button(rgb(148, 105, 55), 0.13, text.Primary, 0),
		Hover = button(rgb(170, 124, 67), 0.10, text.Primary, 0),
		Pressed = button(rgb(116, 82, 45), 0.06, text.Primary, 0),
		Disabled = button(rgb(105, 100, 93), 0.46, text.Muted, 0.25),
	},
	Subtle = {
		Normal = button(rgb(87, 76, 65), 0.60, text.Primary, 0),
		Hover = button(rgb(119, 103, 83), 0.38, text.Primary, 0),
		Pressed = button(rgb(66, 57, 49), 0.22, text.Primary, 0),
		Disabled = button(rgb(103, 99, 93), 0.70, text.Muted, 0.25),
	},
}
for _, palette in variants do table.freeze(palette) end
table.freeze(variants)

function PartyUIStyle.buttonState(enabled: boolean, hovered: boolean, pressed: boolean): string
	if not enabled then return "Disabled" end
	if pressed then return "Pressed" end
	if hovered then return "Hover" end
	return "Normal"
end

function PartyUIStyle.button(variant: string?, state: string): ButtonVisual
	local palette = variants[variant or "Accent"] or variants.Accent
	return palette[state] or palette.Normal
end

return table.freeze(PartyUIStyle)
