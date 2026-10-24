--!strict
-- Puts a bat in a character's right hand: a wooden cylinder welded to the hand, pointing ahead and a little down,
-- massless and not colliding (the hits are judged by BatService, not by touching). Made on the server so every client
-- sees it; the swing itself is drawn on each client by turning the shoulder (SwingPose).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local BatGear = {}

-- Gives `model` a bat in its current hand (again after the avatar's own body parts replace the default hand, which
-- takes the old bat's weld with it). Returns false when the model has no hand yet.
function BatGear.equip(model: Model): boolean
	local hand = CharacterParts.batHand(model)
	if not hand then
		return false
	end
	local old = model:FindFirstChild(Names.BatPart)
	if old then
		local weld = old:FindFirstChildOfClass("WeldConstraint")
		if weld and weld.Part0 == hand then
			return true
		end
		old:Destroy()
	end
	local b = Config.Bat
	local bat = Instance.new("Part")
	bat.Name = Names.BatPart
	bat.Shape = Enum.PartType.Cylinder -- along its own X
	bat.Size = Vector3.new(b.Length, b.Thickness, b.Thickness)
	bat.Color = b.Color
	bat.Material = Enum.Material.Wood
	bat.Massless = true
	bat.CanCollide = false
	bat.CanTouch = false
	bat.CanQuery = false
	-- Gripped at one end in the fist: the bat's length (its X) turned to point ahead (-Z), then tipped 15 degrees down.
	-- With the arm lifted out to the side for a swing (SwingPose), that tips the bat a little outward, so it sweeps
	-- level and far in front instead of across the chest.
	local grip = CFrame.new(0, -hand.Size.Y * 0.3, 0) * CFrame.Angles(math.rad(-15), 0, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(b.Length / 2 - 0.3, 0, 0)
	bat.CFrame = hand.CFrame * grip
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = bat
	weld.Parent = bat
	bat.Parent = model
	return true
end

return BatGear
