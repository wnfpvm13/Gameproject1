--!strict
-- Prototype ground and rails: a sand floor and one straight track per locomotive slot, built once at server start
-- into Workspace.WesternTrainStage (only that folder is replaced).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))

local PrototypeStage = {}

export type Stage = { folder: Folder, slotCFrame: (slot: number) -> CFrame }

local FOLDER_NAME = "WesternTrainStage"
local SAND = Color3.fromRGB(214, 176, 120)
local RAIL = Color3.fromRGB(92, 88, 86)
local SLEEPER = Color3.fromRGB(96, 66, 44)

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

local function slotX(slot: number): number
	local stage = Config.Stage
	return (slot - (stage.Slots + 1) / 2) * stage.SlotSpacing
end

function PrototypeStage.build(): Stage
	local stage = Config.Stage
	local track = Config.Locomotive.WheelTrack
	local old = Workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local width = stage.Slots * stage.SlotSpacing + 200
	block("Ground", Vector3.new(width, 2, stage.RailLength + 200), CFrame.new(0, -1, 0), SAND, Enum.Material.Sand, folder)
	for slot = 1, stage.Slots do
		local x = slotX(slot)
		for _, side in { -1, 1 } do
			local rail = CFrame.new(x + side * track, stage.RailHeight / 2, 0)
			block("Rail", Vector3.new(0.35, stage.RailHeight, stage.RailLength), rail, RAIL, Enum.Material.Metal, folder)
		end
		local z = -stage.RailLength / 2
		while z <= stage.RailLength / 2 do
			block("Sleeper", Vector3.new(track * 2 + 2, 0.25, 0.8), CFrame.new(x, 0.125, z), SLEEPER, Enum.Material.Wood, folder)
			z += stage.SleeperSpacing
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.5, stage.RailLength / 2 + 20)
	spawn.Parent = folder
	folder.Parent = Workspace
	return {
		folder = folder,
		slotCFrame = function(slot: number): CFrame
			return CFrame.new(slotX(slot), stage.RailHeight, 0) -- facing -Z, the locomotive's forward
		end,
	}
end

return PrototypeStage
