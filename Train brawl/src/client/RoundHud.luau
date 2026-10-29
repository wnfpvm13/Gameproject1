--!strict
-- The round on screen. During a fight: the time on a plate at the top, with the fighters still aboard on its left and
-- the player's knock-offs on its right (each number bounces when it changes; the time turns gold for the last 30
-- seconds). Under it a status line while waiting, watching, out, on the way back after a fall (how long until the
-- parachute, then coming down) or guarded just after landing. Big centre text for the moments: the count-down numbers,
-- "출발!" as the fight starts, the tickets left when the player falls with one to spare, "다시 탑승!" when it lands,
-- "하차!" when it goes out, and the winner (or a shared win when the time ran out on a tie) with a short note. Reads
-- the Workspace round attributes and the player's own character's each frame; the words are Words', the look
-- UiStyle's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local RoundHud = {}
RoundHud.__index = RoundHud

local GO_SECONDS = 1.1 -- "출발!" stays this long
local OUT_SECONDS = 1.6 -- "하차!" stays this long
local FADE_SECONDS = 0.3 -- the big text fades out over its last this long
local HURRY_SECONDS = 30 -- the time turns gold from here
local BIG_TEXT = 96 -- the big text's largest size (a long winner's name shrinks to fit the width)
local COUNT_SCALE = 1.7 -- a count-down number is the big text scaled up this much (text stops at 100 pixels)
local BIG_Y = 0.3 -- the big text's middle, as a share of the screen height
local BIG_MIN_Y = 130 -- but at least this far down, clear of the plates on a short phone screen

type Fields = {
	gui: ScreenGui,
	bar: Frame, -- the plates at the top (shown during a fight)
	clock: TextLabel,
	aboard: TextLabel,
	kos: TextLabel,
	kosPlate: Frame,
	status: TextLabel,
	big: TextLabel,
	note: TextLabel,
	phase: string?,
	standing: string?,
	shownCount: number?,
	shownKos: number?,
	shownTick: number?,
	bigUntil: number, -- os.clock when a passing big text ("출발!", "하차!") has faded (math.huge = it stays)
	-- A line under a passing big text (who knocked the player off: knockedOff) and until when it shows (os.clock).
	noteText: string,
	noteUntil: number,
}
export type Hud = typeof(setmetatable({} :: Fields, RoundHud))

-- A plate at `x` along the top bar holding one styled label (returned with the plate).
local function plate(parent: Instance, name: string, x: number, width: number, height: number, most: number): (TextLabel, Frame)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, x, 0, 0)
	frame.Size = UDim2.fromOffset(width, height)
	UiStyle.plate(frame)
	frame.Parent = parent
	local label = UiStyle.label(frame, "Text", UDim2.new(1, -12, 1, -6), most)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	return label, frame
end

function RoundHud.new(playerGui: Instance): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlHud"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundTransparency = 1
	bar.Position = UDim2.fromOffset(0, 12)
	bar.Size = UDim2.new(1, 0, 0, 48)
	bar.Visible = false
	bar.Parent = gui
	local clock = plate(bar, "Clock", 0, 112, 48, 34)
	local aboard = plate(bar, "Aboard", -128, 124, 34, 22)
	local kos, kosPlate = plate(bar, "KOs", 128, 124, 34, 22)
	local status = UiStyle.label(gui, "Status", UDim2.fromOffset(560, 26), 22)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 66)
	local big = UiStyle.label(gui, "Big", UDim2.fromOffset(640, 100), BIG_TEXT)
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.new(0.5, 0, 0, BIG_MIN_Y) -- placed each frame (place())
	UiStyle.text(big, nil, 4)
	local note = UiStyle.label(gui, "Note", UDim2.fromOffset(480, 30), 26)
	note.AnchorPoint = Vector2.new(0.5, 0)
	note.Position = UDim2.new(0.5, 0, 0, BIG_MIN_Y + 54)
	local fields: Fields = {
		gui = gui,
		bar = bar,
		clock = clock,
		aboard = aboard,
		kos = kos,
		kosPlate = kosPlate,
		status = status,
		big = big,
		note = note,
		phase = nil,
		standing = nil,
		shownCount = nil,
		shownKos = nil,
		shownTick = nil,
		bigUntil = 0,
		noteText = "",
		noteUntil = 0,
	}
	return setmetatable(fields, RoundHud)
end

-- The big text and its note, 30% down the screen but never up against the plates.
local function place(self: Hud)
	local y = math.max(Workspace.CurrentCamera.ViewportSize.Y * BIG_Y, BIG_MIN_Y)
	if self.big.Position.Y.Offset ~= y then
		self.big.Position = UDim2.new(0.5, 0, 0, y)
		self.note.Position = UDim2.new(0.5, 0, 0, y + 54)
	end
end

local function setText(label: TextLabel, text: string)
	if label.Text ~= text then
		label.Text = text
	end
end

-- Shows `text` big in the centre, with a bounce; `seconds` = how long before it fades (nil = it stays); `scale` = how
-- much bigger than the big text it rests (1 when nil).
local function shout(self: Hud, text: string, seconds: number?, color: Color3?, scale: number?)
	self.big.Text = text
	self.big.TextColor3 = color or UiStyle.Cream
	self.bigUntil = if seconds then os.clock() + seconds else math.huge
	UiStyle.fade(self.big, 0)
	UiStyle.pop(self.big, 1.45, scale)
end

-- A call in the middle for something the player did (home runs in a row: Words.homerunStreak), gold, a moment.
function RoundHud.callout(self: Hud, text: string)
	shout(self, text, GO_SECONDS, UiStyle.Gold)
end

-- The player was knocked off: `line` (Words.knockedOff) shows under the big text ("하차!" or the tickets left) a moment.
function RoundHud.knockedOff(self: Hud, line: string)
	self.noteText = line
	self.noteUntil = os.clock() + OUT_SECONDS + 0.8
end

-- Every frame. now: server time; standing: "in" (on the trains), "back" (fell with a ticket left, on the way back),
-- "out" (knocked out of the round) or "watching" (came in during it); kos: the player's knock-offs; own: the player's
-- character (its tickets, way back and guard).
function RoundHud.update(self: Hud, now: number, standing: string, kos: number, own: Model?)
	local raw = Workspace:GetAttribute(Names.Phase)
	local phase = if typeof(raw) == "string" then raw else "Waiting"
	local endsAt = PartUtil.number(Workspace, Names.PhaseEndsAt) or 0
	local left = math.max(0, math.ceil(endsAt - now))
	local count = PartUtil.number(Workspace, Names.AliveCount) or 0
	local before, beforeStanding = self.phase, self.standing
	self.phase, self.standing = phase, standing
	place(self)

	-- The moments, once each.
	if phase ~= before then
		self.shownTick = nil
		if phase == "Fight" and before == "Countdown" then
			shout(self, Words.Go, GO_SECONDS, UiStyle.Gold)
		elseif phase == "Ended" then
			local winner = Workspace:GetAttribute(Names.Winner)
			local won = typeof(winner) == "string" and winner ~= ""
			local tied = (PartUtil.number(Workspace, Names.WinnerCount) or 0) > 1
			local title = if not won then Words.Draw elseif tied then Words.SharedWin else Words.winner(winner :: string)
			shout(self, title, nil, if won then UiStyle.Gold else nil)
			local run = PartUtil.number(Workspace, Names.WinnerStreak) or 0
			setText(self.note, if tied then winner :: string elseif won and run >= 2 then Words.winStreak(run) elseif won then Words.WinnerNote else "")
		elseif phase ~= "Countdown" then
			self.bigUntil = math.min(self.bigUntil, os.clock() + FADE_SECONDS) -- whatever was up fades out
		end
	end
	if phase == "Countdown" then
		local tick = math.max(1, left)
		if tick ~= self.shownTick then
			self.shownTick = tick
			shout(self, tostring(tick), nil, nil, COUNT_SCALE)
		end
	elseif phase == "Fight" and standing == "out" and beforeStanding == "in" then
		shout(self, Words.Out, OUT_SECONDS, UiStyle.Red)
	elseif phase == "Fight" and standing == "back" and beforeStanding == "in" then
		local tickets = if own then PartUtil.number(own, Names.Tickets) else nil
		shout(self, Words.ticketsLeft(tickets or 0), OUT_SECONDS, UiStyle.Gold)
	elseif phase == "Fight" and standing == "in" and beforeStanding == "back" then
		shout(self, Words.Back, GO_SECONDS, UiStyle.Gold)
	end
	if phase ~= "Ended" then
		setText(self.note, if os.clock() < self.noteUntil then self.noteText else "")
	end
	local fadeLeft = self.bigUntil - os.clock()
	if fadeLeft <= 0 then
		setText(self.big, "")
	elseif fadeLeft < FADE_SECONDS then
		UiStyle.fade(self.big, 1 - fadeLeft / FADE_SECONDS)
	end

	-- The plates during a fight.
	local fighting = phase == "Fight"
	self.bar.Visible = fighting
	if fighting then
		setText(self.clock, Words.clock(left))
		self.clock.TextColor3 = if left <= HURRY_SECONDS then UiStyle.Gold else UiStyle.Cream
		setText(self.aboard, Words.aboard(count))
		if self.shownCount and count ~= self.shownCount then
			UiStyle.pop(self.aboard)
		end
		self.shownCount = count
		self.kosPlate.Visible = standing ~= "watching"
		setText(self.kos, Words.knockOffs(kos))
		if self.shownKos and kos > self.shownKos then
			UiStyle.pop(self.kos, 1.5)
		end
		self.shownKos = kos
	else
		self.shownCount, self.shownKos = nil, nil
	end

	-- The status line.
	local status = ""
	if fighting then
		if standing == "out" then
			status = Words.OutWatching
		elseif standing == "watching" then
			status = Words.LateWatching
		elseif standing == "back" and own then
			local dropAt = PartUtil.number(own, Names.ReturnAt)
			status = if own:GetAttribute(Names.ReturnPhase) == "Down" or not dropAt then Words.Dropping else Words.dropIn(math.max(1, math.ceil(dropAt - now)))
		elseif own then
			local guardUntil = PartUtil.number(own, Names.GuardUntil)
			status = if guardUntil and now < guardUntil then Words.Guarded else ""
		end
	elseif phase == "Waiting" then
		-- The server starts when enough are in (sandbags count in Studio practice).
		local solo = RunService:IsStudio() and Workspace:GetAttribute(Names.Solo) == true
		local enough = #Players:GetPlayers() + (if solo then Config.Sandbag.Count else 0) >= Config.Round.MinPlayers
		status = if enough then Words.WaitingSoon else Words.WaitingFew
	end
	setText(self.status, status)
end

return RoundHud
