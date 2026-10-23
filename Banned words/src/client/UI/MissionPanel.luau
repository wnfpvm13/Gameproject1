--!strict
-- The mission card in the middle of the screen (docs/DESIGN_V3.md §5; bundle 4a):
--   - quiz: the question, four answer buttons (only for players who may answer) and the seconds left; afterwards the
--     right answer turns green and my wrong pick red;
--   - roulette (owner 2026-10-23: a 2D wheel): the names on a ring and a pointer that spins and slows down onto the
--     name the server picked; with two players a coin flips between the two names instead.
-- It only shows what it is told and reports the button pressed; the server checks every answer.
local Style = require(script.Parent:WaitForChild("Style"))

local MissionPanel = {}

local TWO_PI = 2 * math.pi
local RING_RADIUS = 112 -- pixels from the wheel centre to the names (up to RING_FULL names; more push it out)
local RING_FULL = 6
local PILL_WIDTH = 104
local SPIN_TURNS = 4 -- whole turns before the pointer stops
local COIN_SIZE = 170
local SLICE_COLORS = { Color3.fromRGB(40, 92, 170), Color3.fromRGB(62, 66, 92) } -- name pills, alternating

local card: Frame
local cardScale: UIScale
local title: TextLabel
local timer: TextLabel
local answerGrid: Frame
local buttons: { TextButton } = {}
local wheel: Frame
local pointer: Frame
local disc: Frame
local needle: Frame
local arrow: TextLabel
local coin: TextLabel
local ringPills: { Frame } = {}
local onAnswer: (number, number) -> () = function(_id, _choice) end

local state = {
	kind = "none",
	endsAt = 0,
	canAnswer = false,
	question = "",
	id = 0, -- the open question's number (sent back with the answer)
	myPick = nil :: number?,
	-- roulette
	names = {} :: { string },
	pick = 1,
	startsAt = 0,
	spinSeconds = 1,
}

local function answerButton(index: number): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Style.PANEL
	b.BackgroundTransparency = 0.1
	b.FontFace = Style.BOLD
	b.TextScaled = true
	b.TextColor3 = Style.WHITE
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 22
	size.Parent = b
	b.LayoutOrder = index
	b.Activated:Connect(function()
		local open = state.endsAt > 0 and workspace:GetServerTimeNow() < state.endsAt -- (not while the question shows first)
		if state.kind == "quiz" and state.canAnswer and open and not state.myPick then
			state.myPick = index
			onAnswer(state.id, index)
			for i, other in buttons do
				other.BackgroundColor3 = if i == index then Style.AMBER else Style.PANEL
				other.TextColor3 = if i == index then Style.PANEL else Style.WHITE
			end
		end
	end)
	b.Parent = answerGrid
	return b
end

-- onPick(questionId, choice): I pressed an answer button.
function MissionPanel.build(onPick: (number, number) -> ())
	onAnswer = onPick
	card = Style.panel(Style.gui(), Style.PANEL, 0.2, 16)
	card.Name = "MissionCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.56) -- a little low: the status board sits above
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

	timer = Style.label(card, Style.BOLD, 20, Style.AMBER)
	timer.Size = UDim2.new(1, 0, 0, 22)
	timer.LayoutOrder = 0
	title = Style.label(card, Style.BOLD, 26, Style.WHITE)
	title.Size = UDim2.new(1, 0, 0, 64)
	title.LayoutOrder = 1

	answerGrid = Instance.new("Frame")
	answerGrid.BackgroundTransparency = 1
	answerGrid.Size = UDim2.new(1, 0, 0, 2 * 52 + 8)
	answerGrid.LayoutOrder = 2
	answerGrid.Parent = card
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -4, 0, 52)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = answerGrid
	for i = 1, 4 do
		buttons[i] = answerButton(i)
	end

	-- The wheel: a round disc with an amber rim, the names as pills on a ring, a needle from the hub.
	wheel = Instance.new("Frame")
	wheel.BackgroundTransparency = 1
	wheel.Size = UDim2.fromOffset(2 * RING_RADIUS + 120, 2 * RING_RADIUS + 50)
	wheel.LayoutOrder = 3
	wheel.Parent = card
	disc = Style.panel(wheel, Color3.fromRGB(26, 32, 46), 0, 1000)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromOffset(2 * RING_RADIUS + 44, 2 * RING_RADIUS + 44)
	local rim = Instance.new("UIStroke")
	rim.Color = Style.AMBER
	rim.Thickness = 4
	rim.Parent = disc
	pointer = Instance.new("Frame")
	pointer.BackgroundTransparency = 1
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.fromScale(0.5, 0.5)
	pointer.Size = UDim2.fromOffset(2 * RING_RADIUS, 2 * RING_RADIUS)
	pointer.ZIndex = 3
	pointer.Parent = wheel
	needle = Style.panel(pointer, Style.AMBER, 0, 3)
	needle.AnchorPoint = Vector2.new(0.5, 1)
	needle.Position = UDim2.fromScale(0.5, 0.5)
	needle.Size = UDim2.fromOffset(6, RING_RADIUS - 40)
	needle.ZIndex = 3
	arrow = Style.label(pointer, Style.BOLD, 30, Style.AMBER)
	arrow.Text = "▲"
	arrow.AnchorPoint = Vector2.new(0.5, 1)
	arrow.Position = UDim2.new(0.5, 0, 0.5, -(RING_RADIUS - 40) + 6)
	arrow.Size = UDim2.fromOffset(30, 26)
	arrow.ZIndex = 3
	local hub = Style.panel(wheel, Style.AMBER, 0, 100)
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(26, 26)
	hub.ZIndex = 4

	coin = Style.label(card, Style.BOLD, 30, Style.PANEL)
	coin.BackgroundColor3 = Style.AMBER
	coin.BackgroundTransparency = 0
	coin.Size = UDim2.fromOffset(COIN_SIZE, COIN_SIZE)
	coin.LayoutOrder = 4
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = coin
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
		local label = Style.label(pill, Style.BOLD, 18, Style.WHITE)
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

-- What the server says the mission shows now. `canAnswer`: I am alive and on the ground (my buttons work);
-- `names`: the roulette's names in the server's order.
function MissionPanel.show(payload: { [string]: any }, canAnswer: boolean, names: { string })
	local kind = payload.kind
	local quizLike = kind == "quiz" or kind == "quizResult"
	if not quizLike or payload.question ~= state.question then
		state.myPick = nil -- a new question (it comes twice: before and once the buttons work) or no quiz
	end
	state.question = if quizLike then payload.question else ""
	state.id = payload.id or 0
	state.kind = kind
	state.endsAt = payload.endsAt or 0
	state.canAnswer = canAnswer
	card.Visible = kind == "quiz" or kind == "quizResult" or kind == "roulette"
	answerGrid.Visible = quizLike
	title.Visible = quizLike
	timer.Visible = quizLike
	wheel.Visible = kind == "roulette" and #names > 2
	coin.Visible = kind == "roulette" and #names <= 2
	if kind == "quiz" or kind == "quizResult" then
		title.Text = payload.question
		local choices = payload.choices :: { string }
		for i, b in buttons do
			b.Visible = choices[i] ~= nil
			b.Text = choices[i] or ""
			local open = kind == "quiz" and canAnswer and payload.endsAt ~= nil and not state.myPick
			b.AutoButtonColor = open
			if kind == "quizResult" then
				local right = i == payload.answer
				b.BackgroundColor3 = if right then Style.GREEN elseif i == state.myPick then Style.RED else Style.PANEL
				b.TextColor3 = if right or i == state.myPick then Style.PANEL else Style.GREY
			elseif i ~= state.myPick then
				b.BackgroundColor3 = Style.PANEL
				b.TextColor3 = if open then Style.WHITE else Style.GREY
			end
		end
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
	MissionPanel.tick(workspace:GetServerTimeNow())
end

-- Every frame (server time): the quiz countdown, the spinning pointer or the flipping coin, and the card's size.
function MissionPanel.tick(now: number)
	if card.Visible then
		-- Keep the card within 80% of the screen height and 90% of its width (a big wheel on a small phone screen).
		local camera = workspace.CurrentCamera
		local scale = math.max(cardScale.Scale, 0.01)
		local height = card.AbsoluteSize.Y / scale
		local width = math.max(card.AbsoluteSize.X, if wheel.Visible then wheel.AbsoluteSize.X + 28 else 0) / scale
		if camera and height > 0 and width > 0 then
			local view = camera.ViewportSize
			cardScale.Scale = math.min(1, view.Y * 0.8 / height, view.X * 0.9 / width)
		end
	end
	if state.kind == "quiz" then
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
				pill.BackgroundColor3 = if lit then Style.AMBER else SLICE_COLORS[(i - 1) % 2 + 1]
				local label = pill:FindFirstChildOfClass("TextLabel")
				if label then
					label.TextColor3 = if lit then Style.PANEL else Style.WHITE
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
