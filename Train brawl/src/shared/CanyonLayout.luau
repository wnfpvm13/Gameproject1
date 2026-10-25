--!strict
-- Where the canyon's pieces are (Config.Canyon), as pure math, so the clients draw it (Canyon) and the tests check the
-- very pieces drawn: stretch after stretch of wall along each side of the arena, each in stepped layers of colour with
-- a rubble slope at its foot, one or two ribs of rock out of its face and now and then a rock spire in front. A fixed
-- scatter instead of random numbers, so every client draws the same canyon. Also how far the sand under it must reach
-- (the server builds it, ArenaBuilder). World axes: Y up, -Z ahead, the arena's middle line on X = 0. Requires nothing.

local CanyonLayout = {}

export type Spec = {
	Inner: number,
	InnerVary: number,
	Depth: number,
	TalusWidth: number,
	RibOut: number,
	SpireOut: number,
	Ahead: number,
	Behind: number,
	SegmentMin: number,
	SegmentMax: number,
	HeightMin: number,
	HeightMax: number,
	Colors: { Color3 },
}
-- A piece: its middle (x, y, z), its size across the track (width), up (height) and along it (length), and its turn
-- about the vertical (yaw). A wedge is the rubble slope: high against the wall (its own +Z turned toward the wall
-- on `side`), drawn with size (length, height, width). color: an index into Spec.Colors. anchor: the middle of the
-- piece's stretch; a stretch wraps around as one (ScrollLoop).
export type Piece = {
	kind: string,
	x: number,
	y: number,
	z: number,
	width: number,
	height: number,
	length: number,
	yaw: number,
	wedge: boolean,
	side: number,
	color: number,
	anchor: number,
}

-- The layers of a wall, from the foot up: where each starts and ends (shares of the wall's height) and how far its
-- face steps back from the inner face (recess, plus up to `grow` more).
local LAYERS = {
	{ from = 0, to = 0.45, recess = 0, grow = 0 },
	{ from = 0.45, to = 0.72, recess = 2, grow = 4 },
	{ from = 0.72, to = 0.9, recess = 6, grow = 5 },
	{ from = 0.9, to = 1, recess = 10, grow = 6 },
}
local RIB_TOP = 0.85 -- a rib reaches at most this share of its wall's height (below the top layer)
local RIB_BACK = 12 -- and goes this far into the wall, past the deepest face it stands against (layer 3: 6 + 5)
-- A spire's three chunks, from the foot up: share of its height, of its thickness; each is 0.9 as deep as wide.
local CHUNKS = { { share = 0.45, width = 1 }, { share = 0.35, width = 0.72 }, { share = 0.2, width = 0.5 } }
local SPIRE_DEPTH = 0.9
-- A turned chunk reaches at most 0.5 * sqrt(1 + 0.9²) = 0.673 of its thickness across; its middle stands this far back.
local SPIRE_BACK = 0.7

-- A fixed scatter in [0, 1) for stretch k (salt picks a different one per use).
local function scatter(k: number, salt: number): number
	return (math.sin(k * 12.9898 + salt * 78.233) * 43758.5453) % 1
end

-- Every piece of the canyon, both sides, from `spec.Ahead` in front of the middle to `spec.Behind` behind it, on
-- ground at height groundY.
function CanyonLayout.pieces(spec: Spec, groundY: number): { Piece }
	local list: { Piece } = {}
	local function add(kind: string, x: number, y: number, z: number, size: { number }, yaw: number, color: number, anchor: number)
		table.insert(list, {
			kind = kind,
			x = x,
			y = y,
			z = z,
			width = size[1],
			height = size[2],
			length = size[3],
			yaw = yaw,
			wedge = false,
			side = if x > 0 then 1 else -1,
			color = (color - 1) % #spec.Colors + 1,
			anchor = anchor,
		})
	end
	for _, side in { -1, 1 } do
		local z = -spec.Ahead
		local k = if side == 1 then 0 else 100 -- the two sides differ
		while z < spec.Behind do
			k += 1
			local length = math.min(spec.SegmentMin + scatter(k, 1) * (spec.SegmentMax - spec.SegmentMin), spec.Behind - z)
			local inner = spec.Inner + scatter(k, 2) * spec.InnerVary
			local height = spec.HeightMin + scatter(k, 3) * (spec.HeightMax - spec.HeightMin)
			local middle = z + length / 2
			for n, layer in LAYERS do
				local face = inner + layer.recess + layer.grow * scatter(k, 4 + n)
				local width = inner + spec.Depth - face
				local bottom, top = groundY + height * layer.from, groundY + height * layer.to
				-- A hair longer than the stretch, so neighbouring stretches show no seam.
				add("Wall", side * (face + width / 2), (bottom + top) / 2, middle, { width, top - bottom, length + 0.1 }, 0, n, middle)
			end
			-- One or two ribs of rock standing out of the face, so a stretch is not one flat slab.
			for n = 1, 1 + math.floor(scatter(k, 15) * 2) do
				local ribHeight = height * (0.5 + scatter(k, 15 + n) * (RIB_TOP - 0.5))
				local ribLength = 6 + scatter(k, 17 + n) * 6
				local out = spec.RibOut * (0.5 + scatter(k, 19 + n) * 0.5)
				local ribZ = z + length * (n - 0.5) / 2 + (scatter(k, 21 + n) - 0.5) * length * 0.3
				add("Rib", side * (inner + (RIB_BACK - out) / 2), groundY + ribHeight / 2, ribZ, { out + RIB_BACK, ribHeight, ribLength }, 0, (n % 2) + 1, middle)
			end
			-- The rubble slope at the foot.
			local talusHeight = 8 + scatter(k, 9) * 6
			table.insert(list, {
				kind = "Talus",
				x = side * (inner - spec.TalusWidth / 2),
				y = groundY + talusHeight / 2,
				z = middle,
				width = spec.TalusWidth,
				height = talusHeight,
				length = length + 0.1,
				yaw = 0,
				wedge = true,
				side = side,
				color = 1,
				anchor = middle,
			})
			-- Now and then a rock spire in front of the wall: three chunks, narrower going up, each turned a little,
			-- its middle far enough back that even turned its nearest corner stays behind SpireOut.
			if scatter(k, 10) > 0.62 then
				local spireHeight = 22 + scatter(k, 11) * 20
				local thick = 9 + scatter(k, 12) * 4
				local x = side * (inner - spec.SpireOut + thick * SPIRE_BACK + scatter(k, 13) * 3)
				local spireZ = middle + (scatter(k, 14) - 0.5) * length * 0.6
				local y = groundY
				for n, chunk in CHUNKS do
					local chunkHeight = spireHeight * chunk.share
					local width = thick * chunk.width
					add("Spire", x, y + chunkHeight / 2, spireZ, { width, chunkHeight, width * SPIRE_DEPTH }, k + n * 0.5, n + 1, middle)
					y += chunkHeight
				end
			end
			z += length
		end
	end
	return list
end

-- Half of how far a piece spans across the track (a turned piece by its corners).
local function across(piece: Piece): number
	return if piece.wedge
		then piece.width / 2
		else math.abs(piece.width / 2 * math.cos(piece.yaw)) + math.abs(piece.length / 2 * math.sin(piece.yaw))
end

-- How near the middle line a piece comes (its nearest face or corner) and how far out it goes.
function CanyonLayout.span(piece: Piece): (number, number)
	return math.abs(piece.x) - across(piece), math.abs(piece.x) + across(piece)
end

-- How far along the track a piece reaches past its stretch's middle (the wrap moves a stretch when its middle passes
-- the loop's end, so this is how far a piece can stick out past the loop).
function CanyonLayout.overhang(piece: Piece): number
	local along = if piece.wedge
		then piece.length / 2
		else math.abs(piece.length / 2 * math.cos(piece.yaw)) + math.abs(piece.width / 2 * math.sin(piece.yaw))
	return math.abs(piece.z - piece.anchor) + along
end

-- The sand under the whole canyon: half its width across the track, and how far it reaches ahead (-Z) and behind,
-- with room for a stretch sticking out past either end of the loop (a stretch is at most SegmentMax long).
function CanyonLayout.ground(spec: Spec): (number, number, number)
	return spec.Inner + spec.InnerVary + spec.Depth + 20, spec.Ahead + spec.SegmentMax, spec.Behind + spec.SegmentMax
end

return CanyonLayout
