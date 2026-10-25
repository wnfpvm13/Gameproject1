--!strict
-- Builds the arena once on the server, from ArenaLayout (Config.Arena): the trains side by side, each car by its kind
-- (a locomotive with a round boiler, a chimney and a cab, a low coal tender, boxcars, a flatcar's low deck with crates
-- to climb, a caboose with a lookout on top), all anchored and solid to stand on; the planks between the trains; the
-- sand; and the waiting room floating over the middle (where new characters spawn and the knocked out watch), with a
-- glass square in its floor. Only what is stood on or bumped into: the clients draw everything else on top (wheels,
-- doors, windows, smoke, the canyon, the stands' balloons: CarDecor, LocomotiveDecor, Scenery, Canyon, Stands). The
-- sand is solid, for everyone the same: a fighter who falls off lands on it, already out, and is left behind
-- (FallDrift, Sandbags); it reaches under the whole canyon the clients draw.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local CanyonLayout = require(shared:WaitForChild("CanyonLayout"))

local ArenaBuilder = {}

export type Arena = {
	folder: Folder,
	layout: ArenaLayout.Layout, -- where everything is
	spots: { ArenaLayout.Spot }, -- where players appear for a round
	fallLine: number, -- feet below this have fallen off
	waitingSpot: CFrame, -- where the knocked out and the waiting stand
}

local STACK_CAP = 0.37 -- the chimney's flared top, as a share of the chimney's height over the boiler

-- A car body from Config.Arena.BodyBottom up to just under `top` and a plate on top (the floor players stand on), as
-- wide as a roof.
local function addBody(parent: Instance, x: number, place: ArenaLayout.CarPlace, top: number, bodyColor: Color3, topColor: Color3, material: Enum.Material)
	local a = Config.Arena
	local body = PartUtil.solidBlock("Body", Vector3.new(a.RoofWidth - 2 * a.BodyInset, top - 0.3 - a.BodyBottom, place.length), bodyColor, material, parent)
	body.CFrame = CFrame.new(x, (top - 0.3 + a.BodyBottom) / 2, place.middle)
	local roof = PartUtil.solidBlock("Roof", Vector3.new(a.RoofWidth, 0.3, place.length), topColor, Enum.Material.Metal, parent)
	roof.CFrame = CFrame.new(x, top - 0.15, place.middle)
end

-- A solid box standing on the car's top: its middle `along` the car.
local function addBox(parent: Instance, name: string, x: number, place: ArenaLayout.CarPlace, along: number, size: Vector3, color: Color3)
	local box = PartUtil.solidBlock(name, size, color, Enum.Material.WoodPlanks, parent)
	box.CFrame = CFrame.new(x, place.roof + size.Y / 2, place.front + place.length * along)
end

-- The locomotive: a round boiler in front (its top a narrow ridge to fight on) with a chimney on it (its flared top a
-- small perch), a tall cab behind (its flat roof the high spot). Shaped from the same fields ArenaLayout reads: the
-- cab from `roofFrom`, the boiler over the front share `boiler.to`, `boiler.width` round with its top at `boiler.top`,
-- the chimney `stack.width` round at `stack.along`, its top `stack.height` over the boiler's.
local function addLocomotive(parent: Instance, x: number, place: ArenaLayout.CarPlace, kind: ArenaLayout.Kind, boilerSpec: { to: number, top: number, width: number })
	local a = Config.Arena
	local cabLength = place.length * (1 - (kind.roofFrom or 0))
	local boilerLength = place.length * boilerSpec.to
	local boilerDiameter = boilerSpec.width
	local frame = PartUtil.solidBlock("Frame", Vector3.new(a.LocomotiveFrame, 1, place.length), a.Colors.Cab, Enum.Material.Metal, parent)
	frame.CFrame = CFrame.new(x, a.BodyBottom + 0.5, place.middle)
	local boiler = PartUtil.solidBlock("Boiler", Vector3.new(boilerLength, boilerDiameter, boilerDiameter), a.Colors.Boiler, Enum.Material.Metal, parent)
	boiler.Shape = Enum.PartType.Cylinder -- along its own X: turned to lie along the track
	boiler.CFrame = CFrame.new(x, boilerSpec.top - boilerDiameter / 2, place.front + boilerLength / 2) * CFrame.Angles(0, math.pi / 2, 0)
	local cab = PartUtil.solidBlock("Cab", Vector3.new(a.RoofWidth - 2 * a.BodyInset, place.roof - 0.3 - a.BodyBottom, cabLength), a.Colors.Cab, Enum.Material.Metal, parent)
	cab.CFrame = CFrame.new(x, (place.roof - 0.3 + a.BodyBottom) / 2, place.back - cabLength / 2)
	local cabRoof = PartUtil.solidBlock("CabRoof", Vector3.new(a.RoofWidth, 0.3, cabLength), a.Colors.Roof, Enum.Material.Metal, parent)
	cabRoof.CFrame = CFrame.new(x, place.roof - 0.15, place.back - cabLength / 2)
	local stack = kind.stack
	if stack then
		-- A pipe from inside the boiler up to a flared cap, both round about their own X, stood up.
		local z = place.front + place.length * stack.along
		local top = boilerSpec.top + stack.height
		local capHeight = stack.height * STACK_CAP
		local pipeBottom = boilerSpec.top - 1
		local pipe = PartUtil.solidBlock("Stack", Vector3.new(top - capHeight - pipeBottom, stack.width * a.StackPipe, stack.width * a.StackPipe), a.Colors.Cab, Enum.Material.Metal, parent)
		pipe.Shape = Enum.PartType.Cylinder
		pipe.CFrame = CFrame.new(x, (pipeBottom + top - capHeight) / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
		local cap = PartUtil.solidBlock("StackCap", Vector3.new(capHeight, stack.width, stack.width), a.Colors.Cab, Enum.Material.Metal, parent)
		cap.Shape = Enum.PartType.Cylinder
		cap.CFrame = CFrame.new(x, top - capHeight / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
	end
end

-- One car of any kind, at train line x.
local function addCar(parent: Instance, x: number, place: ArenaLayout.CarPlace)
	local a = Config.Arena
	local kind = a.CarKinds[place.kind]
	local colors = a.Colors
	if kind.boiler then
		addLocomotive(parent, x, place, kind, kind.boiler)
	elseif place.kind == "Tender" then
		addBody(parent, x, place, place.roof, colors.Tender, colors.Coal, Enum.Material.Metal)
	elseif place.kind == "Flatcar" then
		addBody(parent, x, place, place.roof, colors.Flatcar, colors.Flatcar, Enum.Material.WoodPlanks)
	elseif place.kind == "Caboose" then
		addBody(parent, x, place, place.roof, colors.Caboose, colors.Roof, Enum.Material.WoodPlanks)
	else
		addBody(parent, x, place, place.roof, colors.Boxcar, colors.Roof, Enum.Material.WoodPlanks)
	end
	local crates: { ArenaLayout.Box } = kind.crates or {}
	for _, crate in crates do
		addBox(parent, "Crate", x, place, crate.along, Vector3.new(crate.width, crate.height, crate.length), colors.Crate)
	end
	local cupola = kind.cupola
	if cupola then
		local length = place.length * (cupola.to - cupola.from)
		addBox(parent, "Cupola", x, place, (cupola.from + cupola.to) / 2, Vector3.new(cupola.width, cupola.height, length), colors.Caboose)
	end
end

-- The sand: one wide slab under the whole canyon the clients draw (CanyonLayout.ground), its top at
-- Config.Arena.GroundY.
local function addGround(parent: Instance)
	local halfWidth, ahead, behind = CanyonLayout.ground(Config.Canyon)
	local sand = PartUtil.solidBlock("Sand", Vector3.new(halfWidth * 2, 1, ahead + behind), Config.Run.Colors.Sand, Enum.Material.Sand, parent)
	sand.CFrame = CFrame.new(0, Config.Arena.GroundY - 0.5, (behind - ahead) / 2)
end

-- The waiting room: a floor with high glass walls high over the middle, and the spawn point on it. The middle of the
-- floor is a glass square (as solid as the rest) to look down on the trains through.
local function addWaitingRoom(parent: Instance): CFrame
	local a = Config.Arena
	local room = Instance.new("Model")
	room.Name = Names.WaitingRoom
	local y = a.WaitingRoomHeight
	local size = a.WaitingRoomSize
	local window = a.WaitingRoomWindow
	local band = (size - window) / 2 -- the wooden floor around the glass
	for _, side in { -1, 1 } do
		local strip = PartUtil.solidBlock("Floor", Vector3.new(size, 1, band), a.Colors.Room, Enum.Material.WoodPlanks, room)
		strip.CFrame = CFrame.new(0, y - 0.5, side * (window + band) / 2)
		local beside = PartUtil.solidBlock("Floor", Vector3.new(band, 1, window), a.Colors.Room, Enum.Material.WoodPlanks, room)
		beside.CFrame = CFrame.new(side * (window + band) / 2, y - 0.5, 0)
	end
	local glass = PartUtil.solidBlock("FloorGlass", Vector3.new(window, 1, window), a.Colors.Glass, Enum.Material.Glass, room)
	glass.CFrame = CFrame.new(0, y - 0.5, 0)
	glass.Transparency = 0.55
	for _, side in { -1, 1 } do
		local wall = a.WaitingRoomWall
		local wallX = PartUtil.solidBlock("Wall", Vector3.new(1, wall, size), a.Colors.Room, Enum.Material.Glass, room)
		wallX.CFrame = CFrame.new(side * (size / 2 + 0.5), y + wall / 2, 0)
		wallX.Transparency = 0.8
		local wallZ = PartUtil.solidBlock("Wall", Vector3.new(size, wall, 1), a.Colors.Room, Enum.Material.Glass, room)
		wallZ.CFrame = CFrame.new(0, y + wall / 2, side * (size / 2 + 0.5))
		wallZ.Transparency = 0.8
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no force field
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CFrame = CFrame.new(0, y + 0.2, 0)
	spawn.Parent = room
	for _, part in room:GetDescendants() do
		if part:IsA("BasePart") then
			part.CastShadow = false -- a box floating in the late sun would throw a big square shadow on the trains
		end
	end
	room.Parent = parent
	return CFrame.new(0, y + 3, 0)
end

function ArenaBuilder.build(): Arena
	local a = Config.Arena
	local old = Workspace:FindFirstChild(Names.ArenaFolder)
	if old then
		old:Destroy()
	end
	local folder = PartUtil.folder(Workspace, Names.ArenaFolder)
	local layout = ArenaLayout.layout(a, Config.Fall.Margin)
	for i, train in layout.trains do
		local model = Instance.new("Model")
		model.Name = "Train" .. i
		for _, place in train.cars do
			addCar(model, train.x, place)
		end
		model.Parent = folder
	end
	for _, plank in layout.planks do
		local part = PartUtil.solidBlock("Plank", Vector3.new(plank.length, a.PlankThickness, a.PlankWidth), a.Colors.Plank, Enum.Material.WoodPlanks, folder)
		part.CFrame = CFrame.new(plank.x, plank.top + a.PlankThickness / 2, plank.z)
	end
	addGround(folder)
	local waitingSpot = addWaitingRoom(folder)
	return {
		folder = folder,
		layout = layout,
		spots = layout.spots,
		fallLine = layout.fallLine,
		waitingSpot = waitingSpot,
	}
end

return ArenaBuilder
