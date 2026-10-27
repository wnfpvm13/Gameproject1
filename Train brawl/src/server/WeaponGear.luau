--!strict
-- Puts a character's weapon in its right hand (Config.Weapons, the model's Names.Weapon): a big cartoon bat, a hammer
-- (a handle and an iron head), a dynamite stick (red, a fuse with sparks) or a gold bar; bare fists hold nothing.
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
			local point = Instance.new("Attachment")
			point.Name = name
			point.Position = at
			point.Parent = root
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
