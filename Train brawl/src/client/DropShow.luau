--!strict
-- The sounds of the weapon crates on this client (the crates themselves are the server's: WeaponDrops): a parachute
-- opening as one starts falling, a wooden thump when it lands (Names.CrateLanded), and a bright ding for whoever takes
-- it (Names.CrateTakenBy), and the fizz of a lit dynamite stick while it flies (the server's "Dynamite" parts).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))
local SoundBank = require(shared:WaitForChild("SoundBank"))

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
		SoundBank.play("Twinkle", if root and root:IsA("BasePart") then root else nil)
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
		end
	end)
end

return DropShow
