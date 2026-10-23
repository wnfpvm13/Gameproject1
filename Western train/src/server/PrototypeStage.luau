--!strict
-- Prototype ground and rails: a sand floor and one straight pair of rails per locomotive slot, built once at server
-- start into Workspace.WesternTrainStage (only that folder is replaced), plus a light desert haze that hides the far
-- ends. The sleepers, roadside props and bridges are drawn by each client, moving with the run (TrackScroll,
-- CourseView).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))

local PrototypeStage = {}

export type Stage = { folder: Folder, slotCFrame: (slot: number) -> CFrame }

local FOLDER_NAME = "WesternTrainStage"

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
	block("Ground", Vector3.new(width, 2, stage.RailLength + 200), CFrame.new(0, -1, 0), stage.Colors.Sand, Enum.Material.Sand, folder)
	for slot = 1, stage.Slots do
		local x = slotX(slot)
		for _, side in { -1, 1 } do
			local rail = CFrame.new(x + side * track, stage.RailHeight / 2, 0)
			block("Rail", Vector3.new(0.35, stage.RailHeight, stage.RailLength), rail, stage.Colors.Rail, Enum.Material.Metal, folder)
		end
	end
	local haze = Lighting:FindFirstChild(Names.Haze)
	if not (haze and haze:IsA("Atmosphere")) then
		local h = stage.Haze
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = Names.Haze
		atmosphere.Density = h.Density
		atmosphere.Offset = h.Offset
		atmosphere.Color = h.Color
		atmosphere.Decay = h.Decay
		atmosphere.Glare = h.Glare
		atmosphere.Haze = h.Haze
		atmosphere.Parent = Lighting
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
