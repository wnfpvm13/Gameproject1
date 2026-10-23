--!strict
-- The paper gag after a bridge splat, as pure math: how thin the cowboy is drawn, and where the paper-flat cowboy flies
-- (stuck on the girder's face and carried back with it, then peeling off and fluttering down like a sheet of paper:
-- falling slowly, swaying side to side, rocking in its own plane with the sway and turning about the vertical so its
-- thin edge shows).
-- `t` is seconds since the splat; `p` is Config.Paper. Requires nothing.

local PaperPath = {}

export type Paper = {
	Thickness: number,
	InSeconds: number,
	StuckSeconds: number,
	FallSpeed: number,
	SwayStuds: number,
	SwaysPerSecond: number,
	Tilt: number,
	TurnsPerSecond: number,
	Drift: number,
	PopSeconds: number,
	PopThickness: number,
}

-- The cowboy's front-to-back thickness as a share of their own (1 = normal): flattened at once, paper-thin until
-- `splatSeconds` (when they are back on the train), then puffing up past their own thickness and settling ("뽀용").
function PaperPath.thickness(t: number, splatSeconds: number, p: Paper): number
	if t < 0 then
		return 1
	end
	if t < p.InSeconds then
		return 1 + (p.Thickness - 1) * (t / p.InSeconds)
	end
	if t < splatSeconds then
		return p.Thickness
	end
	local u = (t - splatSeconds) / p.PopSeconds
	if u >= 1 then
		return 1
	end
	local back = p.Thickness + (1 - p.Thickness) * math.min(1, u * 2)
	return back + (p.PopThickness - 1) * math.sin(math.pi * u)
end

-- Where the paper cowboy is `t` seconds after the splat, from the splat point in train space (+z = back, toward where
-- the bridge goes at `speed` studs per second), and how it is turned: yaw about the vertical, then a tilt in its own
-- plane (about its front-to-back axis after the yaw). Returns x, y, z, yaw, tilt.
function PaperPath.at(t: number, speed: number, p: Paper): (number, number, number, number, number)
	if t <= p.StuckSeconds then
		return 0, 0, speed * t, 0, 0 -- on the girder's face
	end
	local f = t - p.StuckSeconds
	local sway = math.sin(2 * math.pi * p.SwaysPerSecond * f)
	return p.SwayStuds * sway, -p.FallSpeed * f, speed * (p.StuckSeconds + p.Drift * f), 2 * math.pi * p.TurnsPerSecond * f, p.Tilt * sway
end

return PaperPath
