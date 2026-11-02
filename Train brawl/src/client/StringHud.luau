--!strict
-- The player's own 1-2-3 string on screen (persona fix 2, 2026-10-29: launches came 19 times to 120 light hits and the
-- testers could not tell why the third did not come). Just right of the aim dot (under it they sat on the character's
-- arm in the shoulder camera): two round marks and a bigger diamond for
-- the launching third, lit for the steps taken; under them a thin bar that runs out over the time left to press the
-- next step (full while the weapon gets ready again, then emptying over Config.Attack.StringGap). When the next press
-- is the third the diamond pulses and the hand that will strike (or the weapon held) glows gold. When a hit breaks a
-- running string the marks flash red and shake with "끊김!" under them; a string left to run out just goes dark. For the
-- first moment after the weapon is ready again - while a hit just landed still stuns (decision 23: HitRules.stun's
-- margin, less the third's wind-up when the next press is the third) - the bar shows thicker and white: press now and
-- the next step lands before the one hit can act (Codex review 2026-11-02: the string's 0.4 s is longer than that). Shown
-- only while the player fights on the trains with something that strings (punches and swings). The rules stay as they
-- are (AttackString); this only shows them. The look is UiStyle's colours.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local StringHud = {}
StringHud.__index = StringHud

-- The player's string as OwnSwing counts it: the last step taken (0: none), when that attack's weapon is ready again
-- (server time), whether a press now would go on with it, and how many running strings a hit has broken so far.
export type View = { step: number, ready: number, live: boolean, breaks: number }

local MARK = 10
local LAST = 15 -- the third, a diamond this big
local SPACE = 8
local RIGHT = 22 -- the marks start this far right of the aim dot
local BAR_HEIGHT = 3
local BAR_TIGHT = 5 -- the bar's height while a press now still lands within the stun
local DIM = Color3.fromRGB(40, 28, 20)
local LIT = UiStyle.Cream
local EDGE_EMPTY = 0.45 -- an unlit mark's cream edge, this see-through (seen on the dark roofs and the bright sand)
local FINISH_HOLD = 0.45 -- all three stay lit this long after the third
local BREAK_SECONDS = 0.6
local SHAKE = 5 -- pixels
local PULSE = 14 -- radians per second, the ready diamond and the glow

type Fields = {
	gui: ScreenGui,
	box: Frame,
	marks: { Frame },
	bar: Frame,
	fill: Frame,
	broke: TextLabel,
	seenBreaks: number,
	seenStep: number,
	finishUntil: number, -- os.clock until which all three stay lit
	breakUntil: number, -- os.clock until which the break shows
	glow: Highlight?,
}
export type Hud = typeof(setmetatable({} :: Fields, StringHud))

local function mark(parent: Instance, size: number, diamond: boolean): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Mark"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = DIM
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Rotation = if diamond then 45 else 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if diamond then UDim.new(0, 2) else UDim.new(1, 0)
	corner.Parent = frame
	local outline = Instance.new("UIStroke")
	outline.Name = "Edge"
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = LIT
	outline.Transparency = EDGE_EMPTY
	outline.Thickness = 1.5
	outline.Parent = frame
	frame.Parent = parent
	return frame
end

function StringHud.new(playerGui: Instance): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlString"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- measured from the true middle, where the aim dot is (AimLock)
	gui.Parent = playerGui
	local width = MARK * 2 + LAST + SPACE * 2
	local box = Instance.new("Frame")
	box.Name = "String"
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Position = UDim2.new(0.5, RIGHT, 0.5, 0)
	box.Size = UDim2.fromOffset(width, LAST + 10)
	box.BackgroundTransparency = 1
	box.Visible = false
	box.Parent = gui
	local marks = {}
	local x = 0
	for i, size in { MARK, MARK, LAST } do
		local m = mark(box, size, i == 3)
		m.Position = UDim2.fromOffset(x + size / 2, LAST / 2)
		x += size + SPACE
		table.insert(marks, m)
	end
	local bar = Instance.new("Frame")
	bar.Name = "Window"
	bar.Position = UDim2.fromOffset(0, LAST + 5)
	bar.Size = UDim2.fromOffset(width, BAR_HEIGHT)
	bar.BackgroundColor3 = DIM
	bar.BackgroundTransparency = 0.4
	bar.BorderSizePixel = 0
	bar.Parent = box
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = LIT
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local broke = UiStyle.label(box, "Broken", UDim2.fromOffset(120, 22), 18, UiStyle.Red)
	broke.AnchorPoint = Vector2.new(0.5, 0)
	broke.Position = UDim2.fromOffset(width / 2, LAST + 10)
	broke.Text = Words.StringBroken
	broke.Visible = false
	local fields: Fields = {
		gui = gui,
		box = box,
		marks = marks,
		bar = bar,
		fill = fill,
		broke = broke,
		seenBreaks = 0,
		seenStep = 0,
		finishUntil = 0,
		breakUntil = 0,
		glow = nil,
	}
	return setmetatable(fields, StringHud)
end

-- The glow on what strikes the third: the weapon held, or the right fist (the third punch is the right's).
local function setGlow(self: Hud, own: Model?, on: boolean, clock: number)
	local target: Instance? = nil
	if on and own then
		target = own:FindFirstChild(Names.WeaponPart) or own:FindFirstChild("RightHand")
	end
	local glow = self.glow
	if not target then
		if glow then
			glow:Destroy()
			self.glow = nil
		end
		return
	end
	if not glow or glow.Adornee ~= target or not glow.Parent then
		if glow then
			glow:Destroy()
		end
		local made = Instance.new("Highlight")
		made.Name = "TrainBrawlFinisherGlow"
		made.FillColor = UiStyle.Gold
		made.OutlineColor = UiStyle.Gold
		made.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		made.Adornee = target
		made.Parent = target
		self.glow = made
		glow = made
	end
	local pulse = (math.sin(clock * PULSE) + 1) / 2
	local shown = glow :: Highlight
	shown.FillTransparency = 0.25 + 0.35 * pulse
	shown.OutlineTransparency = 0.1 * pulse
end

-- Every frame. view: the player's string; shown: whether the player fights on the trains with something that strings
-- (a break or a third while hidden is not shown later); gap: how long after the weapon is ready a press still goes on
-- (Config.Attack.StringGap); now: server time; clock: os.clock; own: the player's character (for the glow).
function StringHud.update(self: Hud, view: View, shown: boolean, gap: number, now: number, clock: number, own: Model?)
	if not shown then
		self.box.Visible = false
		self.seenBreaks, self.seenStep = view.breaks, view.step
		self.breakUntil, self.finishUntil = 0, 0
		setGlow(self, own, false, clock)
		return
	end
	self.box.Visible = true
	if view.breaks > self.seenBreaks then
		self.breakUntil = clock + BREAK_SECONDS
		self.finishUntil = 0
		UiStyle.pop(self.broke, 1.4)
	end
	self.seenBreaks = view.breaks
	if view.step >= #self.marks and view.step ~= self.seenStep then
		self.finishUntil = clock + FINISH_HOLD -- the third: all lit for a moment, then dark
	end
	self.seenStep = view.step
	local breaking = clock < self.breakUntil
	local lit = if clock < self.finishUntil then #self.marks elseif view.live then view.step else 0
	local readyThird = view.live and view.step == #self.marks - 1 and not breaking
	local pulse = (math.sin(clock * PULSE) + 1) / 2
	for i, m in self.marks do
		local on = i <= lit
		m.BackgroundColor3 = if breaking then UiStyle.Red elseif on then (if i == #self.marks then UiStyle.Gold else LIT) else DIM
		m.BackgroundTransparency = if breaking or on then 0 else 0.25
		local edge = m:FindFirstChild("Edge") :: UIStroke
		edge.Color = if breaking or on then UiStyle.Outline else LIT
		edge.Transparency = if breaking or on then 0 else EDGE_EMPTY
		if i == #self.marks and readyThird then
			m.BackgroundColor3 = UiStyle.Gold
			m.BackgroundTransparency = 0.55 - 0.5 * pulse
		end
	end
	local shake = if breaking then math.sin(clock * 60) * SHAKE * (self.breakUntil - clock) / BREAK_SECONDS else 0
	self.box.Position = UDim2.new(0.5, RIGHT + shake, 0.5, 0)
	self.broke.Visible = breaking
	-- The time left to press the next step.
	local running = view.live and view.step > 0 and view.step < #self.marks and not breaking
	self.bar.Visible = running
	if running then
		local share = if now < view.ready then 1 else math.clamp(1 - (now - view.ready) / gap, 0, 1)
		-- Pressed within this of the weapon being ready again, the next step lands while the one hit is still stunned.
		local tight = Config.Hit.StringMargin + (if readyThird then 0 else Config.Attack.FinisherWindup)
		local stillStunned = now >= view.ready and now - view.ready <= tight
		self.fill.Size = UDim2.fromScale(share, 1)
		self.fill.BackgroundColor3 = if stillStunned then Color3.new(1, 1, 1) elseif readyThird then UiStyle.Gold else LIT
		self.bar.Size = UDim2.fromOffset(self.bar.Size.X.Offset, if stillStunned then BAR_TIGHT else BAR_HEIGHT)
	end
	setGlow(self, own, readyThird, clock)
end

return StringHud
