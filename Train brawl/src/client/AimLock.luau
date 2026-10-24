--!strict
-- Mouse lock, the default while a player plays with keyboard and mouse (their last input): the cursor stays in the
-- middle of the screen (a small aim dot there), the camera looks over the right shoulder and the standing character
-- turns to where the camera looks, so a swing goes where the player aims. Left Alt shows the cursor (for menus; mouse
-- clicks then do not swing) and hides it again; an Alt press made while typing, or with another key pressed during it
-- (Alt+Tab), is ignored - keys already held (moving with WASD) do not count. While typing in a text box or with the Roblox menu open the cursor is free too. Touch and
-- gamepad play (also on a PC) keeps the usual camera. The Roblox camera puts the mouse back every frame, so update()
-- runs every frame after it.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local AimLock = {}
AimLock.__index = AimLock

local SHOULDER = Vector3.new(1.75, 0, 0) -- the camera's offset from the character while locked (as Roblox's shift lock)
local OFFSET_EASE = 10 -- how fast the shoulder offset eases in and out (per second)

-- Input kinds that mean keyboard-and-mouse play.
local KEYBOARD_MOUSE: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseWheel] = true,
}
-- Input kinds that mean other play (touch or a gamepad); anything else leaves the choice as it was.
local function isOther(kind: Enum.UserInputType): boolean
	return kind == Enum.UserInputType.Touch or kind.Name:sub(1, 7) == "Gamepad"
end

type Fields = {
	free: boolean, -- the player showed the cursor (Left Alt)
	altDown: boolean,
	altCombined: boolean, -- another key went down while Alt was held, or Alt went down while typing
	keyboardMouse: boolean, -- the player's last input was keyboard or mouse
	locked: boolean, -- the lock applied last frame
	dot: Frame,
}
export type Lock = typeof(setmetatable({} :: Fields, AimLock))

function AimLock.new(playerGui: Instance): Lock
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainBrawlAim"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the true middle of the screen, where the locked mouse is
	gui.Parent = playerGui
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = dot
	dot.Parent = gui

	local last = UserInputService:GetLastInputType()
	local fields: Fields = {
		free = false,
		altDown = false,
		altCombined = false,
		keyboardMouse = KEYBOARD_MOUSE[last] == true or (not isOther(last) and UserInputService.KeyboardEnabled),
		locked = false,
		dot = dot,
	}
	local self = setmetatable(fields, AimLock)
	UserInputService.LastInputTypeChanged:Connect(function(kind: Enum.UserInputType)
		if KEYBOARD_MOUSE[kind] then
			self.keyboardMouse = true
		elseif isOther(kind) then
			self.keyboardMouse = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, typing: boolean)
		if input.KeyCode == Enum.KeyCode.LeftAlt then
			self.altDown = true
			self.altCombined = typing -- an Alt typed into a text box is not a toggle
		elseif self.altDown and input.UserInputType == Enum.UserInputType.Keyboard then
			self.altCombined = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.LeftAlt then
			if self.altDown and not self.altCombined then
				self.free = not self.free
			end
			self.altDown = false
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		self.altDown = false
	end)
	return self
end

-- Whether the lock applies now: keyboard-and-mouse play, the cursor not shown, not typing, the Roblox menu closed.
function AimLock.active(self: Lock): boolean
	return self.keyboardMouse
		and UserInputService.MouseEnabled
		and not self.free
		and UserInputService:GetFocusedTextBox() == nil
		and not GuiService.MenuIsOpen
end

-- Every frame, after the camera. character: the player's own; onSelf: the camera is on it (not watching someone
-- else, not fallen); steady: it may turn now (not flinching or flying from a hit); dt: the frame's seconds. While
-- locked and standing the shoulder camera stays on (through a flinch too); lying down it eases off, as the offset
-- turns with the body.
function AimLock.update(self: Lock, character: Model?, onSelf: boolean, steady: boolean, dt: number)
	local lock = self:active()
	if lock then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	elseif self.locked then
		-- Only on the change: the Roblox camera handles the free mouse itself (right-drag to turn).
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
	self.locked = lock
	self.dot.Visible = lock
	local body = CharacterParts.body(character)
	if not body then
		return
	end
	local shoulder = lock and onSelf and not body.humanoid.PlatformStand and body.humanoid.Health > 0
	body.humanoid.AutoRotate = not shoulder
	local target = if shoulder then SHOULDER else Vector3.zero
	body.humanoid.CameraOffset = body.humanoid.CameraOffset:Lerp(target, math.min(1, dt * OFFSET_EASE))
	if shoulder and steady and not body.root.Anchored then
		local look = Workspace.CurrentCamera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 1e-3 then
			local at = body.root.Position
			body.root.CFrame = CFrame.lookAt(at, at + flat)
		end
	end
end

-- Whether a mouse click should swing now: while the mouse is locked, by this or by the Roblox camera's own toggle
-- (a shown, free cursor is for menus).
function AimLock.clickSwings(self: Lock): boolean
	return self.locked or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
end

return AimLock
