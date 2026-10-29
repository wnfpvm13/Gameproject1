--!strict
-- Where everything in the arena is, as pure math, from Config.Arena: each train's middle line and its cars' places
-- along the track (every train has its own cars and stands a little ahead of or behind the others, so different cars
-- face each other), the surfaces people stand on (roofs, a locomotive's boiler and chimney top, a flatcar's deck and
-- crates, a caboose's lookout), the planks between trains (only where two flat tops of the same height face each other wide
-- enough), the spawn spots, the height below which a fighter has fallen off, and how far a jump carries. Train space
-- and world space share axes (the arena at the world origin, rails on Y = 0, -Z ahead). Requires nothing.

local ArenaLayout = {}

-- A box standing on a car's deck or roof: its middle at `along` (share of the car's length from the front).
export type Box = { along: number, width: number, length: number, height: number }
-- A kind of car (Config.Arena.CarKinds). roof: the main walkable top; roofFrom: it starts this share along the car
-- (a locomotive's flat cab roof is only its back part); boiler: a round boiler over the front share `to`, its top at
-- `top`; stack: a solid chimney on the boiler, `width` round with its middle `along` the car, its flat top `height`
-- over the boiler's; spawns: spawn spots, as shares along the car; plank: planks may rest on its main top.
export type Kind = {
	length: number,
	roof: number,
	roofFrom: number?,
	spawns: { number },
	plank: boolean,
	boiler: { to: number, top: number, width: number }?,
	stack: { along: number, width: number, height: number }?,
	crates: { Box }?,
	cupola: { from: number, to: number, width: number, height: number }?,
}
export type TrainSpec = { shift: number, cars: { string } }
export type Spec = {
	Gap: number,
	RoofWidth: number,
	CarGap: number,
	CarKinds: { [string]: Kind },
	Trains: { TrainSpec },
	PlankWidth: number,
	PlankOverlap: number,
	PlankEdge: number,
	PlanksPerGap: number,
	PlankSpacing: number,
}

-- car: its number along its train (1 = the locomotive in front).
export type CarPlace = { kind: string, train: number, car: number, front: number, back: number, middle: number, length: number, roof: number }
-- A walkable top: its train and car, its middle (x, z), size across (width) and along the track (length), and height.
export type Surface = { train: number, car: number, kind: string, x: number, z: number, width: number, length: number, top: number, plank: boolean }
export type Plank = { x: number, z: number, top: number, length: number }
export type Spot = { x: number, y: number, z: number, train: number, car: number? }
export type Train = { x: number, cars: { CarPlace } }
export type Layout = { trains: { Train }, surfaces: { Surface }, planks: { Plank }, spots: { Spot }, fallLine: number, outerEdge: number }

-- Train i's middle line (X), of `count` trains with roofs `roofWidth` wide and `gap` apart, centred on X = 0.
function ArenaLayout.trainX(i: number, count: number, roofWidth: number, gap: number): number
	return (i - (count + 1) / 2) * (roofWidth + gap)
end

-- A train's cars, front (-Z) to back, `carGap` apart: the whole train centred on Z = `shift`.
function ArenaLayout.carPlaces(cars: { string }, kinds: { [string]: Kind }, carGap: number, shift: number, train: number): { CarPlace }
	local total = (#cars - 1) * carGap
	for _, name in cars do
		assert(kinds[name], "[TrainBrawl] no car kind named " .. name .. " in Config.Arena.CarKinds")
		total += kinds[name].length
	end
	local places = {}
	local z = shift - total / 2
	for k, name in cars do
		local kind = kinds[name]
		table.insert(places, {
			kind = name,
			train = train,
			car = k,
			front = z,
			back = z + kind.length,
			middle = z + kind.length / 2,
			length = kind.length,
			roof = kind.roof,
		})
		z += kind.length + carGap
	end
	return places
end

-- The walkable tops of one car standing on line x.
local function carSurfaces(place: CarPlace, kind: Kind, x: number, roofWidth: number): { Surface }
	local list = {}
	local from = place.front + place.length * (kind.roofFrom or 0)
	table.insert(list, {
		train = place.train,
		car = place.car,
		kind = place.kind,
		x = x,
		z = (from + place.back) / 2,
		width = roofWidth,
		length = place.back - from,
		top = place.roof,
		plank = kind.plank,
	})
	local boiler = kind.boiler
	if boiler then
		local to = place.front + place.length * boiler.to
		table.insert(list, { train = place.train, car = place.car, kind = place.kind, x = x, z = (place.front + to) / 2, width = boiler.width, length = to - place.front, top = boiler.top, plank = false })
		local stack = kind.stack
		if stack then
			-- Round, taken as the square around it (like the boiler).
			local z = place.front + place.length * stack.along
			table.insert(list, { train = place.train, car = place.car, kind = place.kind, x = x, z = z, width = stack.width, length = stack.width, top = boiler.top + stack.height, plank = false })
		end
	end
	local crates: { Box } = kind.crates or {}
	for _, crate in crates do
		table.insert(list, {
			train = place.train,
			car = place.car,
			kind = place.kind,
			x = x,
			z = place.front + place.length * crate.along,
			width = crate.width,
			length = crate.length,
			top = place.roof + crate.height,
			plank = false,
		})
	end
	local cupola = kind.cupola
	if cupola then
		local a, b = place.front + place.length * cupola.from, place.front + place.length * cupola.to
		table.insert(list, { train = place.train, car = place.car, kind = place.kind, x = x, z = (a + b) / 2, width = cupola.width, length = b - a, top = place.roof + cupola.height, plank = false })
	end
	return list
end

-- The planks across the gap between trains `left` and `right`: where two plank tops of the same height face each
-- other along at least a plank's width (keeping PlankEdge from their ends). The widest goes first; each next one is
-- the one farthest from those already laid (spread along the trains), at least PlankSpacing away, up to PlanksPerGap.
local function gapPlanks(spec: Spec, surfaces: { Surface }, left: number, right: number, x: number): { Plank }
	local candidates = {}
	for _, a in surfaces do
		if a.train == left and a.plank then
			for _, b in surfaces do
				if b.train == right and b.plank and math.abs(a.top - b.top) < 1e-6 then
					local lo = math.max(a.z - a.length / 2, b.z - b.length / 2) + spec.PlankEdge
					local hi = math.min(a.z + a.length / 2, b.z + b.length / 2) - spec.PlankEdge
					if hi - lo >= spec.PlankWidth then
						table.insert(candidates, { z = (lo + hi) / 2, size = hi - lo, top = a.top })
					end
				end
			end
		end
	end
	table.sort(candidates, function(p, q)
		return if p.size ~= q.size then p.size > q.size else p.z < q.z
	end)
	local chosen: { Plank } = {}
	local used: { [number]: boolean } = {}
	while #chosen < spec.PlanksPerGap do
		local best, bestAway, bestIndex = nil, -1, 0
		for index, candidate in candidates do
			if used[index] then
				continue
			end
			local away = math.huge
			for _, plank in chosen do
				away = math.min(away, math.abs(plank.z - candidate.z))
			end
			if away >= spec.PlankSpacing and away > bestAway then
				best, bestAway, bestIndex = candidate, away, index
			end
		end
		if not best then
			break
		end
		used[bestIndex] = true
		table.insert(chosen, { x = x, z = best.z, top = best.top, length = spec.Gap + spec.PlankOverlap * 2 })
	end
	return chosen
end

-- The whole arena from `spec` (Config.Arena); feet `fallMargin` under the lowest walkable top have fallen off.
function ArenaLayout.layout(spec: Spec, fallMargin: number): Layout
	local count = #spec.Trains
	local trains: { Train } = {}
	local surfaces: { Surface } = {}
	local spots: { Spot } = {}
	for i, train in spec.Trains do
		local x = ArenaLayout.trainX(i, count, spec.RoofWidth, spec.Gap)
		local cars = ArenaLayout.carPlaces(train.cars, spec.CarKinds, spec.CarGap, train.shift, i)
		table.insert(trains, { x = x, cars = cars })
		for _, place in cars do
			local kind = spec.CarKinds[place.kind]
			for _, surface in carSurfaces(place, kind, x, spec.RoofWidth) do
				table.insert(surfaces, surface)
			end
			for _, share in kind.spawns do
				table.insert(spots, { x = x, y = place.roof, z = place.front + place.length * share, train = i, car = place.car })
			end
		end
	end
	local planks: { Plank } = {}
	for i = 1, count - 1 do
		local x = (trains[i].x + trains[i + 1].x) / 2
		for _, plank in gapPlanks(spec, surfaces, i, i + 1, x) do
			table.insert(planks, plank)
		end
	end
	local lowest = math.huge
	for _, surface in surfaces do
		lowest = math.min(lowest, surface.top)
	end
	local outer = 0
	for _, train in trains do
		outer = math.max(outer, math.abs(train.x) + spec.RoofWidth / 2)
	end
	return { trains = trains, surfaces = surfaces, planks = planks, spots = spots, fallLine = lowest - fallMargin, outerEdge = outer }
end

-- The spawn spots of `trains` trains in the order to hand them out: the middle train's (or two) first, then the trains
-- next to them, outward, so a few players meet in the middle and more spread out. `shuffle` mixes each train's own
-- spots and which of two equally far trains goes first; equally far trains then take turns.
function ArenaLayout.preferMiddle(spots: { Spot }, trains: number, shuffle: <T>({ T }) -> { T }): { Spot }
	local middle = (trains + 1) / 2
	local byTrain: { [number]: { Spot } } = {}
	for _, spot in spots do
		byTrain[spot.train] = byTrain[spot.train] or {}
		table.insert(byTrain[spot.train], spot)
	end
	-- Trains grouped by how far they are from the middle (twice the distance, a whole number).
	local groups: { [number]: { number } } = {}
	local farthest = 0
	for i = 1, trains do
		local away = math.round(math.abs(i - middle) * 2)
		groups[away] = groups[away] or {}
		table.insert(groups[away], i)
		farthest = math.max(farthest, away)
	end
	local list = {}
	for away = 0, farthest do
		local queues = {}
		for _, i in shuffle(groups[away] or {}) do
			table.insert(queues, shuffle(byTrain[i] or {}))
		end
		local k = 1
		local added = true
		while added do
			added = false
			for _, queue in queues do
				if queue[k] then
					table.insert(list, queue[k])
					added = true
				end
			end
			k += 1
		end
	end
	return list
end

-- The planks (their numbers in `layout.planks`) resting on car `car` of train `train`: beside that train, within the
-- car's length (a car that leaves the train takes them along).
function ArenaLayout.planksOn(layout: Layout, train: number, car: number): { number }
	local line = layout.trains[train]
	local place = line and line.cars[car]
	local list = {}
	if not place then
		return list
	end
	for n, plank in layout.planks do
		-- (Planks only lie between neighbouring trains: one that reaches this train's line lies beside it.)
		if math.abs(plank.x - line.x) < plank.length and plank.z >= place.front and plank.z <= place.back then
			table.insert(list, n)
		end
	end
	return list
end

-- The spawn spot farthest from everyone in `others` (flat positions: the fighters on the trains), where someone coming
-- back lands (decision 11's "safe car"): the one whose nearest other is farthest away, the first of equally far ones
-- (the caller shuffles for variety), the first spot when nobody else is there. Nil for no spots.
function ArenaLayout.clearest(spots: { Spot }, others: { { x: number, z: number } }): Spot?
	local best: Spot? = nil
	local bestRoom = -1
	for _, spot in spots do
		local room = math.huge
		for _, other in others do
			room = math.min(room, math.sqrt((spot.x - other.x) ^ 2 + (spot.z - other.z) ^ 2))
		end
		if room > bestRoom then
			best, bestRoom = spot, room
		end
	end
	return best
end

-- The top someone with feet at height `feet` over (x, z) stands on: the highest of `surfaces` there that is not above
-- the feet (a little slack for standing on it), nil over a gap, a plank or the sand.
function ArenaLayout.topUnder(surfaces: { Surface }, x: number, z: number, feet: number): Surface?
	local best: Surface? = nil
	for _, surface in surfaces do
		local inside = math.abs(x - surface.x) <= surface.width / 2 and math.abs(z - surface.z) <= surface.length / 2
		if inside and surface.top <= feet + 0.5 and (not best or surface.top > best.top) then
			best = surface
		end
	end
	return best
end

-- How far a running jump carries along the ground when it lands `drop` lower than it started (Roblox's character
-- jump: up to `jumpHeight` at `walkSpeed`, under `gravity`). The plain flight only: a real jump crosses about 4 more
-- (it can start past the edge and catch the far edge; measured, tests' JUMP_EXTRA).
function ArenaLayout.jumpReach(walkSpeed: number, jumpHeight: number, gravity: number, drop: number): number
	local up = math.sqrt(2 * jumpHeight / gravity)
	local down = math.sqrt(2 * (jumpHeight + drop) / gravity)
	return walkSpeed * (up + down)
end

return ArenaLayout
