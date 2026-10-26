--!strict
-- Combat health on screen, from each fighter's Names.Health (written by the server): a small bar over every other
-- fighter's head (players and sandbags) and the player's own bar at the bottom of the screen with the number in it.
-- A hit leaves a pale "just lost" stretch behind the fill that holds a moment and then shrinks to it, so a hit reads as
-- a chunk taken. A bar turns red and blinks at or under Config.Health.LowFraction, so everyone can see who is close to
-- flying far. The look is UiStyle's.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local UiStyle = require(shared:WaitForChild("UiStyle"))

local HealthBars = {}
HealthBars.__index = HealthBars

local FULL_COLOR = Color3.fromRGB(122, 214, 92)
local LOW_COLOR = Color3.fromRGB(235, 70, 60)
local TAIL_COLOR = Color3.fromRGB(255, 236, 200)
local BACK_COLOR = Color3.fromRGB(30, 22, 18)
local BLINK_SECONDS = 0.25 -- a low bar blinks this fast
local TAIL_HOLD = 0.35 -- the "just lost" stretch holds this long after a hit
local TAIL_SPEED = 0.9 -- then shrinks this much of a full bar per second

-- tailShare: where the "just lost" stretch ends; shownShare: the health last shown; droppedAt, lastAt: os.clock of the
-- last drop and the last frame.
type Bar = { root: Frame, fill: Frame, tail: Frame, tailShare: number, shownShare: number, droppedAt: number, lastAt: number }
type Overhead = { gui: BillboardGui, bar: Bar }
type Fields = {
	overhead: { [Model]: Overhead },
	own: Bar,
	ownLabel: TextLabel,
}
export type Bars = typeof(setmetatable({} :: Fields, HealthBars))

local function rounded(frame: Frame, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
end

local function makeBar(parent: Instance, size: UDim2, edge: number, radius: number): Bar
	local back = Instance.new("Frame")
	back.Name = "Health"
	back.Size = size
	back.BackgroundColor3 = BACK_COLOR
	back.BackgroundTransparency = 0.15
	back.BorderSizePixel = 0
	rounded(back, radius)
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = UiStyle.Outline
	outline.Thickness = edge
	outline.Parent = back
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.Size = UDim2.fromScale(1, 1)
	tail.BackgroundColor3 = TAIL_COLOR
	tail.BorderSizePixel = 0
	rounded(tail, radius)
	tail.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = FULL_COLOR
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	rounded(fill, radius)
	fill.Parent = back
	back.Parent = parent
	return { root = back, fill = fill, tail = tail, tailShare = 1, shownShare = 1, droppedAt = 0, lastAt = 0 }
end

-- A bar over `head`.
local function makeOverhead(head: BasePart): Overhead
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TrainBrawlHealth"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(66, 10)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.MaxDistance = 90
	billboard.Parent = head
	local bar = makeBar(billboard, UDim2.new(1, -4, 1, -4), 1.5, 4)
	bar.root.AnchorPoint = Vector2.new(0.5, 0.5) -- room for the outline on every side
	bar.root.Position = UDim2.fromScale(0.5, 0.5)
	return { gui = billboard, bar = bar }
end

local function show(bar: Bar, share: number, now: number)
	share = math.clamp(share, 0, 1)
	if bar.lastAt == 0 then
		bar.tailShare, bar.shownShare = share, share -- a new bar (someone hit before it was made): no stretch
	end
	local dt = math.min(now - bar.lastAt, 0.1)
	bar.lastAt = now
	if share < bar.shownShare - 1e-4 then
		bar.droppedAt = now -- a new hit: the stretch holds again
	end
	bar.shownShare = share
	if share >= bar.tailShare then
		bar.tailShare = share -- healed (a new round): no stretch
	elseif now - bar.droppedAt > TAIL_HOLD then
		bar.tailShare = math.max(share, bar.tailShare - TAIL_SPEED * dt)
	end
	bar.fill.Size = UDim2.fromScale(share, 1)
	-- From the fill's end only, so a blinking low fill does not show the stretch through it.
	bar.tail.Position = UDim2.fromScale(share, 0)
	bar.tail.Size = UDim2.fromScale(bar.tailShare - share, 1)
	bar.tail.Visible = bar.tailShare > share + 1e-3
	local low = share <= Config.Health.LowFraction
	bar.fill.BackgroundColor3 = if low then LOW_COLOR else FULL_COLOR
	bar.fill.BackgroundTransparency = if low and (now // BLINK_SECONDS) % 2 == 1 then 0.6 else 0
end

function HealthBars.new(playerGui: Instance): Bars
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlHealth"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local own = makeBar(gui, UDim2.fromOffset(280, 20), 2.5, 6)
	own.root.AnchorPoint = Vector2.new(0.5, 1)
	own.root.Position = UDim2.new(0.5, 0, 1, -24)
	own.root.Visible = false
	local label = UiStyle.label(own.root, "Label", UDim2.new(1, -16, 1, 2), 20)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.ZIndex = 3
	local fields: Fields = { overhead = {}, own = own, ownLabel = label }
	return setmetatable(fields, HealthBars)
end

-- Every frame. fighters: the models still in the round; own: the player's character; now: os.clock (for the
-- blinking and the "just lost" stretch).
function HealthBars.update(self: Bars, fighters: { Model }, own: Model?, now: number)
	local max = Config.Health.Max
	local seen: { [Model]: boolean } = {}
	for _, model in fighters do
		local health = PartUtil.number(model, Names.Health)
		local head = model:FindFirstChild("Head")
		if model ~= own and health and head and head:IsA("BasePart") then
			seen[model] = true
			local entry = self.overhead[model]
			local stale = entry ~= nil and entry.gui.Adornee ~= head -- the head was replaced (the avatar's body loaded)
			if entry and stale then
				entry.gui:Destroy()
			end
			local current = if entry and not stale then entry else makeOverhead(head)
			self.overhead[model] = current
			show(current.bar, health / max, now)
		end
	end
	for model, entry in self.overhead do
		if not seen[model] then
			entry.gui:Destroy()
			self.overhead[model] = nil
		end
	end
	local ownHealth = if own and own:GetAttribute(Names.Alive) == true then PartUtil.number(own, Names.Health) else nil
	self.own.root.Visible = ownHealth ~= nil
	if ownHealth then
		show(self.own, ownHealth / max, now)
		self.ownLabel.Text = tostring(math.ceil(ownHealth))
	end
end

return HealthBars
