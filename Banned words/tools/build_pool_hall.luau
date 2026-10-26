-- Indoor pool hall for 금칙어 게임 Korean V3 (owner 2026-10-22: a big, bright indoor pool in daylight with white walls;
-- the old V1 outdoor pool is discarded; docs/DESIGN_V3.md §9-10). Run in Studio's Edit datamodel, then
-- tools/build_pool_lighting.luau.
-- Rebuilds workspace.PoolHall from scratch, removes the V2 LoungeMap and the V1 PoolMap and refills the pool with
-- terrain water. Plain materials only: the V2 studio-set MaterialVariants (quilted leather, dark carpet) read grey and
-- maroon in daylight.
-- Layout (studs, deck top at y = 0, +Z = toward the far end of the pool):
--   10 flying chairs (the 플라잉 체어 of the variety shows: a blue box with white cushions, owner pick 2026-10-22) in a
--   row on a red carpet at the near end (z = 7, 5 studs apart), backs to the pool, facing the show camera (z = -36).
--   The presenter's podium stands off to the camera's right (x = -24), angled at the row, so nothing sits between the
--   camera and the faces. A failed player is blown off the chair as a ragdoll by an explosion (owner 2026-10-24) and
--   comes down anywhere behind or beside the chairs (owner 2026-10-25: faster and in any direction; Landing, z 58-94,
--   is where the splash and a lost body go) while the chair's seat flap snaps back and eases down again. Spectator
--   stands along the +X side (the camera's left), windows along -X and the far end, a white roof (y 56) with
--   skylights and white trusses over the water (y 44). FlightGuard: thick invisible walls and a lid just outside the
--   shell, so a body thrown at ~200 studs/s cannot pass the thin glass.
-- Code reads (map contract, DESIGN_V3 §9): PoolHall (attribute CeilingY: kept for reference, no code reads it now;
-- since 2026-10-25 a fast throw may reach the roof), PoolHall.Chairs (Chair01..10, each a Model
-- with Base, an invisible Seat carrying SeatIndex 1..10 from the show camera's left (+X) to its right, Flap: the
-- visible cushion and backrest, welded to the anchored invisible Hinge on the box's back top edge; clients turn the
-- Hinge about its own X axis for a launch, the server never moves any of it; and Bell (bundle 6b): a desk bell on a
-- post at the seated player's right, PrimaryPart Button (clients put their prompt on it), Light (the dome, a PointLight
-- clients switch on when it rings)), Landing (attributes WaterY, PoolMargin), Podium, ShowCamera,
-- PresenterCamera, Stands, Lobby.

local CHAIR_COUNT = 10
local CHAIR_SPACING = 5
local CHAIR_Z = 7
local CARPET_TOP = 0.1
local POOL_HALF_X = 32
local POOL_NEAR_Z, POOL_FAR_Z = 16, 104
local POOL_FLOOR_Y = -12
local WATER_TOP_Y = -1
local HALL_HALF_X = 66
local HALL_NEAR_Z, HALL_FAR_Z = -48, 124
local ROOF_Y = 56
local TRUSS_Y = 44
local CEILING_Y = 40 -- highest point a flying player may reach (below the trusses)

local WHITE = Color3.fromRGB(246, 248, 250)
local WALL_WHITE = Color3.fromRGB(238, 241, 244)
local TILE_WHITE = Color3.fromRGB(226, 233, 238)
local STEEL_WHITE = Color3.fromRGB(222, 227, 233)
local DECK_TILE = Color3.fromRGB(220, 227, 231)
local DECK_EDGE = Color3.fromRGB(178, 188, 196)
local POOL_TILE = Color3.fromRGB(104, 192, 220)
local LANE_TILE = Color3.fromRGB(22, 62, 122)
local POOL_GLOW = Color3.fromRGB(160, 228, 242)
local CHAIR_BLUE = Color3.fromRGB(28, 112, 226)
local CHAIR_BLUE_DARK = Color3.fromRGB(18, 78, 168)
local CUSHION_WHITE = Color3.fromRGB(248, 248, 245)
local CARPET_RED = Color3.fromRGB(200, 40, 52)
local ACCENT_BLUE = Color3.fromRGB(40, 122, 222)
local CORAL_GLOW = Color3.fromRGB(240, 110, 140)
local SKY_GLASS = Color3.fromRGB(190, 222, 245)
local CHROME = Color3.fromRGB(196, 200, 208)
local METAL = Color3.fromRGB(150, 158, 168)
local BLACK = Color3.fromRGB(20, 20, 24)
local LEAF_GREEN = Color3.fromRGB(62, 138, 70)
local LEAF_LIGHT = Color3.fromRGB(96, 168, 84)
local WARM_WHITE = Color3.fromRGB(255, 244, 230)
local COOL_WHITE = Color3.fromRGB(240, 246, 255)

-- Images uploaded through Studio MCP. The logos (the name "의자에서 살아남기!", owner 2026-10-26) are drawn by
-- tools/art/make_logos.py in each face's shape, since a Decal stretches over the whole face; onAir by
-- tools/art/make_art.ps1 (2026-10-21, text ON AIR, not in the word bank).
local IMAGES = {
	screenLogo = "rbxassetid://131242369545373", -- far LED screen, 1024x387
	podiumLogo = "rbxassetid://133224927272345", -- podium front, 1024x465
	onAir = "rbxassetid://79467207024292",
}

for _, name in { "PoolHall", "LoungeMap", "PoolMap", "Baseplate", "Spawn", "SttProbe" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
workspace.Terrain:Clear()

local hall = Instance.new("Folder")
hall.Name = "PoolHall"
hall:SetAttribute("CeilingY", CEILING_Y)

type Options = { solid: boolean?, shadow: boolean?, transparency: number?, reflectance: number? }

-- Every visual part goes through here. Small trim passes solid = false / shadow = false (cheaper, nothing to bump into).
local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, options: Options?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if options then
		if options.solid == false then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
		if options.shadow == false then
			p.CastShadow = false
		end
		p.Transparency = options.transparency or 0
		p.Reflectance = options.reflectance or 0
	end
	p.Parent = parent
	return p
end

local TRIM: Options = { solid = false, shadow = false }
local HIDDEN: Options = { solid = false, shadow = false, transparency = 1 }

-- Axis-aligned box between two corners (handy for the room shell and the pool basin).
local function box(parent: Instance, name: string, a: Vector3, b: Vector3, color: Color3, material: Enum.Material?, options: Options?): Part
	local low = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local high = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	return part(parent, name, high - low, CFrame.new((low + high) / 2), color, material, options)
end

-- Upright cylinder ("puck") centred on `cframe`, axis along the cframe's Y.
local function puck(parent: Instance, name: string, cframe: CFrame, diameter: number, height: number, color: Color3, material: Enum.Material?, options: Options?): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, options)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Cylinder (tube) from a to b.
local function tube(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?, options: Options?): Part
	local p = part(parent, name, Vector3.new((b - a).Magnitude, diameter, diameter), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, material, options)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, position: Vector3, diameter: number, color: Color3, material: Enum.Material?, options: Options?): Part
	local p = part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(position), color, material, options)
	p.Shape = Enum.PartType.Ball
	return p
end

local function decal(target: BasePart, image: string, face: Enum.NormalId)
	local d = Instance.new("Decal")
	d.Texture = image
	d.Face = face
	d.Parent = target
end

-- Invisible holder for a light source (lights need a part).
local function lightHolder(parent: Instance, name: string, cframe: CFrame): Part
	return part(parent, name, Vector3.new(0.2, 0.2, 0.2), cframe, BLACK, nil, HIDDEN)
end

local function marker(name: string, size: Vector3, cframe: CFrame): Part
	return part(hall, name, size, cframe, BLACK, nil, HIDDEN)
end

local function spot(holder: Part, face: Enum.NormalId, angle: number, range: number, brightness: number, color: Color3, shadows: boolean)
	local light = Instance.new("SpotLight")
	light.Face = face
	light.Angle = angle
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Shadows = shadows
	light.Parent = holder
end

-- Makes every other part under `model` follow `root`: unanchored, massless, no collisions, welded to it.
local function weldTo(model: Instance, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
end

-- A digit on a SurfaceGui (seat numbers; digits are never in the word bank).
local function digits(target: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud -- the default fixed 800x600 canvas shrinks scaled text
	gui.PixelsPerStud = 60
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
end

---------------------------------------------------------------- floor and pool basin
-- Deck: light ceramic tiles all around the pool, a grey anti-slip border along the water, drain grates.
local floor = Instance.new("Folder")
floor.Name = "Floor"
floor.Parent = hall
local deckDepth = 2
-- The deck stops at the basin walls' outer faces (POOL_WALL thick): a deck reaching the water's edge shared the walls'
-- inner faces, grey and blue drawn in one plane, which flickered along the waterline (owner 2026-10-27).
local POOL_WALL = 1
box(floor, "DeckNear", Vector3.new(-HALL_HALF_X, -deckDepth, HALL_NEAR_Z), Vector3.new(HALL_HALF_X, 0, POOL_NEAR_Z - POOL_WALL), DECK_TILE, Enum.Material.CeramicTiles)
box(floor, "DeckFar", Vector3.new(-HALL_HALF_X, -deckDepth, POOL_FAR_Z + POOL_WALL), Vector3.new(HALL_HALF_X, 0, HALL_FAR_Z), DECK_TILE, Enum.Material.CeramicTiles)
box(floor, "DeckLeft", Vector3.new(-HALL_HALF_X, -deckDepth, POOL_NEAR_Z - POOL_WALL), Vector3.new(-POOL_HALF_X - POOL_WALL, 0, POOL_FAR_Z + POOL_WALL), DECK_TILE, Enum.Material.CeramicTiles)
box(floor, "DeckRight", Vector3.new(POOL_HALF_X + POOL_WALL, -deckDepth, POOL_NEAR_Z - POOL_WALL), Vector3.new(HALL_HALF_X, 0, POOL_FAR_Z + POOL_WALL), DECK_TILE, Enum.Material.CeramicTiles)
local border = 1.6
box(floor, "EdgeNear", Vector3.new(-POOL_HALF_X - border, 0, POOL_NEAR_Z - border), Vector3.new(POOL_HALF_X + border, 0.06, POOL_NEAR_Z), DECK_EDGE, Enum.Material.Slate, TRIM)
box(floor, "EdgeFar", Vector3.new(-POOL_HALF_X - border, 0, POOL_FAR_Z), Vector3.new(POOL_HALF_X + border, 0.06, POOL_FAR_Z + border), DECK_EDGE, Enum.Material.Slate, TRIM)
box(floor, "EdgeLeft", Vector3.new(-POOL_HALF_X - border, 0, POOL_NEAR_Z), Vector3.new(-POOL_HALF_X, 0.06, POOL_FAR_Z), DECK_EDGE, Enum.Material.Slate, TRIM)
box(floor, "EdgeRight", Vector3.new(POOL_HALF_X, 0, POOL_NEAR_Z), Vector3.new(POOL_HALF_X + border, 0.06, POOL_FAR_Z), DECK_EDGE, Enum.Material.Slate, TRIM)
for _, x in { -POOL_HALF_X - border - 0.6, POOL_HALF_X + border + 0.6 } do
	box(floor, "Drain", Vector3.new(x - 0.4, 0, POOL_NEAR_Z), Vector3.new(x + 0.4, 0.04, POOL_FAR_Z), Color3.fromRGB(150, 158, 164), Enum.Material.DiamondPlate, TRIM)
end

-- Basin: light blue tiles, dark lane lines with T ends, a pale strip under the waterline (reads as pool lights through
-- the water without adding light sources).
local pool = Instance.new("Folder")
pool.Name = "Pool"
pool.Parent = hall
box(pool, "Bottom", Vector3.new(-POOL_HALF_X, POOL_FLOOR_Y - 1, POOL_NEAR_Z), Vector3.new(POOL_HALF_X, POOL_FLOOR_Y, POOL_FAR_Z), POOL_TILE, Enum.Material.CeramicTiles)
-- (the end walls run over the corners, so the deck has no hole there)
box(pool, "WallNear", Vector3.new(-POOL_HALF_X - POOL_WALL, POOL_FLOOR_Y, POOL_NEAR_Z - POOL_WALL), Vector3.new(POOL_HALF_X + POOL_WALL, 0, POOL_NEAR_Z), POOL_TILE, Enum.Material.CeramicTiles)
box(pool, "WallFar", Vector3.new(-POOL_HALF_X - POOL_WALL, POOL_FLOOR_Y, POOL_FAR_Z), Vector3.new(POOL_HALF_X + POOL_WALL, 0, POOL_FAR_Z + POOL_WALL), POOL_TILE, Enum.Material.CeramicTiles)
box(pool, "WallLeft", Vector3.new(-POOL_HALF_X - POOL_WALL, POOL_FLOOR_Y, POOL_NEAR_Z), Vector3.new(-POOL_HALF_X, 0, POOL_FAR_Z), POOL_TILE, Enum.Material.CeramicTiles)
box(pool, "WallRight", Vector3.new(POOL_HALF_X, POOL_FLOOR_Y, POOL_NEAR_Z), Vector3.new(POOL_HALF_X + POOL_WALL, 0, POOL_FAR_Z), POOL_TILE, Enum.Material.CeramicTiles)
local LANES = 8
local laneWidth = POOL_HALF_X * 2 / LANES
for lane = 1, LANES do
	local x = -POOL_HALF_X + (lane - 0.5) * laneWidth
	-- (the line stops where the T bars begin: overlapping tops in one plane flicker)
	box(pool, "LaneLine", Vector3.new(x - 0.5, POOL_FLOOR_Y, POOL_NEAR_Z + 3.5), Vector3.new(x + 0.5, POOL_FLOOR_Y + 0.05, POOL_FAR_Z - 3.5), LANE_TILE, Enum.Material.CeramicTiles, TRIM)
	for _, z in { POOL_NEAR_Z + 3, POOL_FAR_Z - 3 } do
		box(pool, "LaneT", Vector3.new(x - 1.5, POOL_FLOOR_Y, z - 0.5), Vector3.new(x + 1.5, POOL_FLOOR_Y + 0.05, z + 0.5), LANE_TILE, Enum.Material.CeramicTiles, TRIM)
	end
end
local glowY = WATER_TOP_Y - 1.2
box(pool, "GlowNear", Vector3.new(-POOL_HALF_X + 1, glowY - 0.15, POOL_NEAR_Z), Vector3.new(POOL_HALF_X - 1, glowY + 0.15, POOL_NEAR_Z + 0.1), POOL_GLOW, Enum.Material.Neon, TRIM)
box(pool, "GlowFar", Vector3.new(-POOL_HALF_X + 1, glowY - 0.15, POOL_FAR_Z - 0.1), Vector3.new(POOL_HALF_X - 1, glowY + 0.15, POOL_FAR_Z), POOL_GLOW, Enum.Material.Neon, TRIM)
box(pool, "GlowLeft", Vector3.new(-POOL_HALF_X, glowY - 0.15, POOL_NEAR_Z + 1), Vector3.new(-POOL_HALF_X + 0.1, glowY + 0.15, POOL_FAR_Z - 1), POOL_GLOW, Enum.Material.Neon, TRIM)
box(pool, "GlowRight", Vector3.new(POOL_HALF_X - 0.1, glowY - 0.15, POOL_NEAR_Z + 1), Vector3.new(POOL_HALF_X, glowY + 0.15, POOL_FAR_Z - 1), POOL_GLOW, Enum.Material.Neon, TRIM)

-- Lane ropes from wall to wall (owner 2026-10-22: they must not stop halfway): a white cable hooked to both walls,
-- blue and white floats spread evenly on it, the last four at each end red.
local FLOAT_LENGTH, FLOAT_GAP, RED_FLOATS = 2, 0.4, 4
local floatSpan = POOL_FAR_Z - POOL_NEAR_Z - 0.6 -- room for the hooks
local floatCount = math.floor((floatSpan + FLOAT_GAP) / (FLOAT_LENGTH + FLOAT_GAP))
local floatsLength = floatCount * FLOAT_LENGTH + (floatCount - 1) * FLOAT_GAP
local firstFloatZ = (POOL_NEAR_Z + POOL_FAR_Z) / 2 - floatsLength / 2 + FLOAT_LENGTH / 2
for lane = 1, LANES - 1 do
	local x = -POOL_HALF_X + lane * laneWidth
	local rope = Instance.new("Model")
	rope.Name = "LaneRope"
	tube(rope, "Cable", Vector3.new(x, WATER_TOP_Y + 0.05, POOL_NEAR_Z), Vector3.new(x, WATER_TOP_Y + 0.05, POOL_FAR_Z), 0.18, Color3.fromRGB(236, 236, 236), nil, TRIM)
	for n = 0, floatCount - 1 do
		local z = firstFloatZ + n * (FLOAT_LENGTH + FLOAT_GAP)
		local nearEnd = n < RED_FLOATS or n >= floatCount - RED_FLOATS
		local color = if nearEnd then Color3.fromRGB(220, 50, 50) elseif n % 2 == 0 then Color3.fromRGB(36, 110, 210) else Color3.fromRGB(244, 244, 244)
		puck(rope, "Float", CFrame.new(x, WATER_TOP_Y + 0.05, z) * CFrame.Angles(math.rad(90), 0, 0), 0.7, FLOAT_LENGTH, color, nil, TRIM)
	end
	for _, z in { POOL_NEAR_Z + 0.15, POOL_FAR_Z - 0.15 } do
		part(rope, "Hook", Vector3.new(0.5, 0.5, 0.3), CFrame.new(x, WATER_TOP_Y + 0.3, z), CHROME, Enum.Material.Metal, TRIM)
	end
	rope.Parent = pool
end

-- Water: terrain water fills the basin up to just under the deck, clear and bright in daylight. Owner 2026-10-25: too
-- glaring, keep it bright but see through it more (was colour 56,168,200, transparency 0.7, reflectance 0.35).
local terrain = workspace.Terrain
terrain.WaterColor = Color3.fromRGB(120, 200, 214) -- (a lighter tint: clearer water alone looked dark over the floor)
terrain.WaterTransparency = 0.85
terrain.WaterReflectance = 0.2
terrain.WaterWaveSize = 0.08
terrain.WaterWaveSpeed = 6
-- The water runs one terrain voxel (4 studs) past the basin's walls and floor, under the deck: water that stopped
-- exactly on the walls' inner faces and the floor's top had its edge in their planes (like the deck above; 2026-10-27).
-- The extra water is hidden behind the walls, under the deck and under the floor.
local WATER_TUCK = 4
local waterBottomY = POOL_FLOOR_Y - WATER_TUCK
local waterSize = Vector3.new(POOL_HALF_X * 2 + WATER_TUCK * 2, WATER_TOP_Y - waterBottomY, POOL_FAR_Z - POOL_NEAR_Z + WATER_TUCK * 2)
terrain:FillBlock(CFrame.new(0, (WATER_TOP_Y + waterBottomY) / 2, (POOL_NEAR_Z + POOL_FAR_Z) / 2), waterSize, Enum.Material.Water)

-- Landing zone for flying players (far half of the pool, inside the lanes).
local LANDING_MARGIN = 6 -- studs of water beside the landing zone on each side
local landing = marker("Landing", Vector3.new((POOL_HALF_X - LANDING_MARGIN) * 2, 1, 36), CFrame.new(0, WATER_TOP_Y, 76))
landing:SetAttribute("WaterY", WATER_TOP_Y)
landing:SetAttribute("PoolMargin", LANDING_MARGIN) -- (the splash shows over the whole width of the pool)

---------------------------------------------------------------- red carpet and flying chairs
-- A red carpet runner along the near edge (as on the shows), white edge lines, the chairs on it.
local stage = Instance.new("Folder")
stage.Name = "ChairStage"
stage.Parent = hall
local stageHalf = (CHAIR_COUNT - 1) * CHAIR_SPACING / 2 + 4.5
box(stage, "Carpet", Vector3.new(-stageHalf, 0, CHAIR_Z - 4.6), Vector3.new(stageHalf, CARPET_TOP, CHAIR_Z + 2.6), CARPET_RED, Enum.Material.Carpet)
for _, z in { CHAIR_Z - 4.6, CHAIR_Z + 2.6 } do
	box(stage, "CarpetEdge", Vector3.new(-stageHalf, 0, z - 0.12), Vector3.new(stageHalf, CARPET_TOP + 0.01, z + 0.12), WHITE, Enum.Material.SmoothPlastic, TRIM)
end

-- Flying chairs, facing -Z with their backs to the pool. Base (blue box) and Seat (invisible) never move; the Flap
-- (white seat cushion + backrest) is welded to the Hinge on the box's back top edge, so a client turning the Hinge
-- about its X axis (positive = front up, back toward the pool) swings the whole flap. Under the cushion sits a dark
-- well with a chrome spring, seen only while the flap is up.
local chairs = Instance.new("Folder")
chairs.Name = "Chairs"
chairs.Parent = hall
local BASE = Vector3.new(3.4, 1.5, 3.2)
local BELL_SIDE = BASE.X / 2 + 0.45 -- the bell stands in the gap to the chair's right, close to its own chair
local BELL_FORWARD = -0.8 -- a little in front of the seat's middle, under the seated player's hand
local BELL_HEIGHT = 2.2 -- top of the post (the cushion top is about 2.05)
local BELL_GOLD = Color3.fromRGB(232, 184, 64)
local CUSHION_HEIGHT = 0.55
for i = 1, CHAIR_COUNT do
	local x = (CHAIR_COUNT - 1) * CHAIR_SPACING / 2 - (i - 1) * CHAIR_SPACING -- seat 1 on the camera's left
	local floorAt = Vector3.new(x, CARPET_TOP, CHAIR_Z)
	local f = CFrame.lookAt(floorAt, floorAt - Vector3.zAxis) -- local -Z = the chair's front (toward the camera)
	local top = BASE.Y
	local model = Instance.new("Model")
	model.Name = string.format("Chair%02d", i)
	local base = part(model, "Base", BASE, f * CFrame.new(0, top / 2, 0), CHAIR_BLUE, Enum.Material.Plastic)
	part(model, "Plinth", Vector3.new(BASE.X + 0.16, 0.18, BASE.Z + 0.16), f * CFrame.new(0, 0.09, 0), CHAIR_BLUE_DARK, Enum.Material.Rubber, TRIM)
	part(model, "Stripe", Vector3.new(BASE.X + 0.02, 0.22, BASE.Z + 0.02), f * CFrame.new(0, top - 0.32, 0), WHITE, Enum.Material.SmoothPlastic, TRIM)
	local hingeFrame = f * CFrame.new(0, top, BASE.Z / 2)
	tube(model, "HingeBarrel", (hingeFrame * CFrame.new(-1.5, 0, 0)).Position, (hingeFrame * CFrame.new(1.5, 0, 0)).Position, 0.3, CHROME, Enum.Material.Metal, TRIM)
	part(model, "Well", Vector3.new(BASE.X - 0.4, 0.04, BASE.Z - 0.4), f * CFrame.new(0, top + 0.02, 0), Color3.fromRGB(32, 36, 44), nil, TRIM)
	tube(model, "SpringRod", (f * CFrame.new(0, top, -0.3)).Position, (f * CFrame.new(0, top + 0.5, -0.3)).Position, 0.16, METAL, Enum.Material.Metal, TRIM)
	for ring = 1, 3 do
		puck(model, "SpringRing", f * CFrame.new(0, top + ring * 0.13, -0.3), 0.8, 0.06, CHROME, Enum.Material.Metal, TRIM)
	end
	-- Seat number on a small plate leaning back on the carpet in front of the feet (faces the show camera).
	local plate = part(model, "Plate", Vector3.new(2, 1, 0.08), CFrame.new(x, CARPET_TOP + 0.45, CHAIR_Z - 3.6) * CFrame.Angles(math.rad(30), 0, 0), CHAIR_BLUE_DARK, nil, TRIM)
	digits(plate, tostring(i), WHITE)
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(2.8, 0.4, 2.8)
	seat.CFrame = f * CFrame.new(0, top + CUSHION_HEIGHT - 0.2, -0.05) -- top face level with the cushion top
	seat.Transparency = 1
	seat.CastShadow = false
	seat.Disabled = true -- nobody sits by touch; SeatService seats the players of a round
	seat:SetAttribute("SeatIndex", i)
	seat.Parent = model
	local flap = Instance.new("Model")
	flap.Name = "Flap"
	local hinge = part(flap, "Hinge", Vector3.new(0.2, 0.2, 0.2), hingeFrame, BLACK, nil, HIDDEN)
	part(flap, "Cushion", Vector3.new(3.2, CUSHION_HEIGHT, 3.0), f * CFrame.new(0, top + CUSHION_HEIGHT / 2, -0.05), CUSHION_WHITE, Enum.Material.Leather)
	local nose = part(flap, "CushionFront", Vector3.new(3.2, CUSHION_HEIGHT, CUSHION_HEIGHT), f * CFrame.new(0, top + CUSHION_HEIGHT / 2, -1.55), CUSHION_WHITE, Enum.Material.Leather)
	nose.Shape = Enum.PartType.Cylinder
	part(flap, "BackShell", Vector3.new(BASE.X, 3.6, 0.45), f * CFrame.new(0, top + 1.8, 1.375), CHAIR_BLUE, Enum.Material.Plastic)
	part(flap, "BackCushion", Vector3.new(3.0, 2.9, 0.4), f * CFrame.new(0, top + CUSHION_HEIGHT + 1.5, 0.95), CUSHION_WHITE, Enum.Material.Leather)
	local roll = part(flap, "BackTop", Vector3.new(BASE.X, 0.6, 0.6), f * CFrame.new(0, top + 3.6, 1.375), CHAIR_BLUE, Enum.Material.Plastic)
	roll.Shape = Enum.PartType.Cylinder
	flap.PrimaryPart = hinge
	weldTo(flap, hinge)
	flap.Parent = model
	-- The seat bell: in the gap at the seated player's right (local +X), on a post at hand height. It never moves.
	local bell = Instance.new("Model")
	bell.Name = "Bell"
	local bellAt = f * CFrame.new(BELL_SIDE, 0, BELL_FORWARD)
	tube(bell, "Post", (bellAt * CFrame.new(0, CARPET_TOP, 0)).Position, (bellAt * CFrame.new(0, BELL_HEIGHT - 0.1, 0)).Position, 0.18, CHROME, Enum.Material.Metal, TRIM)
	puck(bell, "Stand", bellAt * CFrame.new(0, BELL_HEIGHT - 0.05, 0), 0.9, 0.1, CHAIR_BLUE_DARK, Enum.Material.SmoothPlastic, TRIM)
	local dome = ball(bell, "Light", (bellAt * CFrame.new(0, BELL_HEIGHT + 0.1, 0)).Position, 0.75, BELL_GOLD, Enum.Material.SmoothPlastic, TRIM)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 214, 120)
	glow.Range = 10
	glow.Brightness = 3
	glow.Enabled = false
	glow.Parent = dome
	local button = puck(bell, "Button", bellAt * CFrame.new(0, BELL_HEIGHT + 0.5, 0), 0.22, 0.12, CARPET_RED, Enum.Material.SmoothPlastic, TRIM)
	bell.PrimaryPart = button
	bell.Parent = model
	model.PrimaryPart = base
	model.Parent = chairs
end

---------------------------------------------------------------- presenter podium and camera marks
-- Podium: white desk with a blue top and a coral glow band, the logo on the front, a microphone and the "날려!" lever
-- (red knob). It stands to the camera's right, angled at the middle of the row.
local podium = Instance.new("Model")
podium.Name = "PodiumSet"
local PODIUM_AT = Vector3.new(-24, 0, -8)
local podiumFrame = CFrame.lookAt(PODIUM_AT, Vector3.new(0, 0, CHAIR_Z))
part(podium, "Riser", Vector3.new(10, 0.6, 6), podiumFrame * CFrame.new(0, 0.3, 0), Color3.fromRGB(70, 128, 210), Enum.Material.Carpet)
part(podium, "Desk", Vector3.new(6, 3.6, 2), podiumFrame * CFrame.new(0, 2.4, -1.2), WHITE, Enum.Material.SmoothPlastic)
part(podium, "DeskTop", Vector3.new(6.4, 0.2, 2.4), podiumFrame * CFrame.new(0, 4.3, -1.2), CHAIR_BLUE, Enum.Material.SmoothPlastic, { reflectance = 0.05 })
part(podium, "GlowBand", Vector3.new(6.02, 0.15, 2.02), podiumFrame * CFrame.new(0, 3.6, -1.2), CORAL_GLOW, Enum.Material.Neon, TRIM)
local front = part(podium, "Front", Vector3.new(4.4, 2, 0.06), podiumFrame * CFrame.new(0, 2.2, -2.23), BLACK, nil, TRIM)
decal(front, IMAGES.podiumLogo, Enum.NormalId.Front)
tube(podium, "MicStand", (podiumFrame * CFrame.new(-1.8, 4.4, -1.4)).Position, (podiumFrame * CFrame.new(-1.8, 5.3, -1.6)).Position, 0.08, CHROME, Enum.Material.Metal, TRIM)
ball(podium, "Mic", (podiumFrame * CFrame.new(-1.8, 5.4, -1.65)).Position, 0.3, BLACK, Enum.Material.Metal, TRIM)
local lever = Instance.new("Model")
lever.Name = "Lever"
part(lever, "Base", Vector3.new(0.9, 0.3, 0.9), podiumFrame * CFrame.new(1.8, 4.55, -1.2), METAL, Enum.Material.Metal, TRIM)
tube(lever, "Handle", (podiumFrame * CFrame.new(1.8, 4.6, -1.2)).Position, (podiumFrame * CFrame.new(1.8, 5.8, -1.5)).Position, 0.14, CHROME, Enum.Material.Metal, TRIM)
ball(lever, "Knob", (podiumFrame * CFrame.new(1.8, 5.85, -1.52)).Position, 0.45, Color3.fromRGB(200, 30, 40), Enum.Material.Neon, TRIM)
lever.Parent = podium
podium.Parent = hall
marker("Podium", Vector3.new(2, 1, 2), podiumFrame * CFrame.new(0, 0.6, 0.6))

-- Camera marks: the show camera frames the whole row with the pool behind; the presenter camera sits behind the desk.
local show = marker("ShowCamera", Vector3.new(1, 1, 1), CFrame.lookAt(Vector3.new(0, 10.5, -36), Vector3.new(0, 7, 24)))
show:SetAttribute("HalfWidth", stageHalf + 2) -- studs either side of the row centre that must stay on screen
show:SetAttribute("MinFov", 40)
show:SetAttribute("MaxFov", 70)
local behindDesk = PODIUM_AT - podiumFrame.LookVector * 8
local presenterCamera = marker("PresenterCamera", Vector3.new(1, 1, 1), CFrame.lookAt(behindDesk + Vector3.new(0, 8.5, 0), Vector3.new(0, 4, CHAIR_Z)))
presenterCamera:SetAttribute("Fov", 55)

-- TV cameras on pedestals either side of the podium (set dressing, out of the show camera's centre).
for _, x in { -14, 14 } do
	local f = CFrame.lookAt(Vector3.new(x, 0, -20), Vector3.new(x * 0.4, 0, CHAIR_Z))
	local tv = Instance.new("Model")
	tv.Name = "TVCamera"
	puck(tv, "Base", f * CFrame.new(0, 0.1, 0), 1.8, 0.2, BLACK, Enum.Material.Metal)
	puck(tv, "Pedestal", f * CFrame.new(0, 1.9, 0), 0.36, 3.4, Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	part(tv, "Body", Vector3.new(1, 1.1, 2), f * CFrame.new(0, 4.25, 0), Color3.fromRGB(30, 30, 36))
	tube(tv, "Lens", (f * CFrame.new(0, 4.25, -0.95)).Position, (f * CFrame.new(0, 4.25, -1.95)).Position, 0.75, BLACK, Enum.Material.Metal, TRIM)
	tv.Parent = hall
end

---------------------------------------------------------------- spectator stands
-- Six white concrete tiers along the +X side facing the pool, blue bench seats, a blue step nosing, a chrome rail.
local stands = Instance.new("Folder")
stands.Name = "StandsSet"
stands.Parent = hall
local STAND_X0, TIER_DEPTH, TIER_RISE, TIERS = POOL_HALF_X + 9, 3.6, 1.7, 6
local STAND_Z0, STAND_Z1 = -6, 92
for t = 0, TIERS - 1 do
	local x0 = STAND_X0 + t * TIER_DEPTH
	local top = (t + 1) * TIER_RISE
	box(stands, "Tier", Vector3.new(x0, 0, STAND_Z0), Vector3.new(x0 + TIER_DEPTH, top, STAND_Z1), Color3.fromRGB(232, 236, 240), Enum.Material.Concrete)
	box(stands, "Bench", Vector3.new(x0 + TIER_DEPTH - 1.6, top, STAND_Z0 + 1), Vector3.new(x0 + TIER_DEPTH - 0.4, top + 0.3, STAND_Z1 - 1), CHAIR_BLUE, Enum.Material.Plastic)
	box(stands, "Nosing", Vector3.new(x0 - 0.05, top - 0.14, STAND_Z0), Vector3.new(x0 + 0.1, top + 0.01, STAND_Z1), ACCENT_BLUE, Enum.Material.Plastic, TRIM)
end
tube(stands, "Rail", Vector3.new(STAND_X0 - 0.4, 3.2, STAND_Z0), Vector3.new(STAND_X0 - 0.4, 3.2, STAND_Z1), 0.18, CHROME, Enum.Material.Metal, TRIM)
for z = STAND_Z0, STAND_Z1, 8 do
	tube(stands, "RailPost", Vector3.new(STAND_X0 - 0.4, 0, z), Vector3.new(STAND_X0 - 0.4, 3.2, z), 0.14, CHROME, Enum.Material.Metal, TRIM)
end
local standsSpot = marker("Stands", Vector3.new(TIER_DEPTH * 2, 1, 40), CFrame.new(STAND_X0 + TIER_DEPTH * 2.5, 3 * TIER_RISE + 0.5, 40))
standsSpot:SetAttribute("FaceX", -1) -- spectators face -X (the pool)

---------------------------------------------------------------- room shell
-- Walls: white tiled lower band with a blue stripe, white plaster above; big windows along -X and the far end (daylight
-- outside); a white roof with skylight strips. Everything sits far behind the row, so it frames the shot.
local walls = Instance.new("Folder")
walls.Name = "Walls"
walls.Parent = hall
local wallTop = ROOF_Y
local function wallRun(name: string, a: Vector3, b: Vector3, windowed: boolean)
	-- a/b: the wall's two ends on the floor line (axis-aligned); the wall is 1 stud thick, outward of that line.
	-- The frame stays right-handed, so its +Z points INTO the hall: outward offsets are negative. The blue stripes are
	-- 0.1 thicker than the wall and stand out of its inner face.
	local along = (b - a).Unit
	local length = (b - a).Magnitude
	local outward = Vector3.new(along.Z, 0, -along.X)
	local center = (a + b) / 2
	local frame = CFrame.fromMatrix(center, along, Vector3.yAxis, -outward)
	part(walls, name .. "Tile", Vector3.new(length, 8, 1), frame * CFrame.new(0, 4, -0.5), TILE_WHITE, Enum.Material.CeramicTiles)
	part(walls, name .. "Stripe", Vector3.new(length, 0.6, 1.1), frame * CFrame.new(0, 8.3, -0.45), ACCENT_BLUE, Enum.Material.Plastic)
	if windowed then
		local glassBottom, glassTop = 14.6, wallTop - 6
		part(walls, name .. "Sill", Vector3.new(length, glassBottom - 8.6, 1), frame * CFrame.new(0, (8.6 + glassBottom) / 2, -0.5), WALL_WHITE, Enum.Material.Plaster)
		part(walls, name .. "Glass", Vector3.new(length, glassTop - glassBottom, 0.3), frame * CFrame.new(0, (glassBottom + glassTop) / 2, -0.6), SKY_GLASS, Enum.Material.Glass, { transparency = 0.6, reflectance = 0.1, shadow = false })
		part(walls, name .. "Header", Vector3.new(length, wallTop - glassTop, 1), frame * CFrame.new(0, (glassTop + wallTop) / 2, -0.5), WALL_WHITE, Enum.Material.Plaster)
		local mullions = math.floor(length / 10)
		for m = 0, mullions do
			local offset = -length / 2 + m * length / mullions
			part(walls, name .. "Mullion", Vector3.new(0.6, glassTop - glassBottom, 0.8), frame * CFrame.new(offset, (glassBottom + glassTop) / 2, -0.5), STEEL_WHITE, Enum.Material.Metal, TRIM)
		end
		part(walls, name .. "Transom", Vector3.new(length, 0.5, 0.8), frame * CFrame.new(0, (glassBottom + glassTop) / 2, -0.5), STEEL_WHITE, Enum.Material.Metal, TRIM)
	else
		part(walls, name .. "Upper", Vector3.new(length, wallTop - 8.6, 1), frame * CFrame.new(0, 8.6 + (wallTop - 8.6) / 2, -0.5), WALL_WHITE, Enum.Material.Plaster)
		part(walls, name .. "HighStripe", Vector3.new(length, 0.8, 1.1), frame * CFrame.new(0, 30, -0.45), ACCENT_BLUE, Enum.Material.Plastic, TRIM)
	end
end
wallRun("Left", Vector3.new(-HALL_HALF_X, 0, HALL_FAR_Z), Vector3.new(-HALL_HALF_X, 0, HALL_NEAR_Z), true)
wallRun("Far", Vector3.new(HALL_HALF_X, 0, HALL_FAR_Z), Vector3.new(-HALL_HALF_X, 0, HALL_FAR_Z), true)
wallRun("Right", Vector3.new(HALL_HALF_X, 0, HALL_NEAR_Z), Vector3.new(HALL_HALF_X, 0, HALL_FAR_Z), false)
wallRun("Near", Vector3.new(-HALL_HALF_X, 0, HALL_NEAR_Z), Vector3.new(HALL_HALF_X, 0, HALL_NEAR_Z), false)

-- Roof: white panels with skylight strips over the pool, LED light panels along the panels' edges.
local roof = Instance.new("Folder")
roof.Name = "Roof"
roof.Parent = hall
local roofSegments = { { HALL_NEAR_Z, 20 }, { 32, 48 }, { 60, 76 }, { 88, HALL_FAR_Z } }
for _, seg in roofSegments do
	box(roof, "Panel", Vector3.new(-HALL_HALF_X - 1, ROOF_Y, seg[1] - 1), Vector3.new(HALL_HALF_X + 1, ROOF_Y + 1, seg[2] + 1), WALL_WHITE, Enum.Material.Plaster)
end
for _, gap in { { 20, 32 }, { 48, 60 }, { 76, 88 } } do
	box(roof, "Skylight", Vector3.new(-HALL_HALF_X - 1, ROOF_Y + 0.4, gap[1] - 1), Vector3.new(HALL_HALF_X + 1, ROOF_Y + 0.7, gap[2] + 1), SKY_GLASS, Enum.Material.Glass, { transparency = 0.5, shadow = false })
	for _, z in { gap[1] - 1.6, gap[2] + 1.6 } do
		box(roof, "LedPanel", Vector3.new(-HALL_HALF_X + 4, ROOF_Y - 0.12, z - 0.4), Vector3.new(HALL_HALF_X - 4, ROOF_Y, z + 0.4), COOL_WHITE, Enum.Material.Neon, TRIM)
	end
end

-- Far-end LED screen over the windows' sill: the logo, in a white frame (high above the word-bubble band).
local screenFrame = part(walls, "ScreenFrame", Vector3.new(30, 12, 0.6), CFrame.new(0, 26, HALL_FAR_Z - 0.6), STEEL_WHITE, Enum.Material.Metal)
local screen = part(walls, "Screen", Vector3.new(28.6, 10.8, 0.1), CFrame.new(0, 26, HALL_FAR_Z - 0.95), BLACK, nil, TRIM) -- Front (-Z) faces the pool
decal(screen, IMAGES.screenLogo, Enum.NormalId.Front)
screenFrame.CastShadow = false

---------------------------------------------------------------- trusses and lights
-- Flight guard (2026-10-25): one physics step at 205 studs/s moves ~0.9 studs, more than the 0.3-stud glass and the
-- skylights. Invisible walls GUARD studs thick just outside the shell, a lid over the roof and a slab under the pool
-- keep a thrown body in the hall (SeatService also puts a body that still gets out back over the pool).
do
	local GUARD = 6
	local guard = Instance.new("Folder")
	guard.Name = "FlightGuard"
	guard.Parent = hall
	local function guardBox(name: string, a: Vector3, b: Vector3)
		local p = box(guard, name, a, b, WHITE, nil, { transparency = 1, shadow = false })
		p.CanQuery = false
		p.CanTouch = false
	end
	local low, high = POOL_FLOOR_Y - 1 - GUARD, ROOF_Y + 2 + GUARD
	local x0, x1 = -HALL_HALF_X - 1.5, HALL_HALF_X + 1.5
	local z0, z1 = HALL_NEAR_Z - 1.5, HALL_FAR_Z + 1.5
	guardBox("Left", Vector3.new(x0 - GUARD, low, z0 - GUARD), Vector3.new(x0, high, z1 + GUARD))
	guardBox("Right", Vector3.new(x1, low, z0 - GUARD), Vector3.new(x1 + GUARD, high, z1 + GUARD))
	guardBox("Near", Vector3.new(x0, low, z0 - GUARD), Vector3.new(x1, high, z0))
	guardBox("Far", Vector3.new(x0, low, z1), Vector3.new(x1, high, z1 + GUARD))
	guardBox("Lid", Vector3.new(x0, ROOF_Y + 2, z0), Vector3.new(x1, high, z1))
	guardBox("UnderPool", Vector3.new(-POOL_HALF_X - 1, low, POOL_NEAR_Z - 1), Vector3.new(POOL_HALF_X + 1, POOL_FLOOR_Y - 1, POOL_FAR_Z + 1))
end

-- White trusses across the hall over the water (y 44-46).
local truss = Instance.new("Folder")
truss.Name = "Truss"
truss.Parent = hall
local function trussSpan(z: number)
	local corners = { Vector3.new(0, TRUSS_Y + 1.2, z), Vector3.new(0, TRUSS_Y, z - 0.7), Vector3.new(0, TRUSS_Y, z + 0.7) }
	for _, c in corners do
		tube(truss, "Chord", Vector3.new(-HALL_HALF_X, c.Y, c.Z), Vector3.new(HALL_HALF_X, c.Y, c.Z), 0.3, STEEL_WHITE, Enum.Material.Metal, TRIM)
	end
	local bays = 16
	for n = 0, bays - 1 do
		local x1 = -HALL_HALF_X + n * (HALL_HALF_X * 2 / bays)
		local x2 = x1 + HALL_HALF_X * 2 / bays
		for _, low in { 2, 3 } do
			local from = if n % 2 == 0 then corners[1] else corners[low]
			local to = if n % 2 == 0 then corners[low] else corners[1]
			tube(truss, "Lacing", Vector3.new(x1, from.Y, from.Z), Vector3.new(x2, to.Y, to.Z), 0.16, STEEL_WHITE, Enum.Material.Metal, TRIM)
		end
	end
	for _, x in { -HALL_HALF_X + 6, 0, HALL_HALF_X - 6 } do
		tube(truss, "Cable", Vector3.new(x, TRUSS_Y + 1.2, z), Vector3.new(x, ROOF_Y, z), 0.08, METAL, Enum.Material.Metal, TRIM)
	end
end
for _, z in { 26, 54, 82 } do
	trussSpan(z)
end

-- Daylight comes in through the windows and skylights; these lights keep the room even and light the faces.
local lights = Instance.new("Folder")
lights.Name = "Lights"
lights.Parent = hall
-- Downlights hung from the trusses over the water (white cans, no shadows).
for _, z in { 26, 54, 82 } do
	for _, x in { -24, 24 } do
		local at = Vector3.new(x, TRUSS_Y - 1, z)
		tube(truss, "Hanger", at + Vector3.new(0, 0.4, 0), at + Vector3.new(0, 1, 0), 0.12, STEEL_WHITE, Enum.Material.Metal, TRIM)
		puck(truss, "Can", CFrame.new(at), 1.4, 0.8, STEEL_WHITE, Enum.Material.Metal, TRIM)
		puck(truss, "Lens", CFrame.new(at - Vector3.new(0, 0.42, 0)), 1.1, 0.05, COOL_WHITE, Enum.Material.Neon, TRIM)
		spot(lightHolder(lights, "DownLight", CFrame.new(at - Vector3.new(0, 0.6, 0))), Enum.NormalId.Bottom, 110, 60, 1, COOL_WHITE, false)
	end
end
-- Key lights for the faces, without fixtures in front of the row (nothing hangs between the camera and the chairs):
-- five spots in front of the row at face height + 9, each on two seats; two of them cast shadows. A soft fill from
-- the front.
for k = 0, 4 do
	local x = -20 + k * 10
	spot(lightHolder(lights, "KeyLight", CFrame.lookAt(Vector3.new(x * 0.8, 13, CHAIR_Z - 13), Vector3.new(x, 4.5, CHAIR_Z))), Enum.NormalId.Front, 70, 26, 1.1, WARM_WHITE, k == 1 or k == 3)
end
local fill = Instance.new("PointLight")
fill.Range = 24
fill.Brightness = 0.3
fill.Color = Color3.fromRGB(255, 248, 240)
fill.Parent = lightHolder(lights, "FillLight", CFrame.new(0, 7, CHAIR_Z - 9))
-- Soft downlights for the stands and the lobby side.
for _, z in { 8, 44, 80 } do
	spot(lightHolder(lights, "StandsLight", CFrame.new(STAND_X0 + 10, 26, z)), Enum.NormalId.Bottom, 120, 30, 0.8, COOL_WHITE, false)
end
spot(lightHolder(lights, "LobbyLight", CFrame.new(0, 24, -38)), Enum.NormalId.Bottom, 120, 30, 0.8, COOL_WHITE, false)

---------------------------------------------------------------- set dressing
-- Starting blocks on all eight lanes at the far end, a lifeguard chair, an ON AIR sign, floats, sun loungers and plants
-- along the window deck, a kickboard rack, lockers by the lobby.
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = hall
for lane = 1, LANES do
	local x = -POOL_HALF_X + (lane - 0.5) * laneWidth
	local f = CFrame.lookAt(Vector3.new(x, 0, POOL_FAR_Z + 1.4), Vector3.new(x, 0, POOL_NEAR_Z))
	part(decor, "BlockBase", Vector3.new(1.8, 1.4, 1.6), f * CFrame.new(0, 0.7, 0), WHITE)
	part(decor, "BlockTop", Vector3.new(1.9, 0.2, 1.9), f * CFrame.new(0, 1.5, -0.15) * CFrame.Angles(math.rad(-8), 0, 0), CHAIR_BLUE)
end
local guardFrame = CFrame.lookAt(Vector3.new(-POOL_HALF_X - 5, 0, 60), Vector3.new(0, 0, 60))
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		tube(decor, "GuardLeg", (guardFrame * CFrame.new(sx * 1.2, 0, sz * 1.2)).Position, (guardFrame * CFrame.new(sx * 0.9, 6, sz * 0.9)).Position, 0.2, WHITE, nil, TRIM)
	end
end
part(decor, "GuardSeat", Vector3.new(2.4, 0.3, 2.2), guardFrame * CFrame.new(0, 6.15, 0), Color3.fromRGB(210, 40, 40))
part(decor, "GuardBack", Vector3.new(2.4, 1.8, 0.25), guardFrame * CFrame.new(0, 7.2, 1), Color3.fromRGB(210, 40, 40))
-- ON AIR hangs over the lobby by the near wall (behind the show camera, so its cables never cross the shot).
local sign = part(decor, "OnAir", Vector3.new(4.2, 1.6, 0.4), CFrame.new(0, 20, HALL_NEAR_Z + 1.6) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(120, 10, 20), nil, TRIM)
decal(sign, IMAGES.onAir, Enum.NormalId.Front)
for _, x in { -1.6, 1.6 } do
	local top = (sign.CFrame * CFrame.new(x, 0.8, 0)).Position
	tube(decor, "SignCable", top, Vector3.new(top.X, ROOF_Y, top.Z), 0.06, METAL, nil, TRIM)
end
-- A few pool floats drifting near the far end (decor only, they never block a landing).
for n, spec in { { -18, 98, Color3.fromRGB(255, 205, 60) }, { 6, 100, Color3.fromRGB(255, 120, 150) }, { 24, 97, Color3.fromRGB(120, 220, 255) } } do
	local ring = puck(decor, "FloatRing" .. n, CFrame.new(spec[1], WATER_TOP_Y + 0.2, spec[2]), 3.2, 0.7, spec[3], Enum.Material.SmoothPlastic, TRIM)
	ring.Shape = Enum.PartType.Cylinder
end
-- Sun loungers on the window deck, feet toward the pool, back raised at the window end.
for _, z in { 30, 44, 72, 86 } do
	local f = CFrame.lookAt(Vector3.new(-50, 0, z), Vector3.new(0, 0, z))
	part(decor, "LoungerFrame", Vector3.new(2.2, 0.25, 6), f * CFrame.new(0, 1.1, 0), WHITE, Enum.Material.Plastic)
	for _, sz in { -2.6, 2.6 } do
		for _, sx in { -0.9, 0.9 } do
			part(decor, "LoungerLeg", Vector3.new(0.2, 1, 0.2), f * CFrame.new(sx, 0.5, sz), WHITE, Enum.Material.Plastic, TRIM)
		end
	end
	part(decor, "LoungerPad", Vector3.new(2, 0.2, 3.6), f * CFrame.new(0, 1.32, -1), CHAIR_BLUE, Enum.Material.Fabric, TRIM)
	part(decor, "LoungerBack", Vector3.new(2, 0.25, 2.4), f * CFrame.new(0, 2.02, 1.72) * CFrame.Angles(math.rad(-40), 0, 0), CHAIR_BLUE, Enum.Material.Fabric, TRIM)
end
-- Potted plants by the windows and in the lobby.
local function plant(at: Vector3, scale: number)
	puck(decor, "Pot", CFrame.new(at + Vector3.new(0, scale, 0)), 2.2 * scale, 2 * scale, WHITE, Enum.Material.Plastic)
	ball(decor, "Leaves", at + Vector3.new(0, 3.2 * scale, 0), 3.2 * scale, LEAF_GREEN, Enum.Material.LeafyGrass)
	ball(decor, "Leaves", at + Vector3.new(0.6 * scale, 4.4 * scale, 0.3 * scale), 2.4 * scale, LEAF_LIGHT, Enum.Material.LeafyGrass, TRIM)
end
for _, z in { 22, 58, 100 } do
	plant(Vector3.new(-61, 0, z), 1.2)
end
for _, x in { -15, 15 } do
	plant(Vector3.new(x, 0, -45), 1)
end
-- Kickboard rack on the far deck (decor).
local rackFrame = CFrame.lookAt(Vector3.new(46, 0, POOL_FAR_Z + 9), Vector3.new(46, 0, POOL_FAR_Z))
part(decor, "RackBase", Vector3.new(7.4, 0.4, 1.6), rackFrame * CFrame.new(0, 0.2, 0), WHITE)
part(decor, "RackBack", Vector3.new(7.4, 2.6, 0.2), rackFrame * CFrame.new(0, 1.5, 0.75), WHITE, nil, TRIM)
local boardColors = { Color3.fromRGB(255, 196, 40), Color3.fromRGB(240, 90, 110), Color3.fromRGB(60, 190, 120), Color3.fromRGB(40, 140, 230) }
for n = 0, 5 do
	part(decor, "Kickboard", Vector3.new(0.2, 2.2, 1.3), rackFrame * CFrame.new(-2.9 + n * 1.16, 1.5, 0) * CFrame.Angles(0, 0, math.rad(8)), boardColors[n % 4 + 1], Enum.Material.Plastic, TRIM)
end
-- Lockers along the near wall on both sides of the lobby (blue doors in a white frame).
for _, side in { -1, 1 } do
	local x0, x1 = side * 20, side * 40
	box(decor, "LockerBank", Vector3.new(x0, 0, HALL_NEAR_Z), Vector3.new(x1, 7.2, HALL_NEAR_Z + 1.4), WHITE, Enum.Material.Plastic)
	for n = 0, 9 do
		local cx = math.min(x0, x1) + 1 + n * 2
		box(decor, "LockerDoor", Vector3.new(cx - 0.9, 0.4, HALL_NEAR_Z + 1.4), Vector3.new(cx + 0.9, 6.8, HALL_NEAR_Z + 1.5), if n % 2 == 0 then CHAIR_BLUE else ACCENT_BLUE, Enum.Material.Plastic, TRIM)
	end
end

---------------------------------------------------------------- spawn / lobby
-- Light blue rubber mat between the lockers, two wooden benches.
local lobby = Instance.new("SpawnLocation")
lobby.Name = "Lobby"
lobby.Anchored = true
lobby.Neutral = true
lobby.Size = Vector3.new(10, 0.2, 8)
lobby.CFrame = CFrame.new(0, 0.1, -40)
lobby.Color = Color3.fromRGB(128, 196, 232)
lobby.Material = Enum.Material.Rubber
lobby.Duration = 0
lobby.Parent = hall
for _, x in { -9, 9 } do
	box(decor, "BenchSeat", Vector3.new(x - 0.8, 1.4, -43), Vector3.new(x + 0.8, 1.7, -37), Color3.fromRGB(176, 128, 96), Enum.Material.Wood)
	for _, z in { -42.4, -37.6 } do
		box(decor, "BenchLeg", Vector3.new(x - 0.7, 0, z - 0.2), Vector3.new(x + 0.7, 1.4, z + 0.2), WHITE, Enum.Material.Plastic, TRIM)
	end
end

hall.Parent = workspace

local parts, lightCount, shadowed = 0, 0, 0
for _, d in hall:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("Light") then
		lightCount += 1
		if (d :: any).Shadows then
			shadowed += 1
		end
	end
end
return string.format("PoolHall built: %d chairs, %d parts, %d lights (%d with shadows), ceiling %d", #chairs:GetChildren(), parts, lightCount, shadowed, CEILING_Y)
