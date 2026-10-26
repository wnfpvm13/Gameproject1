--!strict
-- The mission card at the bottom of the screen (docs/DESIGN_V3.md §5; bundle 4a; owner 2026-10-24: low, so the chairs
-- and the pool behind them stay in view):
--   - quiz: the question, four answer buttons (only for players who may answer) and the seconds left; afterwards the
--     right answer turns green and my wrong pick red;
--   - roulette (owner 2026-10-23: a 2D wheel): the names on a ring and a pointer that spins and slows down onto the
--     name the server picked; with two players a coin flips between the two names instead;
--   - a word to everyone (bundle 4b): whose turn, the topic, the seconds left, and for the performer a "swap topic"
--     button while they read it; then "the presenter is choosing", or a vote: the performers, "nobody" and "I could
--     not hear" (my own name cannot be picked);
--   - the banned-word talk (bundle 6a): one slim line under the status board, "topic · seconds left" (the middle of the
--     screen stays free: the players read each other's words over their heads there);
--   - the bells (bundle 6b): "ring to speak first" before "say what you like", and the bell quiz: the question, then
--     who is answering (the right answer comes as a quiz result);
--   - bundle 6c: crocodile teeth (whose turn and ten teeth, pressable on my turn, pressed ones shut; the biting one at
--     the end), the bomb (who holds it, a pass button for the holder: off at first, then lit — owner 2026-10-25),
--     nunchi (the rule and the seconds
--     left; at the end the order the bells came in);
--   - bundle 8b (owner 2026-10-24): 숫자 맞추기 (the target, a clock counting up that hides after a few seconds, then
--     everyone's time), 총잡이 결투 ("ready…", then a red "fire!" when the server says so, my opponent; then the
--     reactions), 물병 세우기 (a power bar with a green zone and a marker sweeping at the server's pace, stopping where
--     I rang; who stood);
--   - bundle 8c (owner 2026-10-24): the 초성 quiz and the O/X quiz on the quiz's own screen (O/X: then everyone's
--     wrong count), the number quiz (a box for a whole number and "send"; then everyone's number and the answer);
--   - bundle 9c (owner 2026-10-25): 머리 위 스무고개 (the topic, whose turn, the round and how many are right; on my
--     turn the same box takes my answer as text; each answer's verdict; at the end who was right, who flies and my
--     own word);
--   - between games (owner 2026-10-24): what the last game did with the vote for the next one (or "the presenter is
--     picking"), then the next game's briefing: its name, its one-line rule, 3-2-1; at the end the round's result
--     with its awards (the longest flight, the most games without losing a life);
--   - bundle 6d: the balance game ("A vs B", who argues, then two picks that may change until the time is up; the
--     counts), red light (the light big on a green or red card, my steps), the liar (the category, the word — or "you
--     are the liar" — on my own screen, whose clue it is, the vote, the liar's guess among four, who it was).
-- It only shows what it is told and reports the button pressed; the server checks every answer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local PowerBar = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("PowerBar"))
local Hangul = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Hangul"))
local Style = require(script.Parent:WaitForChild("Style"))

local MissionPanel = {}

local TWO_PI = 2 * math.pi
local RING_RADIUS = 112 -- pixels from the wheel centre to the names (up to RING_FULL names; more push it out)
local RING_FULL = 6
local PILL_WIDTH = 104
local SPIN_TURNS = 4 -- whole turns before the pointer stops
local COIN_SIZE = 170
local MAX_BUTTONS = Config.MAX_PLAYERS + 2 -- a vote: everyone on the ground (the liar game), "nobody", "could not hear"
local TEXT = Config.TEXT
local ESTIMATE_DIGITS = #tostring(Config.ESTIMATE_MAX) -- (the number box takes no longer number)
local TITLE_SIZE = 26 -- the title's largest text size (it scales down to fit)
local INITIALS_SIZE = 40 -- the 초성 quiz's consonants in the title (drawn at about half height, see shared/Hangul)
local SLICE_COLORS = { Color3.fromRGB(140, 200, 255), Color3.fromRGB(255, 182, 210) } -- name pills, alternating
-- 악어 이빨 (owner 2026-10-25: redrawn): the crocodile seen from the front with its jaws open (Config.IMAGES.CROC,
-- CROC_W x CROC_H pixels, assets/icons/croc.svg). The teeth stand on the inner rim of the U-shaped lower jaw — an
-- ellipse (RIM_*) from RIM_FROM to RIM_TO degrees — at equal gaps, each leaning toward the middle of the mouth, each
-- in an invisible square touch area as wide as the gap (a fingertip on a phone is wider than a drawn tooth; along the
-- U the gaps are about 1.5 times what a straight row fits in the same height). Sizes in picture pixels.
local CROC_W, CROC_H = 640, 300
local CROC_MAX_HEIGHT = 220 -- screen pixels before the card scales
local RIM_X, RIM_Y, RIM_A, RIM_B = 320, 126, 240, 136
local RIM_FROM, RIM_TO = 197, 343
local TOOTH_W, TOOTH_H = 34, 44
local TOOTH_WHITE = Color3.new(1, 1, 1)
local GREEN_LIGHT = Color3.fromRGB(128, 222, 148) -- the red light game's card (bright: dark text on it)
local RED_LIGHT = Color3.fromRGB(255, 122, 122)

local card: Frame
local cardScale: UIScale
local title: TextLabel
local titleLimit: UITextSizeConstraint -- (lifted for the 초성 quiz's bigger consonants)
local timer: TextLabel
local note: TextLabel
local noteLimit: UITextSizeConstraint -- (the briefing's rule reads bigger)
local subNote: TextLabel -- a small line under the buttons (the briefing: what the last game did)
local swapButton: TextButton
local answerGrid: Frame
local answerLayout: UIGridLayout
local buttons: { TextButton } = {}
local teethGrid: ImageLabel -- the crocodile's jaws (the teeth stand on its lower jaw)
local teeth: { TextButton } = {} -- the touch areas
local drawnTeeth: { TextLabel } = {} -- the white teeth in them
local toothInward: { Vector2 } = {} -- each tooth's direction into the mouth (picture pixels)
local reachSize = 1 -- a touch area's side (picture pixels)
local wheel: Frame
local pointer: Frame
local disc: Frame
local needle: Frame
local arrow: TextLabel
local coin: TextLabel
local ringPills: { Frame } = {}
local answerRow: Frame -- the answer box and its "send" button: 숫자 근사's whole number, 스무고개's answer (text)
local answerBox: TextBox
local sendButton: TextButton
local bar: Frame -- 물병 세우기's power bar, its green zone and the marker
local zone: Frame
local marker: Frame
local onAnswer: (number, number | string) -> () = function(_id, _choice) end

local state = {
	kind = "none",
	endsAt = 0,
	canAnswer = false,
	question = "",
	id = 0, -- the open question's number (sent back with the answer)
	myPick = nil :: number?,
	sentText = "", -- 스무고개: the answer I sent this turn (shown back to me only)
	myId = 0,
	voteIds = {} :: { number }, -- a vote's candidates (my own name cannot be picked)
	myTurn = false, -- crocodile teeth: my turn now
	rings = 0, -- nunchi: bells rung so far (the next number is one more)
	nunchiEndsAt = 0, -- nunchi: which game `rings` counts
	down = {} :: { boolean }, -- crocodile teeth: the teeth already pressed
	-- roulette
	names = {} :: { string },
	pick = 1,
	startsAt = 0,
	spinSeconds = 1,
	topicLine = "", -- the banned-word talk's topic line (the seconds are added every frame)
	timing = { startAt = 0, visibleFor = 0, barStartAt = 0, period = 1, stoppedAt = 0 }, -- bundle 8b's moments
	-- (`stoppedAt`: when I rang in this 물병 throw, 0 = not yet)
	slim = false, -- the talk's slim line at the top (else the card sits on the bottom row)
	hidden = false, -- stepped aside for a launch (setHidden)
	shown = false, -- what the screen asks for, before `hidden`
}
local CARD_GAP = 8 -- pixels between the card and the bottom row (the reactions, the presenter's sounds)
local TALK_POSITION = UDim2.new(0.5, 0, 0, Style.row(4)) -- the talk's slim line: under the status board and the
-- getting-ready lines (rows 1-3), above the chair row

-- Where the card goes: the talk's slim line under the status board, else on top of the bottom row (its height changes
-- with the reactions; the bell button sits on the right side since 2026-10-25).
local function place()
	if state.slim then
		card.Position = TALK_POSITION
	else
		card.Position = UDim2.new(0.5, 0, 1, -(Style.bottomStack().AbsoluteSize.Y + 12 + CARD_GAP))
	end
end

local function answerButton(index: number): TextButton
	local b = Style.button(Style.BOLD, 22)
	b.TextScaled = true
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 22
	size.Parent = b
	-- (a small second line: the next-game vote shows each game's rule under its name, review 2026-10-25 — a first-time
	-- player otherwise votes for names only)
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0.5, 1)
	sub.Position = UDim2.fromScale(0.5, 1)
	sub.Size = UDim2.fromScale(1, 0.52)
	sub.FontFace = Style.REGULAR
	sub.TextColor3 = Style.INK
	sub.TextScaled = true
	sub.TextWrapped = true
	sub.Text = ""
	sub.Visible = false
	local subSize = Instance.new("UITextSizeConstraint")
	subSize.MaxTextSize = 14
	subSize.Parent = sub
	sub.Parent = b
	b.LayoutOrder = index
	b.Activated:Connect(function()
		local open = state.endsAt > 0 and workspace:GetServerTimeNow() < state.endsAt -- (not while the question shows first)
		local mine = state.kind == "vote" and state.voteIds[index] == state.myId
		local answering = state.kind == "quiz" or state.kind == "vote" or state.kind == "bomb" or state.kind == "balance"
			or state.kind == "liarGuess" or state.kind == "nextVote"
		local repick = state.kind == "balance" -- (a balance pick may change until the time is up)
		if answering and state.canAnswer and open and (repick or not state.myPick) and not mine then
			state.myPick = index
			onAnswer(state.id, index)
			for i, other in buttons do
				other.BackgroundColor3 = if i == index then Style.PICK elseif repick then Style.KEY else Style.KEY_OFF
				other.TextColor3 = if i == index or repick then Style.INK else Style.FAINT
				other.AutoButtonColor = repick -- (answered: nothing else can be pressed, except a balance pick)
			end
		end
	end)
	b.Parent = answerGrid
	return b
end

-- onPick(questionId, choice): I pressed an answer button.
-- The teeth's places on the jaw's rim: `count` of them at equal gaps along it — each one's centre (picture pixels) and
-- direction into the mouth — and the gap between neighbours.
local function rimSpots(count: number): ({ { centre: Vector2, inward: Vector2 } }, number)
	local samples: { { t: number, along: number, at: Vector2 } } = {}
	local along = 0
	local last: Vector2? = nil
	for k = 0, 200 do
		local t = math.rad(RIM_FROM + (RIM_TO - RIM_FROM) * k / 200)
		local at = Vector2.new(RIM_X + RIM_A * math.cos(t), RIM_Y - RIM_B * math.sin(t))
		if last then
			along += (at - last).Magnitude
		end
		table.insert(samples, { t = t, along = along, at = at })
		last = at
	end
	local gap = along / math.max(1, count - 1)
	local spots = {}
	for i = 1, count do
		local want = gap * (i - 1)
		local pick = samples[#samples]
		for _, sample in samples do
			if sample.along >= want - 1e-6 then
				pick = sample
				break
			end
		end
		local inward = Vector2.new(-math.cos(pick.t) / RIM_A, math.sin(pick.t) / RIM_B).Unit
		table.insert(spots, { centre = pick.at + inward * (TOOTH_H / 2 - 4), inward = inward })
	end
	return spots, gap
end

-- `text` cut to `letters` letters (스무고개's answer box).
local function clip(text: string, letters: number): string
	local ok, cut = pcall(utf8.offset, text, letters + 1)
	return if ok and cut then string.sub(text, 1, cut - 1) else text
end

-- Lets go of the answer box (a phone keyboard closes with it).
local function dropFocus()
	if answerBox and answerBox:IsFocused() then
		answerBox:ReleaseFocus()
	end
end

-- onPick(questionId, choice): I pressed an answer button (or sent a number or a text).
function MissionPanel.build(onPick: (number, number | string) -> ())
	onAnswer = onPick
	card = Style.panel(Style.gui(), Style.PAPER, Style.PAPER_ALPHA, 16)
	card.Name = "MissionCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.fromScale(0.5, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Visible = false
	Style.limit(card, Vector2.new(320, 0), Vector2.new(580, 600))
	cardScale = Instance.new("UIScale") -- shrinks the card on short screens (tick)
	cardScale.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = card

	timer = Style.label(card, Style.BOLD, 20, Style.ACCENT_TEXT)
	timer.Size = UDim2.new(1, 0, 0, 22)
	timer.LayoutOrder = 0
	title = Style.label(card, Style.BOLD, TITLE_SIZE, Style.INK)
	titleLimit = title:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
	title.Size = UDim2.new(1, 0, 0, 64)
	title.LayoutOrder = 1
	note = Style.label(card, Style.REGULAR, 18, Style.FAINT)
	noteLimit = note:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
	note.Size = UDim2.new(1, 0, 0, 22)
	note.LayoutOrder = 2
	subNote = Style.label(card, Style.REGULAR, 15, Style.FAINT)
	subNote.Size = UDim2.new(1, 0, 0, 18)
	subNote.LayoutOrder = 5
	subNote.Visible = false

	answerGrid = Instance.new("Frame")
	answerGrid.BackgroundTransparency = 1
	answerGrid.Size = UDim2.fromScale(1, 0)
	answerGrid.AutomaticSize = Enum.AutomaticSize.Y
	answerGrid.LayoutOrder = 3
	answerGrid.Parent = card
	answerLayout = Instance.new("UIGridLayout")
	answerLayout.CellSize = UDim2.new(0.5, -4, 0, 44)
	answerLayout.CellPadding = UDim2.fromOffset(8, 8)
	answerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	answerLayout.Parent = answerGrid
	for i = 1, MAX_BUTTONS do
		buttons[i] = answerButton(i)
	end

	-- Crocodile teeth: the open jaws, the teeth in a row on the lower jaw (owner 2026-10-25: the old grid of pink tiles
	-- looked odd).
	teethGrid = Instance.new("ImageLabel")
	teethGrid.BackgroundTransparency = 1
	teethGrid.Image = Config.IMAGES.CROC
	teethGrid.ScaleType = Enum.ScaleType.Stretch
	teethGrid.Size = UDim2.fromScale(1, 0)
	teethGrid.LayoutOrder = 3
	teethGrid.Visible = false
	teethGrid.Parent = card
	-- (the picture's shape at the card's width, at most CROC_MAX_HEIGHT tall so the card does not cover the status
	-- board: an aspect constraint fights the card's automatic height)
	local function fitJaws()
		local width = card.AbsoluteSize.X / math.max(cardScale.Scale, 0.01) - 28
		local height = math.floor(math.min(width * CROC_H / CROC_W, CROC_MAX_HEIGHT))
		local size = UDim2.fromOffset(math.floor(height * CROC_W / CROC_H), height)
		if teethGrid.Size ~= size then
			teethGrid.Size = size
		end
	end
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitJaws)
	fitJaws()
	-- Each tooth: its touch area (a square, as wide as the gap between teeth; a press counts at once) with the drawn
	-- tooth in the middle, leaning into the mouth.
	local spots, gap = rimSpots(Config.CROC_TEETH)
	reachSize = gap * 0.95
	for i, spot in spots do
		local reach = Instance.new("TextButton")
		reach.AnchorPoint = Vector2.new(0.5, 0.5)
		reach.Position = UDim2.fromScale(spot.centre.X / CROC_W, spot.centre.Y / CROC_H)
		reach.Size = UDim2.fromScale(reachSize / CROC_W, reachSize / CROC_H)
		reach.BackgroundTransparency = 1
		reach.Text = ""
		local tooth = Instance.new("TextLabel")
		tooth.Name = "Tooth"
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.Position = UDim2.fromScale(0.5, 0.5)
		tooth.Size = UDim2.fromScale(TOOTH_W / reachSize, TOOTH_H / reachSize)
		tooth.Rotation = math.deg(math.atan2(spot.inward.X, -spot.inward.Y))
		tooth.BackgroundColor3 = TOOTH_WHITE
		tooth.FontFace = Style.BOLD
		tooth.TextScaled = true
		tooth.TextColor3 = Style.INK
		tooth.Text = ""
		Style.round(tooth, 8)
		tooth.Parent = reach
		reach.Activated:Connect(function()
			local open = state.endsAt > 0 and workspace:GetServerTimeNow() < state.endsAt
			if state.kind == "croc" and state.myTurn and open and not state.down[i] and not state.myPick then
				state.myPick = i
				onAnswer(state.id, i)
				tooth.BackgroundColor3 = Style.PICK
			end
		end)
		reach.Parent = teethGrid
		teeth[i] = reach
		drawnTeeth[i] = tooth
		toothInward[i] = spot.inward
	end

	swapButton = Instance.new("TextButton")
	swapButton.Size = UDim2.fromOffset(200, 40)
	swapButton.BackgroundColor3 = Style.KEY
	swapButton.FontFace = Style.BOLD
	swapButton.TextSize = 20
	swapButton.TextColor3 = Style.INK
	swapButton.Text = TEXT.ONE_WORD_SWAP
	swapButton.LayoutOrder = 4
	swapButton.Visible = false
	Style.round(swapButton, 10)
	swapButton.Parent = card
	swapButton.Activated:Connect(function()
		if state.kind == "oneWord" and state.id > 0 and workspace:GetServerTimeNow() < state.endsAt then
			swapButton.Visible = false
			onAnswer(state.id, 1)
		end
	end)

	-- The wheel: a round paper disc with a dark rim, the names as pills on a ring, a red needle from the hub.
	wheel = Instance.new("Frame")
	wheel.BackgroundTransparency = 1
	wheel.Size = UDim2.fromOffset(2 * RING_RADIUS + 120, 2 * RING_RADIUS + 50)
	wheel.LayoutOrder = 5
	wheel.Parent = card
	disc = Style.panel(wheel, Style.PAPER, 0, 1000)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromOffset(2 * RING_RADIUS + 44, 2 * RING_RADIUS + 44)
	local rim = disc:FindFirstChildOfClass("UIStroke") :: UIStroke -- (Style.panel's edge, made the thick rim)
	rim.Color = Style.INK
	rim.Transparency = 0
	rim.Thickness = 4
	pointer = Instance.new("Frame")
	pointer.BackgroundTransparency = 1
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.fromScale(0.5, 0.5)
	pointer.Size = UDim2.fromOffset(2 * RING_RADIUS, 2 * RING_RADIUS)
	pointer.ZIndex = 3
	pointer.Parent = wheel
	needle = Style.panel(pointer, Style.WRONG, 0, 3)
	needle.AnchorPoint = Vector2.new(0.5, 1)
	needle.Position = UDim2.fromScale(0.5, 0.5)
	needle.Size = UDim2.fromOffset(6, RING_RADIUS - 40)
	needle.ZIndex = 3
	arrow = Style.label(pointer, Style.BOLD, 30, Style.WRONG)
	arrow.Text = "▲"
	arrow.AnchorPoint = Vector2.new(0.5, 1)
	arrow.Position = UDim2.new(0.5, 0, 0.5, -(RING_RADIUS - 40) + 6)
	arrow.Size = UDim2.fromOffset(30, 26)
	arrow.ZIndex = 3
	local hub = Style.panel(wheel, Style.KEY, 0, 100)
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(26, 26)
	hub.ZIndex = 4

	coin = Style.label(card, Style.BOLD, 30, Style.INK)
	coin.BackgroundColor3 = Style.KEY
	coin.BackgroundTransparency = 0
	coin.Size = UDim2.fromOffset(COIN_SIZE, COIN_SIZE)
	coin.LayoutOrder = 6
	Style.round(coin, COIN_SIZE)

	-- 숫자 근사 퀴즈 (bundle 8c): a box for digits only and a "send" button; the number goes as the answer. 머리 위 스무고개
	-- (bundle 9c): the same box takes a short text on my turn.
	answerRow = Instance.new("Frame")
	answerRow.BackgroundTransparency = 1
	answerRow.Size = UDim2.new(1, 0, 0, 44)
	answerRow.LayoutOrder = 3
	answerRow.Visible = false
	answerRow.Parent = card
	answerBox = Instance.new("TextBox")
	answerBox.Size = UDim2.new(0.7, -8, 1, 0)
	answerBox.BackgroundColor3 = Color3.new(1, 1, 1)
	answerBox.BackgroundTransparency = 0.1
	answerBox.FontFace = Style.BOLD
	answerBox.TextSize = 22
	answerBox.TextColor3 = Style.INK
	answerBox.PlaceholderText = TEXT.ESTIMATE_HINT
	answerBox.PlaceholderColor3 = Style.FAINT
	answerBox.ClearTextOnFocus = false
	answerBox.Text = ""
	Style.round(answerBox, 10)
	answerBox.Parent = answerRow
	answerBox:GetPropertyChangedSignal("Text"):Connect(function()
		local text = answerBox.Text
		local fixed = if state.kind == "twenty" then clip(text, Config.TWENTY_ANSWER_MAX)
			else string.sub(string.gsub(text, "%D", ""), 1, ESTIMATE_DIGITS)
		if fixed ~= text then
			answerBox.Text = fixed
		end
	end)
	sendButton = Style.button(Style.BOLD, 20)
	sendButton.Size = UDim2.fromScale(0.3, 1)
	sendButton.Position = UDim2.fromScale(0.7, 0)
	sendButton.Text = TEXT.ESTIMATE_SEND
	sendButton.Parent = answerRow
	-- (the box and the button rest once sent)
	local function sent(line: string)
		answerBox.TextEditable = false
		sendButton.AutoButtonColor = false
		sendButton.TextColor3 = Style.FAINT
		sendButton.BackgroundColor3 = Style.KEY_OFF
		note.Text = line
		dropFocus()
	end
	local function send()
		local open = state.endsAt > 0 and workspace:GetServerTimeNow() < state.endsAt
		if not (state.canAnswer and open and not state.myPick) then
			return
		end
		if state.kind == "estimate" then
			local value = tonumber(answerBox.Text)
			if value and value >= 1 and value <= Config.ESTIMATE_MAX and value % 1 == 0 then
				state.myPick = value
				onAnswer(state.id, value)
				sent(string.format(TEXT.ESTIMATE_SENT, value))
			end
		elseif state.kind == "twenty" then
			local typed = string.match(answerBox.Text, "^%s*(.-)%s*$") or ""
			if typed ~= "" then
				state.myPick = 1
				state.sentText = typed
				onAnswer(state.id, typed)
				sent(string.format(TEXT.TWENTY_SENT, typed))
			end
		end
	end
	sendButton.Activated:Connect(send)
	answerBox.FocusLost:Connect(function(enter: boolean)
		if enter then
			send()
		end
	end)

	-- 물병 세우기's power bar (bundle 8b): the track, the green zone, the marker the bell stops.
	bar = Style.panel(card, Style.KEY_OFF, 0, 8)
	bar.Size = UDim2.new(1, 0, 0, 26)
	bar.LayoutOrder = 7
	bar.Visible = false
	zone = Style.panel(bar, Style.RIGHT, 0, 6)
	zone.AnchorPoint = Vector2.new(0.5, 0)
	zone.Size = UDim2.fromScale(0.3, 1)
	marker = Style.panel(bar, Style.INK, 0, 3)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Size = UDim2.new(0, 6, 1, 10)
	marker.Position = UDim2.fromScale(0, 0.5)
	marker.ZIndex = 2
end

-- Sizes the wheel for a ring of this radius (more names need a wider ring so the pills do not overlap).
local function sizeWheel(radius: number)
	wheel.Size = UDim2.fromOffset(2 * radius + PILL_WIDTH + 16, 2 * radius + 50)
	disc.Size = UDim2.fromOffset(2 * radius + 44, 2 * radius + 44)
	pointer.Size = UDim2.fromOffset(2 * radius, 2 * radius)
	needle.Size = UDim2.fromOffset(6, radius - 40)
	arrow.Position = UDim2.new(0.5, 0, 0.5, -(radius - 40) + 6)
end

local function setRing(names: { string })
	-- Neighbouring pills sit 2*r*sin(pi/n) apart; keep that at least the pill width once there are many names.
	local radius = math.max(RING_RADIUS, (PILL_WIDTH + 6) / (2 * math.sin(math.pi / math.max(#names, RING_FULL))))
	sizeWheel(radius)
	for _, pill in ringPills do
		pill:Destroy()
	end
	table.clear(ringPills)
	for i, name in names do
		local angle = (i - 1) / #names * TWO_PI -- clockwise from the top
		local pill = Style.panel(wheel, SLICE_COLORS[(i - 1) % 2 + 1], 0, 14)
		pill.AnchorPoint = Vector2.new(0.5, 0.5)
		pill.Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius)
		pill.Size = UDim2.fromOffset(PILL_WIDTH, 30)
		pill.ZIndex = 2
		local label = Style.label(pill, Style.BOLD, 18, Style.INK)
		label.Size = UDim2.new(1, -8, 1, -4)
		label.Position = UDim2.fromOffset(4, 2)
		label.Text = name
		label.ZIndex = 2
		table.insert(ringPills, pill)
	end
end

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 3
end

-- A picture on the left of an answer button (the bomb's pass button, owner 2026-10-25), or none.
local function buttonIcon(b: TextButton, image: string?)
	local icon = b:FindFirstChild("Icon") :: ImageLabel?
	if image and not icon then
		local made = Instance.new("ImageLabel")
		made.Name = "Icon"
		made.BackgroundTransparency = 1
		made.AnchorPoint = Vector2.new(0, 0.5)
		made.Position = UDim2.new(0, 2, 0.5, 0)
		made.Size = UDim2.fromScale(0.9, 0.9)
		made.ScaleType = Enum.ScaleType.Fit
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = made
		made.Parent = b
		icon = made
	end
	if icon then
		icon.Visible = image ~= nil
		icon.Image = image or ""
	end
end

-- Colours one answer button: open (can be pressed), mine (my pick), or neither.
local function paint(b: TextButton, open: boolean, picked: boolean)
	b.AutoButtonColor = open
	b.BackgroundColor3 = if picked then Style.PICK elseif open then Style.KEY else Style.KEY_OFF
	-- (faint only beside my pick: a question shown first, or one I watch, stays readable)
	b.TextColor3 = if picked or open or not state.myPick then Style.INK else Style.FAINT
end

-- What the server says the mission shows now. `canAnswer`: I am alive and on the ground (my buttons work);
-- `names`: the payload's players (`ids`) by name, in the server's order; `myId`: my UserId.
function MissionPanel.show(payload: { [string]: any }, canAnswer: boolean, names: { string }, myId: number)
	local kind = payload.kind
	local quizLike = kind == "quiz" or kind == "quizResult"
	local newQuestion = if quizLike then payload.question ~= state.question
		elseif kind == "vote" or kind == "balance" or kind == "liarGuess" or kind == "nextVote" then
			payload.id ~= nil and payload.id ~= state.id
		elseif kind == "estimate" or kind == "twenty" then (payload.id or 0) ~= state.id or state.kind ~= kind
		else true
	if newQuestion then
		state.myPick = nil -- a new question (a quiz comes twice: before and once the buttons work), a new vote, or none
	end
	state.question = if quizLike then payload.question else ""
	state.id = payload.id or 0
	state.kind = kind
	state.endsAt = payload.shownEndsAt or payload.endsAt or 0 -- (the bomb's time is always far off, never the bang)
	state.canAnswer = canAnswer
	state.myId = myId
	local bells = kind == "oneWordBell" or kind == "bellQuiz"
	local games = kind == "croc" or kind == "crocResult" or kind == "bomb" or kind == "bombResult" or kind == "nunchi"
		or kind == "nunchiResult" or kind == "balance" or kind == "balanceResult" or kind == "redLight"
		or kind == "redLightResult" or kind == "liar" or kind == "liarGuess" or kind == "liarResult"
	local between = kind == "nextVote" or kind == "nextPick" or kind == "brief" or kind == "roundResult"
	local timing = kind == "timeGuess" or kind == "timeGuessResult" or kind == "duel" or kind == "duelResult"
		or kind == "bottle" or kind == "bottleThrow" or kind == "bottleResult"
	local quizKinds = kind == "estimate" or kind == "estimateResult" or kind == "oxResult"
	local twenty = kind == "twenty" or kind == "twentyResult"
	-- (스무고개: the box only on my own turn)
	local myTurn = kind == "twenty" and payload.stage == "ask" and (payload.ids or {})[payload.asker or 0] == myId
	answerRow.Visible = kind == "estimate" or myTurn
	if not answerRow.Visible then
		dropFocus() -- (the box is gone: no phone keyboard left over)
	end
	answerBox.PlaceholderText = if kind == "twenty" then TEXT.TWENTY_HINT else TEXT.ESTIMATE_HINT
	sendButton.Text = if kind == "twenty" then TEXT.TWENTY_SEND else TEXT.ESTIMATE_SEND
	title.TextColor3 = Style.INK -- (the duel turns it red at "fire!")
	for _, b in buttons do
		buttonIcon(b, nil) -- (only the bomb's pass button has a picture)
		b.TextYAlignment = Enum.TextYAlignment.Center
		local sub = b:FindFirstChild("Sub") :: TextLabel?
		if sub then
			sub.Visible = false -- (only the next-game vote has the small line)
		end
	end
	subNote.Visible = false
	noteLimit.MaxTextSize = 18
	-- (only the 초성 quiz's consonants are drawn as RichText, at a fixed size and without the size limit: a bigger
	-- RichText size inside scaled or limited text is cut off)
	title.RichText = false
	title.TextScaled = true
	title.AutomaticSize = Enum.AutomaticSize.None
	titleLimit.MaxTextSize = TITLE_SIZE
	bar.Visible = kind == "bottle"
	local sameThrow = kind == "bottle" and state.timing.barStartAt == (tonumber(payload.barStartAt) or 0)
	state.timing = {
		startAt = tonumber(payload.startAt) or 0,
		visibleFor = tonumber(payload.visibleFor) or 0,
		barStartAt = tonumber(payload.barStartAt) or 0,
		period = tonumber(payload.period) or 1,
		stoppedAt = if sameThrow then state.timing.stoppedAt else 0, -- (the same throw sent again keeps my stop)
	}
	-- (the awards and the timing games' results take two lines: many names)
	note.Size = UDim2.new(1, 0, 0, if kind == "roundResult" or kind == "timeGuessResult" or kind == "duelResult"
		or kind == "bottleThrow" or kind == "bottleResult" or kind == "oxResult" or kind == "estimateResult" or twenty
		or kind == "brief" then 46 else 22)
	state.shown = quizLike or kind == "roulette" or kind == "oneWord" or kind == "oneWordJudge" or kind == "vote"
		or kind == "talk" or bells or games or between or timing or quizKinds or twenty
	card.Visible = state.shown and not state.hidden
	answerGrid.Visible = quizLike or kind == "vote" or kind == "bomb" or (kind == "balance" and payload.stage == "pick")
		or kind == "liarGuess" or kind == "nextVote"
	teethGrid.Visible = kind == "croc" or kind == "crocResult"
	title.Visible = quizLike or kind == "oneWord" or kind == "oneWordJudge" or kind == "vote" or kind == "talk" or bells
		or games or between or timing or quizKinds or twenty
	timer.Visible = quizLike or kind == "oneWord" or kind == "vote" or bells or kind == "croc"
		or kind == "nunchi" or kind == "balance" or kind == "redLight" or kind == "liar" or kind == "liarGuess"
		or kind == "nextVote" or kind == "brief" or kind == "timeGuess" or kind == "bottle" or kind == "estimate"
		or kind == "twenty"
	note.Visible = kind == "oneWord" or kind == "bellQuiz" or kind == "bomb" or kind == "nunchi" or kind == "nunchiResult"
		or between or timing or quizKinds or twenty
		or kind == "balance" or kind == "balanceResult" or kind == "redLight" or kind == "redLightResult" or kind == "liar"
	card.BackgroundColor3 = if kind == "redLight" then (if payload.light == "red" then RED_LIGHT else GREEN_LIGHT)
		else Style.PAPER
	-- (on the bright red / green card the small lines are dark too; on paper they keep their colours)
	timer.TextColor3 = if kind == "redLight" then Style.INK else Style.ACCENT_TEXT
	note.TextColor3 = if kind == "redLight" then Style.INK else Style.FAINT
	local slim = kind == "talk"
	card.BackgroundTransparency = Style.PAPER_ALPHA
	card.AnchorPoint = if slim then Vector2.new(0.5, 0) else Vector2.new(0.5, 1)
	state.slim = slim
	place()
	title.TextSize = if slim then 20 else 24
	title.Size = UDim2.new(1, 0, 0, if slim then 28 else 52)
	swapButton.Visible = false
	wheel.Visible = kind == "roulette" and #names > 2
	coin.Visible = kind == "roulette" and #names <= 2
	if quizLike then
		local rich = Hangul.richInitials(payload.question or "", INITIALS_SIZE)
		title.RichText = rich ~= nil
		title.TextScaled = rich == nil
		title.AutomaticSize = if rich then Enum.AutomaticSize.Y else Enum.AutomaticSize.None -- (a long one may wrap)
		titleLimit.MaxTextSize = if rich then INITIALS_SIZE else TITLE_SIZE
		title.Text = rich or payload.question
		local choices = payload.choices :: { string }
		for i, b in buttons do
			b.Visible = choices[i] ~= nil
			b.Text = choices[i] or ""
			local open = kind == "quiz" and canAnswer and payload.endsAt ~= nil and not state.myPick
			if kind == "quizResult" then
				local right = i == payload.answer
				b.AutoButtonColor = false
				b.BackgroundColor3 = if right then Style.RIGHT elseif i == state.myPick then Style.WRONG else Style.KEY_OFF
				b.TextColor3 = if right or i == state.myPick then Style.INK else Style.FAINT
			else
				paint(b, open, i == state.myPick)
			end
		end
	elseif kind == "nextVote" or kind == "nextPick" then
		title.Text = if kind == "nextVote" then TEXT.NEXT_VOTE else TEXT.PICKING
		note.Text = payload.recap or "" -- (what the last game did; nothing before the first)
		note.Visible = note.Text ~= ""
		local choices = if kind == "nextVote" then payload.choices or {} else {}
		local rules = if kind == "nextVote" then payload.rules or {} else {}
		for i, b in buttons do
			b.Visible = choices[i] ~= nil
			b.Text = choices[i] or ""
			paint(b, canAnswer and not state.myPick, i == state.myPick)
			local sub = b:FindFirstChild("Sub") :: TextLabel?
			if sub and rules[i] and rules[i] ~= "" then
				sub.Text = rules[i]
				sub.Visible = true
				b.TextYAlignment = Enum.TextYAlignment.Top
			end
		end
	elseif kind == "timeGuess" or kind == "timeGuessResult" then
		title.Text = string.format(TEXT.TIMEGUESS_TARGET, tonumber(payload.target) or 0)
		if kind == "timeGuess" then
			note.Text = string.format(TEXT.TIMEGUESS_HOW, tonumber(payload.visibleFor) or 0)
		else
			local seconds, losers, ids = payload.seconds or {}, payload.losers or {}, payload.ids or {}
			local parts = {}
			for i, name in names do
				local s = tonumber(seconds[i])
				local mark = if table.find(losers, ids[i]) then " 💥" else ""
				table.insert(parts, name .. " " .. (if s and s >= 0 then string.format("%.2f", s) else TEXT.TIMEGUESS_NONE) .. mark)
			end
			note.Text = table.concat(parts, " · ")
		end
	elseif kind == "duel" or kind == "duelResult" then
		-- (everyone in pair order a, b, a, b, ...; with `hasBye` the last one sits this one out)
		local ids = payload.ids or {}
		local fighters = if payload.hasBye then #ids - 1 else #ids
		local fire = kind == "duel" and payload.stage == "fire"
		title.Text = if kind == "duelResult" then TEXT.DUEL_TITLE elseif fire then TEXT.DUEL_FIRE else TEXT.DUEL_WAIT
		title.TextColor3 = if fire then Style.RED_TEXT else Style.INK
		local mine = table.find(ids, myId)
		if kind == "duel" and mine and mine > fighters then
			note.Text = TEXT.DUEL_BYE
		elseif kind == "duel" and mine then
			local other = if mine % 2 == 1 then mine + 1 else mine - 1
			note.Text = string.format(TEXT.DUEL_VS, names[other] or "?")
		else
			local ms, losers, parts = payload.ms or {}, payload.losers or {}, {}
			for i = 1, fighters - 1, 2 do
				if kind == "duel" then
					table.insert(parts, string.format(TEXT.DUEL_PAIR, names[i] or "?", names[i + 1] or "?"))
				else
					local sides = {}
					for _, j in { i, i + 1 } do
						local n = names[j] or "?"
						local value = tonumber(ms[j])
						local text = if value == nil then string.format(TEXT.DUEL_NEVER, n)
							elseif value < 0 then string.format(TEXT.DUEL_FALSE, n)
							else string.format(TEXT.DUEL_MS, n, value)
						table.insert(sides, text .. (if table.find(losers, ids[j]) then " 💥" else ""))
					end
					table.insert(parts, table.concat(sides, " · "))
				end
			end
			note.Text = table.concat(parts, "  |  ")
		end
	elseif kind == "bottle" or kind == "bottleThrow" or kind == "bottleResult" then
		title.Text = if kind == "bottleResult" then TEXT.BOTTLE_TITLE
			else string.format(TEXT.BOTTLE_THROW, tonumber(payload.throw) or 1, tonumber(payload.throws) or 3)
		local stood, landed, losers, ids = payload.stood or {}, payload.landed or {}, payload.losers or {}, payload.ids or {}
		local parts = {}
		for i, name in names do
			local mark = if kind == "bottleThrow" then (if landed[i] then " ✔" else " ✖")
				elseif table.find(losers, ids[i]) then " 💥" else ""
			table.insert(parts, string.format(TEXT.BOTTLE_STOOD, name, tonumber(stood[i]) or 0) .. mark)
		end
		note.Text = table.concat(parts, " · ")
		if kind == "bottle" then
			local width = tonumber(payload.width) or 0.3
			zone.Size = UDim2.fromScale(width, 1)
			zone.Position = UDim2.fromScale(tonumber(payload.center) or 0.5, 0)
		end
	elseif kind == "estimate" then
		title.Text = payload.question or ""
		if newQuestion then -- (a new number question: an empty box)
			answerBox.Text = ""
		end
		-- (only while the question is open to me: before that, after sending, or flying, the box and the button rest)
		local open = canAnswer and payload.id ~= nil and not state.myPick
		answerBox.TextEditable = open
		sendButton.AutoButtonColor = open
		sendButton.TextColor3 = if open then Style.INK else Style.FAINT
		sendButton.BackgroundColor3 = if open then Style.KEY else Style.KEY_OFF
		if not open then
			dropFocus()
		end
		note.Text = if state.myPick then string.format(TEXT.ESTIMATE_SENT, state.myPick) else TEXT.ESTIMATE_START
	elseif kind == "twenty" then
		local asker = names[payload.asker or 0] or "?"
		local info = string.format(TEXT.TWENTY_INFO, payload.topic or "", payload.round or 1, payload.rounds or 1,
			#(payload.right or {}), payload.need or 1)
		if newQuestion then -- (a new turn: an empty box)
			answerBox.Text = ""
			state.sentText = ""
		end
		if payload.stage == "intro" then
			title.Text = string.format(TEXT.TWENTY_INTRO, Config.TWENTY_TURN_SECONDS)
			note.Text = info .. "\n" .. TEXT.TWENTY_NO_LEAK
		elseif payload.stage == "ask" then
			title.Text = if myTurn then TEXT.TWENTY_MY_TURN else string.format(TEXT.TWENTY_TURN, asker)
			local line = if not myTurn then TEXT.TWENTY_NO_LEAK
				elseif state.myPick then string.format(TEXT.TWENTY_SENT, state.sentText)
				else TEXT.TWENTY_ONE_TRY
			note.Text = info .. "\n" .. line
			local open = myTurn and canAnswer and payload.id ~= nil and not state.myPick
			answerBox.TextEditable = open
			sendButton.AutoButtonColor = open
			sendButton.TextColor3 = if open then Style.INK else Style.FAINT
			sendButton.BackgroundColor3 = if open then Style.KEY else Style.KEY_OFF
			if not open then
				dropFocus()
			end
		else
			title.Text = if payload.verdict == "right" then string.format(TEXT.TWENTY_RIGHT, asker, payload.word or "")
				elseif payload.verdict == "wrong" then string.format(TEXT.TWENTY_WRONG, asker)
				else string.format(TEXT.TWENTY_TIMEOUT, asker)
			note.Text = info
		end
	elseif kind == "twentyResult" then
		title.Text = string.format(TEXT.TWENTY_RESULT_TITLE, payload.topic or "")
		local ids, right, losers = payload.ids or {}, payload.right or {}, payload.losers or {}
		local leaked = payload.leaked or {}
		local rightNames, flown = {}, {}
		for i, name in names do
			if table.find(right, ids[i]) then
				table.insert(rightNames, name)
			end
			if table.find(leaked, ids[i]) then
				table.insert(flown, string.format(TEXT.TWENTY_LEAKED, name) .. " 💥") -- (💥: who flew, as on every result)
			elseif table.find(losers, ids[i]) then
				table.insert(flown, name .. " 💥")
			end
		end
		local parts = {}
		if #rightNames > 0 then
			table.insert(parts, string.format(TEXT.TWENTY_RIGHT_LIST, table.concat(rightNames, ", ")))
		end
		if #flown > 0 then
			table.insert(parts, table.concat(flown, ", "))
		end
		local mine = if typeof(payload.myWord) == "string" then string.format(TEXT.TWENTY_MY_WORD, payload.myWord) .. "\n"
			else ""
		note.Text = mine .. table.concat(parts, " · ")
	elseif kind == "estimateResult" then
		title.Text = payload.question or ""
		local guesses, losers, ids, parts = payload.guesses or {}, payload.losers or {}, payload.ids or {}, {}
		for i, name in names do
			local value = tonumber(guesses[i]) or -1
			local mark = if table.find(losers, ids[i]) then " 💥" else ""
			table.insert(parts, (if value >= 1 then string.format(TEXT.ESTIMATE_GUESS, name, value)
				else string.format(TEXT.ESTIMATE_NONE, name)) .. mark)
		end
		note.Text = string.format(TEXT.ESTIMATE_RIGHT, tonumber(payload.answer) or 0) .. "  |  " .. table.concat(parts, " · ")
	elseif kind == "oxResult" then
		title.Text = TEXT.OX_TITLE
		local wrong, losers, ids, parts = payload.wrong or {}, payload.losers or {}, payload.ids or {}, {}
		for i, name in names do
			local mark = if table.find(losers, ids[i]) then " 💥" else ""
			table.insert(parts, string.format(TEXT.OX_WRONG, name, tonumber(wrong[i]) or 0) .. mark)
		end
		note.Text = table.concat(parts, " · ")
	elseif kind == "roundResult" then
		title.Text = payload.title or ""
		note.Text = table.concat(payload.lines or {}, "\n")
		note.Visible = note.Text ~= ""
	elseif kind == "brief" then
		-- (review 2026-10-25: the rule was a tiny line glued to the last game's recap, unreadable in 3 s; now the name, the
		-- rule in two big lines, and the recap on its own small line; the game count is on the status board)
		title.Text = payload.title or ""
		note.Text = payload.rule or ""
		note.TextColor3 = Style.INK
		noteLimit.MaxTextSize = 21
		subNote.Text = payload.recap or ""
		subNote.Visible = subNote.Text ~= ""
	elseif kind == "vote" then
		local liarVote = payload.prompt == "liar"
		title.Text = if liarVote then TEXT.LIAR_VOTE else TEXT.JUDGE_VOTE
		state.voteIds = payload.ids or {}
		local labels = table.clone(names)
		table.insert(labels, if liarVote then TEXT.LIAR_NONE else TEXT.VOTE_NONE)
		table.insert(labels, TEXT.VOTE_ABSTAIN)
		for i, b in buttons do
			b.Visible = labels[i] ~= nil
			b.Text = labels[i] or ""
			local mine = state.voteIds[i] == myId
			paint(b, canAnswer and not state.myPick and not mine, i == state.myPick)
		end
	elseif kind == "oneWord" then
		local current = payload.current or 1
		title.Text = string.format(TEXT.ONE_WORD_TURN, names[current] or "?", payload.topic or "")
		note.Text = if payload.phase == "prep" then TEXT.ONE_WORD_PREP elseif payload.chat then TEXT.ONE_WORD_BY_CHAT else ""
		local ids = payload.ids or {}
		swapButton.Visible = payload.phase == "prep" and not payload.swapped and payload.id ~= nil and ids[current] == myId
	elseif kind == "oneWordJudge" then
		title.Text = TEXT.JUDGE_WAIT
	elseif kind == "croc" or kind == "crocResult" then
		local ids = payload.ids or {}
		state.down = payload.down or {}
		state.myTurn = kind == "croc" and canAnswer and ids[payload.current or 0] == myId
		title.Text = if kind == "croc" then string.format(TEXT.CROC_TURN, names[payload.current or 0] or "?")
			else string.format(if payload.late then TEXT.CROC_LATE else TEXT.CROC_BITE, names[payload.loser or 0] or "?")
		for i, tooth in drawnTeeth do
			local bitten = kind == "crocResult" and i == payload.bad
			local shut = state.down[i] == true
			tooth.Text = if bitten then "!" else ""
			tooth.BackgroundColor3 = if bitten then Style.WRONG elseif shut then Style.KEY_OFF else TOOTH_WHITE
			-- (a pressed tooth sinks into the jaw: shorter, its base where it was)
			local height = if shut and not bitten then TOOTH_H * 0.45 else TOOTH_H
			local sink = -toothInward[i] * (TOOTH_H - height) / 2 / reachSize
			tooth.Size = UDim2.fromScale(TOOTH_W / reachSize, height / reachSize)
			tooth.Position = UDim2.fromScale(0.5 + sink.X, 0.5 + sink.Y)
			teeth[i].Active = state.myTurn and not shut
		end
	elseif kind == "bomb" then
		local ids = payload.ids or {}
		local holding = ids[payload.holder or 0] == myId
		state.canAnswer = canAnswer and holding and payload.id ~= nil -- (lit only once the server opens the pass)
		title.Text = if holding then TEXT.BOMB_MINE else string.format(TEXT.BOMB_HOLDER, names[payload.holder or 0] or "?")
		local ring = {} -- the passing order, the holder marked
		for i, name in names do
			table.insert(ring, if i == payload.holder then string.format(TEXT.BOMB_HOLDER, name) else name)
		end
		note.Text = table.concat(ring, " → ")
		local choices = payload.choices or {}
		for i, b in buttons do
			b.Visible = choices[i] ~= nil
			b.Text = choices[i] or ""
			paint(b, state.canAnswer and not state.myPick, i == state.myPick)
		end
		buttonIcon(buttons[1], Config.IMAGES.BOMB)
	elseif kind == "bombResult" then
		title.Text = string.format(TEXT.BOMB_BOOM, names[payload.holder or 0] or "?")
	elseif kind == "nunchi" then
		title.Text = TEXT.NUNCHI_START
		if payload.endsAt ~= state.nunchiEndsAt then -- (a new game; the same one shown again keeps its count)
			state.nunchiEndsAt = payload.endsAt
			state.rings = 0
		end
		note.Text = string.format(TEXT.NUNCHI_NEXT, state.rings + 1)
	elseif kind == "nunchiResult" then
		title.Text = TEXT.NUNCHI_TITLE
		local losers = payload.losers or {}
		local ids = payload.ids or {}
		local order = {}
		for i, name in names do
			local mark = if table.find(losers, ids[i]) then "💥" else ""
			table.insert(order, if i <= (payload.rang or 0) then string.format(TEXT.NUNCHI_ORDER, i, name .. mark)
				else string.format(TEXT.NUNCHI_NONE, name .. mark))
		end
		note.Text = table.concat(order, " · ")
	elseif kind == "balance" or kind == "balanceResult" then
		title.Text = string.format(TEXT.BALANCE_VS, payload.a or "", payload.b or "")
		if kind == "balanceResult" then
			note.Text = string.format(TEXT.BALANCE_COUNT, payload.a or "", payload.countA or 0, payload.b or "", payload.countB or 0)
		elseif payload.stage == "bell" then
			note.Text = TEXT.BALANCE_BELL
		elseif payload.stage == "talk" then
			note.Text = string.format(TEXT.BALANCE_TALK, names[1] or "?")
		else
			note.Text = TEXT.BALANCE_PICK
			local choices = payload.choices or {}
			for i, b in buttons do
				b.Visible = choices[i] ~= nil
				b.Text = choices[i] or ""
				paint(b, canAnswer, i == state.myPick)
			end
		end
	elseif kind == "redLight" or kind == "redLightResult" then
		title.Text = if kind == "redLightResult" then TEXT.REDLIGHT_TITLE
			elseif payload.light == "red" then TEXT.REDLIGHT_RED else TEXT.REDLIGHT_GREEN
		local mine = table.find(payload.ids or {}, myId)
		local steps = if mine then (payload.steps or {})[mine] or 0 else 0
		note.Text = if not mine then ""
			elseif table.find(payload.caught or {}, myId) then TEXT.REDLIGHT_YOU_CAUGHT
			elseif steps >= (payload.goal or math.huge) then TEXT.REDLIGHT_YOU_SAFE
			else string.format(TEXT.REDLIGHT_STEPS, steps, payload.goal or 0)
	elseif kind == "liar" then
		title.Text = if payload.liar then string.format(TEXT.LIAR_YOU, payload.category or "")
			elseif payload.word then string.format(TEXT.LIAR_WORD, payload.word)
			else string.format(TEXT.LIAR_CATEGORY, payload.category or "")
		note.Text = if payload.stage == "clue" then string.format(TEXT.LIAR_CLUE, names[1] or "?")
			elseif payload.stage == "accuse" then TEXT.LIAR_ACCUSE
			else string.format(TEXT.LIAR_CATEGORY, payload.category or "")
	elseif kind == "liarGuess" then
		title.Text = TEXT.LIAR_GUESS
		local ids = payload.ids or {}
		state.canAnswer = canAnswer and ids[1] == myId
		local choices = payload.choices or {}
		for i, b in buttons do
			b.Visible = choices[i] ~= nil
			b.Text = choices[i] or ""
			paint(b, state.canAnswer and not state.myPick, i == state.myPick)
		end
	elseif kind == "liarResult" then
		title.Text = string.format(if payload.caught then TEXT.LIAR_CAUGHT else TEXT.LIAR_ESCAPED, names[1] or "?",
			payload.word or "")
	elseif kind == "oneWordBell" then
		title.Text = TEXT.ONE_WORD_BELL
	elseif kind == "bellQuiz" then
		title.Text = payload.question or ""
		note.Text = if payload.stage == "answer" then string.format(TEXT.BELL_QUIZ_ANSWERING, names[1] or "?")
			else TEXT.BELL_QUIZ_WAIT
	elseif kind == "talk" then
		state.topicLine = (if payload.stage == "prep" then TEXT.TALK_SOON .. " · " else "")
			.. string.format(TEXT.TALK_TOPIC, payload.topic or "")
		title.Text = state.topicLine
	elseif kind == "roulette" then
		title.Text = ""
		state.names = names
		state.pick = payload.pick
		state.startsAt = payload.startsAt or workspace:GetServerTimeNow()
		state.spinSeconds = payload.spinSeconds or 1
		if #names > 2 then
			setRing(names)
		end
	end
	local shownButtons, longest = 0, 0
	for _, b in buttons do
		if b.Visible then
			shownButtons += 1
			longest = math.max(longest, utf8.len(b.Text) or #b.Text)
		end
	end
	-- (four short answers: one row, so the card stays low; a big vote: three smaller columns, so twelve still fit a
	-- phone)
	answerLayout.CellSize = if kind == "nextVote" then UDim2.new(1 / math.max(shownButtons, 1), -6, 0, 66) -- (each
		-- game's name and its rule)
		elseif shownButtons > 6 then UDim2.new(1 / 3, -6, 0, 40)
		elseif shownButtons == 4 and longest <= 7 then UDim2.new(0.25, -6, 0, 44)
		elseif shownButtons == 3 then UDim2.new(1 / 3, -6, 0, 44)
		else UDim2.new(0.5, -4, 0, 44)
	MissionPanel.tick(workspace:GetServerTimeNow())
end

-- I rang my bell at `now` (server time): 물병 세우기's marker stops there on my screen.
function MissionPanel.rang(now: number)
	if state.kind == "bottle" and state.timing.stoppedAt == 0 and now >= state.timing.barStartAt then
		state.timing.stoppedAt = now
	end
end

-- A seat bell rang (nunchi counts them: the next number on the card).
function MissionPanel.bellRang()
	if state.kind == "nunchi" then
		state.rings += 1
		note.Text = string.format(TEXT.NUNCHI_NEXT, state.rings + 1)
	end
end

-- Every frame (server time): the quiz countdown, the spinning pointer or the flipping coin, and the card's size.
-- Steps the card aside (a launch flying, owner 2026-10-24) without forgetting what it shows or what I picked.
function MissionPanel.setHidden(hidden: boolean)
	state.hidden = hidden
	card.Visible = state.shown and not hidden
	if hidden then
		dropFocus()
	end
end

function MissionPanel.tick(now: number)
	if card.Visible then
		place()
		-- Keep the card within 80% of the screen height and 90% of its width (a big wheel on a small phone screen), and
		-- a card standing on the bottom row below the status board (the crocodile's jaws on a low phone screen).
		local camera = workspace.CurrentCamera
		local scale = math.max(cardScale.Scale, 0.01)
		local height = card.AbsoluteSize.Y / scale
		local width = math.max(card.AbsoluteSize.X, if wheel.Visible then wheel.AbsoluteSize.X + 28 else 0) / scale
		if camera and height > 0 and width > 0 then
			local view = camera.ViewportSize
			local room = view.Y * 0.8
			if not state.slim then
				room = math.min(room, card.AbsolutePosition.Y + card.AbsoluteSize.Y - Style.row(0))
			end
			cardScale.Scale = math.clamp(math.min(1, room / height, view.X * 0.9 / width), 0.3, 1)
		end
	end
	if state.kind == "talk" then
		timer.Text = ""
		title.Text = string.format("%s · %d", state.topicLine, math.max(0, math.ceil(state.endsAt - now)))
	elseif state.kind == "timeGuess" then
		-- (3, 2, 1 before the start; then the clock for a few seconds; then only "?")
		local t = now - state.timing.startAt
		timer.Text = if t < 0 then tostring(math.ceil(-t)) elseif t < state.timing.visibleFor then string.format("%.2f", t)
			else "?"
	elseif state.kind == "bottle" then
		local at = if state.timing.stoppedAt > 0 then state.timing.stoppedAt else now
		marker.Position = UDim2.fromScale(PowerBar.at(at - state.timing.barStartAt, state.timing.period), 0.5)
		timer.Text = if state.endsAt > 0 then tostring(math.max(0, math.ceil(state.endsAt - now))) else ""
	elseif state.kind == "quiz" or state.kind == "vote" or state.kind == "oneWord" or state.kind == "oneWordBell"
		or state.kind == "bellQuiz" or state.kind == "croc" or state.kind == "bomb" or state.kind == "nunchi"
		or state.kind == "balance" or state.kind == "redLight" or state.kind == "liar" or state.kind == "liarGuess"
		or state.kind == "nextVote" or state.kind == "brief" or state.kind == "estimate" or state.kind == "twenty" then
		timer.Text = if state.endsAt > 0 then tostring(math.max(0, math.ceil(state.endsAt - now))) else ""
	elseif state.kind == "roulette" then
		timer.Text = ""
		local t = math.clamp((now - state.startsAt) / state.spinSeconds, 0, 1)
		local count = #state.names
		if count > 2 then
			local target = SPIN_TURNS * 360 + (state.pick - 1) / count * 360
			local angle = target * easeOut(t)
			pointer.Rotation = angle
			local nearest = math.round((angle % 360) / 360 * count) % count + 1
			for i, pill in ringPills do
				local lit = i == nearest
				pill.BackgroundColor3 = if lit then Style.PICK else SLICE_COLORS[(i - 1) % 2 + 1]
				local label = pill:FindFirstChildOfClass("TextLabel")
				if label then
					label.TextColor3 = Style.INK
				end
			end
		elseif count > 0 then
			-- The coin flips (its width follows the turn), showing each name in turn, slower and slower, and lands on
			-- the pick.
			local phase = easeOut(t) * (SPIN_TURNS * 4 + 1) * math.pi
			local flips = math.floor(phase / math.pi + 0.5)
			local shown = if t >= 1 then state.pick else ((state.pick - 1 + flips + 1) % count) + 1
			coin.Text = state.names[shown]
			coin.Size = UDim2.fromOffset(if t >= 1 then COIN_SIZE else math.max(8, COIN_SIZE * math.abs(math.cos(phase))), COIN_SIZE)
		end
	else
		timer.Text = ""
	end
end

return MissionPanel
