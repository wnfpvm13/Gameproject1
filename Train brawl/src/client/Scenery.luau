--!strict
-- Draws the trackside on this client and slides it backward so the trains look like they run (they stand still): the
-- ground itself (sand between the canyon walls and a gravel bed under each train, in long tiles just over the
-- server's sand, ArenaBuilder: a material's pattern moves with its part, so the ground is seen to run), rails under
-- each train as far as the canyon (one long piece each: they look the same wherever they are), sleepers across the
-- rails, cacti and rocks beside the arena, and a line of telegraph poles with their wires along one side. Everything
-- moves backward at Config.Run.Speed and wraps around (ScrollLoop): the ground in the canyon's long loop, so its
-- wrap is lost in the haze, the rest in the view's. Nothing here collides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local ScrollLoop = require(shared:WaitForChild("ScrollLoop"))

local Scenery = {}
Scenery.__index = Scenery

type Fields = {
	folder: Folder,
	loop: ScrollLoop.Loop,
	ground: ScrollLoop.Loop,
}
export type View = typeof(setmetatable({} :: Fields, Scenery))

-- layout: the arena (ArenaLayout.layout), for where the trains and their outer edge are.
function Scenery.new(layout: ArenaLayout.Layout): View
	local a, r, c = Config.Arena, Config.Run, Config.Canyon
	local old = Workspace:FindFirstChild(Names.SceneryFolder)
	if old then
		old:Destroy()
	end
	local folder = PartUtil.folder(Workspace, Names.SceneryFolder)
	local loop = ScrollLoop.new(r.ViewAhead, r.ViewBehind)
	local ground = ScrollLoop.new(c.Ahead, c.Behind)
	local span = r.ViewAhead + r.ViewBehind
	-- The running ground: tiles end to end along the canyon's whole loop, sand as wide as the canyon floor and a gravel
	-- bed under each train, each tile wrapping on its own (deep in the haze).
	local tileCount = math.ceil((c.Ahead + c.Behind) / r.GroundTile)
	local tileLength = (c.Ahead + c.Behind) / tileCount
	local floorWidth = (c.Inner + c.InnerVary) * 2
	for n = 1, tileCount do
		local z = -c.Ahead + (n - 0.5) * tileLength
		local sand = PartUtil.decor("Sand", Vector3.new(floorWidth, 0.2, tileLength), CFrame.identity, r.Colors.Sand, Enum.Material.Sand, folder)
		ground:add(sand, CFrame.new(0, a.GroundY - 0.05, z))
		for _, train in layout.trains do
			local bed = PartUtil.decor("Ballast", Vector3.new(a.Gauge * 2 + 3, 0.3, tileLength), CFrame.identity, r.Colors.Ballast, Enum.Material.Pebble, folder)
			ground:add(bed, CFrame.new(train.x, a.GroundY + 0.15, z))
		end
	end
	-- The rails run as far as the canyon, so they do not end in sight down the track.
	local farLength, farMiddle = c.Ahead + c.Behind, (c.Behind - c.Ahead) / 2
	for _, train in layout.trains do
		local x = train.x
		for _, side in { -1, 1 } do
			local rail = PartUtil.ghostBlock("Rail", Vector3.new(0.4, 0.4, farLength), r.Colors.Rail, Enum.Material.Metal, folder)
			rail.CFrame = CFrame.new(x + side * a.Gauge, -0.2, farMiddle)
		end
		local z = -r.ViewAhead
		while z < r.ViewBehind do
			local sleeper = PartUtil.ghostBlock("Sleeper", Vector3.new(a.Gauge * 2 + 2.5, 0.3, 0.9), r.Colors.Sleeper, Enum.Material.Wood, folder)
			sleeper.CastShadow = false
			loop:add(sleeper, CFrame.new(x, -0.55, z))
			z += r.SleeperSpacing
		end
	end
	for k = 1, r.RoadsideProps do
		local side = if k % 2 == 0 then 1 else -1
		local near = layout.outerEdge + r.RoadsideClearance
		local x = side * (near + ((k * 7) % 9) / 8 * math.max(r.RoadsideFar - near, 0))
		local z = -r.ViewAhead + (k - 0.5) * span / r.RoadsideProps
		if k % 3 == 0 then
			local size = 2 + (k % 4)
			local rock = PartUtil.ghostBlock("Rock", Vector3.new(size * 1.4, size, size), r.Colors.Rock, Enum.Material.Slate, folder)
			loop:add(rock, CFrame.new(x, a.GroundY + size / 2 - 0.4, z) * CFrame.Angles(0, k, 0.2))
		else
			local height = 5 + (k % 4) * 1.5
			local cactus = PartUtil.ghostBlock("Cactus", Vector3.new(1.4, height, 1.4), r.Colors.Cactus, Enum.Material.Grass, folder)
			loop:add(cactus, CFrame.new(x, a.GroundY + height / 2, z))
			-- An arm on most cacti, up from a short elbow.
			if k % 4 ~= 1 then
				local arm = if k % 2 == 0 then 1 else -1
				local elbow = PartUtil.ghostBlock("CactusArm", Vector3.new(1.6, 0.9, 0.9), r.Colors.Cactus, Enum.Material.Grass, folder)
				loop:add(elbow, CFrame.new(x + arm * 1.1, a.GroundY + height * 0.45, z))
				local up = PartUtil.ghostBlock("CactusArm", Vector3.new(0.9, height * 0.35, 0.9), r.Colors.Cactus, Enum.Material.Grass, folder)
				loop:add(up, CFrame.new(x + arm * 1.45, a.GroundY + height * (0.45 + 0.175) - 0.45, z))
			end
		end
	end
	-- Telegraph poles: a pole and a cross arm each, moving; two wires along the line, standing still (they look the
	-- same wherever they are).
	local poleX = r.PoleSide * (layout.outerEdge + r.PoleDistance)
	local armY = a.GroundY + r.PoleHeight - 0.6
	local z = -r.ViewAhead
	while z < r.ViewBehind do
		local pole = PartUtil.ghostBlock("Pole", Vector3.new(0.6, r.PoleHeight, 0.6), r.Colors.Pole, Enum.Material.Wood, folder)
		loop:add(pole, CFrame.new(poleX, a.GroundY + r.PoleHeight / 2, z))
		local arm = PartUtil.ghostBlock("PoleArm", Vector3.new(3.4, 0.35, 0.35), r.Colors.Pole, Enum.Material.Wood, folder)
		arm.CastShadow = false
		loop:add(arm, CFrame.new(poleX, armY, z))
		z += r.PoleSpacing
	end
	for _, side in { -1, 1 } do
		local wire = PartUtil.ghostBlock("Wire", Vector3.new(0.08, 0.08, span), r.Colors.Wire, Enum.Material.Metal, folder)
		wire.CFrame = CFrame.new(poleX + side * 1.4, armY + 0.25, (r.ViewBehind - r.ViewAhead) / 2)
		wire.CastShadow = false
	end
	local fields: Fields = { folder = folder, loop = loop, ground = ground }
	local self = setmetatable(fields, Scenery)
	self:update(0)
	return self
end

-- Slides the scenery backward by this frame's run (dt seconds).
function Scenery.update(self: View, dt: number)
	self.loop:update(dt, Config.Run.Speed)
	self.ground:update(dt, Config.Run.Speed)
end

function Scenery.destroy(self: View)
	self.folder:Destroy()
end

return Scenery
