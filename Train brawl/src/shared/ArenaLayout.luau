--!strict
-- Where everything in the arena is, as pure math: each train's middle line, its cars' places along the track, the
-- planks between trains, the spawn spots and the height below which a player has fallen off. Train space and world
-- space share axes (the arena stands at the world origin, rails on Y = 0, -Z ahead). Requires nothing.

local ArenaLayout = {}

export type Car = { kind: string, length: number, roof: number }
export type CarPlace = { kind: string, front: number, back: number, middle: number, length: number, roof: number }
export type Plank = { x: number, z: number, top: number, length: number }
export type Spot = { x: number, y: number, z: number }

-- Train i's middle line (X), of `count` trains with roofs `roofWidth` wide and `gap` apart, centred on X = 0.
function ArenaLayout.trainX(i: number, count: number, roofWidth: number, gap: number): number
	return (i - (count + 1) / 2) * (roofWidth + gap)
end

-- The cars of a train, front (-Z) to back, `carGap` apart, the whole train centred on Z = 0.
function ArenaLayout.carPlaces(cars: { Car }, carGap: number): { CarPlace }
	local total = (#cars - 1) * carGap
	for _, car in cars do
		total += car.length
	end
	local places = {}
	local z = -total / 2
	for _, car in cars do
		table.insert(places, {
			kind = car.kind,
			front = z,
			back = z + car.length,
			middle = z + car.length / 2,
			length = car.length,
			roof = car.roof,
		})
		z += car.length + carGap
	end
	return places
end

-- The planks: one across each gap between neighbouring trains, in the middle of each car listed in `plankCars`.
function ArenaLayout.planks(places: { CarPlace }, plankCars: { number }, count: number, roofWidth: number, gap: number, overlap: number): { Plank }
	local planks = {}
	for i = 1, count - 1 do
		local x = (ArenaLayout.trainX(i, count, roofWidth, gap) + ArenaLayout.trainX(i + 1, count, roofWidth, gap)) / 2
		for _, index in plankCars do
			local place = places[index]
			if place then
				table.insert(planks, { x = x, z = place.middle, top = place.roof, length = gap + overlap * 2 })
			end
		end
	end
	return planks
end

-- Spawn spots on the roofs: `perCar` spread along each car of each train (a little in from the ends).
function ArenaLayout.spawnSpots(places: { CarPlace }, count: number, roofWidth: number, gap: number, perCar: number): { Spot }
	local spots = {}
	for i = 1, count do
		local x = ArenaLayout.trainX(i, count, roofWidth, gap)
		for _, place in places do
			for k = 1, perCar do
				local z = place.front + place.length * k / (perCar + 1)
				table.insert(spots, { x = x, y = place.roof, z = z })
			end
		end
	end
	return spots
end

-- Feet lower than this have fallen off the trains: `margin` under the lowest roof.
function ArenaLayout.fallLine(places: { CarPlace }, margin: number): number
	local lowest = math.huge
	for _, place in places do
		lowest = math.min(lowest, place.roof)
	end
	return lowest - margin
end

return ArenaLayout
