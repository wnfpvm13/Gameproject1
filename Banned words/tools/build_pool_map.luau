-- Grey-box pool map for 금칙어 게임 Korean. Run in Studio's Edit datamodel; rebuilds workspace.PoolMap from scratch.
-- Layout (studs): deck 120 x 90 with top at y = 0, pool hole 44 x 28 at the centre, water surface at y = -1.5,
-- 10 lounge chairs in one row along the north edge facing the pool (panel-show seating, 5 studs apart),
-- a fixed show camera over the pool looking back at the row, spawn behind the row.

local DECK = Vector2.new(120, 90)
local HOLE = Vector2.new(44, 28)
local POOL_DEPTH = 9
local CHAIR_COUNT = 10
local ROW_SPACING = 5
local ROW_Z = -HOLE.Y / 2 - 4.5
local CAMERA_POS = Vector3.new(0, 7, 10)
local CAMERA_FOV = 55

local DECK_COLOR = Color3.fromRGB(226, 214, 190)
local COPING_COLOR = Color3.fromRGB(245, 245, 240)
local TILE_COLOR = Color3.fromRGB(110, 190, 225)
local FRAME_COLOR = Color3.fromRGB(250, 250, 250)
local CUSHIONS = {
	Color3.fromRGB(255, 140, 120), Color3.fromRGB(255, 200, 90), Color3.fromRGB(120, 200, 160),
	Color3.fromRGB(120, 170, 240), Color3.fromRGB(200, 150, 230),
}

for _, name in { "PoolMap", "Baseplate", "Spawn", "SttProbe" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
workspace.Terrain:Clear()

local map = Instance.new("Folder")
map.Name = "PoolMap"

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

-- Deck: four slabs around the hole, top face at y = 0.
local deck = Instance.new("Folder")
deck.Name = "Deck"
deck.Parent = map
local sideDepth = (DECK.Y - HOLE.Y) / 2
local sideWidth = (DECK.X - HOLE.X) / 2
part(deck, "North", Vector3.new(DECK.X, 2, sideDepth), CFrame.new(0, -1, -(HOLE.Y + sideDepth) / 2), DECK_COLOR, Enum.Material.Concrete)
part(deck, "South", Vector3.new(DECK.X, 2, sideDepth), CFrame.new(0, -1, (HOLE.Y + sideDepth) / 2), DECK_COLOR, Enum.Material.Concrete)
part(deck, "West", Vector3.new(sideWidth, 2, HOLE.Y), CFrame.new(-(HOLE.X + sideWidth) / 2, -1, 0), DECK_COLOR, Enum.Material.Concrete)
part(deck, "East", Vector3.new(sideWidth, 2, HOLE.Y), CFrame.new((HOLE.X + sideWidth) / 2, -1, 0), DECK_COLOR, Enum.Material.Concrete)

-- Coping: white rim around the pool edge.
local rim = 1.5
part(deck, "CopingN", Vector3.new(HOLE.X + rim * 2, 0.4, rim), CFrame.new(0, 0.2, -HOLE.Y / 2 - rim / 2), COPING_COLOR)
part(deck, "CopingS", Vector3.new(HOLE.X + rim * 2, 0.4, rim), CFrame.new(0, 0.2, HOLE.Y / 2 + rim / 2), COPING_COLOR)
part(deck, "CopingW", Vector3.new(rim, 0.4, HOLE.Y), CFrame.new(-HOLE.X / 2 - rim / 2, 0.2, 0), COPING_COLOR)
part(deck, "CopingE", Vector3.new(rim, 0.4, HOLE.Y), CFrame.new(HOLE.X / 2 + rim / 2, 0.2, 0), COPING_COLOR)

-- Pool basin.
local basin = Instance.new("Folder")
basin.Name = "Basin"
basin.Parent = map
local wallH = POOL_DEPTH - 2
local wallY = -2 - wallH / 2
part(basin, "Floor", Vector3.new(HOLE.X, 1, HOLE.Y), CFrame.new(0, -POOL_DEPTH - 0.5, 0), TILE_COLOR, Enum.Material.Glass)
part(basin, "WallN", Vector3.new(HOLE.X, wallH, 1), CFrame.new(0, wallY, -HOLE.Y / 2 + 0.5), TILE_COLOR, Enum.Material.Glass)
part(basin, "WallS", Vector3.new(HOLE.X, wallH, 1), CFrame.new(0, wallY, HOLE.Y / 2 - 0.5), TILE_COLOR, Enum.Material.Glass)
part(basin, "WallW", Vector3.new(1, wallH, HOLE.Y - 2), CFrame.new(-HOLE.X / 2 + 0.5, wallY, 0), TILE_COLOR, Enum.Material.Glass)
part(basin, "WallE", Vector3.new(1, wallH, HOLE.Y - 2), CFrame.new(HOLE.X / 2 - 0.5, wallY, 0), TILE_COLOR, Enum.Material.Glass)

local center = part(map, "PoolCenter", Vector3.new(1, 1, 1), CFrame.new(0, -1.5, 0), TILE_COLOR)
center.Transparency = 1
center.CanCollide = false
center.CanQuery = false
center.CanTouch = false

-- Invisible fence at the deck edge so nobody walks off the map.
local fence = Instance.new("Folder")
fence.Name = "Fence"
fence.Parent = map
for _, spec in {
	{ Vector3.new(DECK.X, 12, 1), Vector3.new(0, 6, -DECK.Y / 2) },
	{ Vector3.new(DECK.X, 12, 1), Vector3.new(0, 6, DECK.Y / 2) },
	{ Vector3.new(1, 12, DECK.Y), Vector3.new(-DECK.X / 2, 6, 0) },
	{ Vector3.new(1, 12, DECK.Y), Vector3.new(DECK.X / 2, 6, 0) },
} do
	local f = part(fence, "Wall", spec[1], CFrame.new(spec[2]), DECK_COLOR)
	f.Transparency = 1
end

-- Lounge chairs in a row on the north deck, all facing the pool (+Z), numbered left to right as seen from the camera.
local chairs = Instance.new("Folder")
chairs.Name = "Chairs"
chairs.Parent = map
for i = 1, CHAIR_COUNT do
	local pos = Vector3.new((i - (CHAIR_COUNT + 1) / 2) * ROW_SPACING, 0, ROW_Z)
	local facing = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
	local model = Instance.new("Model")
	model.Name = string.format("Chair%02d", i)
	local cushion = CUSHIONS[(i - 1) % #CUSHIONS + 1]

	part(model, "Base", Vector3.new(3, 1, 3.4), facing * CFrame.new(0, 0.5, 0), FRAME_COLOR)
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(2.8, 0.5, 2.8)
	seat.CFrame = facing * CFrame.new(0, 1.25, 0)
	seat.Color = cushion
	seat.Material = Enum.Material.SmoothPlastic
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat:SetAttribute("SeatIndex", i)
	seat.Parent = model
	-- Backrest sits behind the occupant (away from the pool) and leans back.
	part(model, "Back", Vector3.new(2.8, 3, 0.5), facing * CFrame.new(0, 2.7, 1.5) * CFrame.Angles(math.rad(-15), 0, 0), cushion)
	local spring = part(model, "Spring", Vector3.new(1.2, 0.6, 1.2), facing * CFrame.new(0, 0.9, 0), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
	spring.Shape = Enum.PartType.Cylinder
	spring.CFrame = facing * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	model.PrimaryPart = seat
	model.Parent = chairs
end

-- Parasols near the deck corners.
local deco = Instance.new("Folder")
deco.Name = "Decor"
deco.Parent = map
for _, p in { Vector3.new(-50, 0, -36), Vector3.new(50, 0, -36), Vector3.new(-50, 0, 36), Vector3.new(50, 0, 36) } do
	part(deco, "Pole", Vector3.new(0.4, 9, 0.4), CFrame.new(p + Vector3.new(0, 4.5, 0)), FRAME_COLOR)
	local top = part(deco, "Canopy", Vector3.new(1, 10, 10), CFrame.new(p + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 120, 110), Enum.Material.Fabric)
	top.Shape = Enum.PartType.Cylinder
end

-- Show camera: clients use this CFrame (and FieldOfView attribute) while a round is running.
local cameraPoint = part(map, "ShowCamera", Vector3.new(1, 1, 1), CFrame.lookAt(CAMERA_POS, Vector3.new(0, 3.5, ROW_Z)), FRAME_COLOR)
cameraPoint.Transparency = 1
cameraPoint.CanCollide = false
cameraPoint.CanQuery = false
cameraPoint.CanTouch = false
cameraPoint:SetAttribute("FieldOfView", CAMERA_FOV)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(10, 0.2, 10)
spawn.CFrame = CFrame.new(0, 0.1, -38)
spawn.Color = Color3.fromRGB(120, 200, 160)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Parent = map

map.Parent = workspace

-- Water fills the basin from the floor up to y = -1.5 (Terrain water = real swimming).
workspace.Terrain:FillBlock(CFrame.new(0, (-POOL_DEPTH - 1.5) / 2, 0), Vector3.new(HOLE.X - 2, POOL_DEPTH - 1.5, HOLE.Y - 2), Enum.Material.Water)
workspace.Terrain.WaterColor = Color3.fromRGB(60, 170, 220)
workspace.Terrain.WaterTransparency = 0.6

game:GetService("Lighting").ClockTime = 14
return string.format("PoolMap built: %d chairs", #chairs:GetChildren())
