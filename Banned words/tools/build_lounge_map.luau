-- Talk-show studio set for 금칙어 게임 Korean (direction A, owner 2026-10-21; plan docs/VISUAL_PLAN_2026-10-21.md).
-- Run in Studio's Edit datamodel, then tools/build_lounge_lighting.luau. Rebuilds workspace.LoungeMap from scratch,
-- removes the old PoolMap and keeps the MaterialVariants in MaterialService up to date.
-- Layout (studs, floor top at y = 0, stage top at y = 0.21):
--   centre table with a buzzer, 10 armchairs on a ring (radius 10, facing the centre, ~6.3 studs apart) on a round stage,
--   an invisible RingBarrier (radius 14) that only spectators collide with, 8 set walls (radius 31) with screens,
--   an octagonal lighting truss (radius 22, y 14), TV cameras, sofas and a bar outside the ring, a round wall
--   (radius 42) under a dark ceiling (y 24), spawn outside the ring.
-- The seated camera sees the far side through a "word bubble band" about 2-10 degrees below the horizon
-- (far wall heights ~0-9): everything there stays dark and plain; screens, signs and glows sit higher.
-- Clients read LoungeMap.Center and LoungeMap.CameraRig (Back/Up/LookY/HalfAngle) for the seated camera.

local FLOOR_RADIUS = 42
local CHAIR_COUNT = 10
local CHAIR_RADIUS = 10
local BARRIER_RADIUS = 14
local STAGE_RADIUS = 15.5
local STAGE_TOP = 0.21
local SET_RADIUS = 31
local TRUSS_RADIUS = 22
local CEILING_Y = 24

local NAVY = Color3.fromRGB(24, 33, 44)
local NAVY_DARK = Color3.fromRGB(16, 21, 30)
local IVORY = Color3.fromRGB(226, 218, 202)
local TEAL = Color3.fromRGB(66, 100, 108)
local TEAL_DARK = Color3.fromRGB(46, 72, 80)
local TEAL_GLOW = Color3.fromRGB(76, 185, 202)
local TEAL_GLOW_DIM = Color3.fromRGB(40, 118, 130)
local CORAL_GLOW = Color3.fromRGB(240, 110, 140)
local WALNUT = Color3.fromRGB(150, 112, 92)
local CHROME = Color3.fromRGB(196, 200, 208)
local METAL = Color3.fromRGB(120, 129, 140)
local BLACK = Color3.fromRGB(20, 20, 24)
local WARM_WHITE = Color3.fromRGB(255, 240, 222)

-- Images painted by tools/art/make_art.ps1 and uploaded 2026-10-21 (texts: 금칙어 / KOREAN / TALK / LIVE / ON AIR,
-- none of them in the word bank).
local IMAGES = {
	screenLogo = "rbxassetid://99718360226508",
	screenTalk = "rbxassetid://87644068451782",
	onAir = "rbxassetid://79467207024292",
	floorMedallion = "rbxassetid://127398268614665",
}

-- MaterialVariants picked from Roblox generate_material results (2026-10-21). Maps: colour, normal, roughness, metalness.
local VARIANTS = {
	{ name = "BW_Leather", base = Enum.Material.Leather, studs = 6, maps = { "rbxassetid://104912978475572", "rbxassetid://115641812013401", "rbxassetid://99079211034687", "rbxassetid://77191835678658" } },
	{ name = "BW_Carpet", base = Enum.Material.Carpet, studs = 8, maps = { "rbxassetid://113219748236017", "rbxassetid://86627878284565", "rbxassetid://104523259600666", "rbxassetid://137584139216841" } },
	{ name = "BW_Acoustic", base = Enum.Material.Fabric, studs = 8, maps = { "rbxassetid://125353462766051", "rbxassetid://107964630109020", "rbxassetid://124077298834894", "rbxassetid://74947446137733" } },
	{ name = "BW_Stage", base = Enum.Material.Marble, studs = 14, maps = { "rbxassetid://89441735908455", "rbxassetid://97766172366155", "rbxassetid://90961731095303", "rbxassetid://85710741602980" } },
	{ name = "BW_Walnut", base = Enum.Material.Wood, studs = 6, maps = { "rbxassetid://72778896182645", "rbxassetid://94543261695115", "rbxassetid://98699201243236", "rbxassetid://137056784802506" } },
}

-- MaterialVariants live in MaterialService (not in the map), so a rebuild only refreshes them.
local function ensureVariants()
	local service = game:GetService("MaterialService")
	local folder = service:FindFirstChild("BannedWordsMaterials") or Instance.new("Folder")
	folder.Name = "BannedWordsMaterials"
	folder.Parent = service
	for _, spec in VARIANTS do
		local variant = folder:FindFirstChild(spec.name) or Instance.new("MaterialVariant")
		variant.Name = spec.name
		variant.BaseMaterial = spec.base
		variant.StudsPerTile = spec.studs
		variant.ColorMap = spec.maps[1]
		variant.NormalMap = spec.maps[2]
		variant.RoughnessMap = spec.maps[3]
		variant.MetalnessMap = spec.maps[4]
		variant.Parent = folder
	end
end
ensureVariants()

for _, name in { "LoungeMap", "PoolMap", "Baseplate", "Spawn", "SttProbe" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
workspace.Terrain:Clear()

local map = Instance.new("Folder")
map.Name = "LoungeMap"

type Options = { variant: string?, solid: boolean?, shadow: boolean?, transparency: number?, reflectance: number? }

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
		if options.variant then
			p.MaterialVariant = options.variant
		end
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

-- Upright cylinder ("puck") centred on `cframe`, axis along the cframe's Y.
local function puck(parent: Instance, name: string, cframe: CFrame, diameter: number, height: number, color: Color3, material: Enum.Material?, options: Options?): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, options)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Flat disc around the map centre with its top face at `topY`.
local function disc(parent: Instance, name: string, radius: number, thickness: number, topY: number, color: Color3, material: Enum.Material?, options: Options?): Part
	return puck(parent, name, CFrame.new(0, topY - thickness / 2, 0), radius * 2, thickness, color, material, options)
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
	return part(parent, name, Vector3.new(0.2, 0.2, 0.2), cframe, BLACK, nil, { solid = false, shadow = false, transparency = 1 })
end

local function onCircle(angle: number, radius: number, y: number): Vector3
	return Vector3.new(math.sin(angle) * radius, y, math.cos(angle) * radius)
end

local function marker(name: string, cframe: CFrame): Part
	return part(map, name, Vector3.new(1, 1, 1), cframe, BLACK, nil, { solid = false, transparency = 1 })
end

-- Floor: studio carpet, then the round stage (marble, chrome edge, a thin glow line), a teal carpet under the table
-- and a painted medallion (rings and rays; the table covers its empty centre).
local floor = Instance.new("Folder")
floor.Name = "Floor"
floor.Parent = map
disc(floor, "Floor", FLOOR_RADIUS, 2, 0, Color3.fromRGB(78, 80, 94), Enum.Material.Carpet, { variant = "BW_Carpet" })
disc(floor, "EdgeGlow", STAGE_RADIUS + 0.4, 0.06, 0.06, TEAL_GLOW_DIM, Enum.Material.Neon, TRIM)
disc(floor, "StageEdge", STAGE_RADIUS + 0.3, 0.24, 0.2, CHROME, Enum.Material.Metal)
disc(floor, "Stage", STAGE_RADIUS, 0.3, STAGE_TOP, Color3.fromRGB(58, 60, 72), Enum.Material.Marble, { variant = "BW_Stage" })
disc(floor, "CenterCarpet", 6.6, 0.06, STAGE_TOP + 0.03, Color3.fromRGB(34, 84, 92), Enum.Material.Carpet, { variant = "BW_Carpet", shadow = false })
local medallion = part(floor, "Medallion", Vector3.new(STAGE_RADIUS * 2, 0.05, STAGE_RADIUS * 2), CFrame.new(0, STAGE_TOP + 0.06, 0), BLACK, nil, { solid = false, shadow = false, transparency = 1 })
decal(medallion, IMAGES.floorMedallion, Enum.NormalId.Top)

marker("Center", CFrame.new(0, 0, 0))
local rig = marker("CameraRig", CFrame.new(0, 0, 0))
rig:SetAttribute("Back", 9)
rig:SetAttribute("Up", 11)
rig:SetAttribute("LookY", 6)
rig:SetAttribute("HalfAngle", 42)

-- Centre table: walnut top on a black under-top, chrome column, a red buzzer, mugs and cue cards.
-- Everything stays under ~3.1 so faces across the ring are never blocked.
local table_ = Instance.new("Model")
table_.Name = "CenterTable"
puck(table_, "Foot", CFrame.new(0, STAGE_TOP + 0.075, 0), 3.2, 0.15, CHROME, Enum.Material.Metal)
puck(table_, "Column", CFrame.new(0, 1.125, 0), 0.7, 1.55, CHROME, Enum.Material.Metal)
puck(table_, "UnderTop", CFrame.new(0, 1.96, 0), 6.3, 0.12, BLACK)
puck(table_, "Top", CFrame.new(0, 2.13, 0), 6, 0.22, WALNUT, Enum.Material.Wood, { variant = "BW_Walnut" })
puck(table_, "BuzzerBase", CFrame.new(0, 2.39, 0), 1.5, 0.3, BLACK, nil, TRIM)
ball(table_, "Buzzer", Vector3.new(0, 2.54, 0), 1.1, Color3.fromRGB(170, 25, 35), Enum.Material.Neon, TRIM)
for _, spot in { Vector3.new(1.9, 0, 0.9), Vector3.new(-1.6, 0, -1.5) } do
	puck(table_, "Mug", CFrame.new(spot.X, 2.49, spot.Z), 0.45, 0.5, Color3.fromRGB(240, 240, 238), nil, TRIM)
end
for n, turn in { 18, 31 } do
	part(table_, "CueCard", Vector3.new(0.9, 0.04, 1.3), CFrame.new(-1.1, 2.22 + n * 0.04, 1.7) * CFrame.Angles(0, math.rad(turn), 0), IVORY, nil, TRIM)
end
table_.Parent = map

-- Talk-show armchairs on the ring, numbered counter-clockwise (seen from above), each facing the centre:
-- chrome swivel foot, walnut shell, quilted leather (ivory / teal in turn), a low reclined back (top ~3.6, so the
-- camera behind sees over it), padded arms and a dim glow under the seat. The Seat itself is the seat cushion.
local chairs = Instance.new("Folder")
chairs.Name = "Chairs"
chairs.Parent = map
for i = 1, CHAIR_COUNT do
	local angle = (i - 1) / CHAIR_COUNT * math.pi * 2
	local f = CFrame.lookAt(onCircle(angle, CHAIR_RADIUS, 0), Vector3.zero)
	local leather = if i % 2 == 1 then IVORY else TEAL
	local soft: Options = { variant = "BW_Leather", solid = false, shadow = false }
	local model = Instance.new("Model")
	model.Name = string.format("Chair%02d", i)
	puck(model, "Foot", f * CFrame.new(0, STAGE_TOP + 0.06, 0.1), 2.5, 0.12, CHROME, Enum.Material.Metal)
	puck(model, "Column", f * CFrame.new(0, 0.5, 0.1), 0.55, 0.36, CHROME, Enum.Material.Metal, TRIM)
	part(model, "Shell", Vector3.new(3.2, 0.32, 3.1), f * CFrame.new(0, 0.84, 0.1), WALNUT, Enum.Material.Wood, { variant = "BW_Walnut" })
	part(model, "Glow", Vector3.new(3, 0.05, 2.9), f * CFrame.new(0, 0.655, 0.1), TEAL_GLOW_DIM, Enum.Material.Neon, TRIM)
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(2.8, 0.5, 2.8)
	seat.CFrame = f * CFrame.new(0, 1.25, 0)
	seat.Color = leather
	seat.Material = Enum.Material.Leather
	seat.MaterialVariant = "BW_Leather"
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat:SetAttribute("SeatIndex", i)
	seat.Parent = model
	local nose = part(model, "SeatFront", Vector3.new(2.8, 0.5, 0.5), f * CFrame.new(0, 1.25, -1.4), leather, Enum.Material.Leather, soft)
	nose.Shape = Enum.PartType.Cylinder
	-- Back: hinged at the rear of the seat and reclined 10 degrees.
	local hinge = f * CFrame.new(0, 1, 1.45) * CFrame.Angles(math.rad(10), 0, 0)
	part(model, "Back", Vector3.new(3.2, 2.4, 0.3), hinge * CFrame.new(0, 1.2, 0.15), WALNUT, Enum.Material.Wood, { variant = "BW_Walnut" })
	part(model, "BackCushion", Vector3.new(2.9, 2, 0.35), hinge * CFrame.new(0, 1.15, -0.175), leather, Enum.Material.Leather, soft)
	local roll = part(model, "BackRoll", Vector3.new(3.2, 0.42, 0.42), hinge * CFrame.new(0, 2.4, 0.08), leather, Enum.Material.Leather, soft)
	roll.Shape = Enum.PartType.Cylinder
	for _, x in { -1.575, 1.575 } do
		part(model, "Arm", Vector3.new(0.35, 0.8, 2.7), f * CFrame.new(x, 1.4, 0.15), WALNUT, Enum.Material.Wood, { variant = "BW_Walnut" })
		local pad = part(model, "ArmPad", Vector3.new(2.7, 0.5, 0.5), f * CFrame.new(x, 1.95, 0.15) * CFrame.Angles(0, math.rad(90), 0), leather, Enum.Material.Leather, soft)
		pad.Shape = Enum.PartType.Cylinder
		ball(model, "ArmEnd", (f * CFrame.new(x, 1.95, -1.2)).Position, 0.5, leather, Enum.Material.Leather, soft)
	end
	model.PrimaryPart = seat
	model.Parent = chairs
end

-- Invisible barrier around the ring. GhostService puts it in a collision group that only spectators hit.
local barrier = Instance.new("Folder")
barrier.Name = "RingBarrier"
barrier:SetAttribute("Radius", BARRIER_RADIUS)
barrier.Parent = map
local SEGMENTS = 24
for i = 1, SEGMENTS do
	local angle = (i - 0.5) / SEGMENTS * math.pi * 2
	-- Taller than the ceiling (24), so nobody gets over it; GhostService also moves anyone found inside.
	local pos = onCircle(angle, BARRIER_RADIUS, 15)
	local width = 2 * BARRIER_RADIUS * math.tan(math.pi / SEGMENTS) + 0.4
	local wall = part(barrier, "Wall", Vector3.new(width, 30, 0.6), CFrame.lookAt(pos, Vector3.new(0, 15, 0)), BLACK)
	wall.Transparency = 1
	wall.CanQuery = false
	wall.CanTouch = false
	wall.CastShadow = false
end

-- Room shell: dark acoustic wall (radius 42) up to a dark ceiling, so only the studio lights light the set.
local walls = Instance.new("Folder")
walls.Name = "Walls"
walls.Parent = map
local WALL_SEGMENTS = 36
for i = 1, WALL_SEGMENTS do
	local angle = (i - 0.5) / WALL_SEGMENTS * math.pi * 2
	local width = 2 * FLOOR_RADIUS * math.tan(math.pi / WALL_SEGMENTS) + 0.6
	local pos = onCircle(angle, FLOOR_RADIUS, CEILING_Y / 2)
	part(walls, "Wall", Vector3.new(width, CEILING_Y, 1), CFrame.lookAt(pos, Vector3.new(0, CEILING_Y / 2, 0)), Color3.fromRGB(20, 24, 32), Enum.Material.Fabric, { variant = "BW_Acoustic" })
end
disc(walls, "Ceiling", FLOOR_RADIUS + 0.5, 1, CEILING_Y + 1, Color3.fromRGB(12, 14, 20))

-- Set walls: 8 free-standing flats on radius 31 with gaps between them (the one at +Z is the entrance by the spawn).
-- Low half: dark navy acoustic panel (the word-bubble band); walnut rail with a dim glow line at y ~10.6;
-- high half: ivory panel with a framed screen (logo / talk in turn). Every other flat has a light bar over its screen.
local set = Instance.new("Folder")
set.Name = "Set"
set.Parent = map
for k = 0, 7 do
	local angle = math.rad(22.5 + 45 * k)
	local f = CFrame.lookAt(onCircle(angle, SET_RADIUS, 0), Vector3.zero)
	local flat = Instance.new("Model")
	flat.Name = "Flat" .. (k + 1)
	part(flat, "Panel", Vector3.new(11, 10.5, 0.6), f * CFrame.new(0, 5.25, 0), NAVY, Enum.Material.Fabric, { variant = "BW_Acoustic" })
	for _, x in { -5.2, 5.2 } do
		part(flat, "Pillar", Vector3.new(0.6, 10.5, 0.9), f * CFrame.new(x, 5.25, -0.1), NAVY_DARK)
	end
	part(flat, "Base", Vector3.new(11, 0.5, 0.9), f * CFrame.new(0, 0.25, -0.1), NAVY_DARK)
	part(flat, "Rail", Vector3.new(11.4, 1, 1.1), f * CFrame.new(0, 11, -0.15), WALNUT, Enum.Material.Wood, { variant = "BW_Walnut" })
	part(flat, "RailGlow", Vector3.new(11, 0.1, 0.1), f * CFrame.new(0, 10.62, -0.72), TEAL_GLOW_DIM, Enum.Material.Neon, TRIM)
	part(flat, "Upper", Vector3.new(11, 4, 0.5), f * CFrame.new(0, 13.5, 0.05), IVORY, Enum.Material.Plaster)
	part(flat, "UpperBack", Vector3.new(11, 4, 0.1), f * CFrame.new(0, 13.5, 0.35), NAVY_DARK, nil, TRIM) -- backstage side
	part(flat, "Cap", Vector3.new(11.4, 0.6, 1.2), f * CFrame.new(0, 15.8, -0.2), WALNUT, Enum.Material.Wood, { variant = "BW_Walnut" })
	part(flat, "ScreenFrame", Vector3.new(7, 3.9, 0.3), f * CFrame.new(0, 13.5, -0.3), BLACK)
	local screen = part(flat, "Screen", Vector3.new(6.6, 3.71, 0.08), f * CFrame.new(0, 13.5, -0.48), BLACK, nil, TRIM)
	decal(screen, if k % 2 == 0 then IMAGES.screenLogo else IMAGES.screenTalk, Enum.NormalId.Front)
	if k % 2 == 1 then
		local color = if k % 4 == 1 then TEAL_GLOW else CORAL_GLOW
		local bar = part(flat, "LightBar", Vector3.new(6, 0.2, 0.4), f * CFrame.new(0, 15.35, -0.95), color, Enum.Material.Neon, TRIM)
		local wash = Instance.new("SurfaceLight")
		wash.Face = Enum.NormalId.Bottom
		wash.Range = 5
		wash.Angle = 60
		wash.Brightness = 0.6
		wash.Color = color
		wash.Parent = bar
	end
	flat.Parent = set
end
-- ON AIR sign hanging over the entrance gap.
local sign = part(set, "OnAir", Vector3.new(4.2, 1.6, 0.4), CFrame.lookAt(onCircle(0, SET_RADIUS, 17.2), Vector3.new(0, 17.2, 0)), Color3.fromRGB(120, 10, 20), nil, TRIM)
decal(sign, IMAGES.onAir, Enum.NormalId.Front)
for _, x in { -1.6, 1.6 } do
	local top = (sign.CFrame * CFrame.new(x, 0.8, 0)).Position
	tube(set, "SignCable", top, Vector3.new(top.X, CEILING_Y, top.Z), 0.06, BLACK, nil, TRIM)
end

-- Lighting truss: an octagon of triangular truss (radius 22, y 14-15.2) hung from the ceiling, with a can light on
-- each side aimed at the chairs below it. Two of the cans carry the rim lights; the rest only glow. Every other corner
-- holds a soft downlight for the spectator area.
local truss = Instance.new("Folder")
truss.Name = "Truss"
truss.Parent = map
local CHORDS = {
	{ radius = TRUSS_RADIUS, y = 15.2 },
	{ radius = TRUSS_RADIUS - 0.6, y = 14 },
	{ radius = TRUSS_RADIUS + 0.6, y = 14 },
}
local LACING = 5 -- zigzag bays per side and face
for k = 0, 7 do
	local a1, a2 = math.rad(45 * k), math.rad(45 * (k + 1))
	local ends = {}
	for c, chord in CHORDS do
		ends[c] = { onCircle(a1, chord.radius, chord.y), onCircle(a2, chord.radius, chord.y) }
		tube(truss, "Chord", ends[c][1], ends[c][2], 0.3, METAL, Enum.Material.Metal, TRIM)
	end
	for _, low in { 2, 3 } do
		for n = 0, LACING - 1 do
			local from = if n % 2 == 0 then 1 else low
			local to = if n % 2 == 0 then low else 1
			local p1 = ends[from][1]:Lerp(ends[from][2], n / LACING)
			local p2 = ends[to][1]:Lerp(ends[to][2], (n + 1) / LACING)
			tube(truss, "Lacing", p1, p2, 0.16, METAL, Enum.Material.Metal, TRIM)
		end
	end
	local corner = onCircle(a1, TRUSS_RADIUS, 14.6)
	part(truss, "Corner", Vector3.new(1.5, 1.5, 1.5), CFrame.lookAt(corner, Vector3.new(0, 14.6, 0)), METAL, Enum.Material.Metal, TRIM)
	tube(truss, "Cable", corner + Vector3.new(0, 0.75, 0), Vector3.new(corner.X, CEILING_Y, corner.Z), 0.08, BLACK, nil, TRIM)
	if k % 2 == 0 then
		-- Soft downlight for the spectator area (ambient alone leaves the floor outside the stage black).
		local down = Instance.new("SpotLight")
		down.Face = Enum.NormalId.Bottom
		down.Angle = 120
		down.Range = 22
		down.Brightness = 1.1
		down.Color = Color3.fromRGB(235, 238, 255)
		down.Parent = lightHolder(truss, "AreaLight", CFrame.new(corner - Vector3.new(0, 1.2, 0)))
	end
	-- Can light under the middle of this side.
	local mid = math.rad(45 * k + 22.5)
	local at = onCircle(mid, TRUSS_RADIUS * math.cos(math.rad(22.5)), 13.1)
	local rim = k == 1 or k == 5
	local target = if rim then Vector3.new(0, 3, 0) else onCircle(mid, CHAIR_RADIUS, 3)
	local aim = CFrame.lookAt(at, target)
	tube(truss, "Hanger", at, at + Vector3.new(0, 0.9, 0), 0.12, BLACK, nil, TRIM)
	tube(truss, "Can", (aim * CFrame.new(0, 0, 0.45)).Position, (aim * CFrame.new(0, 0, -0.55)).Position, 0.75, BLACK, Enum.Material.Metal, TRIM)
	tube(truss, "Lens", (aim * CFrame.new(0, 0, -0.55)).Position, (aim * CFrame.new(0, 0, -0.6)).Position, 0.62, Color3.fromRGB(230, 214, 190), Enum.Material.Neon, TRIM)
	if rim then
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 90
		light.Range = 26
		light.Brightness = 0.7
		light.Color = Color3.fromRGB(221, 235, 255)
		light.Parent = lightHolder(truss, "RimLight", aim)
	end
end

-- Studio lights without fixtures (so nothing hangs in front of faces): five key lights between the table and the
-- chairs, each on a pair of seats at face height (two cast shadows), and one soft fill over the table.
local lights = Instance.new("Folder")
lights.Name = "Lights"
lights.Parent = map
for k = 0, 4 do
	local angle = math.rad(18 + 72 * k)
	local key = Instance.new("SpotLight")
	key.Face = Enum.NormalId.Front
	key.Angle = 90
	key.Range = 20
	key.Brightness = 2
	key.Color = WARM_WHITE
	key.Shadows = k == 0 or k == 2
	key.Parent = lightHolder(lights, "KeyLight", CFrame.lookAt(onCircle(angle, 4.5, 10.5), onCircle(angle, CHAIR_RADIUS, 4)))
end
local fill = Instance.new("PointLight")
fill.Range = 16
fill.Brightness = 0.4
fill.Color = Color3.fromRGB(255, 248, 240)
fill.Parent = lightHolder(lights, "FillLight", CFrame.new(0, 4.5, 0))

-- Outside the ring (spectators): TV cameras on pedestals, green-room sofas and a bar seen through the far gap.
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = map
for _, deg in { 45, 135, 225, 315 } do
	local f = CFrame.lookAt(onCircle(math.rad(deg), 18.5, 0), Vector3.zero)
	local camera = Instance.new("Model")
	camera.Name = "TVCamera"
	puck(camera, "Base", f * CFrame.new(0, 0.1, 0), 1.8, 0.2, BLACK, Enum.Material.Metal)
	puck(camera, "Pedestal", f * CFrame.new(0, 1.9, 0), 0.36, 3.4, Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	part(camera, "Head", Vector3.new(0.8, 0.3, 0.8), f * CFrame.new(0, 3.75, 0), BLACK, Enum.Material.Metal, TRIM)
	part(camera, "Body", Vector3.new(1, 1.1, 2), f * CFrame.new(0, 4.45, 0), Color3.fromRGB(30, 30, 36))
	tube(camera, "Lens", (f * CFrame.new(0, 4.45, -0.95)).Position, (f * CFrame.new(0, 4.45, -1.95)).Position, 0.75, BLACK, Enum.Material.Metal, TRIM)
	tube(camera, "Glass", (f * CFrame.new(0, 4.45, -1.95)).Position, (f * CFrame.new(0, 4.45, -1.99)).Position, 0.6, Color3.fromRGB(14, 20, 34), nil, TRIM) -- dark, so it never reads as a light
	part(camera, "Viewfinder", Vector3.new(0.5, 0.45, 0.6), f * CFrame.new(-0.55, 5.1, 0.4), BLACK, nil, TRIM)
	for _, x in { -0.3, 0.3 } do
		tube(camera, "PanBar", (f * CFrame.new(x, 4.1, 1)).Position, (f * CFrame.new(x * 2, 3.6, 2.4)).Position, 0.1, CHROME, Enum.Material.Metal, TRIM)
	end
	camera.Parent = decor
end
for n, deg in { 30, 90, 150, 210, 270, 330 } do
	local f = CFrame.lookAt(onCircle(math.rad(deg), 25, 0), Vector3.zero)
	local sofa = Instance.new("Model")
	sofa.Name = "Sofa"
	part(sofa, "Plinth", Vector3.new(8, 0.2, 2.8), f * CFrame.new(0, 0.1, 0), BLACK)
	part(sofa, "Base", Vector3.new(8.4, 1.2, 3.2), f * CFrame.new(0, 0.8, 0), NAVY, Enum.Material.Fabric)
	part(sofa, "Back", Vector3.new(8.4, 2, 0.8), f * CFrame.new(0, 2.2, 1.2), NAVY, Enum.Material.Fabric)
	for _, x in { -4.2, 4.2 } do
		part(sofa, "Arm", Vector3.new(0.8, 1.9, 3.2), f * CFrame.new(x, 1.15, 0), NAVY, Enum.Material.Fabric)
	end
	for _, x in { -2.7, 0, 2.7 } do
		part(sofa, "Cushion", Vector3.new(2.6, 0.45, 2.6), f * CFrame.new(x, 1.62, -0.15), if n % 2 == 1 then TEAL_DARK else Color3.fromRGB(150, 140, 125), Enum.Material.Leather, { variant = "BW_Leather", shadow = false })
		local s = Instance.new("Seat")
		s.Anchored = true
		s.Size = Vector3.new(2.4, 0.4, 2.6)
		s.CFrame = f * CFrame.new(x, 1.9, -0.2)
		s.Transparency = 1
		s.Parent = sofa
	end
	sofa.Parent = decor
end
local barFacing = CFrame.lookAt(onCircle(math.pi, 36, 0), Vector3.zero)
part(decor, "BarCounter", Vector3.new(12, 3.4, 2.2), barFacing * CFrame.new(0, 1.9, 0), WALNUT, Enum.Material.Wood, { variant = "BW_Walnut" })
part(decor, "BarKick", Vector3.new(11.6, 0.2, 2), barFacing * CFrame.new(0, 0.1, 0), BLACK)
part(decor, "BarTop", Vector3.new(12.4, 0.25, 2.8), barFacing * CFrame.new(0, 3.725, 0), Color3.fromRGB(25, 25, 28), Enum.Material.Marble, { reflectance = 0.1 })
part(decor, "BarShelf", Vector3.new(10, 0.2, 0.8), barFacing * CFrame.new(0, 6.2, 2.8), WALNUT, Enum.Material.Wood, { variant = "BW_Walnut" })
for n = 0, 5 do
	local bottle = Color3.fromRGB(40 + n * 25, 90, 70 + n * 15)
	puck(decor, "Bottle", barFacing * CFrame.new(-3.5 + n * 1.4, 6.85, 2.8), 0.4, 1.1, bottle, Enum.Material.Glass, { solid = false, shadow = false, reflectance = 0.2 })
end
for _, x in { -3.5, 0, 3.5 } do
	puck(decor, "StoolFoot", barFacing * CFrame.new(x, 0.05, -2), 1.2, 0.1, CHROME, Enum.Material.Metal)
	puck(decor, "StoolPole", barFacing * CFrame.new(x, 1.2, -2), 0.2, 2.2, CHROME, Enum.Material.Metal, TRIM)
	puck(decor, "StoolSeat", barFacing * CFrame.new(x, 2.42, -2), 1.1, 0.25, TEAL, Enum.Material.Leather, { variant = "BW_Leather" })
end

local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(8, 0.2, 8)
spawn.CFrame = CFrame.new(0, 0.1, 26)
spawn.Color = Color3.fromRGB(34, 84, 92)
spawn.Material = Enum.Material.Carpet
spawn.MaterialVariant = "BW_Carpet"
spawn.Duration = 0
spawn.Parent = map

map.Parent = workspace

local parts, lightCount = 0, 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("Light") then
		lightCount += 1
	end
end
return string.format("LoungeMap built: %d chairs, barrier radius %d, %d parts, %d lights", #chairs:GetChildren(), BARRIER_RADIUS, parts, lightCount)
