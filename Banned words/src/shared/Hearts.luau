--!strict
-- Lives as a row of hearts for RichText labels: the lives left in red, the lost ones in grey (the HUD and the head
-- bubbles show them the same way).
local Hearts = {}

local GLYPH = "♥"
local FULL = "#FF4D6D"
local LOST = "#7E8490" -- (dark enough on the HUD's paper, owner 2026-10-25 sticker look)

function Hearts.text(lives: number, max: number): string
	local full = math.clamp(lives, 0, max)
	local parts = {}
	if full > 0 then
		table.insert(parts, string.format('<font color="%s">%s</font>', FULL, string.rep(GLYPH, full)))
	end
	if max > full then
		table.insert(parts, string.format('<font color="%s">%s</font>', LOST, string.rep(GLYPH, max - full)))
	end
	return table.concat(parts)
end

return Hearts
