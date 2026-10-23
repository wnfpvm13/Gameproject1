--!strict
-- Where one train's rolling barrels are, for the drawing (BarrelView) and the cowboy's hit test (CowboyRules) alike, so
-- the two always agree: the barrels on the roofs at a run distance (CourseMath with the train's ends and
-- Config.Barrels) and the roof top under a barrel right now (the car roof floors squash with the train).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CourseMath = require(shared:WaitForChild("CourseMath"))

local BarrelTrack = {}

-- Where a barrel lands (train space Z): just behind where the first car's roof begins (Names.CarRoofFront).
function BarrelTrack.landing(train: Model): number
	return (PartUtil.number(train, Names.CarRoofFront) or 0) + Config.Barrels.Radius
end

-- The barrels on the train's roofs at run distance `distance`: landed already and not yet rolled past the train's back
-- (Names.SpanBack).
function BarrelTrack.active(train: Model, distance: number): { CourseMath.Barrel }
	local k, b = Config.Barrels, Config.Bridge
	local endZ = (PartUtil.number(train, Names.SpanBack) or 0) + k.Radius
	return CourseMath.activeBarrels(distance, b.FirstAt, b.Gaps, k.At, BarrelTrack.landing(train), endZ, k.RollSpeed / Config.Run.Speed)
end

-- The roof floors barrels roll on: the train's Names.Walkable parts wider at rest than the plank walkway.
function BarrelTrack.roofs(train: Model): { BasePart }
	local found = {}
	for _, item in train:GetDescendants() do
		local rest = item:GetAttribute(Names.RestSize)
		if item:IsA("BasePart") and item:GetAttribute(Names.Walkable) == true and typeof(rest) == "Vector3" and rest.X > Config.Cars.WalkWidth + 0.5 then
			table.insert(found, item)
		end
	end
	return found
end

-- The roof top (train space Y) under train-space Z right now, or nil past the roofs. A barrel up to its radius past a
-- roof's end (across the gap between two cars, or going over the back) still rests on that roof.
function BarrelTrack.roofTopAt(roofs: { BasePart }, baseCFrame: CFrame, z: number): number?
	local best: number? = nil
	for _, floor in roofs do
		local here = baseCFrame:PointToObjectSpace(floor.Position)
		if math.abs(z - here.Z) <= floor.Size.Z / 2 + Config.Barrels.Radius then
			local top = here.Y + floor.Size.Y / 2
			best = if best then math.max(best, top) else top
		end
	end
	return best
end

return BarrelTrack
