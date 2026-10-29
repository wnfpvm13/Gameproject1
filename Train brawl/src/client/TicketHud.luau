--!strict
-- Tickets on screen, from each fighter's Names.Tickets (written by the server's RoundService): the player's own as
-- small gold tickets left of its health bar at the bottom, named over them as the weapon is over the bar (a spent one
-- goes grey with a bounce), and a row of tiny
-- ticket marks over every other fighter's health bar, so everyone sees who is on their last ticket. The look is
-- UiStyle's colours; drawn with frames only (no uploaded image).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local TicketHud = {}
TicketHud.__index = TicketHud

local SPENT = Color3.fromRGB(96, 84, 74)
local OWN_SIZE = Vector2.new(30, 22)
local OWN_GAP = 6
local OWN_RIGHT = 152 -- the row ends this far left of the screen's middle (the health bar is 280 wide)
local OWN_BOTTOM = 22
local PIP_SIZE = Vector2.new(10, 7)
local PIP_GAP = 3

type Overhead = { gui: BillboardGui, pips: { Frame } }
type Fields = { gui: ScreenGui, row: Frame, name: TextLabel, own: { Frame }, shownOwn: number?, overhead: { [Model]: Overhead } }
export type Hud = typeof(setmetatable({} :: Fields, TicketHud))

-- A ticket: a gold card with a dark outline and a perforation a third of the way along.
local function ticket(parent: Instance, size: Vector2, edge: number, radius: number, perforation: boolean): Frame
	local card = Instance.new("Frame")
	card.Name = "Ticket"
	card.Size = UDim2.fromOffset(size.X, size.Y)
	card.BackgroundColor3 = UiStyle.Gold
	card.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = card
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = UiStyle.Outline
	outline.Thickness = edge
	outline.Parent = card
	if perforation then
		local line = Instance.new("Frame")
		line.Name = "Perforation"
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.33, 0.5)
		line.Size = UDim2.new(0, 2, 1, -6)
		line.BackgroundColor3 = UiStyle.Outline
		line.BackgroundTransparency = 0.45
		line.BorderSizePixel = 0
		line.Parent = card
	end
	card.Parent = parent
	return card
end

local function row(parent: Instance, gap: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Tickets"
	frame.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	frame.Parent = parent
	return frame
end

local function paint(card: Frame, spent: boolean)
	card.BackgroundColor3 = if spent then SPENT else UiStyle.Gold
	card.BackgroundTransparency = if spent then 0.35 else 0
end

function TicketHud.new(playerGui: Instance): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlTickets"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local count = Config.Round.Tickets
	local own = row(gui, OWN_GAP)
	own.AnchorPoint = Vector2.new(1, 1)
	own.Position = UDim2.new(0.5, -OWN_RIGHT, 1, -OWN_BOTTOM)
	own.Size = UDim2.fromOffset(count * (OWN_SIZE.X + OWN_GAP), OWN_SIZE.Y + 8)
	own.Visible = false
	-- Its name over it, level with the weapon's name over the health bar (WeaponHud).
	local name = UiStyle.label(gui, "TicketsName", UDim2.fromOffset(own.Size.X.Offset + 20, 22), 18, UiStyle.Gold)
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, -OWN_RIGHT - own.Size.X.Offset / 2, 1, -50)
	name.Text = Words.Tickets
	name.Visible = false
	local cards = {}
	for i = 1, count do
		local card = ticket(own, OWN_SIZE, 2, 4, true)
		card.LayoutOrder = i
		table.insert(cards, card)
	end
	local fields: Fields = { gui = gui, row = own, name = name, own = cards, shownOwn = nil, overhead = {} }
	return setmetatable(fields, TicketHud)
end

local function makeOverhead(head: BasePart): Overhead
	local count = Config.Round.Tickets
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TrainBrawlTickets"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(count * (PIP_SIZE.X + PIP_GAP) + 4, PIP_SIZE.Y + 4)
	billboard.StudsOffset = Vector3.new(0, 2.8, 0) -- just over the health bar (HealthBars: 2.4)
	billboard.MaxDistance = 90
	billboard.Parent = head
	local line = row(billboard, PIP_GAP)
	line.Size = UDim2.fromScale(1, 1)
	local pips = {}
	for i = 1, count do
		local pip = ticket(line, PIP_SIZE, 1, 2, false)
		pip.LayoutOrder = i
		table.insert(pips, pip)
	end
	return { gui = billboard, pips = pips }
end

-- Every frame. fighters: the models on the trains; own: the player's character (its tickets show while it is in the
-- round, on its way back too).
function TicketHud.update(self: Hud, fighters: { Model }, own: Model?)
	local seen: { [Model]: boolean } = {}
	for _, model in fighters do
		local tickets = PartUtil.number(model, Names.Tickets)
		local head = model:FindFirstChild("Head")
		if model ~= own and tickets and head and head:IsA("BasePart") then
			seen[model] = true
			local entry = self.overhead[model]
			local stale = entry ~= nil and entry.gui.Adornee ~= head -- the head was replaced (the avatar's body loaded)
			if entry and stale then
				entry.gui:Destroy()
			end
			local current = if entry and not stale then entry else makeOverhead(head)
			self.overhead[model] = current
			for i, pip in current.pips do
				paint(pip, i > tickets)
			end
		end
	end
	for model, entry in self.overhead do
		if not seen[model] then
			entry.gui:Destroy()
			self.overhead[model] = nil
		end
	end
	local tickets = if own and own:GetAttribute(Names.Alive) == true then PartUtil.number(own, Names.Tickets) else nil
	self.row.Visible = tickets ~= nil
	self.name.Visible = tickets ~= nil
	if tickets then
		for i, card in self.own do
			paint(card, i > tickets)
			if self.shownOwn and i > tickets and i <= self.shownOwn then
				UiStyle.pop(card, 1.7) -- just spent
			end
		end
	end
	self.shownOwn = tickets
end

return TicketHud
