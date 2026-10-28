--!strict
-- The sounds of the weapon crates on this client (the crates themselves are the server's: WeaponDrops): a parachute
-- opening as one starts falling, a wooden thump when it lands (Names.CrateLanded), and the weapon being taken up at
-- whoever takes it (Names.CrateTakenBy); and of what weapons leave in the arena (the server's): the fizz of a lit
-- dynamite stick while it flies ("Dynamite" parts), a wheel rumbling while it rolls (Names.WheelModel), oil splashing
-- down as a slick is poured (Names.SlickPart), and a coal lump cracking with a puff of black dust where it ends
-- (Names.LumpPart).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local SoundBank = require(shared:WaitForChild("SoundBank"))

local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

-- A coal lump ended at `at` (it hit someone or the train): a crack and a puff of coal dust.
local function crumble(at: Vector3)
	local part = PartUtil.decor("TrainBrawlCoalDust", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, Workspace)
	part.Transparency = 1
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = DUST_TEXTURE
	dust.Enabled = false
	dust.Lifetime = NumberRange.new(0.3, 0.5)
	dust.Speed = NumberRange.new(4, 9)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Drag = 4
	dust.Size = NumberSequence.new(0.6, 1.8)
	dust.Transparency = NumberSequence.new(0.3, 1)
	dust.Color = ColorSequence.new(Color3.fromRGB(40, 38, 40))
	dust.Parent = attachment
	dust:Emit(10)
	SoundBank.play("CoalHit", part)
	Debris:AddItem(part, 1.5)
end

local DropShow = {}

local function watch(crate: Instance)
	if not crate:IsA("Model") then
		return
	end
	-- Its parts may arrive after the model itself.
	local box = crate.PrimaryPart or crate:WaitForChild("Box", 5)
	if not (box and box:IsA("BasePart")) then
		return
	end
	if crate:GetAttribute(Names.CrateLanded) ~= true then
		SoundBank.play("Parachute", box)
	end
	crate:GetAttributeChangedSignal(Names.CrateLanded):Connect(function()
		if crate:GetAttribute(Names.CrateLanded) == true then
			SoundBank.play("CrateLand", box)
		end
	end)
	crate:GetAttributeChangedSignal(Names.CrateTakenBy):Connect(function()
		-- At whoever took it (the crate goes a moment later and would cut the sound off).
		local name = crate:GetAttribute(Names.CrateTakenBy)
		local player = if typeof(name) == "string" then Players:FindFirstChild(name) else nil
		local character = if player and player:IsA("Player") then player.Character else nil
		local root = character and character:FindFirstChild("HumanoidRootPart")
		SoundBank.play("Pickup", if root and root:IsA("BasePart") then root else nil)
	end)
end

-- crates: the folder the server drops crates into; arena: the arena folder (lit sticks fly in it).
function DropShow.start(crates: Instance, arena: Instance)
	crates.ChildAdded:Connect(function(crate: Instance)
		task.spawn(watch, crate)
	end)
	for _, crate in crates:GetChildren() do
		task.spawn(watch, crate)
	end
	arena.ChildAdded:Connect(function(child: Instance)
		if child.Name == "Dynamite" and child:IsA("BasePart") then
			SoundBank.play("Fuse", child)
		elseif child.Name == Names.SlickPart and child:IsA("BasePart") then
			SoundBank.play("OilSplat", child)
		elseif child.Name == Names.WheelModel and child:IsA("Model") then
			local rim = child.PrimaryPart or child:WaitForChild("Rim", 2)
			if rim and rim:IsA("BasePart") then
				SoundBank.play("WheelRoll", rim)
			end
		elseif child.Name == Names.LumpPart and child:IsA("BasePart") then
			child.AncestryChanged:Connect(function()
				if not child:IsDescendantOf(Workspace) then
					crumble(child.Position)
				end
			end)
		end
	end)
end

return DropShow
