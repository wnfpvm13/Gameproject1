--!strict
-- The roof edge the player is close to, painted with a warning band (persona fix 5, 2026-10-29: the testers fell off
-- without knowing they were at an edge). While the player fights on the trains and stands within Config.Edge.Within of
-- an edge of the top under it that drops into nothing (just past it there is no lower top: ArenaLayout.topUnder, and
-- no plank), a red-and-cream striped band lies along that edge where the player is, stronger the closer it gets. Edges
-- that only step down onto another car (the next car of the train, a lookout's roof below) get none; a car coming off
-- counts as not there (its edges, and the edge it leaves behind, are judged without it). Drawn on this
-- client only, with a SurfaceGui (no uploaded image, not the glowing Neon that read as a debug marker); no collisions
-- or raycasts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))

local EdgeWarning = {}
EdgeWarning.__index = EdgeWarning

local RED = Color3.fromRGB(214, 52, 38)
local CREAM = Color3.fromRGB(255, 238, 205)
local STRIPES = 9 -- red and cream bands along it (a UIGradient holds up to 20 keys)
local PIXELS_PER_STUD = 20
local PLANK_HALF = 2 -- a plank is 4 wide (Config.Arena.PlankWidth)

-- One band per side of a top: -x, +x, -z, +z.
type Band = { part: Part, fill: Frame }
type Fields = { all: { ArenaLayout.Surface }, surfaces: { ArenaLayout.Surface }, planks: { ArenaLayout.Plank }, bands: { Band }, folder: Folder }
export type Warning = typeof(setmetatable({} :: Fields, EdgeWarning))

local function makeBand(folder: Folder): Band
	local part = PartUtil.decor("EdgeWarning", Vector3.new(1, 0.05, 1), CFrame.identity, RED, Enum.Material.SmoothPlastic)
	part.Transparency = 1
	part.Parent = folder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 1
	gui.Adornee = part
	gui.Parent = part
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundTransparency = 1
	fill.Parent = gui
	-- Hard-edged stripes across the band: each stripe a flat run of one colour between two keys.
	local keys = {}
	for i = 0, STRIPES - 1 do
		local color = if i % 2 == 0 then RED else CREAM
		local a, b = i / STRIPES, (i + 1) / STRIPES
		table.insert(keys, ColorSequenceKeypoint.new(if i == 0 then 0 else a + 1e-3, color))
		table.insert(keys, ColorSequenceKeypoint.new(if i == STRIPES - 1 then 1 else b, color))
	end
	local stripes = Instance.new("UIGradient")
	stripes.Color = ColorSequence.new(keys)
	stripes.Parent = fill
	return { part = part, fill = fill }
end

function EdgeWarning.new(layout: ArenaLayout.Layout): Warning
	local folder = PartUtil.folder(Workspace, "TrainBrawlEdgeWarning")
	local bands = {}
	for _ = 1, 4 do
		table.insert(bands, makeBand(folder))
	end
	local fields: Fields = { all = layout.surfaces, surfaces = layout.surfaces, planks = layout.planks, bands = bands, folder = folder }
	return setmetatable(fields, EdgeWarning)
end

-- Whether a fighter with feet at `feet` stepping past an edge to (x, z) drops into nothing: no lower top there and no
-- plank.
local function dropsOff(self: Warning, x: number, z: number, feet: number): boolean
	if ArenaLayout.topUnder(self.surfaces, x, z, feet) then
		return false
	end
	for _, plank in self.planks do
		if math.abs(x - plank.x) <= plank.length / 2 and math.abs(z - plank.z) <= PLANK_HALF then
			return false
		end
	end
	return true
end

-- Every frame. own: the player's character; fighting: it fights on the trains now; away: whether a car is coming off
-- or gone (UncoupleShow).
function EdgeWarning.update(self: Warning, own: Model?, fighting: boolean, away: (train: number, car: number) -> boolean)
	local e = Config.Edge
	local here = {}
	for _, surface in self.all do
		if not away(surface.train, surface.car) then
			table.insert(here, surface)
		end
	end
	self.surfaces = here
	local body = if fighting then CharacterParts.body(own) else nil
	local top: ArenaLayout.Surface? = nil
	local feet = 0
	if body then
		feet = CharacterParts.feetY(body)
		local at = body.root.Position
		top = ArenaLayout.topUnder(self.surfaces, at.X, at.Z, feet)
	end
	for i, band in self.bands do
		local shown = 0
		if body and top then
			local at = body.root.Position
			local halfWidth, halfLength = top.width / 2, top.length / 2
			-- This side: how far the player is from it, which way is out, and the run along it.
			local across = i <= 2
			local sign = if i % 2 == 1 then -1 else 1
			local gap = if across then halfWidth - sign * (at.X - top.x) else halfLength - sign * (at.Z - top.z)
			if gap < e.Within then
				local edgeX = if across then top.x + sign * halfWidth else at.X
				local edgeZ = if across then at.Z else top.z + sign * halfLength
				local probeX = if across then edgeX + sign * e.Probe else edgeX
				local probeZ = if across then edgeZ else edgeZ + sign * e.Probe
				if dropsOff(self, probeX, probeZ, feet) then
					shown = math.clamp(1 - math.max(gap, 0) / e.Within, 0, 1)
					-- Along the edge where the player is, kept on the top's side and within its length.
					local run = math.min(e.Length, if across then top.length else top.width)
					local along = if across then at.Z else at.X
					local lo, hi = if across then top.z - halfLength + run / 2 else top.x - halfWidth + run / 2, if across then top.z + halfLength - run / 2 else top.x + halfWidth - run / 2
					along = math.clamp(along, math.min(lo, hi), math.max(lo, hi))
					local inset = e.Width / 2 + 0.1
					local centre = if across then Vector3.new(edgeX - sign * inset, top.top + 0.04, along) else Vector3.new(along, top.top + 0.04, edgeZ - sign * inset)
					band.part.Size = if across then Vector3.new(e.Width, 0.05, run) else Vector3.new(run, 0.05, e.Width)
					band.part.CFrame = CFrame.new(centre)
					-- The stripes run across the band: along its length, which is the part's Z (or X for a front edge).
					local gradient = band.fill:FindFirstChildOfClass("UIGradient")
					if gradient then
						gradient.Rotation = if across then 90 else 0
					end
				end
			end
		end
		local pulse = 0.85 + 0.15 * math.sin(os.clock() * 8)
		band.fill.BackgroundTransparency = if shown > 0 then 1 - (0.25 + 0.6 * shown) * pulse else 1
	end
end

return EdgeWarning
