--!strict
-- 물병 세우기's power bar (bundle 8b): where the marker is, 0 = left end, 1 = right end, `t` seconds after the bar
-- started: there and back once every `period` seconds. The server judges with it and every screen draws with it.
local PowerBar = {}

function PowerBar.at(t: number, period: number): number
	local phase = (math.max(0, t) / period) % 1
	return if phase < 0.5 then phase * 2 else (1 - phase) * 2
end

return PowerBar
