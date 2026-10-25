--!strict
-- Dresses every locomotive on this client, from the same layout and car kind the server built it from (ArenaLayout,
-- Config.Arena.CarKinds): two pairs of big driving wheels with coupling rods that circle with them as fast as the
-- run (update; the wheels themselves are plain discs, so not turning them does not show), small leading wheels, the
-- steam cylinders, a cowcatcher and buffer beam, the dark smokebox with its door and headlamp, brass bands, a steam
-- dome, running boards and handrails along the boiler, the cab's windows and number, a rim on the chimney and its
-- smoke (it leaves fast upward and fades as the run's wind bends it back, so it is gone above the roofs behind instead
-- of hiding them; whoever stands on a chimney's top plugs it, so nobody stands inside the smoke). All drawn only
-- (PartUtil.decor): nothing here collides, casts a shadow or is seen by raycasts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))

local LocomotiveDecor = {}
LocomotiveDecor.__index = LocomotiveDecor

-- A part that circles with the driving wheels: where it is at crank angle 0 (the pin at the top) and its side's phase
-- (the left side runs a quarter turn ahead).
type Crank = { part: Part, rest: CFrame, phase: number }
-- A chimney's smoke and where its top is (its middle) and how far round it someone counts as standing on it.
type Chimney = { emitter: ParticleEmitter, top: Vector3, reach: number }
type Fields = {
	folder: Folder,
	cranks: { Crank },
	chimneys: { Chimney },
	parts: { BasePart },
	cframes: { CFrame },
	angle: number,
}
export type Decor = typeof(setmetatable({} :: Fields, LocomotiveDecor))

local DRIVERS = { 0.37, 0.59 } -- the driving wheels' axles, as shares along the locomotive
local LEADING = { 0.07, 0.2 } -- the small leading wheels'
local LEADING_RADIUS = 0.9
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local METAL = Enum.Material.Metal
local BLOCK = Enum.PartType.Block
local CYLINDER = Enum.PartType.Cylinder
local ALONG_TRACK = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder (round about its X) turned to lie along the track
local STOOD_UP = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder stood upright

local function piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	return PartUtil.decor(name, size, cframe, color, material or METAL, parent, shape or BLOCK)
end

local function smoke(parent: Instance, at: Vector3): ParticleEmitter
	local d, colors = Config.Decor, Config.Decor.Colors
	local source = piece(parent, "SmokeSource", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at), colors.Iron)
	source.Transparency = 1
	local attachment = Instance.new("Attachment")
	attachment.Parent = source
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Texture = SMOKE_TEXTURE
	emitter.Rate = d.SmokeRate
	emitter.Lifetime = NumberRange.new(d.SmokeSeconds * 0.75, d.SmokeSeconds)
	emitter.Speed = NumberRange.new(d.SmokeSpeed * 0.85, d.SmokeSpeed * 1.15)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, 2, d.SmokeWind) -- the run's wind pulls it back (+Z)
	emitter.Drag = 0.5
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.8),
		NumberSequenceKeypoint.new(0.35, 4.5),
		NumberSequenceKeypoint.new(1, 8),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(colors.Smoke, colors.SmokeFade)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Parent = attachment
	return emitter
end

-- One locomotive (train `number`) on line x. Adds the parts that circle with the wheels to `cranks` and its chimney's
-- smoke to `chimneys`.
local function dress(parent: Instance, x: number, place: ArenaLayout.CarPlace, kind: ArenaLayout.Kind, number: number, cranks: { Crank }, chimneys: { Chimney })
	local a, d, colors = Config.Arena, Config.Decor, Config.Decor.Colors
	local boiler = kind.boiler
	if not boiler then
		return
	end
	local front = place.front
	local radius = boiler.width / 2
	local boilerY = boiler.top - radius -- the boiler's middle
	local boilerEnd = front + place.length * boiler.to
	local cabFront = front + place.length * (kind.roofFrom or 0)
	local red = a.Colors.Wheel

	-- Driving wheels (a dark tyre round a red disc, a hub), each side's coupling rod and crank pins.
	local driverZ = { front + place.length * DRIVERS[1], front + place.length * DRIVERS[2] }
	local r = d.DriverRadius
	for _, side in { -1, 1 } do
		local wheelX = x + side * a.Gauge
		local phase = if side == 1 then 0 else math.pi / 2
		for _, z in driverZ do
			piece(parent, "Tyre", Vector3.new(0.3, r * 2, r * 2), CFrame.new(wheelX, r, z), colors.Iron, METAL, CYLINDER)
			piece(parent, "Driver", Vector3.new(0.45, r * 2 - 0.6, r * 2 - 0.6), CFrame.new(wheelX, r, z), red, METAL, CYLINDER)
			piece(parent, "Hub", Vector3.new(0.6, 0.8, 0.8), CFrame.new(wheelX, r, z), colors.Iron, METAL, CYLINDER)
			local pinRest = CFrame.new(wheelX + side * 0.45, r + d.CrankRadius, z)
			table.insert(cranks, { part = piece(parent, "CrankPin", Vector3.new(0.3, 0.45, 0.45), pinRest, colors.Brass, METAL, CYLINDER), rest = pinRest, phase = phase })
		end
		local rodRest = CFrame.new(wheelX + side * 0.6, r + d.CrankRadius, (driverZ[1] + driverZ[2]) / 2)
		local rod = piece(parent, "CouplingRod", Vector3.new(0.2, 0.36, driverZ[2] - driverZ[1] + 0.8), rodRest, colors.Iron)
		table.insert(cranks, { part = rod, rest = rodRest, phase = phase })
		-- Leading wheels in their little truck, and the steam cylinder above them.
		for _, share in LEADING do
			piece(parent, "LeadingWheel", Vector3.new(0.35, LEADING_RADIUS * 2, LEADING_RADIUS * 2), CFrame.new(wheelX, LEADING_RADIUS, front + place.length * share), red, METAL, CYLINDER)
		end
		local leadingMiddle = front + place.length * (LEADING[1] + LEADING[2]) / 2
		piece(parent, "LeadingTruck", Vector3.new(0.3, 0.5, 3.2), CFrame.new(x + side * (a.Gauge + 0.4), LEADING_RADIUS + 0.05, leadingMiddle), colors.Iron)
		piece(parent, "SteamCylinder", Vector3.new(2.6, 1.5, 1.5), CFrame.new(x + side * (a.Gauge + 0.55), 2.6, leadingMiddle + 0.4) * ALONG_TRACK, colors.Iron, METAL, CYLINDER)
		-- A running board along the boiler's side (its inner edge inside the boiler) and a handrail higher up.
		local boardY = boilerY - 1.8
		local boardIn = math.sqrt(radius * radius - 1.8 * 1.8) - 0.12
		piece(parent, "RunningBoard", Vector3.new(1.2, 0.15, boilerEnd - front - 1.2), CFrame.new(x + side * (boardIn + 0.6), boardY, (front + boilerEnd) / 2), colors.Iron)
		local railY = boilerY + 2.4
		piece(parent, "Handrail", Vector3.new(0.1, 0.1, boilerEnd - front - 2.7), CFrame.new(x + side * (math.sqrt(radius * radius - 2.4 * 2.4) + 0.15), railY, (front + 1.5 + boilerEnd - 1.2) / 2), colors.Brass)
		-- The cab: two side windows in cream frames, the number under them, a front window beside the boiler.
		for _, dz in { 1.6, 4.4 } do
			local z = cabFront + dz
			local faceX = x + side * (a.RoofWidth / 2 - a.BodyInset)
			piece(parent, "WindowFrame", Vector3.new(0.08, 2.4, 2), CFrame.new(faceX + side * 0.04, place.roof - 2.6, z), colors.Trim, Enum.Material.Wood)
			piece(parent, "Window", Vector3.new(0.1, 2, 1.6), CFrame.new(faceX + side * 0.06, place.roof - 2.6, z), colors.Window, Enum.Material.Glass)
		end
		local plateAt = CFrame.new(x + side * (a.RoofWidth / 2 - a.BodyInset + 0.03), place.roof - 5.3, cabFront + 3)
		PartUtil.letterPlate(parent, Vector3.new(0.04, 1.2, 3.2), plateAt, if side == 1 then Enum.NormalId.Right else Enum.NormalId.Left, "No. " .. number, colors.Brass)
		piece(parent, "Window", Vector3.new(1.2, 1.5, 0.1), CFrame.new(x + side * 3.9, place.roof - 2.1, cabFront - 0.05), colors.Window, Enum.Material.Glass)
	end

	-- The front: smokebox (a darker band of the boiler), its door with a hinge and handle, the headlamp, the buffer
	-- beam and the cowcatcher (a wedge sloping down to the front).
	local stack = kind.stack
	local smokeboxLength = if stack then place.length * stack.along * 2 else 3 -- reaches past the chimney
	piece(parent, "Smokebox", Vector3.new(smokeboxLength, boiler.width + 0.1, boiler.width + 0.1), CFrame.new(x, boilerY, front + smokeboxLength / 2) * ALONG_TRACK, colors.Iron, METAL, CYLINDER)
	piece(parent, "SmokeboxDoor", Vector3.new(0.25, boiler.width * 0.7, boiler.width * 0.7), CFrame.new(x, boilerY, front - 0.12) * ALONG_TRACK, colors.Iron:Lerp(Color3.new(0, 0, 0), 0.3), METAL, CYLINDER)
	piece(parent, "DoorHandle", Vector3.new(0.35, 0.9, 0.9), CFrame.new(x, boilerY, front - 0.3) * ALONG_TRACK, colors.Brass, METAL, CYLINDER)
	piece(parent, "DoorHinge", Vector3.new(2.8, 0.2, 0.08), CFrame.new(x + 1, boilerY, front - 0.27), colors.Iron)
	local lampY = boiler.top - 0.9
	piece(parent, "Headlamp", Vector3.new(1.6, 1.5, 1.5), CFrame.new(x, lampY, front - 0.5), colors.Iron)
	piece(parent, "LampGlass", Vector3.new(0.12, 1.1, 1.1), CFrame.new(x, lampY, front - 1.31) * ALONG_TRACK, colors.Lamp, Enum.Material.Neon, CYLINDER)
	piece(parent, "BufferBeam", Vector3.new(a.RoofWidth - 1.6, 0.9, 0.4), CFrame.new(x, a.BodyBottom + 0.25, front - 0.2), red)
	PartUtil.decorWedge("Cowcatcher", Vector3.new(7, 1.6, 2.4), CFrame.new(x, 0.85, front - 1.3), red, METAL, parent)

	-- Along the boiler: brass bands (clear of the chimney and dome) and the steam dome, low on the ridge.
	for _, share in { 0.38, 0.73, 0.97 } do
		local z = front + (boilerEnd - front) * share
		piece(parent, "Band", Vector3.new(0.3, boiler.width + 0.12, boiler.width + 0.12), CFrame.new(x, boilerY, z) * ALONG_TRACK, colors.Brass, METAL, CYLINDER)
	end
	local domeZ = front + (boilerEnd - front) * 0.56
	piece(parent, "Dome", Vector3.new(1.2, 2.4, 2.4), CFrame.new(x, boiler.top - 0.1, domeZ) * STOOD_UP, colors.Brass, METAL, CYLINDER)
	piece(parent, "DomeCap", Vector3.new(0.25, 2.7, 2.7), CFrame.new(x, boiler.top + 0.6, domeZ) * STOOD_UP, colors.Brass, METAL, CYLINDER)
	piece(parent, "Whistle", Vector3.new(0.6, 0.35, 0.35), CFrame.new(x + 2.5, place.roof + 0.3, cabFront + 0.4) * STOOD_UP, colors.Brass, METAL, CYLINDER)

	-- The chimney (solid, the server's): a collar where it meets the boiler, a rim flush with its top, and the smoke.
	if stack then
		local z = front + place.length * stack.along
		local top = boiler.top + stack.height
		local collar = stack.width * a.StackPipe + 0.5
		piece(parent, "StackCollar", Vector3.new(0.5, collar, collar), CFrame.new(x, boiler.top + 0.1, z) * STOOD_UP, colors.Brass, METAL, CYLINDER)
		piece(parent, "StackRim", Vector3.new(0.25, stack.width + 0.12, stack.width + 0.12), CFrame.new(x, top - 0.125, z) * STOOD_UP, colors.Iron, METAL, CYLINDER)
		table.insert(chimneys, { emitter = smoke(parent, Vector3.new(x, top + 0.2, z)), top = Vector3.new(x, top, z), reach = stack.width / 2 + 0.5 })
	end
end

-- layout: the arena (ArenaLayout.layout).
function LocomotiveDecor.new(layout: ArenaLayout.Layout): Decor
	local old = Workspace:FindFirstChild(Names.LocomotiveDecorFolder)
	if old then
		old:Destroy()
	end
	local folder = PartUtil.folder(Workspace, Names.LocomotiveDecorFolder)
	local cranks: { Crank } = {}
	local chimneys: { Chimney } = {}
	for i, train in layout.trains do
		for _, place in train.cars do
			local kind = Config.Arena.CarKinds[place.kind]
			if kind.boiler then
				dress(folder, train.x, place, kind, i, cranks, chimneys)
			end
		end
	end
	local parts: { BasePart }, cframes: { CFrame } = {}, {}
	for _, crank in cranks do
		table.insert(parts, crank.part)
		table.insert(cframes, crank.rest)
	end
	local fields: Fields = { folder = folder, cranks = cranks, chimneys = chimneys, parts = parts, cframes = cframes, angle = 0 }
	return setmetatable(fields, LocomotiveDecor)
end

-- Turns the coupling rods on by this frame's run (dt seconds): as fast as wheels of the driving radius would roll.
-- characters: the fighters on the trains; one standing on a chimney's top plugs its smoke.
function LocomotiveDecor.update(self: Decor, dt: number, characters: { Model })
	local d = Config.Decor
	self.angle = (self.angle + dt * Config.Run.Speed / d.DriverRadius) % (2 * math.pi)
	for i, crank in self.cranks do
		local turn = self.angle + crank.phase
		-- Angle 0 is the top of the circle; the top moves forward (-Z) as the wheels roll on.
		self.cframes[i] = crank.rest + Vector3.new(0, d.CrankRadius * (math.cos(turn) - 1), -d.CrankRadius * math.sin(turn))
	end
	Workspace:BulkMoveTo(self.parts, self.cframes, Enum.BulkMoveMode.FireCFrameChanged)
	for _, chimney in self.chimneys do
		local plugged = false
		for _, model in characters do
			local at = model:GetPivot().Position
			local dx, dz = at.X - chimney.top.X, at.Z - chimney.top.Z
			if dx * dx + dz * dz < chimney.reach * chimney.reach and at.Y > chimney.top.Y and at.Y < chimney.top.Y + 7 then
				plugged = true
				break
			end
		end
		if chimney.emitter.Enabled == plugged then
			chimney.emitter.Enabled = not plugged
		end
	end
end

function LocomotiveDecor.destroy(self: Decor)
	self.folder:Destroy()
end

return LocomotiveDecor
