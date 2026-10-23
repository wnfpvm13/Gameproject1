--!strict
-- Draws one train's gold mail on this client: the tall gold cranes beside the track with their bags hung high over the
-- middle, and the jump markers across the rails that show the driver where to jump for them (where the locomotive's
-- front should be when it jumps, GoldTrack.jumpFrom). Both pass by with the run, like the bridges. A bag shows until it
-- is picked up or gone by (Names.GoldNext). Only for trains with a cowboy (nobody else can reach the gold).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local TrainState = require(shared:WaitForChild("TrainState"))
local GoldTrack = require(shared:WaitForChild("GoldTrack"))

local GoldView = {}
GoldView.__index = GoldView

type Fields = {
	locomotive: Model,
	base: BasePart,
	front: number, -- the train's front (Names.SpanFront)
	folder: Folder,
	cranes: { [number]: Model },
	markers: { [number]: Model },
	drawn: string?, -- what was last drawn (distance, next bag): nothing changes while it stays the same
}
export type View = typeof(setmetatable({} :: Fields, GoldView))

-- A gold crane in its own space (origin on the rail tops under its bag; side 1 = right): a tall post beside the track,
-- an arm reaching over the middle and a gold bag hanging from it on a rope.
local function buildCrane(parent: Instance, side: number): Model
	local g = Config.GoldMail
	local ground = -Config.Stage.RailHeight
	local model = Instance.new("Model")
	model.Name = "GoldCrane"
	local armY = g.BagY + g.BagSize.Y / 2 + g.ArmAboveBag
	local postTop = armY + g.ArmThickness
	local post = PartUtil.ghostBlock("Post", Vector3.new(g.PostThickness, postTop - ground, g.PostThickness), g.Colors.Post, Enum.Material.Wood, model)
	post.CFrame = CFrame.new(side * g.PostX, (postTop + ground) / 2, 0)
	local reach = g.PostX + g.ArmThickness
	local arm = PartUtil.ghostBlock("Arm", Vector3.new(reach, g.ArmThickness, g.ArmThickness), g.Colors.Post, Enum.Material.Wood, model)
	arm.CFrame = CFrame.new(side * (reach / 2 - g.ArmThickness), armY, 0)
	local rope = PartUtil.ghostBlock("Rope", Vector3.new(0.08, armY - g.BagY - g.BagSize.Y / 2, 0.08), g.Colors.Strap, Enum.Material.Fabric, model)
	rope.CFrame = CFrame.new(0, (armY + g.BagY + g.BagSize.Y / 2) / 2, 0)
	local bag = PartUtil.ghostBlock("Bag", g.BagSize, g.Colors.Bag, Enum.Material.Foil, model)
	local sack = Instance.new("SpecialMesh")
	sack.MeshType = Enum.MeshType.Sphere -- a rounded sack
	sack.Parent = bag
	bag.CFrame = CFrame.new(0, g.BagY, 0)
	local strap = PartUtil.ghostBlock("Strap", Vector3.new(g.BagSize.X * 0.95, 0.18, g.BagSize.Z * 0.95), g.Colors.Strap, Enum.Material.Fabric, model)
	strap.CFrame = CFrame.new(0, g.BagY + g.BagSize.Y * 0.28, 0)
	model.WorldPivot = CFrame.new()
	model.Parent = parent
	return model
end

-- A jump marker in its own space (origin on the rail tops at its middle): a gold board across the sleepers and a short
-- gold-topped post on each side of the track.
local function buildMarker(parent: Instance): Model
	local g = Config.GoldMail
	local stage = Config.Stage
	local ground = -stage.RailHeight
	local width = Config.Locomotive.WheelTrack * 2 + 2 -- as wide as a sleeper
	local model = Instance.new("Model")
	model.Name = "JumpMarker"
	local board = PartUtil.ghostBlock("Board", Vector3.new(width, 0.1, g.MarkerDepth), g.Colors.Marker, Enum.Material.SmoothPlastic, model)
	board.CFrame = CFrame.new(0, 0.3 - stage.RailHeight, 0) -- just over the sleepers, under the rail tops
	for _, side in { -1, 1 } do
		local x = side * (width / 2 + 0.6)
		local post = PartUtil.ghostBlock("Post", Vector3.new(0.3, 2.2, 0.3), g.Colors.Post, Enum.Material.Wood, model)
		post.CFrame = CFrame.new(x, ground + 1.1, 0)
		local cap = PartUtil.ghostBlock("Cap", Vector3.new(0.6, 0.6, 0.6), g.Colors.Marker, Enum.Material.SmoothPlastic, model)
		cap.CFrame = CFrame.new(x, ground + 2.4, 0) * CFrame.Angles(0, math.pi / 4, math.pi / 4)
	end
	model.WorldPivot = CFrame.new()
	model.Parent = parent
	return model
end

local function setBagShown(crane: Model, shown: boolean)
	for _, name in { "Bag", "Strap", "Rope" } do
		local part = crane:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Transparency = if shown then 0 else 1
		end
	end
end

function GoldView.new(locomotive: Model, base: BasePart): View
	local own = Instance.new("Folder")
	own.Name = locomotive.Name .. "_Gold"
	own.Parent = PartUtil.folder(Workspace, Names.CourseFolder)
	local fields: Fields = {
		locomotive = locomotive,
		base = base,
		front = PartUtil.number(locomotive, Names.SpanFront) or 0,
		folder = own,
		cranes = {},
		markers = {},
		drawn = nil,
	}
	return setmetatable(fields, GoldView)
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

-- Draws the cranes and markers within the view for this run distance (nil = no run yet: nothing).
function GoldView.update(self: View, distance: number?)
	local nextBag = PartUtil.number(self.locomotive, Names.GoldNext) or 1
	local show = distance ~= nil and TrainState.hasCowboy(self.locomotive)
	local key = if show then string.format("%.3f|%d", distance :: number, nextBag) else "none"
	if key == self.drawn then
		return -- held, crashed or waiting to start: everything is already in place
	end
	self.drawn = key
	local keepCranes: { [number]: boolean } = {}
	local keepMarkers: { [number]: boolean } = {}
	if show and distance then
		local r = Config.Run
		local baseCFrame = self.base.CFrame
		-- The last bags gone by keep their cranes (without the bag) while they pass out of sight behind.
		local k = math.max(1, nextBag - 2)
		while true do
			local at, side = GoldTrack.at(k)
			local markerAt = GoldTrack.jumpFrom(self.locomotive, k) - self.front -- where the front is when it jumps
			if math.min(at, markerAt) - distance > r.ViewAhead then
				break
			end
			if distance - at <= r.ViewBehind then
				keepCranes[k] = true
				local crane = self.cranes[k] or buildCrane(self.folder, side)
				self.cranes[k] = crane
				setBagShown(crane, k >= nextBag)
				crane:PivotTo(baseCFrame * CFrame.new(0, 0, distance - at))
			end
			if k >= nextBag and distance - markerAt <= r.ViewBehind and markerAt - distance <= r.ViewAhead then
				keepMarkers[k] = true
				local marker = self.markers[k] or buildMarker(self.folder)
				self.markers[k] = marker
				marker:PivotTo(baseCFrame * CFrame.new(0, 0, distance - markerAt))
			end
			k += 1
		end
	end
	prune(self.cranes, keepCranes)
	prune(self.markers, keepMarkers)
end

function GoldView.destroy(self: View)
	self.folder:Destroy()
end

return GoldView
