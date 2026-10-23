--!strict
-- Builds one locomotive out of a stripped avatar (AvatarBody): "the locomotive wearing the avatar" (owner pick
-- 2026-10-23). The head is the face on the smokebox front, the torso stands at the back as the cab (shirt facing
-- backward, toward the play camera), the arms are the coupling rods between the driving wheels and the lower legs
-- and shoes are the rear buffers. The boiler is a real cylinder in Config's boiler colour; frame, wheels, crank
-- pins, chimney, dome, lamp, buffer beam and a slatted cowcatcher are added. Every moving part gets its rest pose as
-- attributes (Names.Rest*, and Names.Crank* for the parts that circle with the wheels) for the client's
-- LocomotiveAnimator. Locomotive space: X right, Y up, Z back (forward is -Z), origin on the rails under the middle.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CrankMotion = require(shared:WaitForChild("CrankMotion"))

local LocomotiveBuilder = {}

-- Lying on the back with the head forward: own Y forward (-Z), the front (chest; for a foot, the toes) up, the
-- underside (soles) backward.
local SUPINE = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0))
-- An arm lying along the train's side, the hand forward and its outer side outward (own X stays world X).
local ROD = CFrame.fromMatrix(Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, -1, 0))
local BACKWARD = CFrame.Angles(0, math.pi, 0) -- the front faces the back of the train
local ALONG_TRACK = CFrame.Angles(math.pi / 2, 0, 0) -- a cylinder's own Y axis along the track
local ACROSS = CFrame.Angles(0, 0, -math.pi / 2) -- a cylinder's own Y axis across the track (wheels, pins)

-- Roblox keeps Part cylinders and Cylinder meshes round, so they cannot squash into an ellipse; a FileMesh stretches
-- freely. This classic head shape ships with every Roblox client and is a plain cylinder along its own Y axis.
local CYLINDER_MESH = "rbxasset://avatar/heads/headP.mesh"
local CYLINDER_MESH_SIZE = Vector3.new(1.2424, 1.25, 1.2424) -- its MeshPart.MeshSize, measured in Studio

type Placement = {
	part: BasePart,
	size: Vector3,
	rest: CFrame,
	anchor: Vector3?, -- nil = the part's centre
	exponent: number?, -- nil = 1
	crank: CrankMotion.Crank?,
}
type Add = (Placement) -> ()

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

-- A cylinder along its own Y axis that can squash into an ellipse (see CYLINDER_MESH).
local function cylinder(name: string, color: Color3, parent: Instance): BasePart
	local part = newPart("Part", name, color, Enum.Material.Metal, parent)
	part.Size = CYLINDER_MESH_SIZE -- mesh scale 1 fills this size; resize() keeps the two in step from here
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = CYLINDER_MESH
	mesh.Parent = part
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

-- Z distances in Config are measured back from the boiler front (z = 0 here until the whole train is centred).
local function boilerCentreY(): number
	local L = Config.Locomotive
	return L.DeckHeight + L.BoilerDiameter / 2
end

-- The avatar's pieces: face, cab, rods and buffers. Returns the cab's back and the shoe buffers' back (Z).
local function placeAvatar(avatar: Model, add: Add): (number, number)
	local L = Config.Locomotive
	local head = avatarPart(avatar, "Head")
	local upper = avatarPart(avatar, "UpperTorso")
	local lower = avatarPart(avatar, "LowerTorso")
	assert(head and upper and lower, "the avatar has no R15 head or torso")

	-- The face: its own proportions, as tall as most of the boiler, flattened front to back and set on the door.
	local headScale = L.BoilerDiameter * L.HeadToBoiler / head.Size.Y
	local headSize = Vector3.new(head.Size.X * headScale, head.Size.Y * headScale, head.Size.Z * headScale * L.HeadDepth)
	add({ part = head, size = headSize, rest = CFrame.new(0, boilerCentreY(), -L.DoorThickness - headSize.Z / 2 + 0.15) })

	-- The cab: waist (lower torso, the belt and the top of the pants) with the upper torso standing on it.
	local cabFront = L.BoilerLength - 0.3
	local cabZ = cabFront + L.CabDepth / 2
	local upperHeight = L.CabHeight - L.CabWaist
	add({ part = lower, size = Vector3.new(L.CabWidth, L.CabWaist, L.CabDepth), rest = CFrame.new(0, L.DeckHeight + L.CabWaist / 2, cabZ) * BACKWARD })
	add({
		part = upper,
		size = Vector3.new(L.CabWidth, upperHeight, L.CabDepth),
		rest = CFrame.new(0, L.DeckHeight + L.CabWaist + upperHeight / 2, cabZ) * BACKWARD,
	})
	local cabBack = cabFront + L.CabDepth

	-- The rods: each arm runs from the rear driving wheel's crank pin (shoulder end) to the front one, which the hand
	-- holds. Each side's crank comes from CrankMotion.forSide, shared with the crank pins.
	local front, rear = L.DriversAt[1], L.DriversAt[2]
	local rodX = L.WheelTrack + L.WheelWidth / 2 + L.PinLength + L.ArmThickness / 2
	for _, side in { "Right", "Left" } do
		local sign = if side == "Right" then 1 else -1
		local crank = CrankMotion.forSide(sign, L.CrankRadius)
		local pieces = {}
		for _, piece in { "UpperArm", "LowerArm", "Hand" } do
			local part = avatarPart(avatar, side .. piece)
			if part then
				table.insert(pieces, part)
			end
		end
		if #pieces > 0 then
			local reach = 0 -- arm length (own Y) up to the hand's middle
			for i, part in pieces do
				reach += if i == #pieces then part.Size.Y / 2 else part.Size.Y
			end
			local stretch = (rear - front) / reach
			local thick = L.ArmThickness / pieces[1].Size.X
			local z = rear
			for _, part in pieces do
				local size = Vector3.new(part.Size.X * thick, part.Size.Y * stretch, part.Size.Z * thick)
				add({ part = part, size = size, rest = CFrame.new(sign * rodX, L.DriverRadius, z - size.Y / 2) * ROD, crank = crank })
				z -= size.Y
			end
		end
	end

	-- The buffers: lower legs sticking out of the cab back, shoes on their ends with the soles facing backward.
	local rearEnd = cabBack
	for _, side in { "Right", "Left" } do
		local x = if side == "Right" then L.BufferSpread else -L.BufferSpread
		local shin = avatarPart(avatar, side .. "LowerLeg")
		local foot = avatarPart(avatar, side .. "Foot")
		local z = cabBack
		if shin then
			local thick = 0.7 / shin.Size.X
			local size = Vector3.new(shin.Size.X * thick, L.ShinLength, shin.Size.Z * thick)
			add({ part = shin, size = size, rest = CFrame.new(x, L.BufferHeight, z + size.Y / 2) * SUPINE })
			z += size.Y
		end
		if foot then
			local size = foot.Size * (L.FootLength / foot.Size.Z)
			add({ part = foot, size = size, rest = CFrame.new(x, L.BufferHeight, z + size.Y / 2) * SUPINE })
			z += size.Y
		end
		rearEnd = math.max(rearEnd, z)
	end
	return cabBack, rearEnd
end

-- Boiler, wheels, crank pins, frame and fittings. Returns the cowcatcher's front (Z).
local function addTrainParts(model: Model, cabBack: number, add: Add): number
	local L = Config.Locomotive
	local colors = L.Colors
	local deck = L.DeckHeight
	local diameter = L.BoilerDiameter
	local centreY = boilerCentreY()
	local top = deck + diameter

	add({ part = cylinder("Boiler", colors.Boiler, model), size = Vector3.new(diameter, L.BoilerLength, diameter), rest = CFrame.new(0, centreY, L.BoilerLength / 2) * ALONG_TRACK })
	for _, share in L.BandsAt do
		local band = cylinder("BoilerBand", colors.Brass, model)
		add({ part = band, size = Vector3.new(diameter + 0.12, 0.25, diameter + 0.12), rest = CFrame.new(0, centreY, L.BoilerLength * share) * ALONG_TRACK })
	end
	local door = cylinder("SmokeboxDoor", colors.Iron, model)
	add({ part = door, size = Vector3.new(L.DoorDiameter, L.DoorThickness, L.DoorDiameter), rest = CFrame.new(0, centreY, -L.DoorThickness / 2) * ALONG_TRACK })

	-- Wheels stay still (a squashed round wheel turning would wobble); the crank pins and the arms show the turning.
	local wheelX = L.WheelTrack
	for _, sign in { -1, 1 } do
		local crank = CrankMotion.forSide(sign, L.CrankRadius) -- the same circle as that side's arm
		for _, z in L.DriversAt do
			local r = L.DriverRadius
			add({ part = cylinder("Wheel", colors.Iron, model), size = Vector3.new(r * 2, L.WheelWidth, r * 2), rest = CFrame.new(sign * wheelX, r, z) * ACROSS })
			local face = wheelX + L.WheelWidth / 2
			add({ part = cylinder("Hub", colors.Brass, model), size = Vector3.new(r * 0.6, 0.12, r * 0.6), rest = CFrame.new(sign * (face + 0.06), r, z) * ACROSS })
			local pin = cylinder("CrankPin", colors.Brass, model)
			add({ part = pin, size = Vector3.new(0.4, L.PinLength, 0.4), rest = CFrame.new(sign * (face + L.PinLength / 2), r, z) * ACROSS, crank = crank })
		end
		local r = L.LeadRadius
		add({ part = cylinder("Wheel", colors.Iron, model), size = Vector3.new(r * 2, L.WheelWidth, r * 2), rest = CFrame.new(sign * wheelX, r, L.LeadAt) * ACROSS })
	end

	-- Cab roof over the standing torso (the cowboy's floor later).
	local overhang = L.RoofOverhang * 2
	add({
		part = newPart("Part", "CabRoof", colors.Iron, Enum.Material.Metal, model),
		size = Vector3.new(L.CabWidth + overhang, L.RoofThickness, L.CabDepth + overhang),
		rest = CFrame.new(0, deck + L.CabHeight + L.RoofThickness / 2, cabBack - L.CabDepth / 2),
	})

	-- Frame between the wheels, from the buffer beam to the cab back.
	local frameWidth = (L.WheelTrack - L.WheelWidth / 2) * 2 - 0.2
	local frame = newPart("Part", "Frame", colors.Iron, Enum.Material.Metal, model)
	local beamBack = L.BeamAt + 0.5
	add({
		part = frame,
		size = Vector3.new(frameWidth, L.FrameThickness, cabBack - L.BeamAt),
		rest = CFrame.new(0, deck - L.FrameThickness / 2, (L.BeamAt + cabBack) / 2),
	})
	local beam = newPart("Part", "BufferBeam", colors.Beam, Enum.Material.SmoothPlastic, model)
	add({ part = beam, size = Vector3.new(L.BeamWidth, L.BeamHeight, beamBack - L.BeamAt), rest = CFrame.new(0, deck - L.BeamHeight / 2, (L.BeamAt + beamBack) / 2) })

	-- Chimney and its cap fold together from the chimney's foot (harder than the body: ChimneyExponent).
	local foot = Vector3.new(0, top - L.ChimneySink, L.ChimneyAt)
	local chimneyHeight = L.ChimneyHeight + L.ChimneySink
	local exponent = Config.Squash.ChimneyExponent
	local chimney = cylinder("Chimney", colors.Iron, model)
	add({
		part = chimney,
		size = Vector3.new(L.ChimneyDiameter, chimneyHeight, L.ChimneyDiameter),
		rest = CFrame.new(foot + Vector3.new(0, chimneyHeight / 2, 0)),
		anchor = foot,
		exponent = exponent,
	})
	local cap = cylinder(Names.ChimneyCap, colors.Iron, model)
	add({
		part = cap,
		size = Vector3.new(L.CapDiameter, L.CapHeight, L.CapDiameter),
		rest = CFrame.new(foot + Vector3.new(0, chimneyHeight + L.CapHeight / 2, 0)),
		anchor = foot,
		exponent = exponent,
	})

	-- A block with a sphere mesh, not a Ball part: Roblox keeps Ball parts perfectly round, the mesh can squash.
	local dome = newPart("Part", "SteamDome", colors.Brass, Enum.Material.Metal, model)
	local domeMesh = Instance.new("SpecialMesh")
	domeMesh.MeshType = Enum.MeshType.Sphere
	domeMesh.Parent = dome
	local domeSize = L.DomeSize
	add({ part = dome, size = Vector3.new(domeSize, domeSize, domeSize), rest = CFrame.new(0, top + 0.2, L.DomeAt), anchor = Vector3.new(0, top, L.DomeAt) })

	-- Headlamp on the boiler front: an iron box with a glowing lens.
	local lamp = newPart("Part", "Lamp", colors.Iron, Enum.Material.Metal, model)
	local lampSize = Vector3.new(1.1, 0.9, 0.9)
	local lampY = top + lampSize.Y / 2 - 0.1
	add({ part = lamp, size = lampSize, rest = CFrame.new(0, lampY, L.LampAt), anchor = Vector3.new(0, top, L.LampAt) })
	local lens = newPart("Part", "LampLens", colors.Lamp, Enum.Material.Neon, model)
	local lensZ = L.LampAt - lampSize.Z / 2 - 0.05
	add({ part = lens, size = Vector3.new(0.75, 0.6, 0.1), rest = CFrame.new(0, lampY, lensZ), anchor = Vector3.new(0, top, lensZ) })

	-- Slatted cowcatcher in front of the buffer beam; each slat slopes down toward the front (a wedge's own -Z).
	local slats = L.CowcatcherSlats
	local span = L.BeamWidth * 0.9
	local slatWidth = span / (slats * 2 - 1)
	local slatHeight = deck - L.BeamHeight - 0.1
	local catcherFront = L.BeamAt - L.CowcatcherLength
	for i = 1, slats do
		local x = -span / 2 + slatWidth / 2 + (i - 1) * slatWidth * 2
		local slat = newPart("WedgePart", "Cowcatcher", colors.Wood, Enum.Material.Wood, model)
		add({
			part = slat,
			size = Vector3.new(slatWidth, slatHeight, L.CowcatcherLength),
			rest = CFrame.new(x, 0.1 + slatHeight / 2, L.BeamAt - L.CowcatcherLength / 2),
		})
	end
	return catcherFront
end

-- The finished locomotive at `base` (on the rails, facing -Z). The avatar model becomes its child.
function LocomotiveBuilder.build(avatar: Model, base: CFrame): Model
	local model = Instance.new("Model")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the animator needs every part at once
	local placements: { Placement } = {}
	local function add(placement: Placement)
		table.insert(placements, placement)
	end

	local cabBack, back = placeAvatar(avatar, add)
	local placed: { [BasePart]: boolean } = {}
	for _, placement in placements do
		placed[placement.part] = true
	end
	local front = addTrainParts(model, cabBack, add)

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
		local crank = placement.crank
		if crank then
			part:SetAttribute(Names.CrankRadius, crank.radius)
			part:SetAttribute(Names.CrankPhase, crank.phase)
		end
	end
	-- Anything else in the avatar (root part, upper legs, an unexpected extra part) waits invisibly at the base.
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
	focus.CFrame = base * CFrame.new(0, Config.Locomotive.DeckHeight + Config.Locomotive.BoilerDiameter, 0)
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
