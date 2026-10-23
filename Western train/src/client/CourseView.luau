--!strict
-- Draws one train's low bridges and mail cranes on this client, moving toward it with the run distance (local parts:
-- every client builds the same ones from Config and the shared run, so nothing moves over the network). A bridge the
-- train crashed into carries the face stamp until the train has got all the way under it. A crane's bag shows while
-- the train has a cowboy and the bag is not taken yet (Names.MailNext).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CourseMath = require(shared:WaitForChild("CourseMath"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local TrainState = require(shared:WaitForChild("TrainState"))

local CourseView = {}
CourseView.__index = CourseView

type Fields = {
	locomotive: Model,
	base: BasePart,
	back: number,
	folder: Folder,
	bridges: { [number]: Model },
	cranes: { [number]: Model },
	stampIndex: number?,
	stamp: Model?,
	drawn: string?, -- what was last drawn (distance, next bag, cowboy): nothing changes while it stays the same
}
export type View = typeof(setmetatable({} :: Fields, CourseView))

-- One bridge in its own space (origin on the rail tops under its middle, Z along the track): two stone piers outside
-- the track, standing on the sand, and a heavy timber girder across at the clearance height, with a top rail.
local function buildBridge(parent: Instance): Model
	local b = Config.Bridge
	local ground = -Config.Stage.RailHeight
	local model = Instance.new("Model")
	model.Name = "Bridge"
	local top = b.Clearance + b.GirderHeight
	for _, side in { -1, 1 } do
		local x = side * (b.Span / 2 + b.PierWidth / 2)
		local pier = PartUtil.ghostBlock("Pier", Vector3.new(b.PierWidth, top - ground, b.Depth + 1), b.Colors.Stone, Enum.Material.Cobblestone, model)
		pier.CFrame = CFrame.new(x, (top + ground) / 2, 0)
		local rail = PartUtil.ghostBlock("Rail", Vector3.new(b.Span + b.PierWidth * 2, 0.5, 0.4), b.Colors.Wood, Enum.Material.Wood, model)
		rail.CFrame = CFrame.new(0, top + 0.25, side * (b.Depth / 2 - 0.2))
	end
	local girder = PartUtil.ghostBlock("Girder", Vector3.new(b.Span + b.PierWidth * 2, b.GirderHeight, b.Depth), b.Colors.Wood, Enum.Material.WoodPlanks, model)
	girder.CFrame = CFrame.new(0, b.Clearance + b.GirderHeight / 2, 0)
	model.WorldPivot = CFrame.new()
	model.Parent = parent
	return model
end

-- One mail crane in its own space (origin on the rail tops under its middle; side 1 = right): a post beside the track,
-- an arm reaching over the roof's edge, and a canvas bag hanging from it on a rope.
local function buildCrane(parent: Instance, side: number): Model
	local m = Config.Mail
	local ground = -Config.Stage.RailHeight
	local model = Instance.new("Model")
	model.Name = "MailCrane"
	local armY = m.BagY + m.BagSize.Y / 2 + m.ArmAboveBag
	local post = PartUtil.ghostBlock("Post", Vector3.new(m.PostThickness, m.PostHeight - ground, m.PostThickness), m.Colors.Post, Enum.Material.Wood, model)
	post.CFrame = CFrame.new(side * m.PostX, (m.PostHeight + ground) / 2, 0)
	local reach = m.PostX - m.BagX + m.ArmThickness
	local arm = PartUtil.ghostBlock("Arm", Vector3.new(reach, m.ArmThickness, m.ArmThickness), m.Colors.Post, Enum.Material.Wood, model)
	arm.CFrame = CFrame.new(side * (m.BagX + reach / 2 - m.ArmThickness), armY, 0)
	local rope = PartUtil.ghostBlock("Rope", Vector3.new(0.08, armY - m.BagY - m.BagSize.Y / 2, 0.08), m.Colors.Strap, Enum.Material.Fabric, model)
	rope.CFrame = CFrame.new(side * m.BagX, (armY + m.BagY + m.BagSize.Y / 2) / 2, 0)
	local bag = PartUtil.ghostBlock("Bag", m.BagSize, m.Colors.Bag, Enum.Material.Fabric, model)
	local sack = Instance.new("SpecialMesh")
	sack.MeshType = Enum.MeshType.Sphere -- a rounded sack
	sack.Parent = bag
	bag.CFrame = CFrame.new(side * m.BagX, m.BagY, 0)
	local strap = PartUtil.ghostBlock("Strap", Vector3.new(m.BagSize.X * 0.95, 0.18, m.BagSize.Z * 0.95), m.Colors.Strap, Enum.Material.Fabric, model)
	strap.CFrame = CFrame.new(side * m.BagX, m.BagY + m.BagSize.Y * 0.28, 0)
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

function CourseView.new(locomotive: Model, base: BasePart): View
	local own = Instance.new("Folder")
	own.Name = locomotive.Name
	own.Parent = PartUtil.folder(Workspace, Names.CourseFolder)
	local fields: Fields = {
		locomotive = locomotive,
		base = base,
		back = PartUtil.number(locomotive, Names.SpanBack) or 0,
		folder = own,
		bridges = {},
		cranes = {},
		stampIndex = nil,
		stamp = nil,
		drawn = nil,
	}
	return setmetatable(fields, CourseView)
end

local function removeStamp(self: View)
	if self.stamp then
		self.stamp:Destroy()
	end
	self.stamp = nil
	self.stampIndex = nil
end

-- The face pressed flat on the girder's near face (the side the locomotive comes from, which the play camera sees),
-- from a copy of the locomotive's head at its rest size. The copy sits in a little model with a Humanoid and the
-- avatar's BodyColors: a head whose face is in its texture gets its skin colour that way, and draws white without it
-- (seen in Studio).
function CourseView.stampFace(self: View, index: number)
	removeStamp(self)
	self.drawn = nil -- draw the stamp at once
	local avatar = PartUtil.avatarOf(self.locomotive)
	local head = avatar and avatar:FindFirstChild(Names.AvatarHead)
	local rest = head and head:GetAttribute(Names.RestSize)
	if not (avatar and head and head:IsA("BasePart") and typeof(rest) == "Vector3") then
		return
	end
	local b = Config.Bridge
	local scale = b.GirderHeight * b.StampFill / rest.Y
	local stamp = Instance.new("Model")
	stamp.Name = "FaceStamp"
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- no name tag over the stamp
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = stamp
	local colors = avatar:FindFirstChildOfClass("BodyColors")
	if colors then
		colors:Clone().Parent = stamp
	end
	local face = head:Clone() -- with its avatar children (face controls and the like), as the skin colour needs
	for _, item in face:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Sound") then
			item:Destroy()
		end
	end
	face.Size = Vector3.new(rest.X * scale, rest.Y * scale, b.StampThickness)
	PartUtil.ghost(face)
	face.Parent = stamp
	stamp.PrimaryPart = face
	self.stamp = stamp
	self.stampIndex = index
end

-- Puts the visible bridges and cranes where the run distance says (nil = no run yet: none).
function CourseView.update(self: View, distance: number?)
	local mailNext = PartUtil.number(self.locomotive, Names.MailNext) or 1
	local hasCowboy = TrainState.hasCowboy(self.locomotive)
	local key = string.format("%s|%d|%s", tostring(distance), mailNext, tostring(hasCowboy))
	if distance ~= nil and key == self.drawn then
		return -- held, crashed or waiting to start: everything is already in place
	end
	self.drawn = key
	local b = Config.Bridge
	local r = Config.Run
	local keep: { [number]: boolean } = {}
	local keepCranes: { [number]: boolean } = {}
	if distance then
		local firstBridge = CourseMath.nextBridge(distance - r.ViewBehind, b.FirstAt, b.Gaps, b.Depth, 0)
		local index = firstBridge
		local baseCFrame = self.base.CFrame
		while true do
			local at = CourseMath.bridgeAt(index, b.FirstAt, b.Gaps)
			if at - distance > r.ViewAhead then
				break
			end
			keep[index] = true
			local model = self.bridges[index]
			if not model then
				model = buildBridge(self.folder)
				self.bridges[index] = model
			end
			-- Ahead is -Z: a bridge `at - distance` studs ahead sits at z = distance - at.
			local cframe = baseCFrame * CFrame.new(0, 0, distance - at)
			model:PivotTo(cframe)
			local stamp = self.stamp
			if self.stampIndex == index and stamp then
				-- On the girder's +Z face, turned to face +Z (toward the oncoming locomotive).
				stamp:PivotTo(cframe
					* CFrame.new(0, b.Clearance + b.GirderHeight / 2, b.Depth / 2 + b.StampThickness / 2)
					* CFrame.Angles(0, math.pi, 0))
				stamp.Parent = model
			end
			index += 1
		end
		-- The cranes: crane i stands between bridge i and the next, so the visible ones are around the visible bridges.
		for i = math.max(1, firstBridge - 1), index do
			local at, side = CourseMath.mailAt(i, b.FirstAt, b.Gaps)
			if at - distance <= r.ViewAhead and distance - at <= r.ViewBehind then
				keepCranes[i] = true
				local crane = self.cranes[i]
				if not crane then
					crane = buildCrane(self.folder, side)
					self.cranes[i] = crane
				end
				crane:PivotTo(baseCFrame * CFrame.new(0, 0, distance - at))
				setBagShown(crane, hasCowboy and i >= mailNext)
			end
		end
		-- Once the locomotive has got all the way under the stamped bridge, the stamp has done its job.
		local stampIndex = self.stampIndex
		if stampIndex and distance > CourseMath.bridgeAt(stampIndex, b.FirstAt, b.Gaps) + b.Depth / 2 + self.back then
			removeStamp(self)
		end
	end
	for i, crane in self.cranes do
		if not keepCranes[i] then
			crane:Destroy()
			self.cranes[i] = nil
		end
	end
	for index, model in self.bridges do
		if not keep[index] then
			if self.stamp and self.stamp.Parent == model then
				self.stamp.Parent = nil -- kept for when the bridge comes back after a restart
			end
			model:Destroy()
			self.bridges[index] = nil
		end
	end
end

function CourseView.destroy(self: View)
	removeStamp(self)
	self.folder:Destroy()
end

return CourseView
