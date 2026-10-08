--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared.Config.Registry)
local Style = require(Shared.Config.HuntingUIStyle)
local Presentation = require(Shared.Utilities.HuntingPresentation)
local ButtonStyle = require(script.Parent.PartyButtonStyle)
local HUD = {}
HUD.__index = HUD
local function color(value: any): Color3 return Color3.new(value[1], value[2], value[3]) end
local function round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner"); corner.CornerRadius, corner.Parent = UDim.new(0, radius), parent
end
local function label(parent: Instance, text: string, size: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency, item.Font, item.TextSize, item.TextColor3 = 1, Enum.Font.Gotham, size, color(Style.Text)
	item.Text, item.Parent = text, parent
	return item
end
local function button(parent: Instance, text: string, callback: () -> ()): (TextButton, any)
	local item = Instance.new("TextButton")
	item.Text, item.Font, item.TextSize, item.Parent = text, Enum.Font.GothamBold, 14, parent
	round(item, 10)
	local visual = ButtonStyle.bind(item, true)
	item.Activated:Connect(callback)
	return item, visual
end
function HUD.new(playerGui: PlayerGui, action: (string) -> ()): any
	local self: any = setmetatable({ State = { Ready = false }, Tab = "Ingredients", Buttons = {}, Visuals = {}, Notices = {}, LootVisuals = {}, OnAction = action }, HUD)
	local screen = Instance.new("ScreenGui")
	screen.Name, screen.ResetOnSpawn, screen.DisplayOrder = "MonCookHuntingHUD", false, 10
	screen.ScreenInsets, screen.ZIndexBehavior = Enum.ScreenInsets.CoreUISafeInsets, Enum.ZIndexBehavior.Sibling
	screen.Parent, self.Screen = playerGui, screen
	local root = Instance.new("Frame")
	root.Size, root.BackgroundTransparency, root.Parent = UDim2.fromScale(1, 1), 1, screen
	self.Root = root
	local combat = Instance.new("Frame")
	combat.AnchorPoint, combat.BackgroundTransparency, combat.Parent = Vector2.new(1, 1), 1, root
	self.Combat = combat
	for _, kind in { "Basic", "Heavy", "Dodge" } do
		self.Buttons[kind], self.Visuals[kind] = button(combat, kind, function() self.OnAction(kind) end)
	end
	local inventory = Instance.new("Frame")
	inventory.AnchorPoint, inventory.BackgroundColor3, inventory.BackgroundTransparency = Vector2.new(0, 1), color(Style.Background), Style.BackgroundTransparency
	inventory.Visible, inventory.Parent, self.Panel = false, root, inventory
	round(inventory, 12)
	local title = label(inventory, "Inventory", 18)
	title.Position, title.Size, title.Font = UDim2.fromOffset(14, 10), UDim2.new(1, -65, 0, 28), Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = button(inventory, "×", function() self:SetInventory(false) end)
	close.AnchorPoint, close.Position, close.Size = Vector2.new(1, 0), UDim2.new(1, -8, 0, 5), UDim2.fromOffset(44, 44)
	self.TabButtons = {}
	for index, tab in { "Ingredients", "Materials" } do
		local tabButton = button(inventory, tab, function() self.Tab = tab; self:RenderItems() end)
		tabButton.Position, tabButton.Size = UDim2.new((index-1)/2, 9, 0, 51), UDim2.new(0.5, -14, 0, 44)
		self.TabButtons[tab] = tabButton
	end
	local list = Instance.new("ScrollingFrame")
	list.Position, list.Size, list.BackgroundTransparency, list.BorderSizePixel = UDim2.fromOffset(10, 105), UDim2.new(1, -20, 1, -115), 1, 0
	list.ScrollBarThickness, list.AutomaticCanvasSize, list.CanvasSize = 5, Enum.AutomaticSize.Y, UDim2.fromScale(0, 0)
	list.Parent, self.List = inventory, list
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 6), Enum.SortOrder.LayoutOrder, list
	self.InventoryButton = button(root, "가방  [I]", function() self:SetInventory(not self.Panel.Visible) end)
	self.InventoryButton.AnchorPoint, self.InventoryButton.Size = Vector2.new(1, 1), UDim2.fromOffset(105, 44)
	local health = Instance.new("Frame")
	health.AnchorPoint, health.Position, health.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -10), UDim2.fromOffset(176, 25)
	health.BackgroundColor3, health.BackgroundTransparency, health.Parent = color(Style.Background), 0.2, root
	round(health, 8)
	self.Health = label(health, "준비 중…", 13); self.Health.Size = UDim2.fromScale(1, 1)
	local goal = label(root, "Hornboar · 뿔은 강공으로!", 12)
	goal.AnchorPoint, goal.Position, goal.Size, goal.TextColor3 = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -39), UDim2.fromOffset(250, 20), color(Style.Muted)
	self.Goal = goal
	local notices = Instance.new("Frame")
	notices.AnchorPoint, notices.Position, notices.BackgroundTransparency = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 72), 1
	notices.Parent, self.NoticeFrame = root, notices
	local noticeLayout = Instance.new("UIListLayout")
	noticeLayout.Padding, noticeLayout.HorizontalAlignment, noticeLayout.Parent = UDim.new(0, 6), Enum.HorizontalAlignment.Center, notices
	self.ResizeConnection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Layout() end)
	self.KeyConnection = UserInputService.InputBegan:Connect(function(object, processed)
		if not processed and object.KeyCode == Enum.KeyCode.I and not UserInputService:GetFocusedTextBox() then self:SetInventory(not self.Panel.Visible) end
	end)
	self:Layout()
	return self
end
function HUD.Layout(self: any)
	local size = self.Root.AbsoluteSize
	if size.X < 1 or size.Y < 1 then return end
	local layout = Presentation.layout(size.X, size.Y, Style)
	self.Combat.Position, self.Combat.Size = UDim2.new(1, -12, 1, -layout.CombatBottom), UDim2.fromOffset(layout.Button*3+16, layout.Button)
	for index, kind in { "Basic", "Heavy", "Dodge" } do
		self.Buttons[kind].Position, self.Buttons[kind].Size = UDim2.fromOffset((index-1)*(layout.Button+8), 0), UDim2.fromOffset(layout.Button, layout.Button)
	end
	self.Panel.Size, self.Panel.Position = UDim2.fromOffset(layout.PanelWidth, layout.PanelHeight), UDim2.new(0, 12, 1, -layout.CombatBottom)
	self.InventoryButton.Position = UDim2.new(1, -12, 1, -layout.CombatBottom-layout.Button-10)
	self.NoticeFrame.Size = UDim2.fromOffset(layout.NoticeWidth, 190)
end
function HUD.SetInventory(self: any, visible: boolean)
	self.Panel.Visible = visible and self.State.Ready == true
	if self.Panel.Visible then self:RenderItems() end
	self:Refresh()
end
function HUD.CanAct(self: any): boolean return Presentation.canAct(self.State, self.Panel.Visible) end
function HUD.Render(self: any, state: any)
	if type(state) ~= "table" then return end
	self.State = state
	if self.Panel.Visible and state.Ready then self:RenderItems() end
	self:Refresh()
end
function HUD.Refresh(self: any)
	local state, at = self.State, workspace:GetServerTimeNow()
	local enabled = self:CanAct()
	local busy = state.Action and state.Action.EndAt and at < state.Action.EndAt
	local dodgeRemaining = math.max(0, (state.DodgeReadyAt or 0)-at)
	local touch = UserInputService.TouchEnabled
	self.Buttons.Basic.Text = if touch then "공격" else "공격\nM1 / R2"
	self.Buttons.Heavy.Text = if touch then "강공" else "강공\nQ / X"
	self.Buttons.Dodge.Text = if dodgeRemaining > 0 then string.format("회피\n%.1f", dodgeRemaining) elseif touch then "회피" else "회피\nF / B"
	for _, kind in { "Basic", "Heavy", "Dodge" } do self.Visuals[kind]:SetEnabled(enabled and not busy and (kind ~= "Dodge" or dodgeRemaining <= 0)) end
	self.Combat.Visible, self.Goal.Visible = state.Location == "World" or not state.Ready, state.Location == "World"
	self.InventoryButton.Text = if touch then "가방" else "가방  [I]"
	self.Health.Text = if state.Ready then string.format("HP %d / %d", math.ceil(state.Health or 0), math.ceil(state.MaxHealth or 100)) else "준비 중…"
end
function HUD.RenderItems(self: any)
	local items = if self.State.Inventory then self.State.Inventory[self.Tab] or {} else {}
	local signature = self.Tab
	for _, item in items do signature ..= ":" .. item.IngredientId .. "=" .. tostring(item.Quantity) end
	if signature == self.ItemSignature then return end
	self.ItemSignature = signature
	for _, child in self.List:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	for tab, item in self.TabButtons do item.Text = (if tab == self.Tab then "✓ " else "") .. tab end
	if #items == 0 then
		local empty = label(self.List, "아직 모은 재료가 없어요", 14)
		empty.Size, empty.LayoutOrder = UDim2.new(1, -6, 0, 50), 1
		return
	end
	for index, item in items do
		local row = Instance.new("Frame")
		row.Size, row.BackgroundColor3, row.BackgroundTransparency, row.LayoutOrder = UDim2.new(1, -6, 0, 52), color(Style.Background), 0.38, index
		row.Parent = self.List; round(row, 8)
		local icon = label(row, if item.Rarity == "Rare" then "✨" elseif item.Category == "Material" then "◇" else "●", 22)
		icon.Size, icon.Position = UDim2.fromOffset(44, 44), UDim2.fromOffset(2, 4)
		local name = label(row, item.DisplayName, 14)
		name.Position, name.Size, name.TextXAlignment = UDim2.fromOffset(48, 5), UDim2.new(1, -100, 1, -10), Enum.TextXAlignment.Left
		name.TextWrapped = true
		if item.Rarity == "Rare" then name.TextColor3 = color(Style.Rare) end
		local quantity = label(row, "×" .. tostring(item.Quantity), 14)
		quantity.AnchorPoint, quantity.Position, quantity.Size = Vector2.new(1, 0), UDim2.new(1, -7, 0, 0), UDim2.new(0, 46, 1, 0)
	end
end
function HUD.Notice(self: any, receipt: any)
	local text, rare = Presentation.notice(receipt, Registry.Definitions)
	if text == "" then return end
	local notice = Instance.new("TextLabel")
	notice.Size, notice.BackgroundColor3, notice.BackgroundTransparency = UDim2.new(1, 0, 0, if rare then 90 else 66), color(Style.Background), 0.14
	notice.Text, notice.TextWrapped, notice.Font, notice.TextSize = text, true, Enum.Font.GothamBold, 15
	notice.TextColor3, notice.Parent = color(if rare then Style.Rare else Style.Text), self.NoticeFrame
	round(notice, 10)
	table.insert(self.Notices, notice)
	local maximum = if self.Root.AbsoluteSize.Y < 430 then 1 else Style.MaxNotices
	while #self.Notices > maximum do local oldest = table.remove(self.Notices, 1); if oldest then oldest:Destroy() end end
	task.delay(if rare then Style.RareNoticeSeconds else Style.NoticeSeconds, function()
		if not notice.Parent then return end
		local fade = TweenService:Create(notice, TweenInfo.new(0.2), { TextTransparency = 1, BackgroundTransparency = 1 })
		fade:Play(); Debris:AddItem(notice, 0.25)
	end)
end
return HUD
