--!strict
-- Puts a character's weapon in its right hand (Config.Weapons, the model's Names.Weapon): a big cartoon bat, a hammer
-- (a handle and an iron head), a dynamite stick (red, a fuse with sparks) or a gold bar; bare fists hold nothing.
-- Welded to the hand, pointing ahead and a little down, massless and not colliding (hits are judged by the
-- WeaponService, not by touching). Made on the server so every client sees it; the attacks themselves are drawn on
-- each client by turning the shoulder (SwingPose).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))

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
-- along -Z (ahead of the fist). The first part is the one the others weld to.
local function shapeOf(weapon: string): { { part: Part, at: CFrame } }
	if weapon == "Bat" then
		local b = Config.Bat
		local length = b.Length
		local stick = part("Bat", Vector3.new(length, b.Thickness, b.Thickness), b.Color, Enum.Material.Wood, Enum.PartType.Cylinder)
		return { { part = stick, at = CFrame.new(0, 0, -(length / 2 - 0.3)) * CFrame.Angles(0, math.rad(90), 0) } }
	elseif weapon == "Hammer" then
		local handle = part("Handle", Vector3.new(3.6, 0.32, 0.32), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
		local head = part("Head", Vector3.new(1.0, 1.0, 1.7), IRON, Enum.Material.Metal)
		return {
			{ part = handle, at = CFrame.new(0, 0, -1.5) * CFrame.Angles(0, math.rad(90), 0) },
			{ part = head, at = CFrame.new(0, 0, -3.3) * CFrame.Angles(0, math.rad(90), 0) },
		}
	elseif weapon == "Dynamite" then
		local stick = part("Stick", Vector3.new(1.3, 0.5, 0.5), RED, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		local fuse = part("Fuse", Vector3.new(0.5, 0.1, 0.1), Color3.new(0.1, 0.1, 0.1), Enum.Material.Fabric, Enum.PartType.Cylinder)
		local spark = Instance.new("Sparkles")
		spark.SparkleColor = Color3.fromRGB(255, 200, 90)
		spark.Parent = fuse
		return {
			{ part = stick, at = CFrame.new(0, 0.1, -0.2) * CFrame.Angles(0, 0, math.rad(90)) },
			{ part = fuse, at = CFrame.new(0, 0.95, -0.2) * CFrame.Angles(0, 0, math.rad(90)) },
		}
	elseif weapon == "GoldBar" then
		local bar = part("Bar", Vector3.new(0.8, 0.7, 1.6), GOLD, Enum.Material.Foil)
		return { { part = bar, at = CFrame.new(0, 0, -0.7) } }
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
	local pieces = shapeOf(weapon)
	if #pieces == 0 then
		return true -- bare fists
	end
	-- Gripped in the fist, tipped 15 degrees down: with the arm lifted out for a swing (SwingPose) the weapon sweeps
	-- level and far in front instead of across the chest.
	local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.3, 0) * CFrame.Angles(math.rad(-15), 0, 0)
	local root = pieces[1].part
	root.Name = Names.WeaponPart
	root:SetAttribute(Names.Weapon, weapon)
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
