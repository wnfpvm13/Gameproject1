-- Round party lounge for 금칙어 게임 Korean (V2, owner 2026-10-20). Run in Studio's Edit datamodel;
-- rebuilds workspace.LoungeMap from scratch and removes the old PoolMap.
-- Layout (studs, floor top at y = 0):
--   centre table, 10 armchairs on a ring (radius 10, facing the centre, ~6.3 studs apart),
--   a neon ring on the carpet, an invisible RingBarrier (radius 14) that only ghosts/spectators collide with,
--   sofas / lamps / bar for ghosts in the outer lounge, round wall at radius 42, spawn outside the ring.
-- Clients read LoungeMap.Center and LoungeMap.CameraRig (Back/Up/LookY/HalfAngle) for the seated camera.

local FLOOR_RADIUS = 42
local CHAIR_COUNT = 10
local CHAIR_RADIUS = 10
local BARRIER_RADIUS = 14
local CARPET_RADIUS = 15.5

local FLOOR_COLOR = Color3.fromRGB(70, 58, 72)
local CARPET_COLOR = Color3.fromRGB(150, 60, 70)
local NEON_COLOR = Color3.fromRGB(255, 190, 90)
local WALL_COLOR = Color3.fromRGB(48, 40, 58)
local WOOD = Color3.fromRGB(120, 80, 55)
local CUSHIONS = {
	Color3.fromRGB(255, 140, 120), Color3.fromRGB(255, 200, 90), Color3.fromRGB(120, 200, 160),
	Color3.fromRGB(120, 170, 240), Color3.fromRGB(200, 150, 230),
}

for _, name in { "LoungeMap", "PoolMap", "Baseplate", "Spawn", "SttProbe" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
workspace.Terrain:Clear()

local map = Instance.new("Folder")
map.Name = "LoungeMap"

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Flat disc (cylinder standing up) with its top face at `topY`.
local function disc(parent: Instance, name: string, radius: number, thickness: number, topY: number, color: Color3, material: Enum.Material?): Part
	local d = part(parent, name, Vector3.new(thickness, radius * 2, radius * 2), CFrame.new(0, topY - thickness / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	d.Shape = Enum.PartType.Cylinder
	return d
end

local function marker(name: string, cframe: CFrame): Part
	local m = part(map, name, Vector3.new(1, 1, 1), cframe, NEON_COLOR)
	m.Transparency = 1
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	return m
end

-- Floor, carpet and the neon ring (a slightly bigger neon disc peeking out under the carpet).
local floor = Instance.new("Folder")
floor.Name = "Floor"
floor.Parent = map
disc(floor, "Floor", FLOOR_RADIUS, 2, 0, FLOOR_COLOR, Enum.Material.WoodPlanks)
disc(floor, "NeonRing", CARPET_RADIUS + 0.6, 0.12, 0.1, NEON_COLOR, Enum.Material.Neon)
disc(floor, "Carpet", CARPET_RADIUS, 0.14, 0.14, CARPET_COLOR, Enum.Material.Fabric)

marker("Center", CFrame.new(0, 0, 0))
local rig = marker("CameraRig", CFrame.new(0, 0, 0))
rig:SetAttribute("Back", 9)
rig:SetAttribute("Up", 11)
rig:SetAttribute("LookY", 6)
rig:SetAttribute("HalfAngle", 42)

-- Centre table with a glowing centrepiece (low enough not to block faces across the ring).
local table_ = Instance.new("Model")
table_.Name = "CenterTable"
disc(table_, "Top", 3, 0.4, 2, WOOD, Enum.Material.Wood)
local leg = part(table_, "Leg", Vector3.new(1, 1.8, 1), CFrame.new(0, 0.9, 0), WOOD, Enum.Material.Wood)
leg.Shape = Enum.PartType.Cylinder
leg.CFrame = CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90))
leg.Size = Vector3.new(1.8, 1, 1)
local glow = part(table_, "Centerpiece", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 2.45, 0), NEON_COLOR, Enum.Material.Neon)
glow.Shape = Enum.PartType.Ball
local light = Instance.new("PointLight")
light.Color = NEON_COLOR
light.Range = 18
light.Brightness = 1.5
light.Parent = glow
table_.Parent = map

-- Armchairs on the ring, numbered clockwise (seen from above), each facing the centre.
local chairs = Instance.new("Folder")
chairs.Name = "Chairs"
chairs.Parent = map
for i = 1, CHAIR_COUNT do
	local angle = (i - 1) / CHAIR_COUNT * math.pi * 2
	local pos = Vector3.new(math.sin(angle) * CHAIR_RADIUS, 0, math.cos(angle) * CHAIR_RADIUS)
	local facing = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	local model = Instance.new("Model")
	model.Name = string.format("Chair%02d", i)
	local cushion = CUSHIONS[(i - 1) % #CUSHIONS + 1]
	part(model, "Base", Vector3.new(3.2, 1, 3.2), facing * CFrame.new(0, 0.5, 0), WOOD, Enum.Material.Wood)
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(2.8, 0.5, 2.8)
	seat.CFrame = facing * CFrame.new(0, 1.25, 0)
	seat.Color = cushion
	seat.Material = Enum.Material.Fabric
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat:SetAttribute("SeatIndex", i)
	seat.Parent = model
	-- Back on the outer side (behind the occupant), short so the camera behind sees over it.
	part(model, "Back", Vector3.new(3.2, 2.4, 0.6), facing * CFrame.new(0, 2.4, 1.4) * CFrame.Angles(math.rad(-10), 0, 0), cushion, Enum.Material.Fabric)
	part(model, "ArmL", Vector3.new(0.5, 0.9, 3), facing * CFrame.new(-1.6, 1.6, 0), cushion, Enum.Material.Fabric)
	part(model, "ArmR", Vector3.new(0.5, 0.9, 3), facing * CFrame.new(1.6, 1.6, 0), cushion, Enum.Material.Fabric)
	model.PrimaryPart = seat
	model.Parent = chairs
end

-- Invisible barrier around the ring. GhostService puts it in a collision group that only ghosts/spectators hit.
local barrier = Instance.new("Folder")
barrier.Name = "RingBarrier"
barrier:SetAttribute("Radius", BARRIER_RADIUS)
barrier.Parent = map
local SEGMENTS = 24
for i = 1, SEGMENTS do
	local angle = (i - 0.5) / SEGMENTS * math.pi * 2
	-- Tall (30) so nobody gets over it from the sofas or lamps; GhostService also moves anyone found inside.
	local pos = Vector3.new(math.sin(angle) * BARRIER_RADIUS, 15, math.cos(angle) * BARRIER_RADIUS)
	local width = 2 * BARRIER_RADIUS * math.tan(math.pi / SEGMENTS) + 0.4
	local wall = part(barrier, "Wall", Vector3.new(width, 30, 0.6), CFrame.lookAt(pos, Vector3.new(0, 15, 0)), NEON_COLOR)
	wall.Transparency = 1
	wall.CanQuery = false
	wall.CanTouch = false
	wall.CastShadow = false
end

-- Outer wall (round), with a warm light strip on top.
local walls = Instance.new("Folder")
walls.Name = "Walls"
walls.Parent = map
local WALL_SEGMENTS = 36
for i = 1, WALL_SEGMENTS do
	local angle = (i - 0.5) / WALL_SEGMENTS * math.pi * 2
	local width = 2 * FLOOR_RADIUS * math.tan(math.pi / WALL_SEGMENTS) + 0.6
	local pos = Vector3.new(math.sin(angle) * FLOOR_RADIUS, 8, math.cos(angle) * FLOOR_RADIUS)
	local cf = CFrame.lookAt(pos, Vector3.new(0, 8, 0))
	part(walls, "Wall", Vector3.new(width, 16, 1), cf, WALL_COLOR, Enum.Material.Plaster)
	part(walls, "Strip", Vector3.new(width, 0.4, 0.3), cf * CFrame.new(0, 7.6, -0.6), NEON_COLOR, Enum.Material.Neon)
end

-- Outer lounge for ghosts and spectators: sofas facing the ring, standing lamps, a bar counter.
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = map
local SOFA_ANGLES = { 30, 90, 150, 210, 270, 330 }
for n, deg in SOFA_ANGLES do
	local angle = math.rad(deg)
	local pos = Vector3.new(math.sin(angle) * 30, 0, math.cos(angle) * 30)
	local facing = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	local color = CUSHIONS[(n - 1) % #CUSHIONS + 1]
	local sofa = Instance.new("Model")
	sofa.Name = "Sofa"
	part(sofa, "Base", Vector3.new(9, 1.6, 3.6), facing * CFrame.new(0, 0.8, 0), color, Enum.Material.Fabric)
	part(sofa, "Back", Vector3.new(9, 2.6, 1), facing * CFrame.new(0, 2.6, 1.4), color, Enum.Material.Fabric)
	for x = -2.5, 2.5, 2.5 do
		local s = Instance.new("Seat")
		s.Anchored = true
		s.Size = Vector3.new(2.4, 0.4, 2.6)
		s.CFrame = facing * CFrame.new(x, 1.8, -0.2)
		s.Transparency = 1
		s.Parent = sofa
	end
	sofa.Parent = decor
end
for i = 1, 8 do
	local angle = (i - 0.5) / 8 * math.pi * 2
	local pos = Vector3.new(math.sin(angle) * 22, 0, math.cos(angle) * 22)
	part(decor, "LampPole", Vector3.new(0.4, 7, 0.4), CFrame.new(pos + Vector3.new(0, 3.5, 0)), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	local shade = part(decor, "LampShade", Vector3.new(2, 1.6, 2), CFrame.new(pos + Vector3.new(0, 7.4, 0)), Color3.fromRGB(255, 230, 180), Enum.Material.Neon)
	local lampLight = Instance.new("PointLight")
	lampLight.Color = Color3.fromRGB(255, 210, 160)
	lampLight.Range = 20
	lampLight.Brightness = 1.2
	lampLight.Parent = shade
end
local barAngle = math.rad(180)
local barPos = Vector3.new(math.sin(barAngle) * 36, 0, math.cos(barAngle) * 36)
local barFacing = CFrame.lookAt(barPos, Vector3.new(0, 0, 0))
part(decor, "BarCounter", Vector3.new(16, 3.6, 2.4), barFacing * CFrame.new(0, 1.8, 0), WOOD, Enum.Material.Wood)
part(decor, "BarTop", Vector3.new(16.4, 0.3, 2.8), barFacing * CFrame.new(0, 3.75, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Marble)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(8, 0.2, 8)
spawn.CFrame = CFrame.new(0, 0.1, 26)
spawn.Color = Color3.fromRGB(120, 200, 160)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Duration = 0
spawn.Parent = map

map.Parent = workspace

local lighting = game:GetService("Lighting")
lighting.ClockTime = 18.6
lighting.Ambient = Color3.fromRGB(90, 80, 95)
lighting.OutdoorAmbient = Color3.fromRGB(120, 110, 130)
lighting.Brightness = 2
return string.format("LoungeMap built: %d chairs, barrier radius %d", #chairs:GetChildren(), BARRIER_RADIUS)
