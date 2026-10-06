--!strict
-- The original Foundation QA panel remains available only behind the Studio gate.
local DebugUI = {}
DebugUI.__index = DebugUI

function DebugUI.new(playerGui: PlayerGui, send: (string, any?) -> ())
	local self = setmetatable({ State = nil, Controls = {} }, DebugUI)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.Enabled = "MonCookFoundationDebug", false, false, false
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
	local title = label(1, 22); title.Text = "Foundation QA · 파티 & 식당"
	self.Info = label(2, 82); self.Info.Text = "연결 중…"
	local partyId = Instance.new("TextBox")
	partyId.LayoutOrder, partyId.Size = 3, UDim2.new(1, 0, 0, 28)
	partyId.PlaceholderText, partyId.Text, partyId.ClearTextOnFocus = "참가할 파티 ID · 현재 ID 복사", "", false
	partyId.TextSize, partyId.Selectable, partyId.Parent = 14, true, panel
	self.PartyId = partyId
	self.Status = label(9, 40); self.Status.Text = ""
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
			table.insert(self.Controls, button)
		end
	end
	row(4, {
		{ Label = "만들기", Action = function() send("Create", nil) end },
		{ Label = "참가", Action = function() send("Join", { PartyId = partyId.Text }) end },
		{ Label = "탈퇴", Action = function() send("Leave", nil) end },
	})
	row(5, { { Label = "식당 입장 제안", Action = function() send("Propose", nil) end } })
	row(6, {
		{ Label = "JOIN", Action = function() if self.State and self.State.Proposal then send("Respond", { ProposalId = self.State.Proposal.ProposalId, Join = true }) end end },
		{ Label = "STAY", Action = function() if self.State and self.State.Proposal then send("Respond", { ProposalId = self.State.Proposal.ProposalId, Join = false }) end end },
	})
	row(7, { { Label = "모든 식재료를 맡기고 입장", Action = function() if self.State and self.State.Proposal then send("Enter", { ProposalId = self.State.Proposal.ProposalId }) end end } })
	row(8, { { Label = "정산 · 월드 복귀", Action = function() send("Return", nil) end } })
	gui.Parent, self.Gui = playerGui, gui
	return self
end

function DebugUI:Render(state: any, visible: boolean)
	self.State, self.Gui.Enabled = state, visible
	if not visible then return end
	local party, proposal = state.Party, state.Proposal
	if party and not self.PartyId:IsFocused() then self.PartyId.Text = party.PartyId end
	local stock = {}
	for id, count in state.Ingredients or {} do table.insert(stock, tostring(id) .. " " .. tostring(count)) end
	table.sort(stock)
	local response = ""
	if proposal then
		local waiting = 0
		for _, id in proposal.MemberUserIds do if proposal.Responses[tostring(id)] == nil then waiting += 1 end end
		response = "\n입장 응답 대기: " .. tostring(waiting)
	end
	self.Info.Text = (state.Location or "World") .. " | Gold " .. tostring(state.Gold or "…") .. "\n"
		.. (if party then "파티 " .. tostring(#party.MemberUserIds) .. "/4" else "파티 없음") .. response .. "\n" .. table.concat(stock, ", ")
	for _, button in self.Controls do
		button.Active, button.Selectable = state.Ready and not state.Traveling, state.Ready and not state.Traveling
	end
end

function DebugUI:SetStatus(message: string) self.Status.Text = message end

return DebugUI
