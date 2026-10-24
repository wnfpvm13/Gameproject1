--!strict
-- Builds the arena once on the server: the big trains side by side (boxcars and a locomotive with a round boiler and
-- a cab, all anchored and solid to stand on), the planks between them, and the waiting room floating over the middle
-- (where new characters spawn and the knocked out watch). The sand under
-- the trains is solid, for everyone the same (built here, not by the clients): a fighter who falls off lands on it,
-- already out, and is left behind (FallDrift, Sandbags); the clients draw the rails and scenery sliding over it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))

local ArenaBuilder = {}

export type Arena = {
	folder: Folder,
	spots: { ArenaLayout.Spot }, -- where players appear for a round
	fallLine: number, -- feet below this have fallen off
	waitingSpot: CFrame, -- where the knocked out and the waiting stand
}

local WHEEL_RADIUS = 1.4

-- Wheels along one side of a car body (drawn only).
local function addWheels(parent: Instance, x: number, place: ArenaLayout.CarPlace, halfWidth: number)
	local a = Config.Arena
	for _, side in { -1, 1 } do
		for _, along in { 0.2, 0.8 } do
			local wheel = PartUtil.ghostBlock("Wheel", Vector3.new(0.6, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2), a.Colors.Wheel, Enum.Material.Metal, parent)
			wheel.Shape = Enum.PartType.Cylinder -- along its own X: across the track
			wheel.CFrame = CFrame.new(x + side * (halfWidth - 0.6), WHEEL_RADIUS, place.front + place.length * along)
		end
	end
end

-- A boxcar: a solid body up to its roof, a darker roof plate on top (the floor players stand on).
local function addBoxcar(parent: Instance, x: number, place: ArenaLayout.CarPlace)
	local a = Config.Arena
	local bottom = WHEEL_RADIUS * 1.4
	local body = PartUtil.solidBlock("Body", Vector3.new(a.RoofWidth - 0.6, place.roof - 0.3 - bottom, place.length), a.Colors.Boxcar, Enum.Material.WoodPlanks, parent)
	body.CFrame = CFrame.new(x, (place.roof - 0.3 + bottom) / 2, place.middle)
	local roof = PartUtil.solidBlock("Roof", Vector3.new(a.RoofWidth, 0.3, place.length), a.Colors.Roof, Enum.Material.Metal, parent)
	roof.CFrame = CFrame.new(x, place.roof - 0.15, place.middle)
	addWheels(parent, x, place, a.RoofWidth / 2 - 0.3)
end

-- The locomotive: a round boiler in front (its top is a slippery round ridge to fight on), a tall cab behind it
-- (its flat roof is the highest spot), and a chimney.
local function addLocomotive(parent: Instance, x: number, place: ArenaLayout.CarPlace)
	local a = Config.Arena
	local bottom = WHEEL_RADIUS * 1.4
	local cabLength = place.length * 0.35
	local boilerLength = place.length - cabLength
	local boilerDiameter = place.roof - 1.5 - bottom
	local frame = PartUtil.solidBlock("Frame", Vector3.new(a.RoofWidth - 1.6, 1, place.length), a.Colors.Cab, Enum.Material.Metal, parent)
	frame.CFrame = CFrame.new(x, bottom + 0.5, place.middle)
	local boiler = PartUtil.solidBlock("Boiler", Vector3.new(boilerLength, boilerDiameter, boilerDiameter), a.Colors.Boiler, Enum.Material.Metal, parent)
	boiler.Shape = Enum.PartType.Cylinder -- along its own X: turned to lie along the track
	boiler.CFrame = CFrame.new(x, bottom + 1 + boilerDiameter / 2, place.front + boilerLength / 2) * CFrame.Angles(0, math.pi / 2, 0)
	local cab = PartUtil.solidBlock("Cab", Vector3.new(a.RoofWidth - 0.6, place.roof - 0.3 - bottom, cabLength), a.Colors.Cab, Enum.Material.Metal, parent)
	cab.CFrame = CFrame.new(x, (place.roof - 0.3 + bottom) / 2, place.back - cabLength / 2)
	local cabRoof = PartUtil.solidBlock("CabRoof", Vector3.new(a.RoofWidth, 0.3, cabLength), a.Colors.Roof, Enum.Material.Metal, parent)
	cabRoof.CFrame = CFrame.new(x, place.roof - 0.15, place.back - cabLength / 2)
	local chimney = PartUtil.solidBlock("Chimney", Vector3.new(3, 1.6, 1.6), a.Colors.Cab, Enum.Material.Metal, parent)
	chimney.Shape = Enum.PartType.Cylinder -- along its own X: stood up
	chimney.CFrame = CFrame.new(x, bottom + 1 + boilerDiameter + 1.2, place.front + 2.5) * CFrame.Angles(0, 0, math.pi / 2)
	addWheels(parent, x, place, a.RoofWidth / 2 - 0.8)
end

-- The sand: one wide slab under the whole view (Config.Run), its top at Config.Arena.GroundY.
local function addGround(parent: Instance)
	local r = Config.Run
	local sand = PartUtil.solidBlock("Sand", Vector3.new(r.RoadsideFar * 2 + 80, 1, r.ViewAhead + r.ViewBehind + 80), r.Colors.Sand, Enum.Material.Sand, parent)
	sand.CFrame = CFrame.new(0, Config.Arena.GroundY - 0.5, (r.ViewBehind - r.ViewAhead) / 2)
end

-- The waiting room: a floor with high glass walls high over the middle, and the spawn point on it.
local function addWaitingRoom(parent: Instance): CFrame
	local a = Config.Arena
	local room = Instance.new("Model")
	room.Name = Names.WaitingRoom
	local y = a.WaitingRoomHeight
	local size = a.WaitingRoomSize
	local floor = PartUtil.solidBlock("Floor", Vector3.new(size, 1, size), a.Colors.Room, Enum.Material.WoodPlanks, room)
	floor.CFrame = CFrame.new(0, y - 0.5, 0)
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
	local places = ArenaLayout.carPlaces(a.Cars, a.CarGap)
	for i = 1, a.Trains do
		local train = Instance.new("Model")
		train.Name = "Train" .. i
		local x = ArenaLayout.trainX(i, a.Trains, a.RoofWidth, a.Gap)
		for _, place in places do
			if place.kind == "Locomotive" then
				addLocomotive(train, x, place)
			else
				addBoxcar(train, x, place)
			end
		end
		train.Parent = folder
	end
	for _, plank in ArenaLayout.planks(places, a.PlankCars, a.Trains, a.RoofWidth, a.Gap, a.PlankOverlap) do
		local part = PartUtil.solidBlock("Plank", Vector3.new(plank.length, a.PlankThickness, a.PlankWidth), a.Colors.Plank, Enum.Material.WoodPlanks, folder)
		part.CFrame = CFrame.new(plank.x, plank.top + a.PlankThickness / 2, plank.z)
	end
	addGround(folder)
	local waitingSpot = addWaitingRoom(folder)
	return {
		folder = folder,
		spots = ArenaLayout.spawnSpots(places, a.Trains, a.RoofWidth, a.Gap, 2),
		fallLine = ArenaLayout.fallLine(places, Config.Fall.Margin),
		waitingSpot = waitingSpot,
	}
end

return ArenaBuilder
