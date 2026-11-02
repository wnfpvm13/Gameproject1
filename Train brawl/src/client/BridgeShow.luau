--!strict
-- A low bridge on this client (decision 24; the server's Bridges sweeps for real). While Workspace has Names.BridgeAt
-- (the server time the beam reaches the front of the trains), an iron truss bridge on stone piers runs in from far ahead
-- with the scenery (BridgeRules.beamZ) and on past the back of the trains, its underside striped yellow and black
-- toward the trains; a banner counts down to it ("낮은 다리! 낮은 칸으로 가거나 막기로 숙여!"), the low tops every train
-- has (BridgeRules.safeTops; not a car coming off: `away`) get a pulsing green border with "여기는 안전" over them, and
-- the whistle blows as it comes in sight. swept() rings the clang of a body on the beam. Nothing here collides or is
-- seen by raycasts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local BridgeRules = require(shared:WaitForChild("BridgeRules"))
local SoundBank = require(shared:WaitForChild("SoundBank"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local BridgeShow = {}
BridgeShow.__index = BridgeShow

local CHORD = 0.9 -- the truss's top and bottom beams, how deep
local MEMBER = 0.45 -- its posts and braces, how thick
local BAY = 6 -- posts this far apart along the span
local STONE = Color3.fromRGB(176, 132, 92)
local YELLOW = Color3.fromRGB(255, 198, 24)
local BLACK = Color3.fromRGB(34, 28, 24)
local STRIPES = 9
local BORDER = 0.4 -- a low top's green border strips, how wide

-- A low top marked while a bridge comes: its green border's strips, the label over it, where it is along the track.
type Mark = { train: number, car: number, strips: { BasePart }, label: BillboardGui, z: number }
type Fields = {
	layout: ArenaLayout.Layout,
	away: (train: number, car: number) -> boolean,
	model: Model,
	marks: { Mark },
	banner: TextLabel,
	frontZ: number,
	backZ: number,
	heard: number?, -- the pass whose whistle has blown (its BridgeAt)
}
export type Show = typeof(setmetatable({} :: Fields, BridgeShow))

-- Yellow and black stripes painted on `part`'s `face`.
local function hazard(part: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 1
	gui.Parent = part
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = gui
	local keys = {}
	for i = 0, STRIPES - 1 do
		local color = if i % 2 == 0 then YELLOW else BLACK
		table.insert(keys, ColorSequenceKeypoint.new(if i == 0 then 0 else i / STRIPES + 1e-3, color))
		table.insert(keys, ColorSequenceKeypoint.new(if i == STRIPES - 1 then 1 else (i + 1) / STRIPES, color))
	end
	local stripes = Instance.new("UIGradient")
	stripes.Color = ColorSequence.new(keys)
	stripes.Rotation = 20
	stripes.Parent = fill
end

-- The bridge, its underside's middle at the origin (moved into place by its pivot): a truss `half` x 2 wide.
local function build(half: number): Model
	local b = Config.Bridge
	local model = Instance.new("Model")
	model.Name = "LowBridge"
	local color, metal = b.Color, Enum.Material.Metal
	local d = b.Depth
	local bottom = PartUtil.decor("Underside", Vector3.new(half * 2, CHORD, d), CFrame.new(0, CHORD / 2, 0), color, metal, model)
	bottom.CastShadow = true
	hazard(bottom, Enum.NormalId.Back) -- (+Z: toward the trains it comes at)
	local top = PartUtil.decor("TopChord", Vector3.new(half * 2, CHORD, d), CFrame.new(0, b.Height - CHORD / 2, 0), color, metal, model)
	top.CastShadow = true
	-- Posts and alternating braces on both faces, cross ties on top.
	local bays = math.floor(half * 2 / BAY)
	local step = half * 2 / bays
	for _, side in { -1, 1 } do
		local z = side * (d / 2 - MEMBER / 2)
		for i = 0, bays do
			local x = -half + i * step
			PartUtil.decor("Post", Vector3.new(MEMBER, b.Height - CHORD * 2, MEMBER), CFrame.new(x, b.Height / 2, z), color, metal, model)
			if i < bays then
				local low, high = CHORD, b.Height - CHORD
				local a = Vector3.new(x, if i % 2 == 0 then low else high, z)
				local c = Vector3.new(x + step, if i % 2 == 0 then high else low, z)
				PartUtil.decorBar("Brace", a, c, MEMBER, color, metal, model)
			end
		end
	end
	for i = 0, bays, 2 do
		local x = -half + i * step
		PartUtil.decor("Tie", Vector3.new(MEMBER, MEMBER, d), CFrame.new(x, b.Height - MEMBER / 2, 0), color, metal, model)
	end
	-- Stone piers out in the sand at both ends.
	local drop = b.Clearance - Config.Arena.GroundY
	for _, side in { -1, 1 } do
		local pier = PartUtil.decor("Pier", Vector3.new(4, drop + b.Height, d + 2), CFrame.new(side * (half + 2), (b.Height - drop) / 2, 0), STONE, Enum.Material.Sandstone, model)
		pier.CastShadow = true
	end
	model.PrimaryPart = bottom
	model.WorldPivot = CFrame.new()
	return model
end

-- A green border round low top `top` (thin strips just inside its edges, just over it) and its label over the middle.
local function mark(top: BridgeRules.Top, parent: Instance): Mark
	local b = Config.Bridge
	local y = top.top + 0.1
	local w, l, inset = top.width, top.length, 0.6
	local strips: { BasePart } = {}
	for _, piece in {
		{ Vector3.new(w - inset * 2, 0.12, BORDER), Vector3.new(top.x, y, top.z - l / 2 + inset) },
		{ Vector3.new(w - inset * 2, 0.12, BORDER), Vector3.new(top.x, y, top.z + l / 2 - inset) },
		{ Vector3.new(BORDER, 0.12, l - inset * 2), Vector3.new(top.x - w / 2 + inset, y, top.z) },
		{ Vector3.new(BORDER, 0.12, l - inset * 2), Vector3.new(top.x + w / 2 - inset, y, top.z) },
	} do
		local strip = PartUtil.decor("SafeEdge", piece[1], CFrame.new(piece[2]), b.SafeColor, Enum.Material.Neon, parent)
		strip.Transparency = 1
		table.insert(strips, strip)
	end
	local anchor = PartUtil.decor("SafeMiddle", Vector3.new(0.2, 0.2, 0.2), CFrame.new(top.x, y, top.z), b.SafeColor, Enum.Material.SmoothPlastic, parent)
	anchor.Transparency = 1
	local label = Instance.new("BillboardGui")
	label.Name = "SafeLabel"
	label.Size = UDim2.fromOffset(160, 34)
	label.StudsOffset = Vector3.new(0, 4.5, 0)
	label.MaxDistance = 160 -- (not drawn on top of everything: it floats clear over its top anyway)
	label.Enabled = false
	label.Parent = anchor
	local text = UiStyle.label(label, "Text", UDim2.fromScale(1, 1), 22, b.SafeColor)
	text.Text = Words.BridgeSafe
	return { train = top.train, car = top.car, strips = strips, label = label, z = top.z }
end

-- layout: where everything is; away(train, car): that car is coming off or gone (UncoupleShow).
function BridgeShow.new(playerGui: Instance, layout: ArenaLayout.Layout, away: (number, number) -> boolean): Show
	local b = Config.Bridge
	local folder = PartUtil.folder(Workspace, "TrainBrawlBridge")
	folder:ClearAllChildren()
	local model = build(layout.outerEdge + b.Overhang)
	local marks = {}
	for t in layout.trains do
		for _, top in BridgeRules.safeTops(layout.surfaces, t, b.Stature, b.Clearance) do
			table.insert(marks, mark(top, folder))
		end
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlBridge"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local banner = UiStyle.label(gui, "Banner", UDim2.fromOffset(620, 34), 28, YELLOW)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 136) -- (under a car's warning, which sits at 96)
	banner.Visible = false
	local front, back = math.huge, -math.huge
	for _, train in layout.trains do
		front = math.min(front, train.cars[1].front)
		back = math.max(back, train.cars[#train.cars].back)
	end
	local fields: Fields = { layout = layout, away = away, model = model, marks = marks, banner = banner, frontZ = front, backZ = back, heard = nil }
	return setmetatable(fields, BridgeShow)
end

-- Every frame: the bridge where the server's pass has it, the warning and the low tops while it comes.
function BridgeShow.update(self: Show)
	local b = Config.Bridge
	local at = PartUtil.number(Workspace, Names.BridgeAt)
	local now = Workspace:GetServerTimeNow()
	local pass: BridgeRules.Pass? = if at then { arriveAt = at, frontZ = self.frontZ, speed = Config.Run.Speed } else nil
	if not pass or BridgeRules.over(pass, now, self.backZ, b.Depth) then
		if self.model.Parent then
			self.model.Parent = nil
		end
		self.banner.Visible = false
		for _, m in self.marks do
			for _, strip in m.strips do
				strip.Transparency = 1
			end
			m.label.Enabled = false
		end
		return
	end
	local beamZ = BridgeRules.beamZ(pass, now)
	self.model:PivotTo(CFrame.new(0, b.Clearance, beamZ))
	if not self.model.Parent then
		self.model.Parent = Workspace:FindFirstChild("TrainBrawlBridge") or Workspace
	end
	if self.heard ~= pass.arriveAt then
		self.heard = pass.arriveAt
		SoundBank.play("Whistle")
	end
	local left = pass.arriveAt - now
	self.banner.Visible = true
	self.banner.Text = Words.bridgeComing(math.max(0, math.ceil(left)))
	-- The low tops' borders pulse until the beam has gone over them.
	local pulse = 0.25 + 0.25 * math.sin(now * 8)
	for _, m in self.marks do
		local showing = beamZ < m.z + 20 and not self.away(m.train, m.car)
		for _, strip in m.strips do
			strip.Transparency = if showing then pulse else 1
		end
		m.label.Enabled = showing
	end
end

-- A low bridge swept `victim` off: the clang of it hitting the beam.
function BridgeShow.swept(_self: Show, victim: Model)
	local root = victim:FindFirstChild("HumanoidRootPart")
	SoundBank.play("BridgeHit", if root and root:IsA("BasePart") then root else nil)
end

return BridgeShow
