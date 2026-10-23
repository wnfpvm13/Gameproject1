--!strict
-- The cowboy's timing ring for a jump together: when the locomotive jumps, a gold ring shrinks onto a fixed white ring
-- and meets it at the top of the arc (the moment to jump for the gold), then fades. Local UI only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))

local ApexRing = {}
ApexRing.__index = ApexRing

local SIZE = 0.13 -- the target ring, as a share of the screen height
local START_SCALE = 2.6 -- the gold ring's size at the jump's start, against the target
local FADE_SECONDS = 0.35 -- after the top
local TARGET_COLOR = Color3.fromRGB(255, 255, 255)
local RING_COLOR = Color3.fromRGB(240, 200, 60)

type Fields = {
	gui: ScreenGui,
	target: Frame,
	ring: Frame,
	targetStroke: UIStroke,
	ringStroke: UIStroke,
	at: number?, -- the jump being shown (server time of its start)
}
export type Ring = typeof(setmetatable({} :: Fields, ApexRing))

local function circle(parent: Instance, name: string, color: Color3, thickness: number): (Frame, UIStroke)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = frame
	frame.Parent = parent
	return frame, stroke
end

function ApexRing.new(playerGui: Instance): Ring
	local gui = Instance.new("ScreenGui")
	gui.Name = "WesternTrainApexRing"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.42) -- over the cowboy, who is in the middle of the screen
	holder.Size = UDim2.fromScale(SIZE, SIZE)
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local target, targetStroke = circle(holder, "Target", TARGET_COLOR, 3)
	local ring, ringStroke = circle(holder, "Ring", RING_COLOR, 5)
	gui.Parent = playerGui
	local fields: Fields = { gui = gui, target = target, ring = ring, targetStroke = targetStroke, ringStroke = ringStroke, at = nil }
	return setmetatable(fields, ApexRing)
end

-- Shows the ring for a jump that started at server time `at`.
function ApexRing.start(self: Ring, at: number)
	self.at = at
end

function ApexRing.hide(self: Ring)
	self.at = nil
	self.gui.Enabled = false
end

-- Every frame: now is the server time.
function ApexRing.update(self: Ring, now: number)
	local at = self.at
	if not at then
		return
	end
	local apex = at + Config.Jump.Seconds / 2
	if now >= apex + FADE_SECONDS then
		self:hide()
		return
	end
	if now < at then
		self.gui.Enabled = false -- our clock is a little behind the server's: not yet
		return
	end
	self.gui.Enabled = true
	local toApex = math.clamp((apex - now) / (apex - at), 0, 1) -- 1 at the start, 0 at the top
	local scale = 1 + (START_SCALE - 1) * toApex
	self.ring.Size = UDim2.fromScale(scale, scale)
	local fade = if now > apex then (now - apex) / FADE_SECONDS else 0
	self.ringStroke.Transparency = fade
	self.targetStroke.Transparency = fade
	-- At the top the target ring lights up gold.
	self.targetStroke.Color = if now >= apex - 0.06 then RING_COLOR else TARGET_COLOR
end

return ApexRing
