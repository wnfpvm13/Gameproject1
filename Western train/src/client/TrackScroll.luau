--!strict
-- Makes one locomotive's track look like it runs, on this client: sleepers under it slide back with the run distance
-- (by less than one sleeper gap, so the row looks endless) and cacti and rocks pass by on both sides. These are
-- local parts (the server's stage has only the ground and the smooth rails), so nothing moves over the network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local TrackScroll = {}
TrackScroll.__index = TrackScroll

type Piece = { part: BasePart, offset: CFrame }

type Fields = {
	base: BasePart,
	parts: { BasePart },
	rest: { CFrame }, -- each part at run distance 0, relative to the base
	wraps: { boolean }, -- true for roadside parts (they wrap round the view), false for sleepers (they slide)
	cframes: { CFrame }, -- reused every frame for BulkMoveTo
	folder: Folder,
	drawn: number?, -- the distance last drawn (nothing moves while it stays the same)
}
export type Scroll = typeof(setmetatable({} :: Fields, TrackScroll))

-- A cactus: a trunk with one raised arm. Part cylinders lie along their own X, so they are stood up.
local function cactus(parent: Instance, height: number): { Piece }
	local color = Config.Stage.Colors.Cactus
	local up = CFrame.Angles(0, 0, math.pi / 2)
	local trunk = PartUtil.ghostBlock("Cactus", Vector3.new(height, 1, 1), color, Enum.Material.Grass, parent)
	trunk.Shape = Enum.PartType.Cylinder
	local arm = PartUtil.ghostBlock("Cactus", Vector3.new(height * 0.35, 0.7, 0.7), color, Enum.Material.Grass, parent)
	arm.Shape = Enum.PartType.Cylinder
	local elbow = PartUtil.ghostBlock("Cactus", Vector3.new(0.9, 0.7, 0.7), color, Enum.Material.Grass, parent)
	elbow.Shape = Enum.PartType.Cylinder
	return {
		{ part = trunk, offset = CFrame.new(0, height / 2, 0) * up },
		{ part = arm, offset = CFrame.new(0.9, height * 0.55, 0) * up },
		{ part = elbow, offset = CFrame.new(0.55, height * 0.38, 0) },
	}
end

local function rock(parent: Instance, size: number): { Piece }
	local part = PartUtil.ghostBlock("Rock", Vector3.new(size * 1.4, size * 0.7, size), Config.Stage.Colors.Rock, Enum.Material.Slate, parent)
	return { { part = part, offset = CFrame.new(0, size * 0.25, 0) * CFrame.Angles(0, 0.6, 0.1) } }
end

function TrackScroll.new(locomotive: Model, base: BasePart): Scroll
	local stage = Config.Stage
	local run = Config.Run
	local track = Config.Locomotive.WheelTrack
	local own = Instance.new("Folder")
	own.Name = locomotive.Name
	own.Parent = PartUtil.folder(Workspace, Names.SceneryFolder)
	local parts, rest, wraps = {}, {}, {}
	local function add(part: BasePart, cframe: CFrame, wrap: boolean)
		table.insert(parts, part)
		table.insert(rest, cframe)
		table.insert(wraps, wrap)
	end
	-- Sleepers over the whole view plus one gap, just under the rail tops (the base is on the rail tops).
	local z = -run.ViewAhead
	while z <= run.ViewBehind + stage.SleeperSpacing do
		local sleeper = PartUtil.ghostBlock("Sleeper", Vector3.new(track * 2 + 2, 0.25, 0.8), stage.Colors.Sleeper, Enum.Material.Wood, own)
		add(sleeper, CFrame.new(0, 0.125 - stage.RailHeight, z), false)
		z += stage.SleeperSpacing
	end
	-- Roadside props spread over the view, alternating sides, at uneven distances from the track.
	local loop = run.ViewAhead + run.ViewBehind
	for i = 1, stage.RoadsideProps do
		local side = if i % 2 == 0 then 1 else -1
		local x = side * (stage.RoadsideNear + ((i * 7) % 5) / 4 * (stage.RoadsideFar - stage.RoadsideNear))
		local at = -run.ViewAhead + (i - 0.5) * loop / stage.RoadsideProps
		local pieces: { Piece } = if i % 3 == 0 then rock(own, 1.2 + (i % 4) * 0.3) else cactus(own, 3.5 + (i % 4) * 0.8)
		for _, piece in pieces do
			add(piece.part, CFrame.new(x, -stage.RailHeight, at) * piece.offset, true)
		end
	end
	local fields: Fields = { base = base, parts = parts, rest = rest, wraps = wraps, cframes = table.clone(rest), folder = own, drawn = nil }
	local self = setmetatable(fields, TrackScroll)
	self:update(nil)
	return self
end

-- The scenery for this run distance (nil = no run yet: everything at its start place).
function TrackScroll.update(self: Scroll, distance: number?)
	local d = distance or 0
	if d == self.drawn then
		return -- held, crashed or waiting to start: everything is already in place
	end
	self.drawn = d
	local run = Config.Run
	local loop = run.ViewAhead + run.ViewBehind
	local slide = d % Config.Stage.SleeperSpacing
	local baseCFrame = self.base.CFrame
	local cframes = self.cframes
	for i, rest in self.rest do
		local shift = slide
		if self.wraps[i] then
			-- Moves back with the run and wraps round to the far end once behind the view.
			shift = (rest.Z + d + run.ViewAhead) % loop - run.ViewAhead - rest.Z
		end
		cframes[i] = baseCFrame * CFrame.new(0, 0, shift) * rest
	end
	Workspace:BulkMoveTo(self.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function TrackScroll.destroy(self: Scroll)
	self.folder:Destroy()
end

return TrackScroll
