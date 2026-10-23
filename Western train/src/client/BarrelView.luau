--!strict
-- Draws one train's barrels on this client: the water towers beside the track (they pass by with the run, like the
-- bridges) and the barrels they drop, which fall onto the first car's roof and roll back along their lane, sitting on
-- the roof as it squashes and springs back. Where the barrels are comes from BarrelTrack, which CowboyRules judges hits
-- with too, so a barrel is drawn exactly where it can hit. Only for trains with a cowboy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CourseMath = require(shared:WaitForChild("CourseMath"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local TrainState = require(shared:WaitForChild("TrainState"))
local BarrelTrack = require(shared:WaitForChild("BarrelTrack"))

local BarrelView = {}
BarrelView.__index = BarrelView

type Fields = {
	locomotive: Model,
	base: BasePart,
	folder: Folder,
	roofs: { BasePart }, -- the car roof floors (BarrelTrack.roofs)
	towers: { [number]: Model },
	towersAt: number?, -- the run distance the towers were last placed for
	barrels: { [number]: Model },
}
export type View = typeof(setmetatable({} :: Fields, BarrelView))

-- A water tower in its own space (origin on the rail tops beside the train's middle line; side 1 = right): a tank on
-- four legs with a spout reaching over its barrel lane, high enough to pass over a standing cowboy's head.
local function buildTower(parent: Instance, side: number): Model
	local b = Config.Barrels
	local ground = -Config.Stage.RailHeight
	local model = Instance.new("Model")
	model.Name = "WaterTower"
	local x = side * b.TowerX
	local legTop = b.SpoutHeight - 0.6
	for _, dx in { -1.2, 1.2 } do
		for _, dz in { -1.2, 1.2 } do
			local leg = PartUtil.ghostBlock("Leg", Vector3.new(0.4, legTop - ground, 0.4), b.Colors.Tower, Enum.Material.Wood, model)
			leg.CFrame = CFrame.new(x + dx, (legTop + ground) / 2, dz)
		end
	end
	local tank = PartUtil.ghostBlock("Tank", Vector3.new(4, 3.2, 3.2), b.Colors.Tower, Enum.Material.WoodPlanks, model)
	tank.Shape = Enum.PartType.Cylinder -- lying along X: stand it up
	tank.CFrame = CFrame.new(x, legTop + 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local spoutLength = b.TowerX - 1.5 - b.LaneX -- from the tank's side to over the lane
	local spout = PartUtil.ghostBlock("Spout", Vector3.new(spoutLength, 0.4, 0.4), b.Colors.Hoop, Enum.Material.Metal, model)
	spout.CFrame = CFrame.new(side * (b.TowerX - 1.5 - spoutLength / 2), b.SpoutHeight, 0)
	model.WorldPivot = CFrame.new()
	model.Parent = parent
	return model
end

-- A barrel lying across the train (its axle along X): wooden staves and two iron hoops.
local function buildBarrel(parent: Instance): Model
	local b = Config.Barrels
	local model = Instance.new("Model")
	model.Name = "Barrel"
	local body = PartUtil.ghostBlock("Staves", Vector3.new(b.Length, b.Radius * 2, b.Radius * 2), b.Colors.Wood, Enum.Material.Wood, model)
	body.Shape = Enum.PartType.Cylinder -- along its own X
	for _, dx in { -b.Length * 0.3, b.Length * 0.3 } do
		local hoop = PartUtil.ghostBlock("Hoop", Vector3.new(0.12, b.Radius * 2 + 0.06, b.Radius * 2 + 0.06), b.Colors.Hoop, Enum.Material.Metal, model)
		hoop.Shape = Enum.PartType.Cylinder
		hoop.CFrame = CFrame.new(dx, 0, 0)
	end
	model.PrimaryPart = body
	model.Parent = parent
	return model
end

function BarrelView.new(locomotive: Model, base: BasePart): View
	local own = Instance.new("Folder")
	own.Name = locomotive.Name .. "_Barrels"
	own.Parent = PartUtil.folder(Workspace, Names.CourseFolder)
	local fields: Fields = {
		locomotive = locomotive,
		base = base,
		folder = own,
		roofs = BarrelTrack.roofs(locomotive),
		towers = {},
		towersAt = nil,
		barrels = {},
	}
	return setmetatable(fields, BarrelView)
end

-- Removes the models whose index is not in `keep`.
local function prune(models: { [number]: Model }, keep: { [number]: boolean })
	for index, model in models do
		if not keep[index] then
			model:Destroy()
			models[index] = nil
		end
	end
end

-- The towers within the view, passing by with the run (left alone while the run stands still).
local function placeTowers(self: View, distance: number, landing: number)
	if distance == self.towersAt then
		return
	end
	self.towersAt = distance
	local b = Config.Barrels
	local bridges = Config.Bridge
	local r = Config.Run
	local baseCFrame = self.base.CFrame
	local keep: { [number]: boolean } = {}
	local i = math.max(1, CourseMath.nextBridge(distance - r.ViewBehind, bridges.FirstAt, bridges.Gaps, 0, 0) - 1)
	while true do
		local drop, lane = CourseMath.barrelAt(i, bridges.FirstAt, bridges.Gaps, b.At)
		if drop - distance > r.ViewAhead then
			break
		end
		if distance - drop <= r.ViewBehind then
			keep[i] = true
			local tower = self.towers[i] or buildTower(self.folder, lane)
			self.towers[i] = tower
			tower:PivotTo(baseCFrame * CFrame.new(0, 0, distance - drop + landing))
		end
		i += 1
	end
	prune(self.towers, keep)
end

-- The barrels on the roofs: falling from the spout onto the first car, then rolling back, turning with the roll. Placed
-- every frame, as the roof under them squashes and springs back.
local function placeBarrels(self: View, distance: number, landing: number)
	local b = Config.Barrels
	local baseCFrame = self.base.CFrame
	local keep: { [number]: boolean } = {}
	for _, barrel in BarrelTrack.active(self.locomotive, distance) do
		local roof = BarrelTrack.roofTopAt(self.roofs, baseCFrame, barrel.z)
		if roof then
			keep[barrel.index] = true
			local model = self.barrels[barrel.index] or buildBarrel(self.folder)
			self.barrels[barrel.index] = model
			local falling = math.max(0, 1 - (distance - barrel.drop) / b.DropStuds)
			local resting = roof + b.Radius
			model:PivotTo(baseCFrame
				* CFrame.new(barrel.lane * b.LaneX, resting + falling * math.max(0, b.SpoutHeight - resting), barrel.z)
				* CFrame.Angles((barrel.z - landing) / b.Radius, 0, 0))
		end
	end
	prune(self.barrels, keep)
end

-- Draws the towers and barrels for this run distance (nil = no run yet: nothing).
function BarrelView.update(self: View, distance: number?)
	if not (distance and TrainState.hasCowboy(self.locomotive)) then
		if next(self.towers) or next(self.barrels) then
			prune(self.towers, {})
			prune(self.barrels, {})
		end
		self.towersAt = nil
		return
	end
	local landing = BarrelTrack.landing(self.locomotive)
	placeTowers(self, distance, landing)
	placeBarrels(self, distance, landing)
end

function BarrelView.destroy(self: View)
	self.folder:Destroy()
end

return BarrelView
