--!strict
-- "친구 초대" (owner 2026-10-26, the recommended choice: few players should not just wait): a sticker button on the right
-- side while no round is being played and fewer than Config.INVITE_BELOW are ready. A press opens Roblox's invite
-- prompt (init.client asks SocialService; this module only draws). It sits where the bell button is during a round.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local InviteButton = {}

local button: TextButton

-- onPress(): the player pressed it.
function InviteButton.build(onPress: () -> ())
	button = Style.button(Style.BOLD, 22)
	button.Name = "Invite"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -18, 0.6, 0)
	button.Size = UDim2.fromOffset(150, 52)
	button.BackgroundColor3 = Style.PICK
	button.Text = Config.TEXT.INVITE
	button.Visible = false
	button.Parent = Style.gui()
	button.Activated:Connect(onPress)
end

function InviteButton.set(visible: boolean)
	button.Visible = visible
end

return InviteButton
