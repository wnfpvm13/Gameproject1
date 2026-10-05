--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("MonCookNetwork", 30)
if not network then warn("[MonCook] Foundation server is not configured; inspect server Output."); return end
local command = network:WaitForChild("Command") :: RemoteFunction
local changed = network:WaitForChild("Changed") :: RemoteEvent
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "MonCookPartyRestaurant", false, false
local panel = Instance.new("ScrollingFrame")
panel.Name, panel.Position, panel.Size = "Panel", UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0.75, 0)
panel.CanvasSize, panel.AutomaticCanvasSize, panel.ScrollBarThickness = UDim2.fromOffset(0, 0), Enum.AutomaticSize.Y, 4
panel.BackgroundColor3, panel.Parent = Color3.fromRGB(248, 239, 220), gui
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize, constraint.Parent = Vector2.new(350, 350), panel
local padding = Instance.new("UIPadding")
padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 10)
padding.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 5), Enum.SortOrder.LayoutOrder, panel
local function label(order: number, height: number): TextLabel
	local item = Instance.new("TextLabel")
	item.LayoutOrder, item.Size = order, UDim2.new(1, 0, 0, height)
	item.BackgroundTransparency, item.TextColor3, item.TextSize = 1, Color3.fromRGB(57, 42, 29), 14
	item.TextWrapped, item.TextXAlignment, item.Parent = true, Enum.TextXAlignment.Left, panel
	return item
end
local title = label(1, 22); title.Text = "파티 & 식당"
local info = label(2, 82); info.Text = "연결 중…"
local partyId = Instance.new("TextBox")
partyId.LayoutOrder, partyId.Size = 3, UDim2.new(1, 0, 0, 28)
partyId.PlaceholderText, partyId.Text, partyId.ClearTextOnFocus = "참가할 파티 ID · 현재 ID 복사", "", false
partyId.TextSize, partyId.Selectable, partyId.Parent = 14, true, panel
local state: any = nil
local pending = false
local controls: { TextButton } = {}
local render: any
local status = label(9, 24); status.Text = ""
local function send(action: string, payload: any?)
	if pending then return end
	pending = true
	local ok, response = pcall(function() return command:InvokeServer(action, payload) end)
	pending = false
	if not ok or not response or not response.Ok then
		status.Text = if ok and response then response.Error or "다시 시도하세요." else "연결을 확인하세요."
	else status.Text = "" end
	if ok and response and response.State then render(response.State) end
end
local function row(order: number, choices: { { Label: string, Action: () -> () } })
	local frame = Instance.new("Frame")
	frame.LayoutOrder, frame.Size, frame.BackgroundTransparency, frame.Parent = order, UDim2.new(1, 0, 0, 30), 1, panel
	for index, choice in choices do
		local button = Instance.new("TextButton")
		button.Text, button.TextSize, button.Selectable = choice.Label, 14, true
		button.Size, button.Position = UDim2.new(1 / #choices, -4, 1, 0), UDim2.new((index - 1) / #choices, 2, 0, 0)
		button.BackgroundColor3, button.TextColor3 = Color3.fromRGB(181, 128, 57), Color3.new(1, 1, 1)
		button.Parent = frame
		button.Activated:Connect(choice.Action)
		table.insert(controls, button)
	end
end
row(4, {
	{ Label = "만들기", Action = function() send("Create") end },
	{ Label = "참가", Action = function() send("Join", { PartyId = partyId.Text }) end },
	{ Label = "탈퇴", Action = function() send("Leave") end },
})
row(5, { { Label = "식당 입장 제안", Action = function() send("Propose") end } })
row(6, {
	{ Label = "JOIN", Action = function() if state and state.Proposal then send("Respond", { ProposalId = state.Proposal.ProposalId, Join = true }) end end },
	{ Label = "STAY", Action = function() if state and state.Proposal then send("Respond", { ProposalId = state.Proposal.ProposalId, Join = false }) end end },
})
row(7, { { Label = "모든 식재료를 맡기고 입장", Action = function() if state and state.Proposal then send("Enter", { ProposalId = state.Proposal.ProposalId }) end end } })
row(8, { { Label = "정산 · 월드 복귀", Action = function() send("Return") end } })
render = function(nextState: any)
	state = nextState
	local party, proposal = state.Party, state.Proposal
	if party and not partyId:IsFocused() then partyId.Text = party.PartyId end
	local stock = {}
	for id, count in state.Ingredients do table.insert(stock, tostring(id) .. " " .. tostring(count)) end
	table.sort(stock)
	local response = ""
	if proposal then
		local waiting = 0
		for _, id in proposal.MemberUserIds do if proposal.Responses[tostring(id)] == nil then waiting += 1 end end
		response = "\n입장 응답 대기: " .. tostring(waiting)
	end
	info.Text = state.Location .. " | Gold " .. tostring(state.Gold or "…") .. "\n"
		.. (if party then "파티 " .. tostring(#party.MemberUserIds) .. "/4" else "파티 없음") .. response .. "\n" .. table.concat(stock, ", ")
	for _, button in controls do button.Active = state.Ready and not state.Traveling end
end
changed.OnClientEvent:Connect(render)
gui.Parent = player:WaitForChild("PlayerGui")
local function focusGamepad(inputType: Enum.UserInputType)
	if string.find(inputType.Name, "Gamepad", 1, true) then GuiService.SelectedObject = controls[1] end
end
UserInputService.LastInputTypeChanged:Connect(focusGamepad)
focusGamepad(UserInputService:GetLastInputType())
local ok, initial = pcall(function() return command:InvokeServer("State") end)
if ok and initial and initial.State then render(initial.State) end
