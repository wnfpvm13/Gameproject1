--!strict
-- Puts a character's weapon in its right hand (Config.Weapons, the model's Names.Weapon): a big cartoon bat, a hammer
-- (a handle and an iron head), a dynamite stick (red, a fuse with sparks), a gold bar, a whip (a grip and a drawn
-- lash), a coal shovel, a lasso (drawn rope coils), a coal lump, a brass steam hose, a red oil can, a bundle of
-- firecrackers or a spare locomotive wheel; bare fists hold nothing.
-- Welded to the hand, pointing ahead and a little down, massless and not colliding (hits are judged by the
-- WeaponService, not by touching). Made on the server so every client sees it; the attacks themselves are drawn on
-- each client by turning the body's joints (SwingPose), with a streak along the part that strikes (between the
-- weapon's Names.TrailTip and Names.TrailBase attachments: SwingTrail).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local FuseSparks = require(shared:WaitForChild("FuseSparks"))

local WeaponGear = {}

local GOLD = Color3.fromRGB(240, 196, 64)
local IRON = Color3.fromRGB(70, 68, 72)
local WOOD = Color3.fromRGB(196, 150, 90)
local RED = Color3.fromRGB(196, 40, 32)
local LEATHER = Color3.fromRGB(92, 58, 36)
local ROPE = Color3.fromRGB(206, 170, 112)
local COAL = Color3.fromRGB(38, 36, 40)
local BRASS = Color3.fromRGB(198, 150, 64)
local RUBBER = Color3.fromRGB(46, 44, 42)

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	return p
end

-- An attachment on `p` at `at` whose X axis points along `axis` (a Beam's curve leaves and arrives along it).
local function point(p: BasePart, name: string, at: Vector3, axis: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	local up = if math.abs(axis.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	a.CFrame = CFrame.fromMatrix(at, axis, (up - axis * up:Dot(axis)).Unit)
	a.Parent = p
	return a
end

-- A drawn rope (a Beam) on `p` from `a` to `b` (attachments).
local function rope(p: BasePart, a: Attachment, b: Attachment, width: number, curve0: number, curve1: number): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a
	beam.Attachment1 = b
	beam.Width0 = width
	beam.Width1 = width
	beam.CurveSize0 = curve0
	beam.CurveSize1 = curve1
	beam.Segments = 12
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(ROPE)
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 1
	beam.Parent = p
	return beam
end

-- A ring of rope on `p` around `center` in the plane across `normal` (one of p's axes), `radius` wide: two half circles
-- (a Beam's curve with its handles 4/3 of the radius out makes nearly a half circle).
local function ropeRing(p: BasePart, name: string, center: Vector3, normal: Vector3, side: Vector3, radius: number, width: number)
	local up = normal:Cross(side)
	local k = radius * 4 / 3
	local top = center + up * radius
	local bottom = center - up * radius
	rope(p, point(p, name .. "A", top, side), point(p, name .. "B", bottom, -side), width, k, k)
	rope(p, point(p, name .. "C", top, -side), point(p, name .. "D", bottom, side), width, k, k)
end

-- The weapon's parts, in the hand's space: a list of (part, where) with the grip at the origin and the weapon's length
-- along -Z (ahead of the fist). The first part is the one the others weld to. A two-handed weapon's handle reaches back
-- past the fist for the other hand (Config.Weapons offHand: SwingPose puts that hand there). Also where the part that
-- strikes ends and starts, in the first part's own space (a blow's streak runs between them; none for a thrown stick).
local function shapeOf(weapon: string): ({ { part: Part, at: CFrame } }, Vector3?, Vector3?)
	if weapon == "Bat" then
		-- (The cylinder's +X end is ahead: the barrel, its last 2 studs.)
		local b = Config.Bat
		local length = b.Length
		local stick = part("Bat", Vector3.new(length, b.Thickness, b.Thickness), b.Color, Enum.Material.Wood, Enum.PartType.Cylinder)
		return { { part = stick, at = CFrame.new(0, 0, -(length / 2 - b.Knob)) * CFrame.Angles(0, math.rad(90), 0) } },
			Vector3.new(length / 2 - 0.15, 0, 0),
			Vector3.new(length / 2 - 2.2, 0, 0)
	elseif weapon == "Hammer" then
		-- The fist 1.2 up the handle from its end (the other hand below it), the head 3 ahead of the fist (2.1 up the
		-- handle from its middle).
		local handle = part("Handle", Vector3.new(4.2, 0.32, 0.32), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
		local head = part("Head", Vector3.new(1.0, 1.0, 1.7), IRON, Enum.Material.Metal)
		return {
			{ part = handle, at = CFrame.new(0, 0, -0.9) * CFrame.Angles(0, math.rad(90), 0) },
			{ part = head, at = CFrame.new(0, 0, -3.0) * CFrame.Angles(0, math.rad(90), 0) },
		},
			Vector3.new(2.6, 0, 0),
			Vector3.new(1.2, 0, 0)
	elseif weapon == "Dynamite" then
		local stick = part("Stick", Vector3.new(1.3, 0.5, 0.5), RED, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		local fuse = part("Fuse", Vector3.new(0.5, 0.1, 0.1), Color3.new(0.1, 0.1, 0.1), Enum.Material.Fabric, Enum.PartType.Cylinder)
		FuseSparks.add(fuse)
		return {
			{ part = stick, at = CFrame.new(0, 0.1, -0.2) * CFrame.Angles(0, 0, math.rad(90)) },
			{ part = fuse, at = CFrame.new(0, 0.95, -0.2) * CFrame.Angles(0, 0, math.rad(90)) },
		}
	elseif weapon == "GoldBar" then
		local bar = part("Bar", Vector3.new(0.8, 0.7, 1.6), GOLD, Enum.Material.Foil)
		return { { part = bar, at = CFrame.new(0, 0, -0.7) } }, Vector3.new(0, 0, -0.8), Vector3.new(0, 0, 0.8)
	elseif weapon == "Whip" then
		-- A short wrapped grip; the lash is a rope drawn from its end to a tip 6.5 ahead, sagging in an S (a Beam: no
		-- parts to swing about). The streak runs along its last 3 studs.
		local grip = part("Grip", Vector3.new(0.9, 0.26, 0.26), LEATHER, Enum.Material.Fabric, Enum.PartType.Cylinder)
		-- Leaving the grip a little down and coming into the tip from above: the rope sags between them.
		local from = point(grip, "LashFrom", Vector3.new(0.45, 0, 0), Vector3.new(1, -0.3, 0).Unit)
		local to = point(grip, "LashTo", Vector3.new(6.9, 0, 0), Vector3.new(1, 0.6, 0).Unit)
		local lash = rope(grip, from, to, 0.16, 2, 2)
		lash.Name = "Lash"
		lash.Width1 = 0.06
		lash.Segments = 16
		lash.Color = ColorSequence.new(LEATHER)
		return { { part = grip, at = CFrame.new(0, 0, -0.05) * CFrame.Angles(0, math.rad(90), 0) } }, Vector3.new(6.9, 0, 0), Vector3.new(3.9, 0, 0)
	elseif weapon == "Shovel" then
		-- The fist 1 up the handle from its end (the other hand below it), the blade 2.9 to 3.9 ahead of the fist.
		local handle = part("Handle", Vector3.new(3.6, 0.28, 0.28), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
		local blade = part("Blade", Vector3.new(1.05, 0.12, 1.25), IRON, Enum.Material.Metal)
		local neck = part("Neck", Vector3.new(0.3, 0.2, 0.5), IRON, Enum.Material.Metal)
		return {
			{ part = handle, at = CFrame.new(0, 0, -0.8) * CFrame.Angles(0, math.rad(90), 0) },
			{ part = neck, at = CFrame.new(0, 0, -2.75) },
			{ part = blade, at = CFrame.new(0, -0.08, -3.55) * CFrame.Angles(math.rad(-12), 0, 0) },
		},
			Vector3.new(2.9, 0, 0),
			Vector3.new(1.6, 0, 0)
	elseif weapon == "Lasso" then
		-- A coil of rope in the fist (two turns) and the open loop hanging from it, drawn with Beams on a small knot.
		local knot = part("Knot", Vector3.new(0.35, 0.35, 0.35), ROPE, Enum.Material.Fabric)
		ropeRing(knot, "Coil1", Vector3.new(0.05, -0.45, 0), Vector3.xAxis, Vector3.zAxis, 0.5, 0.12)
		ropeRing(knot, "Coil2", Vector3.new(-0.05, -0.5, 0.05), Vector3.xAxis, Vector3.zAxis, 0.55, 0.12)
		ropeRing(knot, "Loop", Vector3.new(0.25, -1.55, -0.2), Vector3.new(1, 0, 0.3).Unit, Vector3.zAxis, 0.9, 0.1)
		return { { part = knot, at = CFrame.new(0, 0, -0.1) } }
	elseif weapon == "Coal" then
		local lump = part("Lump", Vector3.new(0.75, 0.6, 0.7), COAL, Enum.Material.Slate)
		return { { part = lump, at = CFrame.new(0, 0, -0.25) * CFrame.Angles(math.rad(20), math.rad(35), 0) } }
	elseif weapon == "SteamHose" then
		-- A brass pipe with a flared nozzle 2.4 ahead and a red valve wheel by the fist; the other hand ahead on the pipe.
		local pipe = part("Pipe", Vector3.new(2.6, 0.3, 0.3), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
		local nozzle = part("Nozzle", Vector3.new(0.45, 0.5, 0.5), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
		local valve = part("Valve", Vector3.new(0.08, 0.6, 0.6), RED, Enum.Material.Metal, Enum.PartType.Cylinder)
		local hose = part("Hose", Vector3.new(1.2, 0.32, 0.32), RUBBER, Enum.Material.Rubber, Enum.PartType.Cylinder)
		local nozzleAt = Instance.new("Attachment")
		nozzleAt.Name = "Nozzle"
		nozzleAt.Position = Vector3.new(1.55, 0, 0)
		local pieces = {
			{ part = pipe, at = CFrame.new(0, 0, -0.9) * CFrame.Angles(0, math.rad(90), 0) },
			{ part = nozzle, at = CFrame.new(0, 0, -2.3) * CFrame.Angles(0, math.rad(90), 0) },
			{ part = valve, at = CFrame.new(0, 0.3, -0.2) * CFrame.Angles(0, 0, math.rad(90)) },
			{ part = hose, at = CFrame.new(0, -0.15, 0.75) * CFrame.Angles(0, math.rad(90), math.rad(25)) },
		}
		nozzleAt.Parent = pipe
		return pieces
	elseif weapon == "OilCan" then
		-- A red can held by its handle, its spout pointing ahead.
		local can = part("Can", Vector3.new(0.8, 1, 0.65), RED, Enum.Material.Metal)
		local spout = part("Spout", Vector3.new(0.9, 0.13, 0.13), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
		local cap = part("Cap", Vector3.new(0.12, 0.3, 0.3), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
		return {
			{ part = can, at = CFrame.new(0, -0.55, -0.15) },
			{ part = spout, at = CFrame.new(0, -0.05, -0.85) * CFrame.Angles(0, math.rad(90), math.rad(35)) },
			{ part = cap, at = CFrame.new(0, -0.03, -0.15) * CFrame.Angles(0, 0, math.rad(90)) },
		}
	elseif weapon == "Firecracker" then
		-- A bundle of red sticks tied with a gold band, one fuse with sparks.
		local band = part("Band", Vector3.new(0.5, 0.62, 0.62), GOLD, Enum.Material.Foil, Enum.PartType.Cylinder)
		local pieces = { { part = band, at = CFrame.new(0, 0.05, -0.2) * CFrame.Angles(0, 0, math.rad(90)) } }
		for k = 0, 4 do
			local a = math.rad(72 * k)
			local stick = part("Stick", Vector3.new(1.2, 0.22, 0.22), RED, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			table.insert(pieces, { part = stick, at = CFrame.new(math.cos(a) * 0.2, 0.05, -0.2 + math.sin(a) * 0.2) * CFrame.Angles(0, 0, math.rad(90)) })
		end
		local fuse = part("Fuse", Vector3.new(0.45, 0.08, 0.08), Color3.new(0.1, 0.1, 0.1), Enum.Material.Fabric, Enum.PartType.Cylinder)
		FuseSparks.add(fuse)
		table.insert(pieces, { part = fuse, at = CFrame.new(0, 0.85, -0.2) * CFrame.Angles(0, 0, math.rad(90)) })
		return pieces
	elseif weapon == "Wheel" then
		-- The spare wheel's axle along the grip (both fists on its ends), the wheel between them.
		local t = Config.Thrown
		local axle = part("Axle", Vector3.new(1.3, 0.3, 0.3), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
		local rim = part("Rim", Vector3.new(t.WheelWidth, t.WheelRadius * 2, t.WheelRadius * 2), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
		local hub = part("Hub", Vector3.new(t.WheelWidth + 0.2, t.WheelRadius * 0.6, t.WheelRadius * 0.6), RED, Enum.Material.Metal, Enum.PartType.Cylinder)
		local pieces = {
			{ part = axle, at = CFrame.new(0, 0, -0.55) * CFrame.Angles(0, math.rad(90), 0) },
			{ part = rim, at = CFrame.new(0, 0, -0.55) * CFrame.Angles(0, math.rad(90), 0) },
			{ part = hub, at = CFrame.new(0, 0, -0.55) * CFrame.Angles(0, math.rad(90), 0) },
		}
		for k = 0, 3 do
			local spoke = part("Spoke", Vector3.new(0.22, t.WheelRadius * 1.8, t.WheelWidth * 0.6), RED, Enum.Material.Metal)
			table.insert(pieces, { part = spoke, at = CFrame.new(0, 0, -0.55) * CFrame.Angles(0, 0, math.rad(45 * k)) })
		end
		return pieces
	end
	return {}
end

-- Gives `model` the weapon in its Names.Weapon attribute (bare fists when none), in its current hand: again after
-- the avatar's own body parts replace the default hand, which takes the old weld with it. Returns false when the model
-- has no hand yet.
function WeaponGear.equip(model: Model): boolean
	local hand = CharacterParts.weaponHand(model)
	if not hand then
		return false
	end
	local weapon = WeaponRules.named(Config.Weapons, model:GetAttribute(Names.Weapon))
	local old = model:FindFirstChild(Names.WeaponPart)
	if old then
		local weld = old:FindFirstChildOfClass("WeldConstraint")
		if weld and weld.Part0 == hand and old:GetAttribute(Names.Weapon) == weapon then
			return true -- already holding it
		end
		old:Destroy()
	end
	local pieces, tip, base = shapeOf(weapon)
	if #pieces == 0 then
		return true -- bare fists
	end
	-- Gripped in the fist, tipped 15 degrees down: with the arm lifted out for a swing (SwingPose) the weapon sweeps
	-- level and far in front instead of across the chest.
	local grip = hand.CFrame * CharacterParts.grip(hand)
	local root = pieces[1].part
	root.Name = Names.WeaponPart
	root:SetAttribute(Names.Weapon, weapon)
	if tip and base then
		for name, at in { [Names.TrailTip] = tip, [Names.TrailBase] = base } do
			local mark = Instance.new("Attachment")
			mark.Name = name
			mark.Position = at
			mark.Parent = root
		end
	end
	for k, piece in pieces do
		piece.part.CFrame = grip * piece.at
		if k > 1 then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = piece.part
			weld.Parent = piece.part
			piece.part.Parent = root
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = root
	weld.Parent = root
	root.Parent = model
	return true
end

return WeaponGear
