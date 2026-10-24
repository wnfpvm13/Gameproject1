--!strict
-- Draws the scenery on this client and slides it backward so the trains look like they run (they stand still): rails
-- under each train, sleepers across the rails and cacti and rocks beside the arena, on the sand the server built
-- (ArenaBuilder). The sleepers and props move backward at Config.Run.Speed and wrap around the view. Nothing here
-- collides.
-- (The wrap-around scroll follows Western train's TrackScroll.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))

local Scenery = {}
Scenery.__index = Scenery

type Fields = {
	folder: Folder,
	parts: { BasePart },
	rest: { CFrame }, -- each moving part's place at offset 0
	cframes: { CFrame },
	offset: number,
}
export type View = typeof(setmetatable({} :: Fields, Scenery))

local GAUGE = 3 -- rail distance from a train's middle line

function Scenery.new(): View
	local a, r = Config.Arena, Config.Run
	local old = Workspace:FindFirstChild(Names.SceneryFolder)
	if old then
		old:Destroy()
	end
	local folder = PartUtil.folder(Workspace, Names.SceneryFolder)
	local loop = r.ViewAhead + r.ViewBehind
	local parts, rest = {}, {}
	local function moving(part: BasePart, cframe: CFrame)
		table.insert(parts, part)
		table.insert(rest, cframe)
	end
	for i = 1, a.Trains do
		local x = ArenaLayout.trainX(i, a.Trains, a.RoofWidth, a.Gap)
		for _, side in { -1, 1 } do
			local rail = PartUtil.ghostBlock("Rail", Vector3.new(0.4, 0.4, loop), r.Colors.Rail, Enum.Material.Metal, folder)
			rail.CFrame = CFrame.new(x + side * GAUGE, -0.2, (r.ViewBehind - r.ViewAhead) / 2)
		end
		local z = -r.ViewAhead
		while z < r.ViewBehind do
			local sleeper = PartUtil.ghostBlock("Sleeper", Vector3.new(GAUGE * 2 + 2.5, 0.3, 0.9), r.Colors.Sleeper, Enum.Material.Wood, folder)
			moving(sleeper, CFrame.new(x, -0.55, z))
			z += r.SleeperSpacing
		end
	end
	for k = 1, r.RoadsideProps do
		local side = if k % 2 == 0 then 1 else -1
		local x = side * (r.RoadsideNear + ((k * 7) % 9) / 8 * (r.RoadsideFar - r.RoadsideNear))
		local z = -r.ViewAhead + (k - 0.5) * loop / r.RoadsideProps
		if k % 3 == 0 then
			local size = 2 + (k % 4)
			local rock = PartUtil.ghostBlock("Rock", Vector3.new(size * 1.4, size, size), r.Colors.Rock, Enum.Material.Slate, folder)
			moving(rock, CFrame.new(x, a.GroundY + size / 2 - 0.4, z) * CFrame.Angles(0, k, 0.2))
		else
			local height = 5 + (k % 4) * 1.5
			local cactus = PartUtil.ghostBlock("Cactus", Vector3.new(1.4, height, 1.4), r.Colors.Cactus, Enum.Material.Grass, folder)
			moving(cactus, CFrame.new(x, a.GroundY + height / 2, z))
		end
	end
	local fields: Fields = { folder = folder, parts = parts, rest = rest, cframes = table.clone(rest), offset = 0 }
	local self = setmetatable(fields, Scenery)
	self:update(0)
	return self
end

-- Slides the scenery backward by this frame's run (dt seconds).
function Scenery.update(self: View, dt: number)
	local r = Config.Run
	local loop = r.ViewAhead + r.ViewBehind
	self.offset = (self.offset + r.Speed * dt) % loop
	for i, cframe in self.rest do
		local z = cframe.Position.Z + self.offset
		if z > r.ViewBehind then
			z -= loop
		end
		self.cframes[i] = cframe + Vector3.new(0, 0, z - cframe.Position.Z)
	end
	Workspace:BulkMoveTo(self.parts, self.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function Scenery.destroy(self: View)
	self.folder:Destroy()
end

return Scenery
