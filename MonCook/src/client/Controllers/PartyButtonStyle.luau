--!strict
-- Visual input binding only. PartyHUD retains all Activated handlers and authority.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Style = require(ReplicatedStorage:WaitForChild("Shared").Config.PartyUIStyle)

local PartyButtonStyle = {}
local Controller = {}
Controller.__index = Controller

function PartyButtonStyle.color(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

local function samePress(first: InputObject, second: InputObject): boolean
	if first == second then return true end
	-- Touch identities must match: a second finger must not release this press.
	if first.UserInputType == Enum.UserInputType.Touch then return false end
	return first.UserInputType == second.UserInputType and first.KeyCode == second.KeyCode
end

function Controller:_refresh(instant: boolean?)
	if self.Destroyed then return end
	local state = Style.buttonState(self.Enabled, self.Hovered or self.Selected, self.PressInput ~= nil and self.PressInside)
	if state == self.State and not instant then return end
	self.State = state
	if self.Tween then self.Tween:Cancel(); self.Tween = nil end
	local visual = Style.button(self.Variant, state)
	local goal = {
		BackgroundColor3 = PartyButtonStyle.color(visual.Color), BackgroundTransparency = visual.Transparency,
		TextColor3 = PartyButtonStyle.color(visual.TextColor), TextTransparency = visual.TextTransparency,
	}
	if instant then
		for property, value in goal do (self.Button :: any)[property] = value end
	else
		self.Tween = TweenService:Create(self.Button, TweenInfo.new(Style.Theme.Motion.ButtonSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		self.Tween:Play()
	end
end

function Controller:_cancelPress()
	self.PressInput, self.PressInside = nil, false
	self:_refresh()
end

function Controller:SetEnabled(enabled: boolean)
	if self.Destroyed then return end
	self.Enabled = enabled
	self.Button.Active, self.Button.Selectable = enabled, enabled
	if not enabled then
		self.PressInput, self.PressInside, self.Hovered, self.Selected = nil, false, false, false
	else
		self.Selected = GuiService.SelectedObject == self.Button
	end
	self:_refresh()
end

function Controller:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	if self.Tween then self.Tween:Cancel(); self.Tween = nil end
	for _, connection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
	self.PressInput = nil
end

function PartyButtonStyle.bind(button: TextButton, enabled: boolean, variant: string?): any
	local self: any = setmetatable({ Button = button, Enabled = enabled, Variant = variant or "Accent", Hovered = false,
		Selected = GuiService.SelectedObject == button, PressInput = nil, PressInside = false, Connections = {}, Destroyed = false }, Controller)
	button.AutoButtonColor, button.Active, button.Selectable = false, enabled, enabled
	local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
		table.insert(self.Connections, signal:Connect(callback))
	end
	local function begin(input: InputObject)
		if not self.Enabled or self.PressInput then return end
		local kind = input.UserInputType
		local pointer = kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
		local gamepad = input.KeyCode == Enum.KeyCode.ButtonA and GuiService.SelectedObject == button
		if not pointer and not gamepad then return end
		self.PressInput, self.PressInside = input, true
		self:_refresh()
	end
	connect(button.MouseEnter, function()
		self.Hovered = true
		if self.PressInput and self.PressInput.UserInputType == Enum.UserInputType.MouseButton1 then self.PressInside = true end
		self:_refresh()
	end)
	connect(button.MouseLeave, function()
		self.Hovered = false
		if self.PressInput and self.PressInput.UserInputType == Enum.UserInputType.MouseButton1 then self.PressInside = false end
		self:_refresh()
	end)
	connect(button.SelectionGained, function() self.Selected = true; self:_refresh() end)
	connect(button.SelectionLost, function()
		self.Selected = false
		if self.PressInput and self.PressInput.KeyCode == Enum.KeyCode.ButtonA then self:_cancelPress() else self:_refresh() end
	end)
	connect(button.InputBegan, begin)
	connect(UserInputService.InputBegan, function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.ButtonA and GuiService.SelectedObject == button then begin(input) end
	end)
	connect(UserInputService.InputChanged, function(input: InputObject)
		if self.PressInput ~= input or input.UserInputType ~= Enum.UserInputType.Touch then return end
		local position, origin, size = input.Position, button.AbsolutePosition, button.AbsoluteSize
		self.PressInside = position.X >= origin.X and position.X <= origin.X + size.X and position.Y >= origin.Y and position.Y <= origin.Y + size.Y
		self:_refresh()
	end)
	connect(UserInputService.InputEnded, function(input: InputObject)
		if self.PressInput and samePress(self.PressInput, input) then self:_cancelPress() end
	end)
	connect(UserInputService.WindowFocusReleased, function()
		self.Hovered = false
		self:_cancelPress()
	end)
	pcall(function()
		connect(GuiService:GetPropertyChangedSignal("MenuIsOpen"), function()
			if GuiService.MenuIsOpen then self.Hovered = false; self:_cancelPress() end
		end)
	end)
	connect(button:GetPropertyChangedSignal("Visible"), function()
		if not button.Visible then self.Hovered = false; self:_cancelPress() end
	end)
	connect(button.Destroying, function() self:Destroy() end)
	self:_refresh(true)
	return self
end

return table.freeze(PartyButtonStyle)
