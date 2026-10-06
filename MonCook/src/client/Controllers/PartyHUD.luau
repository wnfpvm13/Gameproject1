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
local Layout = require(ReplicatedStorage:WaitForChild("Shared").Utilities.PartyHUDLayout)

local PartyHUD = {}
PartyHUD.__index = PartyHUD
local INK = Color3.fromRGB(57, 42, 29)
local CREAM = Color3.fromRGB(248, 239, 220)
local GOLD = Color3.fromRGB(166, 112, 41)
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
				table.insert(bounds, { Left = origin.X, Right = origin.X + size.X, Bottom = origin.Y + size.Y })
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
	item.Font, item.TextSize, item.TextColor3 = Enum.Font.Gotham, 13, INK
	item.TextWrapped, item.TextXAlignment, item.Parent = true, Enum.TextXAlignment.Left, parent
	return item
end

function PartyHUD.new(playerGui: PlayerGui, send: (string, any?) -> ())
	local self: any = setmetatable({ State = nil, Send = send, Expanded = false, Section = "main", Pending = false,
		ChosenVisibility = "Public", ChosenTarget = nil, Status = "", Buttons = {} }, PartyHUD)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "MonCookPartyHUD", false, false, 5
	pcall(function() gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
	local panel = Instance.new("Frame")
	panel.Name, panel.AnchorPoint, panel.Position = "CompactParty", Vector2.new(1, 0), UDim2.new(1, -12, 0, 12)
	panel.BackgroundColor3, panel.BorderSizePixel, panel.ClipsDescendants, panel.Parent = CREAM, 0, true, gui
	round(panel, 10)
	local heading = label(panel, "파티", 20)
	heading.Position, heading.Size, heading.Font = UDim2.fromOffset(10, 3), UDim2.new(1, -52, 0, 20), Enum.Font.GothamBold
	local expand = Instance.new("TextButton")
	expand.Name, expand.Text, expand.Font, expand.TextSize = "Expand", "＋", Enum.Font.GothamBold, 20
	expand.AnchorPoint, expand.Position, expand.Size = Vector2.new(1, 0), UDim2.new(1, -3, 0, 2), UDim2.fromOffset(42, 42)
	expand.BackgroundTransparency, expand.TextColor3, expand.Selectable = 1, INK, true
	expand:SetAttribute("FocusKey", "Expand")
	expand.Parent = panel
	expand.Activated:Connect(function() self:Toggle() end)
	local portraits = Instance.new("Frame")
	portraits.Name, portraits.Position, portraits.Size = "Members", UDim2.fromOffset(8, 24), UDim2.new(1, -48, 0, 45)
	portraits.BackgroundTransparency, portraits.Parent = 1, panel
	local body = Instance.new("ScrollingFrame")
	body.Name, body.Position, body.Size = "Expanded", UDim2.fromOffset(8, 76), UDim2.new(1, -16, 1, -84)
	body.BackgroundTransparency, body.BorderSizePixel, body.ScrollBarThickness = 1, 0, 4
	body.CanvasSize, body.AutomaticCanvasSize, body.Visible = UDim2.fromOffset(0, 0), Enum.AutomaticSize.Y, false
	body.Parent = panel
	gui.Parent = playerGui
	self.Gui, self.Panel, self.Heading, self.Expand, self.Portraits, self.Body = gui, panel, heading, expand, portraits, body
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Resize() end)
	gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() self:Resize() end)
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
	-- GetCoreGuiEnabled has no public change event. A small layout-only poll
	-- follows changes made by other scripts without rebuilding controls/focus.
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

function PartyHUD:Resize()
	local available = self.Gui.AbsoluteSize
	local topbarBottom = 0
	pcall(function() topbarBottom = GuiService.TopbarInset.Max.Y - self.Gui.AbsolutePosition.Y end)
	local metrics = Layout.calculate({
		Width = available.X, Height = available.Y, TopbarBottom = topbarBottom,
		PlayerListEnabled = coreEnabled(Enum.CoreGuiType.PlayerList), PlayerCount = #Players:GetPlayers(),
		ChatBounds = chatBounds(self.Gui), Expanded = self.Expanded,
	})
	self.Panel.Position = UDim2.new(1, -metrics.Right, 0, metrics.Top)
	self.Panel.Size = UDim2.fromOffset(metrics.Width, metrics.Height)
	self.Panel:SetAttribute("LayoutPolicy", metrics.Policy)
	self.Portraits.Visible = not metrics.SmallHeader
	self.Body.Position = UDim2.fromOffset(8, metrics.Header + 2)
	self.Body.Size = UDim2.new(1, -16, 0, metrics.BodyHeight)
	self.Body.Visible, self.Expand.Text = self.Expanded, if self.Expanded then "−" else "＋"
	pcall(function() self.Panel.Visible = not GuiService.MenuIsOpen end)
end

function PartyHUD:Toggle()
	self.Expanded = not self.Expanded
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
	button.Size, button.Text, button.Font, button.TextSize = UDim2.new(1, 0, 0, 42), text, Enum.Font.GothamMedium, 13
	button.BackgroundColor3, button.TextColor3 = if active then GOLD else Color3.fromRGB(209, 198, 179), if active then Color3.new(1, 1, 1) else INK
	button.BorderSizePixel, button.Active, button.Selectable, button.AutoButtonColor = 0, active == true, active == true, active == true
	button:SetAttribute("FocusKey", key)
	button.Parent = parent
	round(button, 6)
	button.Activated:Connect(function() if active then action() end end)
	self.Buttons[key] = button
	return button
end

function PartyHUD:Row(choices: { any })
	local frame = Instance.new("Frame")
	frame.Size, frame.BackgroundTransparency, frame.Parent = UDim2.new(1, 0, 0, 42), 1, self.Body
	for index, choice in choices do
		local button = self:Button(frame, choice.Text, choice.Key, choice.Enabled ~= false, choice.Action, choice.Local)
		button.Size, button.Position = UDim2.new(1 / #choices, -3, 1, 0), UDim2.new((index - 1) / #choices, if index == 1 then 0 else 3, 0, 0)
	end
end

function PartyHUD:RenderPortraits(rows: { any })
	self.Portraits:ClearAllChildren()
	if #rows == 0 then label(self.Portraits, "함께할 파티를 찾아보세요", 42); return end
	for index, member in rows do
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency, cell.Size, cell.Position = 1, UDim2.new(1 / #rows, 0, 1, 0), UDim2.new((index - 1) / #rows, 0, 0, 0)
		cell.Parent = self.Portraits
		local portrait = Instance.new("ImageLabel")
		portrait.Size, portrait.AnchorPoint, portrait.Position = UDim2.fromOffset(26, 26), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 0)
		portrait.BackgroundColor3, portrait.BorderSizePixel = Color3.fromRGB(219, 199, 160), 0
		if member.UserId > 0 then portrait.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(member.UserId) .. "&w=48&h=48" end
		portrait.Parent = cell
		round(portrait, 13)
		if member.IsLeader then
			local crown = label(cell, "♛", 14)
			crown.AnchorPoint, crown.Position, crown.Size = Vector2.new(0.5, 0), UDim2.new(0.5, -10, 0, 0), UDim2.fromOffset(12, 14)
			crown.BackgroundTransparency, crown.BackgroundColor3 = 0, CREAM
		end
		if member.Ready ~= "Idle" then
			local indicator = label(cell, if member.Ready == "Joined" then "✓" elseif member.Ready == "Stayed" then "—" else "…", 14)
			indicator.AnchorPoint, indicator.Position, indicator.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 10, 0, 0), UDim2.fromOffset(12, 14)
			indicator.BackgroundTransparency, indicator.BackgroundColor3 = 0, CREAM
		end
		local name = label(cell, Presentation.shortName(member.Name, 4), 18)
		name.Position, name.TextSize, name.TextXAlignment = UDim2.fromOffset(0, 27), 11, Enum.TextXAlignment.Center
		name.TextWrapped, name.TextTruncate = false, Enum.TextTruncate.AtEnd
	end
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
	label(self.Body, "현재 서버의 공개 파티", 26)
	local parties = Presentation.publicDirectory(state)
	if #parties == 0 then label(self.Body, "모집 중인 공개 파티가 없어요.", 40) end
	for _, candidate in parties do
		local count = #(candidate.MemberUserIds or {})
		local limit = candidate.MaxMembers or 4
		label(self.Body, (ACTIVITY[candidate.Activity] or candidate.Activity or "자유") .. " · " .. (candidate.TargetName or "자유 파티")
			.. "\n" .. (candidate.HostName or "플레이어") .. " · " .. tostring(count) .. "/" .. tostring(limit) .. " · " .. (STATUS[candidate.Status] or "모집 중"), 56)
		local canJoin = not state.Party and count < limit and candidate.Status == "Forming" and state.Location == "World"
		self:Button(self.Body, if count >= limit then "인원이 가득 찼어요" elseif state.Party then "참가하려면 현재 파티를 나가세요" else "파티 참가", "Join:" .. candidate.PartyId, canJoin,
			function() self.Send("JoinPublic", { PartyId = candidate.PartyId }) end)
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
	label(self.Body, if proposal then tostring(summary.Moving) .. "/" .. tostring(summary.Total) .. "명 이동 준비" else (STATUS[party.Status] or "모집 중") .. " · " .. tostring(#rows) .. "/4명", 28)
	for _, member in rows do
		label(self.Body, (if member.IsLeader then "♛ " else "") .. member.Name .. " · " .. Presentation.readyLabel(member.Ready), 36)
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
	self.State = state
	local rows = Presentation.memberRows(state)
	self:RenderPortraits(rows)
	local invitations = #(state.Invites or {})
	local summary = Presentation.summary(state.Party, state.Proposal)
	self.Heading.Text = if state.Traveling then "파티 · 이동 준비 중" elseif state.Proposal then "파티 · " .. tostring(summary.Moving) .. "/" .. tostring(summary.Total) .. "명 준비"
		elseif invitations > 0 then "파티 · 초대 " .. tostring(invitations) else "파티"
	local selected = GuiService.SelectedObject
	local hadSelection = selected and selected:IsDescendantOf(self.Body)
	local focusKey = if hadSelection then selected:GetAttribute("FocusKey") else nil
	local scroll = self.Body.CanvasPosition
	self.Body:ClearAllChildren()
	self.Buttons = {}
	local layout = Instance.new("UIListLayout")
	layout.SortOrder, layout.Padding, layout.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0, 7), self.Body
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
		GuiService.SelectedObject = if replacement and replacement.Selectable and self.Expanded then replacement else self.Expand
	end
end

return PartyHUD
