--!strict
-- The dodge roll's cooldown for the player on a keyboard or a gamepad (decision 22): a small round plate right of the
-- health bar with the roll's key (Words.DodgeKey; Words.DodgeKeyPad when only a gamepad is there) over its name; while the roll cools down the plate dims and counts the
-- seconds down. Shown only while the player fights on the trains, and not on touch screens (the 구르기 button shows it
-- there: DodgeInput.show). The look is UiStyle's.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local DodgeHud = {}
DodgeHud.__index = DodgeHud

local SIZE = 52
local LEFT = 152 -- its left edge this far right of the screen's middle (the health bar is 280 wide; the tickets mirror it)
local BOTTOM = 14

type Fields = { gui: ScreenGui, plate: Frame, key: TextLabel, name: TextLabel, shown: number? }
export type Hud = typeof(setmetatable({} :: Fields, DodgeHud))

function DodgeHud.new(playerGui: Instance): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlDodge"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0, 1)
	plate.Position = UDim2.new(0.5, LEFT, 1, -BOTTOM)
	plate.Size = UDim2.fromOffset(SIZE, SIZE)
	UiStyle.plate(plate, SIZE / 2)
	plate.Visible = false
	plate.Parent = gui
	local key = UiStyle.label(plate, "Key", UDim2.new(1, 0, 0, 26), 24, UiStyle.Gold)
	key.Position = UDim2.fromOffset(0, 5)
	key.Text = Words.DodgeKey
	local name = UiStyle.label(plate, "Name", UDim2.new(1, 0, 0, 16), 13)
	name.Position = UDim2.fromOffset(0, SIZE - 21)
	name.Text = Words.DodgeButton
	local fields: Fields = { gui = gui, plate = plate, key = key, name = name, shown = nil }
	return setmetatable(fields, DodgeHud)
end

-- Every frame. fighting: the player fights on the trains now; wait: seconds until the next roll may start.
function DodgeHud.update(self: Hud, fighting: boolean, wait: number)
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled
	self.plate.Visible = fighting and not touchOnly
	if not self.plate.Visible then
		return
	end
	local pad = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
	local tenths = if wait > 0 then math.ceil(wait * 10) else 0
	local shown = if pad then -1 - tenths else tenths -- (a change of the control shows anew)
	if shown == self.shown then
		return
	end
	self.shown = shown
	self.key.Text = if tenths > 0 then string.format("%.1f", tenths / 10) elseif pad then Words.DodgeKeyPad else Words.DodgeKey
	self.key.TextColor3 = if tenths > 0 then UiStyle.Cream else UiStyle.Gold
	self.plate.BackgroundTransparency = if tenths > 0 then 0.55 else 0.18
end

return DodgeHud
