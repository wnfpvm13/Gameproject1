--!strict
-- Rays that see only the arena (the solid trains, planks and sand), flying through every fighter: what a thrown stick,
-- a coal lump or a rolling wheel meets, and the floor under a spot (Dynamite, Missiles, Wheels, Slicks on the server).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))

local ArenaRay = {}

-- Ray settings that leave out the characters (players' and sandbags').
function ArenaRay.params(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = CollectionService:GetTagged(Names.SandbagTag)
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

-- The first thing of `arena` between `a` and `b`, flying through everything else (up to a few things in the way, each
-- added to `params`' filter).
function ArenaRay.hit(a: Vector3, b: Vector3, arena: Instance, params: RaycastParams): RaycastResult?
	for _ = 1, 4 do
		local hit = Workspace:Raycast(a, b - a, params)
		if not hit or hit.Instance:IsDescendantOf(arena) then
			return hit
		end
		params:AddToFilter(hit.Instance) -- not the arena's: fly through it and look again
	end
	return nil
end

-- The arena's floor straight under `at` within `depth` (from `rise` above it, so a step a little higher counts), and
-- its height; nil when there is none.
function ArenaRay.floor(at: Vector3, rise: number, depth: number, arena: Instance, params: RaycastParams): RaycastResult?
	local from = at + Vector3.new(0, rise, 0)
	return ArenaRay.hit(from, from - Vector3.new(0, rise + depth, 0), arena, params)
end

return ArenaRay
