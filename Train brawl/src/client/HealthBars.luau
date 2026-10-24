--!strict
-- Combat health on screen, from each fighter's Names.Health (written by the server): a small bar over every other
-- fighter's head (players and sandbags) and the player's own bar at the bottom of the screen. A bar turns red and
-- blinks at or under Config.Health.LowFraction, so everyone can see who is close to flying far.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local HealthBars = {}
HealthBars.__index = HealthBars

local FULL_COLOR = Color3.fromRGB(110, 220, 120)
local LOW_COLOR = Color3.fromRGB(235, 70, 60)
local BLINK_SECONDS = 0.25 -- a low bar blinks this fast

type Bar = { root: GuiObject, fill: Frame }
type Overhead = { gui: BillboardGui, bar: Bar }
type Fields = {
	overhead: { [Model]: Overhead },
	own: Bar,
	ownLabel: TextLabel,
}
export type Bars = typeof(setmetatable({} :: Fields, HealthBars))

local function makeBar(parent: Instance, size: UDim2): Bar
	local back = Instance.new("Frame")
	back.Name = "Health"
	back.Size = size
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = FULL_COLOR
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill
	fill.Parent = back
	back.Parent = parent
	return { root = back, fill = fill }
end

-- A bar over `head`.
local function makeOverhead(head: BasePart): Overhead
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TrainBrawlHealth"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(64, 9)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.MaxDistance = 90
	billboard.Parent = head
	return { gui = billboard, bar = makeBar(billboard, UDim2.fromScale(1, 1)) }
end

local function show(bar: Bar, share: number, now: number)
	bar.fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	local low = share <= Config.Health.LowFraction
	bar.fill.BackgroundColor3 = if low then LOW_COLOR else FULL_COLOR
	bar.fill.BackgroundTransparency = if low and (now // BLINK_SECONDS) % 2 == 1 then 0.6 else 0
end

function HealthBars.new(playerGui: Instance): Bars
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlHealth"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local own = makeBar(gui, UDim2.fromOffset(260, 16))
	own.root.AnchorPoint = Vector2.new(0.5, 1)
	own.root.Position = UDim2.new(0.5, 0, 1, -24)
	own.root.Visible = false
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.ZIndex = 2
	label.Parent = own.root
	local fields: Fields = { overhead = {}, own = own, ownLabel = label }
	return setmetatable(fields, HealthBars)
end

-- Every frame. fighters: the models still in the round; own: the player's character; now: any clock (for blinking).
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
		self.ownLabel.Text = string.format("체력 %d", math.ceil(ownHealth))
	end
end

return HealthBars
