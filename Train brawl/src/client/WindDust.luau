--!strict
-- The wind of the run on the roofs, on this client: fine sand-coloured specks blowing backward off both edges of every
-- wide roof, at about twice the run's speed, so standing on a roof feels like riding a moving train (the scenery
-- scrolls past, but the roofs themselves looked still). Few and faint: drawn only, nothing collides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local WindDust = {}

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local PER_STUD = 0.12 -- specks a second for every stud of roof edge

-- Builds the wind over `layout`'s wide roofs; returns the folder (destroy it to remove the wind).
function WindDust.build(layout: ArenaLayout.Layout): Folder
	local folder = Instance.new("Folder")
	folder.Name = "TrainBrawlWind"
	for _, surface in layout.surfaces do
		if surface.width >= Config.Arena.RoofWidth * 0.6 and surface.length > 6 then
			for _, side in { -1, 1 } do
				local x = surface.x + side * (surface.width / 2 - 0.3)
				local strip = PartUtil.decor("Wind", Vector3.new(0.2, 0.2, surface.length), CFrame.new(x, surface.top + 0.6, surface.z), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, folder)
				strip.Transparency = 1
				local specks = Instance.new("ParticleEmitter")
				specks.Texture = SMOKE_TEXTURE
				specks.Color = ColorSequence.new(Color3.fromRGB(226, 200, 160))
				specks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.45) })
				specks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(1, 1) })
				specks.Lifetime = NumberRange.new(0.5, 0.9)
				specks.Rate = surface.length * PER_STUD
				-- Blown back (+Z) at about twice the run's speed, drifting a little outward and up.
				specks.VelocityInheritance = 0
				specks.EmissionDirection = Enum.NormalId.Back
				specks.Speed = NumberRange.new(Config.Run.Speed * 1.6, Config.Run.Speed * 2.4)
				specks.SpreadAngle = Vector2.new(12, 12)
				specks.Parent = strip
			end
		end
	end
	folder.Parent = Workspace
	return folder
end

return WindDust
