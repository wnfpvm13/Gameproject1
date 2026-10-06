--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local Presentation = require(ReplicatedStorage:WaitForChild("Shared").Utilities.PartyPresentation)
local Geometry = require(ReplicatedStorage:WaitForChild("Shared").Utilities.PartyHUDGeometry)
local Style = require(ReplicatedStorage:WaitForChild("Shared").Config.PartyUIStyle)
local ButtonStyle = require(script.Parent.PartyButtonStyle)
local Theme = Style.Theme

local PartyHUD = {}
PartyHUD.__index = PartyHUD
local function surface(item: GuiObject, name: string)
	local value = Theme.Surface[name]
	item.BackgroundColor3 = ButtonStyle.color(value.Color)
	item.BackgroundTransparency = value.Transparency
end
local ACTIVITY = { Free = "자유", SharedHunt = "공용 사냥", Expedition = "원정", Restaurant = "식당" }
local STATUS = { Forming = "모집 중", ReadyCheck = "이동 응답 중", InActivity = "활동 중", Closed = "종료" }
-- The public API exposes PlayerList enablement, but not its panel bounds.
-- Reserve the default single-column list conservatively. MonCook creates no
-- leaderstats columns; revisit these reservations if those columns are added.
-- Actual Studio/CoreUI variants still require visual verification. Narrow
-- screens use an accessible compact fallback instead of a full-screen estimate.

local function coreEnabled(kind: Enum.CoreGuiType): boolean
	local ok, enabled = pcall(function() return StarterGui:GetCoreGuiEnabled(kind) end)
	return not ok or enabled
end

local function chatBounds(gui: ScreenGui): { any }
	if not coreEnabled(Enum.CoreGuiType.Chat) then return {} end
	local bounds = {}
	for _, name in { "ChatWindowConfiguration", "ChatInputBarConfiguration" } do
		local config = TextChatService:FindFirstChild(name)
		if config then
			-- Both public configurations report their own screen rectangle. Convert
			-- it to this ScreenGui's safe-area coordinates; neither owns the other.
			local ok, position, size, enabled = pcall(function()
				return (config :: any).AbsolutePosition, (config :: any).AbsoluteSize, (config :: any).Enabled
			end)
			if ok and enabled and size.X > 0 and size.Y > 0 then
				local origin = position - gui.AbsolutePosition
				table.insert(bounds, { Left = origin.X, Top = origin.Y, Right = origin.X + size.X, Bottom = origin.Y + size.Y })
			end
		end
	end
	-- Older engines/initial chat layout may lack the public rectangle API.
	if #bounds == 0 then
		table.insert(bounds, { Left = 0, Right = math.min(400, gui.AbsoluteSize.X * 0.5), Bottom = math.min(240, gui.AbsoluteSize.Y * 0.5) })
	end
	return bounds
end

local function round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, radius), parent
end

local function label(parent: Instance, text: string, height: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Size, item.BackgroundTransparency, item.Text = UDim2.new(1, 0, 0, height), 1, text
	item.Font, item.TextSize, item.TextColor3 = Enum.Font.Gotham, 13, ButtonStyle.color(Theme.Text.Primary)
	item.TextWrapped, item.TextXAlignment, item.Parent = true, Enum.TextXAlignment.Left, parent
	return item
end

function PartyHUD.new(playerGui: PlayerGui, send: (string, any?) -> ())
	local self: any = setmetatable({ State = nil, Send = send, Expanded = false, Section = "main", Pending = false,
		ChosenVisibility = "Public", ChosenTarget = nil, Status = "", Buttons = {}, Rows = {}, PositionPreference = nil }, PartyHUD)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "MonCookPartyHUD", false, false, 5
	pcall(function() gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
	local panel = Instance.new("Frame")
	panel.Name, panel.AnchorPoint = "CompactParty", Vector2.new(0, 0)
	panel.BorderSizePixel, panel.ClipsDescendants, panel.Parent = 0, true, gui
	surface(panel, "Panel")
	round(panel, 10)
	-- This handle owns drag input. Action buttons never initiate a drag.
	local handle = Instance.new("TextButton")
	handle.Name, handle.Position, handle.Size = "DragHandle", UDim2.fromOffset(0, 0), UDim2.new(1, -44, 0, 44)
	handle.Text, handle.Font, handle.TextSize = "⠿", Enum.Font.GothamBold, 13
	handle.TextTruncate, handle.BorderSizePixel, handle.Parent = Enum.TextTruncate.AtEnd, 0, panel
	ButtonStyle.bind(handle, true, "Subtle")
	handle.Selectable = false
	round(handle, 8)
	local expand = Instance.new("TextButton")
	expand.Name, expand.Text, expand.Font, expand.TextSize = "Expand", "＋", Enum.Font.GothamBold, 22
	expand.AnchorPoint, expand.Position, expand.Size = Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), UDim2.fromOffset(44, 44)
	expand.BorderSizePixel, expand.Parent = 0, panel
	expand:SetAttribute("FocusKey", "Expand")
	ButtonStyle.bind(expand, true, "Subtle")
	round(expand, 8)
	expand.Activated:Connect(function() self:Toggle() end)
	local portraits = Instance.new("ScrollingFrame")
	portraits.Name, portraits.Position = "VerticalMembers", UDim2.fromOffset(6, 48)
	portraits.BackgroundTransparency, portraits.BorderSizePixel, portraits.ScrollBarThickness = 1, 0, 3
	portraits.ScrollingDirection, portraits.AutomaticCanvasSize = Enum.ScrollingDirection.Y, Enum.AutomaticSize.Y
	portraits.CanvasSize, portraits.Parent = UDim2.fromOffset(0, 0), panel
	portraits.ScrollBarImageColor3 = ButtonStyle.color(Theme.Scrollbar)
	local body = Instance.new("ScrollingFrame")
	body.Name, body.Position = "Expanded", UDim2.fromOffset(8, 46)
	body.BackgroundTransparency, body.BorderSizePixel, body.ScrollBarThickness = 1, 0, 4
	body.ScrollBarImageColor3 = ButtonStyle.color(Theme.Scrollbar)
	body.CanvasSize, body.AutomaticCanvasSize, body.ScrollingDirection, body.Visible = UDim2.fromOffset(0, 0), Enum.AutomaticSize.Y, Enum.ScrollingDirection.Y, false
	body.Parent = panel
	gui.Parent = playerGui
	self.Gui, self.Panel, self.Heading, self.Expand, self.Portraits, self.Body = gui, panel, handle, expand, portraits, body
	handle.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and panel.Visible then
			self.Drag = { Input = input, Start = Vector2.new(input.Position.X, input.Position.Y),
				Origin = panel.AbsolutePosition - gui.AbsolutePosition }
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local drag = self.Drag
		if not drag then return end
		local mouse = drag.Input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
		if input == drag.Input or mouse then
			local desired = drag.Origin + Vector2.new(input.Position.X, input.Position.Y) - drag.Start
			local request = self:LayoutInput()
			self.PositionPreference = Geometry.normalize(request, self.Panel.AbsoluteSize.X, self.Panel.AbsoluteSize.Y, desired.X, desired.Y)
			self.ManualPlacement = true
			self:Resize()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if self.Drag and input == self.Drag.Input then self.Drag = nil end
	end)
	UserInputService.WindowFocusReleased:Connect(function() self.Drag = nil end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self.Drag = nil; self:Resize() end)
	gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		self.Drag, self.ManualPlacement = nil, false
		self:Resize()
	end)
	Players.PlayerAdded:Connect(function() self:Resize() end)
	Players.PlayerRemoving:Connect(function() task.defer(function() self:Resize() end) end)
	for _, property in { "TopbarInset", "MenuIsOpen" } do
		pcall(function() GuiService:GetPropertyChangedSignal(property):Connect(function() self:Resize() end) end)
	end
	for _, name in { "ChatWindowConfiguration", "ChatInputBarConfiguration" } do
		local config = TextChatService:FindFirstChild(name)
		if config then
			for _, property in { "AbsoluteSize", "AbsolutePosition", "Enabled" } do
				pcall(function() config:GetPropertyChangedSignal(property):Connect(function() self:Resize() end) end)
			end
		end
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed >= 0.5 then elapsed = 0; self:Resize() end
	end)
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		if string.find(inputType.Name, "Gamepad", 1, true) and not GuiService.SelectedObject then GuiService.SelectedObject = expand end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.P and not UserInputService:GetFocusedTextBox() then
			self:Toggle()
			if not GuiService.SelectedObject then GuiService.SelectedObject = expand end
		end
	end)
	if string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) and not GuiService.SelectedObject then GuiService.SelectedObject = expand end
	self:Resize()
	return self
end

function PartyHUD:LayoutInput(): any
	local available = self.Gui.AbsoluteSize
	local topbarBottom = 0
	pcall(function() topbarBottom = GuiService.TopbarInset.Max.Y - self.Gui.AbsolutePosition.Y end)
	return {
		Width = available.X, Height = available.Y, TopbarBottom = topbarBottom,
		PlayerListEnabled = coreEnabled(Enum.CoreGuiType.PlayerList), PlayerCount = #Players:GetPlayers(),
		ChatBounds = chatBounds(self.Gui), Expanded = self.Expanded, MemberCount = #self.Rows,
		Position = self.PositionPreference,
	}
end

function PartyHUD:Resize()
	local request = self:LayoutInput()
	if Geometry.viewportChanged(self.LayoutViewport, request) then
		self.Drag, self.ManualPlacement = nil, false
	end
	self.LayoutViewport = request
	local metrics = Geometry.measure(request)
	-- Keep existing responsive sizing; only the placement policy changes.
	-- Polls, snapshots and release preserve the manual choice until a resize.
	if self.ManualPlacement then
		local dragged = Geometry.dragPlacement(request, metrics.Width, metrics.Height, self.PositionPreference)
		metrics.Left, metrics.Top, metrics.Position, metrics.Policy = dragged.Left, dragged.Top, dragged.Position, dragged.Policy
	end
	local widthChanged = self.Metrics and self.Metrics.Width ~= metrics.Width
	self.Metrics = metrics
	self.DisplayExpanded = metrics.EffectiveExpanded
	self.Panel.Position, self.Panel.Size = UDim2.fromOffset(metrics.Left, metrics.Top), UDim2.fromOffset(metrics.Width, metrics.Height)
	self.Panel:SetAttribute("LayoutPolicy", metrics.Policy)
	self.Panel:SetAttribute("PreferredX", if self.PositionPreference then self.PositionPreference.X else nil)
	self.Panel:SetAttribute("PreferredY", if self.PositionPreference then self.PositionPreference.Y else nil)
	self.Portraits.Size = UDim2.new(1, -12, 0, metrics.PortraitHeight)
	self.Portraits.Visible = not self.DisplayExpanded
	self.Body.Position, self.Body.Size = UDim2.fromOffset(8, metrics.Header + 2), UDim2.new(1, -16, 0, metrics.BodyHeight)
	self.Body.Visible, self.Expand.Text = self.DisplayExpanded, if self.DisplayExpanded then "−" else "＋"
	self.Heading.Text = if self.DisplayExpanded then "⠿ " .. (self.Title or "파티") else "⠿"
	if self.PortraitNamesVisible ~= metrics.NamesVisible then self.PortraitNamesVisible = metrics.NamesVisible; self:RenderPortraits(self.Rows) end
	pcall(function()
		self.Panel.Visible = not GuiService.MenuIsOpen
		if not self.Panel.Visible then self.Drag = nil end
	end)
	if widthChanged and self.State and not self.Rendering then self:Render(self.State) end
end

function PartyHUD:Toggle()
	self.Expanded = not (self.DisplayExpanded == true)
	self:Resize()
	if self.State then self:Render(self.State) end
end

function PartyHUD:SetPending(value: boolean)
	self.Pending = value
	if self.State then self:Render(self.State) end
end

function PartyHUD:SetStatus(message: string)
	self.Status = message
	if message ~= "" then self.Expanded = true; self:Resize() end
	if self.State then self:Render(self.State) end
end

function PartyHUD:Button(parent: Instance, text: string, key: string, enabled: boolean, action: () -> (), localAction: boolean?): TextButton
	local button = Instance.new("TextButton")
	local active = enabled and (localAction == true or (not self.Pending and self.State and self.State.Ready and not self.State.Traveling))
	button.Size, button.Text, button.Font, button.TextSize = UDim2.new(1, 0, 0, 44), text, Enum.Font.GothamMedium, 13
	button.BorderSizePixel, button.TextWrapped = 0, true
	ButtonStyle.bind(button, active == true, "Accent")
	button:SetAttribute("FocusKey", key)
	button.Parent = parent
	round(button, 6)
	button.Activated:Connect(function() if active then action() end end)
	self.Buttons[key] = button
	return button
end

function PartyHUD:Row(choices: { any })
	local frame = Instance.new("Frame")
	local width = math.max(0, (self.Metrics and self.Metrics.Width or 300) - 16)
	local metrics = Geometry.actionRow(width, #choices)
	frame.Size, frame.BackgroundTransparency, frame.Parent = UDim2.new(1, 0, 0, metrics.Height), 1, self.Body
	for index, choice in choices do
		local button = self:Button(frame, choice.Text, choice.Key, choice.Enabled ~= false, choice.Action, choice.Local)
		if metrics.Stacked then
			button.Size, button.Position = UDim2.new(1, 0, 0, metrics.ButtonHeight), UDim2.fromOffset(0, (index - 1) * (metrics.ButtonHeight + metrics.Gap))
		else
			button.Size, button.Position = UDim2.new(1 / #choices, -3, 1, 0), UDim2.new((index - 1) / #choices, if index == 1 then 0 else 3, 0, 0)
		end
	end
end

local function portrait(parent: Instance, member: any, left: number, top: number)
	local image = Instance.new("ImageLabel")
	image.Name, image.Position, image.Size = "Face", UDim2.fromOffset(left, top), UDim2.fromOffset(32, 32)
	image.BorderSizePixel, image.Parent = 0, parent
	surface(image, "Portrait")
	if member.UserId > 0 then image.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(member.UserId) .. "&w=48&h=48" end
	round(image, 16)
	if member.IsLeader then
		local crown = label(image, "♛", 14)
		crown.Position, crown.Size, crown.TextColor3 = UDim2.fromOffset(-2, -3), UDim2.fromOffset(14, 14), ButtonStyle.color(Theme.Text.Accent)
		surface(crown, "Badge")
		round(crown, 5)
	end
	if member.Ready ~= "Idle" then
		local indicator = label(image, if member.Ready == "Joined" then "✓" elseif member.Ready == "Stayed" then "—" else "…", 14)
		indicator.Position, indicator.Size = UDim2.fromOffset(23, 21), UDim2.fromOffset(14, 14)
		indicator.TextColor3 = ButtonStyle.color(if member.Ready == "Joined" then Theme.Text.Ready elseif member.Ready == "Stayed" then Theme.Text.Stayed else Theme.Text.Waiting)
		surface(indicator, "Badge")
		round(indicator, 5)
	end
end

function PartyHUD:RenderPortraits(rows: { any })
	self.Portraits:ClearAllChildren()
	local stack = Instance.new("UIListLayout")
	stack.SortOrder, stack.Padding, stack.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0, 0), self.Portraits
	if #rows == 0 then
		local empty = label(self.Portraits, "+ 파티", 40)
		empty.TextXAlignment, empty.TextColor3 = Enum.TextXAlignment.Center, ButtonStyle.color(Theme.Text.Muted)
		return
	end
	for index = 1, math.min(4, #rows) do
		local member = rows[index]
		local cell = Instance.new("Frame")
		cell.Name, cell.LayoutOrder = "Member:" .. tostring(member.ActorId), index
		cell.BackgroundTransparency, cell.Size, cell.Parent = 1, UDim2.new(1, -4, 0, 40), self.Portraits
		local names = self.Metrics and self.Metrics.NamesVisible
		local left = if names then 2 else math.max(0, ((self.Metrics and self.Metrics.Width or 88) - 48) * 0.5)
		portrait(cell, member, left, 4)
		if names then
			local name = label(cell, Presentation.shortName(member.Name, 7), 34)
			name.Position, name.Size = UDim2.fromOffset(40, 3), UDim2.new(1, -42, 0, 34)
			name.TextWrapped, name.TextTruncate, name.TextSize = false, Enum.TextTruncate.AtEnd, 12
		end
	end
end

function PartyHUD:MemberRow(member: any)
	local row = Instance.new("Frame")
	row.Size, row.BackgroundTransparency, row.Parent = UDim2.new(1, -6, 0, 42), 1, self.Body
	portrait(row, member, 2, 5)
	local name = label(row, Presentation.shortName(member.Name, 12), 18)
	name.Position, name.Size, name.TextWrapped, name.TextTruncate = UDim2.fromOffset(44, 2), UDim2.new(1, -46, 0, 18), false, Enum.TextTruncate.AtEnd
	name.Font = if member.IsLeader then Enum.Font.GothamBold else Enum.Font.Gotham
	local ready = label(row, Presentation.readyLabel(member.Ready), 20)
	ready.Position, ready.Size = UDim2.fromOffset(44, 20), UDim2.new(1, -46, 0, 20)
	ready.TextColor3 = ButtonStyle.color(if member.Ready == "Joined" then Theme.Text.Ready elseif member.Ready == "Stayed" then Theme.Text.Stayed elseif member.Ready == "Waiting" then Theme.Text.Waiting else Theme.Text.Muted)
end

function PartyHUD:RenderInvites(state: any)
	for _, invitation in state.Invites or {} do
		label(self.Body, (invitation.HostName or "플레이어") .. "님의 파티 초대", 36)
		self:Row({
			{ Text = "초대 수락", Key = "Accept:" .. invitation.InviteId, Action = function() self.Send("RespondInvite", { InviteId = invitation.InviteId, Accept = true }) end },
			{ Text = "거절", Key = "Decline:" .. invitation.InviteId, Action = function() self.Send("RespondInvite", { InviteId = invitation.InviteId, Accept = false }) end },
		})
	end
end

function PartyHUD:RenderFinder(state: any)
	label(self.Body, "공개 파티 · 현재 서버", 24)
	local parties = Presentation.publicDirectory(state)
	if #parties == 0 then label(self.Body, "모집 중인 파티가 없어요.", 36) end
	for _, candidate in parties do
		local count, limit = #(candidate.MemberUserIds or {}), candidate.MaxMembers or 4
		local width = math.max(0, (self.Metrics and self.Metrics.Width or 300) - 22)
		local metrics = Geometry.finderCard(width)
		local card = Instance.new("Frame")
		card.Name, card.Size, card.BorderSizePixel, card.Parent = "PublicPartyCard", UDim2.new(1, -6, 0, metrics.Height), 0, self.Body
		surface(card, "Card")
		round(card, 7)
		local title = label(card, (ACTIVITY[candidate.Activity] or candidate.Activity or "자유") .. " · " .. (candidate.TargetName or "자유 파티"), metrics.InfoHeight)
		title.Position, title.Size = UDim2.fromOffset(metrics.InfoLeft, metrics.InfoTop), UDim2.fromOffset(metrics.InfoWidth, metrics.InfoHeight)
		title.TextWrapped, title.TextTruncate, title.Font = false, Enum.TextTruncate.AtEnd, Enum.Font.GothamBold
		local info = label(card, candidate.HostName or "플레이어", metrics.StatusHeight)
		info.Position, info.Size = UDim2.fromOffset(metrics.InfoLeft, metrics.HostTop), UDim2.fromOffset(metrics.HostNameWidth, metrics.HostHeight)
		info.TextWrapped, info.TextTruncate, info.TextColor3 = false, Enum.TextTruncate.AtEnd, ButtonStyle.color(Theme.Text.Muted)
		local status = label(card, if count >= limit then "정원 참" else (STATUS[candidate.Status] or "모집 중"), metrics.StatusHeight)
		status.Position, status.Size = UDim2.fromOffset(metrics.StatusLeft, metrics.StatusTop), UDim2.fromOffset(metrics.StatusWidth, metrics.StatusHeight)
		status.TextWrapped, status.TextTruncate, status.TextXAlignment = false, Enum.TextTruncate.AtEnd, Enum.TextXAlignment.Right
		local members = label(card, tostring(count) .. "/" .. tostring(limit), metrics.CountHeight)
		members.Position, members.Size = UDim2.fromOffset(metrics.CountLeft, metrics.CountTop), UDim2.fromOffset(metrics.CountWidth, metrics.CountHeight)
		members.TextWrapped, members.TextXAlignment = false, Enum.TextXAlignment.Center
		local canJoin = not state.Party and count < limit and candidate.Status == "Forming" and state.Location == "World"
		local join = self:Button(card, "참가", "Join:" .. candidate.PartyId, canJoin,
			function() self.Send("JoinPublic", { PartyId = candidate.PartyId }) end)
		join.Position, join.Size = UDim2.fromOffset(metrics.ButtonLeft, metrics.ButtonTop), UDim2.fromOffset(metrics.ButtonWidth, metrics.ButtonHeight)
	end
end

function PartyHUD:RenderPicker(state: any, isLeader: boolean)
	label(self.Body, "활동과 목표 선택", 26)
	for _, target in state.Targets or {} do
		self:Button(self.Body, (ACTIVITY[target.Activity] or target.Activity) .. " · " .. target.DisplayName, "Target:" .. target.TargetId,
			not state.Party or isLeader, function()
				self.ChosenTarget, self.Section = target.TargetId, "main"
				if state.Party then self.Send("SetActivity", { Activity = target.Activity, TargetId = target.TargetId }) else self:Render(self.State) end
			end, not state.Party)
	end
end

function PartyHUD:RenderInvitePicker(state: any, isLeader: boolean)
	label(self.Body, "현재 서버 플레이어 초대", 26)
	local count = 0
	for _, profile in state.NearbyPlayers or {} do
		local id = profile.ActorId or profile.UserId
		if id ~= state.ActorId and not table.find(state.Party.MemberUserIds, id) then
			count += 1
			self:Button(self.Body, (profile.DisplayName or profile.Name or "플레이어") .. " · 초대", "Invite:" .. tostring(id), isLeader,
				function() self.Send("Invite", { TargetUserId = id }) end)
		end
	end
	if count == 0 then label(self.Body, "지금 초대할 플레이어가 없어요.", 40) end
end

function PartyHUD:RenderMain(state: any, rows: { any }, isLeader: boolean)
	local party, proposal = state.Party, state.Proposal
	local target
	local targetId = if party then party.TargetId else self.ChosenTarget
	for _, item in state.Targets or {} do if item.TargetId == targetId then target = item; break end end
	if not target and not party then
		for _, item in state.Targets or {} do if item.Activity == "Free" then target = item; break end end
	end
	local activity = if party then party.Activity else if target then target.Activity else "Free"
	local visibility = if party then party.Visibility else self.ChosenVisibility
	label(self.Body, (ACTIVITY[activity] or "자유") .. " · " .. (if target then target.DisplayName else "자유 파티"), 36)
	local canConfigure = not party or (isLeader and (party.Status == "Forming" or party.Status == nil))
	self:Row({
		{ Text = if visibility == "Private" then "🔒 비공개" else "공개 파티", Key = "Visibility", Enabled = canConfigure, Local = not party, Action = function()
			local nextVisibility = if visibility == "Private" then "Public" else "Private"
			if party then self.Send("SetVisibility", { Visibility = nextVisibility }) else self.ChosenVisibility = nextVisibility; self:Render(self.State) end
		end },
		{ Text = "목표 선택", Key = "PickTarget", Enabled = canConfigure, Local = true, Action = function() self.Section = "targets"; self:Render(self.State) end },
	})
	if not party then
		self:Button(self.Body, "파티 만들기", "Create", state.Location == "World", function()
			self.Send("Create", { Visibility = self.ChosenVisibility, Activity = activity, TargetId = if target then target.TargetId else nil })
		end)
		return
	end
	local summary = Presentation.summary(party, proposal)
	label(self.Body, if proposal then tostring(summary.Moving) .. " / " .. tostring(summary.Total) .. "명 이동 준비" else (STATUS[party.Status] or "모집 중") .. " · " .. tostring(#rows) .. "/4명", 28)
	for _, member in rows do
		self:MemberRow(member)
	end
	if proposal then
		if not isLeader then self:Row({
			{ Text = "✓ 함께 이동", Key = "MoveTogether", Action = function() self.Send("Respond", { ProposalId = proposal.ProposalId, Join = true }) end },
			{ Text = "— 이번엔 남음", Key = "StayHere", Action = function() self.Send("Respond", { ProposalId = proposal.ProposalId, Join = false }) end },
		}) end
		if isLeader then
			local destination = if activity == "Expedition" then "원정" else "식당"
			self:Button(self.Body, destination .. "으로 함께 이동", "Enter", summary.Waiting == 0 and summary.Moving > 0,
				function() self.Send("Enter", { ProposalId = proposal.ProposalId }) end)
			if activity ~= "Expedition" then label(self.Body, "입장 시 호스트의 모든 식재료를 식당에 맡깁니다.", 36) end
		end
	elseif isLeader and state.Location == "World" and party.Status ~= "InActivity" then
		local supported = activity == "Free" or activity == "Restaurant" or activity == "Expedition"
		self:Button(self.Body, if activity == "Expedition" then "원정 이동 제안" elseif activity == "SharedHunt" then "공용 사냥 이동은 준비 중" else "식당 이동 제안", "Propose", supported,
			function() self.Send("Propose", nil) end)
	end
	self:Row({
		{ Text = "플레이어 초대", Key = "PickInvite", Enabled = isLeader and party.Status == "Forming" and #rows < 4, Local = true, Action = function() self.Section = "invite"; self:Render(self.State) end },
		{ Text = "파티 탈퇴", Key = "Leave", Enabled = state.Location == "World", Action = function() self.Send("Leave", nil) end },
	})
end

function PartyHUD:RenderExpedition(state: any)
	local expedition = state.Expedition
	if not expedition then return end
	local isHost = expedition.HostUserId == state.ActorId
	if expedition.State == "Active" and state.Features and state.Features.ExpeditionPrototype then
		label(self.Body, "원정 진행 중", 30)
		if isHost then self:Button(self.Body, "원정 결과 보기", "CompleteExpedition", true,
			function() self.Send("CompleteExpedition", { SessionId = expedition.SessionId }) end) end
	elseif expedition.State == "Result" then
		label(self.Body, "원정 결과 · 다음 목적지", 32)
		if not isHost then label(self.Body, "호스트가 다음 목적지를 선택하고 있어요. 새 이동 제안에 응답해 주세요.", 60); return end
		for _, choice in { { "Repeat", "같은 원정 다시 하기" }, { "HostRestaurant", "호스트 식당으로 이동" }, { "Hearthcross", "Hearthcross로 귀환" } } do
			self:Button(self.Body, choice[2], "Result:" .. choice[1], true, function()
				self.Send("ExpeditionResult", { SessionId = expedition.SessionId, Destination = choice[1], ActionId = HttpService:GenerateGUID(false) })
			end)
		end
		label(self.Body, "다시 하기와 식당 이동은 새 이동 동의를 받습니다.", 40)
	end
end

function PartyHUD:Render(state: any)
	self.Rendering = true
	self.State = state
	local rows = Presentation.memberRows(state)
	self.Rows = rows
	self:Resize()
	self:RenderPortraits(rows)
	local invitations = #(state.Invites or {})
	local summary = Presentation.summary(state.Party, state.Proposal)
	self.Title = if state.Traveling then "파티 · 이동 준비 중" elseif state.Proposal then "파티 · " .. tostring(summary.Moving) .. "/" .. tostring(summary.Total) .. "명 준비"
		elseif invitations > 0 then "파티 · 초대 " .. tostring(invitations) else "파티"
	self.Heading.Text = if self.DisplayExpanded then "⠿ " .. self.Title else "⠿"
	local selected = GuiService.SelectedObject
	local hadSelection = selected and selected:IsDescendantOf(self.Body)
	local focusKey = if hadSelection then selected:GetAttribute("FocusKey") else nil
	local scroll = self.Body.CanvasPosition
	self.Body:ClearAllChildren()
	self.Buttons = {}
	local layout = Instance.new("UIListLayout")
	layout.SortOrder, layout.Padding, layout.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0, 5), self.Body
	if self.Status ~= "" then label(self.Body, self.Status, 50) end
	if state.Traveling then label(self.Body, "이동 준비 중…", 34) elseif not state.Ready then label(self.Body, "서버에 연결 중…", 34) end
	self:RenderInvites(state)
	local isLeader = state.Party and state.Party.LeaderUserId == state.ActorId
	if self.Section == "targets" then self:RenderPicker(state, isLeader)
	elseif self.Section == "invite" and state.Party then self:RenderInvitePicker(state, isLeader)
	elseif self.Section == "finder" then self:RenderFinder(state)
	else self.Section = "main"; self:RenderMain(state, rows, isLeader) end
	self:RenderExpedition(state)
	if state.Location == "Restaurant" then
		self:Button(self.Body, "정산 · Hearthcross 귀환", "Return", true, function() self.Send("Return", nil) end)
	end
	self:Row({
		{ Text = if self.Section == "main" then "Party Finder" else "파티로 돌아가기", Key = "Finder", Local = true, Action = function()
			self.Section = if self.Section == "main" then "finder" else "main"; self:Render(self.State)
		end },
	})
	local order = 0
	for _, child in self.Body:GetChildren() do if child:IsA("GuiObject") then order += 1; child.LayoutOrder = order end end
	self.Body.CanvasPosition = scroll
	if hadSelection then
		local replacement = focusKey and self.Buttons[focusKey]
		GuiService.SelectedObject = if replacement and replacement.Selectable and self.DisplayExpanded then replacement else self.Expand
	end
	self.Rendering = false
end

return PartyHUD
