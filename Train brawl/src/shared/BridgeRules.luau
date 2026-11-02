--!strict
-- Low bridges passing over the running trains (decision 24), as pure rules. A bridge is seen coming from far ahead
-- (the scenery runs backward, +Z, at the run's speed while the trains stand still), its beam's underside low enough
-- that only the low tops - a coal tender, a flatcar's deck - pass under it. Whoever stands taller than that as the beam
-- goes over is swept off the train. A pass is known by when its beam reaches the front of the trains (`arriveAt`,
-- server time), where that is (`frontZ`) and how fast it comes (`speed`). Requires nothing.

local BridgeRules = {}

export type Pass = { arriveAt: number, frontZ: number, speed: number }
-- A walkable top as ArenaLayout has it (ArenaLayout.Surface; written out here, as this requires nothing).
export type Top = { train: number, car: number, kind: string, x: number, z: number, width: number, length: number, top: number, plank: boolean }

-- The seconds into a fight bridges come at: `firstAfter`, then every `every`, while under `maxSeconds`.
function BridgeRules.times(firstAfter: number, every: number, maxSeconds: number): { number }
	local list = {}
	local at = firstAfter
	while at < maxSeconds and #list < 100 do
		table.insert(list, at)
		at += every
	end
	return list
end

-- Where along the track (Z) the middle of the pass's beam is at server time `now` (ahead of the trains before it
-- arrives: smaller Z).
function BridgeRules.beamZ(pass: Pass, now: number): number
	return pass.frontZ + pass.speed * (now - pass.arriveAt)
end

-- Whether a fighter at `z` is under a beam `depth` long whose middle is at `beamZ` (`slack` more each way: a frame's
-- travel, the body's own thickness).
function BridgeRules.under(beamZ: number, z: number, depth: number, slack: number): boolean
	return math.abs(z - beamZ) <= depth / 2 + slack
end

-- Whether a fighter whose feet are at `feetY`, `stature` tall, reaches the beam's underside at `clearance`.
function BridgeRules.tooTall(feetY: number, stature: number, clearance: number): boolean
	return feetY + stature > clearance
end

-- Whether someone standing on a top `height` high passes under.
function BridgeRules.safe(height: number, stature: number, clearance: number): boolean
	return not BridgeRules.tooTall(height, stature, clearance)
end

-- Whether the pass is over: its beam is past `backZ` (the back of the trains) by more than its own `depth`.
function BridgeRules.over(pass: Pass, now: number, backZ: number, depth: number): boolean
	return BridgeRules.beamZ(pass, now) > backZ + depth
end

-- The tops of train `train` someone can pass under on (low enough), in the order of `tops`.
function BridgeRules.safeTops(tops: { Top }, train: number, stature: number, clearance: number): { Top }
	local list = {}
	for _, top in tops do
		if top.train == train and BridgeRules.safe(top.top, stature, clearance) then
			table.insert(list, top)
		end
	end
	return list
end

-- Of `safe` (tops of one train), the one nearest along the track to `z`, and how far it is to its nearer end (0 when on
-- it). nil when there is none.
function BridgeRules.nearestSafe(safe: { Top }, z: number): (Top?, number)
	local best: Top? = nil
	local bestAway = math.huge
	for _, top in safe do
		local away = math.max(0, math.abs(z - top.z) - top.length / 2)
		if away < bestAway then
			best, bestAway = top, away
		end
	end
	return best, bestAway
end

return BridgeRules
