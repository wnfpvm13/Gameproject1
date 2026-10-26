--!strict
-- The warnings drawn on the roofs on this client, over the server's invisible flat parts (Names.BlastMark from
-- Dynamite, Names.LandingMark from WeaponDrops, each with Names.MarkEndsAt and Names.MarkSeconds):
-- - where a thrown stick will burst: a red ring as wide as the blast with a red disc inside it that shrinks to nothing
--   as the fuse burns down and blinks faster near the end, so how long is left can be read at a glance;
-- - where a crate will land: its shadow, small and faint when the crate is high, growing and darkening as it comes down.
-- They replace the glowing Neon discs that read as debug markers. Drawn with a SurfaceGui on the part's top face (no
-- uploaded image); lying on the roof, they are hidden under whatever stands on them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local GroundMarks = {}

local BLAST_RED = Color3.fromRGB(235, 64, 48)
local SHADOW = Color3.fromRGB(28, 18, 12)
local PIXELS_PER_STUD = 24

-- A mark being drawn: its part, its kind ("blast" or "landing"), and the frames that change.
type Mark = { part: BasePart, kind: string, ring: Frame?, fill: Frame }
local marks: { [BasePart]: Mark } = {}

local function circle(parent: Instance, color: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = f
	f.Parent = parent
	return f
end

local function watch(part: Instance)
	if not part:IsA("BasePart") or marks[part] then
		return
	end
	local kind = if part.Name == Names.BlastMark then "blast" elseif part.Name == Names.LandingMark then "landing" else nil
	if not kind then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Mark"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = if kind == "blast" then 0 else 1
	gui.Adornee = part
	gui.Parent = part
	local mark: Mark
	if kind == "blast" then
		local ring = circle(gui, BLAST_RED, 1)
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = BLAST_RED
		edge.Thickness = 0.35 * PIXELS_PER_STUD
		edge.Parent = ring
		mark = { part = part, kind = kind, ring = ring, fill = circle(gui, BLAST_RED, 0.55) }
	else
		mark = { part = part, kind = kind, ring = nil, fill = circle(gui, SHADOW, 0.85) }
	end
	marks[part] = mark
end

-- Every frame: the discs follow the time left.
local function update()
	local now = Workspace:GetServerTimeNow()
	for part, mark in marks do
		if not part.Parent then
			marks[part] = nil
			continue
		end
		local ends = PartUtil.number(part, Names.MarkEndsAt) or now
		local seconds = math.max(PartUtil.number(part, Names.MarkSeconds) or 1, 0.1)
		local left = math.clamp((ends - now) / seconds, 0, 1) -- 1 when it starts, 0 when it happens
		if mark.kind == "blast" then
			mark.fill.Size = UDim2.fromScale(left, left)
			-- Blinks faster as the fuse runs out: about 3 a second at the start, 12 at the end.
			local rate = 3 + 9 * (1 - left)
			local on = math.floor(now * rate * 2) % 2 == 0
			mark.fill.BackgroundTransparency = if on then 0.45 else 0.7
			if mark.ring then
				local edge = mark.ring:FindFirstChildOfClass("UIStroke")
				if edge then
					edge.Transparency = if on then 0 else 0.3
				end
			end
		else
			local near = 1 - left
			local size = 0.45 + 0.55 * near
			mark.fill.Size = UDim2.fromScale(size, size)
			mark.fill.BackgroundTransparency = 0.88 - 0.5 * near
		end
	end
end

-- Watches `folders` (the arena, where sticks burn, and the crates folder) for marks.
function GroundMarks.start(folders: { Instance })
	for _, folder in folders do
		folder.ChildAdded:Connect(watch)
		for _, child in folder:GetChildren() do
			watch(child)
		end
	end
	RunService.RenderStepped:Connect(update)
end

return GroundMarks
