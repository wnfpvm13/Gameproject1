--!strict
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Presentation = require(ReplicatedStorage:WaitForChild("Shared").Utilities.HuntingPresentation)
local Input = {}
Input.__index = Input
function Input.new(options: any): any
	local self: any = setmetatable({ Enabled = options.Enabled, OnAction = options.OnAction }, Input)
	self.Connection = UserInputService.InputBegan:Connect(function(object: InputObject, processed: boolean)
		if processed or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
		if object.UserInputType == Enum.UserInputType.MouseButton1 then
			for _, gui in options.PlayerGui:GetGuiObjectsAtPosition(object.Position.X, object.Position.Y) do
				if gui:IsA("GuiButton") then return end
			end
		end
		local action = Presentation.input(object.KeyCode.Name, object.UserInputType.Name)
		if action then self:Activate(action) end
	end)
	return self
end
function Input.Activate(self: any, action: string)
	if self.Enabled() and not GuiService.MenuIsOpen then self.OnAction(action) end
end
function Input.Destroy(self: any) self.Connection:Disconnect() end
return Input
