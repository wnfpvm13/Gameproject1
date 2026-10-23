--!strict
-- Builds one locomotive out of a stripped avatar (AvatarBody): the avatar lies on its back with the head toward the
-- front, the torso stretched into the boiler, the arms along the boiler sides and the legs as the rear deck; the
-- head turns to face forward as the locomotive's face. An iron frame, wheels, a chimney, a steam dome and a wooden
-- cowcatcher are added. Every part that squashes gets its rest pose as attributes (Names.Rest*) for the client's
-- SquashAnimator. Locomotive space: X right, Y up, Z back (forward is -Z), origin on the rails under the middle.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local LocomotiveBuilder = {}

-- Lying on the back with the head forward: the part's own Y (toward the neck) points forward (-Z), its front (-Z
-- own, the chest) points up and its own X points to -X (a person on their back has their right hand on that side).
local SUPINE = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0))
-- Cylinders run along their own X axis; this stands one upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

type Placement = {
	part: BasePart,
	size: Vector3,
	rest: CFrame,
	anchor: Vector3?, -- nil = the part's centre
	exponent: number?, -- nil = 1
}

local function newPart(className: string, name: string, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local part = Instance.new(className) :: BasePart
	part.Name = name
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function cylinder(name: string, color: Color3, parent: Instance): BasePart
	local part = newPart("Part", name, color, Enum.Material.Metal, parent) :: Part
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A part with a FileMesh SpecialMesh keeps its mesh scale in step with its size.
local function resize(part: BasePart, size: Vector3)
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.FileMesh then
		mesh.Scale = PartUtil.meshScale(mesh.Scale, part.Size, size)
	end
	part.Size = size
end

local function avatarPart(avatar: Model, name: string): BasePart?
	local part = avatar:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- The avatar laid out as the boiler, face, arms and legs. Returns the front and back ends (Z) it covers.
local function layAvatar(avatar: Model, add: (BasePart, Vector3, CFrame, Vector3?, number?) -> ()): (number, number, number)
	local L = Config.Locomotive
	local k = L.AvatarScale
	local upper = avatarPart(avatar, "UpperTorso")
	local lower = avatarPart(avatar, "LowerTorso")
	local head = avatarPart(avatar, "Head")
	assert(upper and lower and head, "the avatar has no R15 torso or head")
	local deck = L.DeckHeight
	local upperLength = upper.Size.Y * k * L.TorsoLengthStretch
	local lowerLength = lower.Size.Y * k * L.TorsoLengthStretch
	local boilerHeight = upper.Size.Z * k * L.TorsoThickness
	local boilerWidth = upper.Size.X * k
	add(upper, Vector3.new(boilerWidth, upperLength, boilerHeight), CFrame.new(0, deck + boilerHeight / 2, upperLength / 2) * SUPINE)
	local lowerHeight = lower.Size.Z * k * L.TorsoThickness
	add(lower, Vector3.new(lower.Size.X * k, lowerLength, lowerHeight), CFrame.new(0, deck + lowerHeight / 2, upperLength + lowerLength / 2) * SUPINE)

	local torsoEnd = upperLength + lowerLength
	local back = torsoEnd
	local hipX = lower.Size.X * k * 0.25
	for _, side in { "Left", "Right" } do
		local x = if side == "Left" then hipX else -hipX
		local z = torsoEnd
		for _, piece in { "UpperLeg", "LowerLeg", "Foot" } do
			local part = avatarPart(avatar, side .. piece)
			if part then
				local size = part.Size * k
				add(part, size, CFrame.new(x, deck + size.Z / 2, z + size.Y / 2) * SUPINE)
				z += size.Y
			end
		end
		back = math.max(back, z)
	end
	for _, side in { "Left", "Right" } do
		local sign = if side == "Left" then 1 else -1
		local z = 0
		for _, piece in { "UpperArm", "LowerArm", "Hand" } do
			local part = avatarPart(avatar, side .. piece)
			if part then
				local size = part.Size * k
				add(part, size, CFrame.new(sign * (boilerWidth / 2 + size.X / 2), deck + size.Z / 2, z + size.Y / 2) * SUPINE)
				z += size.Y
			end
		end
	end

	-- The face: facing forward, a little taller than the boiler, its back tucked against the neck end.
	local headSize = head.Size * (boilerHeight * L.HeadToBoiler / head.Size.Y)
	local headY = deck + boilerHeight / 2 + (headSize.Y - boilerHeight) * 0.25
	add(head, headSize, CFrame.new(0, headY, 0.2 - headSize.Z / 2))
	return 0.2 - headSize.Z, back, deck + boilerHeight
end

local function addTrainParts(model: Model, front: number, back: number, boilerTop: number, add: (BasePart, Vector3, CFrame, Vector3?, number?) -> ())
	local L = Config.Locomotive
	local colors = L.Colors
	local deck = L.DeckHeight
	local frameWidth = L.WheelTrack * 2 - L.WheelWidth
	local frame = newPart("Part", "Frame", colors.Iron, Enum.Material.Metal, model)
	add(frame, Vector3.new(frameWidth, L.FrameThickness, back - front), CFrame.new(0, deck - L.FrameThickness / 2, (front + back) / 2))

	local radius = L.WheelRadius
	local firstZ, lastZ = radius + 0.3, back - radius - 0.3
	for i = 1, L.WheelsPerSide do
		local z = firstZ + (i - 1) * (lastZ - firstZ) / math.max(1, L.WheelsPerSide - 1)
		for _, sign in { -1, 1 } do
			add(cylinder("Wheel", colors.Iron, model), Vector3.new(L.WheelWidth, radius * 2, radius * 2), CFrame.new(sign * L.WheelTrack, radius, z))
			local hubX = sign * (L.WheelTrack + L.WheelWidth / 2 + 0.08)
			add(cylinder("Hub", colors.Brass, model), Vector3.new(0.16, radius * 0.8, radius * 0.8), CFrame.new(hubX, radius, z))
		end
	end

	-- Chimney and its funnel cap fold together from the chimney's foot (harder than the body: ChimneyExponent).
	local foot = Vector3.new(0, boilerTop - L.ChimneySink, L.ChimneyFromNeck)
	local chimneyHeight = L.ChimneyHeight + L.ChimneySink
	local exponent = Config.Squash.ChimneyExponent
	local chimney = cylinder("Chimney", colors.Iron, model)
	add(chimney, Vector3.new(chimneyHeight, L.ChimneyDiameter, L.ChimneyDiameter), CFrame.new(foot + Vector3.new(0, chimneyHeight / 2, 0)) * UPRIGHT, foot, exponent)
	local cap = cylinder(Names.ChimneyCap, colors.Iron, model)
	add(cap, Vector3.new(L.CapHeight, L.CapDiameter, L.CapDiameter), CFrame.new(foot + Vector3.new(0, chimneyHeight + L.CapHeight / 2, 0)) * UPRIGHT, foot, exponent)

	-- A block with a sphere mesh, not a Ball part: Roblox keeps Ball parts perfectly round, the mesh can squash.
	local dome = newPart("Part", "SteamDome", colors.Brass, Enum.Material.Metal, model)
	local domeMesh = Instance.new("SpecialMesh")
	domeMesh.MeshType = Enum.MeshType.Sphere
	domeMesh.Parent = dome
	local domeZ = L.ChimneyFromNeck + 3.2
	add(dome, Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, boilerTop + 0.3, domeZ), Vector3.new(0, boilerTop, domeZ))

	-- The cowcatcher's slope faces forward (a wedge slopes down toward its own -Z).
	local catcher = newPart("WedgePart", "Cowcatcher", colors.Wood, Enum.Material.Wood, model)
	local catcherSize = Vector3.new(frameWidth + 0.6, deck * 0.95, L.CowcatcherLength)
	add(catcher, catcherSize, CFrame.new(0, catcherSize.Y / 2, front - L.CowcatcherLength / 2 + 0.4))
end

-- The finished locomotive at `base` (on the rails, facing -Z). The avatar model becomes its child.
function LocomotiveBuilder.build(avatar: Model, base: CFrame): Model
	local model = Instance.new("Model")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the animator needs every part at once
	local placements: { Placement } = {}
	local function add(part: BasePart, size: Vector3, rest: CFrame, anchor: Vector3?, exponent: number?)
		table.insert(placements, { part = part, size = size, rest = rest, anchor = anchor, exponent = exponent })
	end

	local front, back, boilerTop = layAvatar(avatar, add)
	local placed: { [BasePart]: boolean } = {}
	for _, placement in placements do
		placed[placement.part] = true
	end
	addTrainParts(model, front, back, boilerTop, add)

	-- Centre the locomotive over the base, then put every part in its rest pose.
	local shift = CFrame.new(0, 0, -(front + back) / 2)
	for _, placement in placements do
		local part = placement.part
		local rest = shift * placement.rest
		resize(part, placement.size)
		PartUtil.ghost(part)
		part.CFrame = base * rest
		part:SetAttribute(Names.RestCFrame, rest)
		part:SetAttribute(Names.RestSize, placement.size)
		part:SetAttribute(Names.RestAnchor, if placement.anchor then shift * placement.anchor else rest.Position)
		part:SetAttribute(Names.SquashExponent, placement.exponent or 1)
		local mesh = part:FindFirstChildOfClass("SpecialMesh")
		if mesh and mesh.MeshType == Enum.MeshType.FileMesh then
			part:SetAttribute(Names.RestMeshScale, mesh.Scale)
		end
	end
	-- Anything else in the avatar (the root part, an unexpected extra part) waits invisibly at the base.
	for _, item in avatar:GetDescendants() do
		if item:IsA("BasePart") and not placed[item] then
			item.Transparency = 1
			item.CFrame = base
		end
	end
	avatar.Parent = model

	local basePart = newPart("Part", Names.BasePart, Color3.new(), Enum.Material.SmoothPlastic, model)
	basePart.Size = Vector3.new(1, 0.2, 1)
	basePart.CFrame = base
	local focus = newPart("Part", Names.CameraFocus, Color3.new(), Enum.Material.SmoothPlastic, model)
	focus.Size = Vector3.new(1, 1, 1)
	focus.CFrame = base * CFrame.new(0, boilerTop, 0)
	for _, helper in { basePart, focus } do
		helper.Transparency = 1
		PartUtil.ghost(helper)
	end
	model.PrimaryPart = basePart
	model:SetAttribute(Names.Squashed, false)
	CollectionService:AddTag(model, Names.LocomotiveTag)
	return model
end

return LocomotiveBuilder
