--!strict
-- Word bubbles above heads: other participants show their forbidden word, the local player sees "???".
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Billboards = {}

local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local bubbles: { [number]: BillboardGui } = {}

local function bubbleFor(player: Player): BillboardGui?
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local existing = bubbles[player.UserId]
	if existing and existing.Parent == head then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "WordBubble"
	-- Sized in studs (not pixels) so ten bubbles in the 5-stud chair row never overlap on the show camera.
	gui.Size = UDim2.fromScale(4.4, 1.3)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(40, 40, 48)
	local label = Instance.new("TextLabel")
	label.Name = "Word"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = FONT
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(30, 30, 36)
	label.Parent = frame
	local pad = Instance.new("UIPadding", label)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	gui.Adornee = head
	gui.Parent = head
	bubbles[player.UserId] = gui
	return gui
end

local function setText(player: Player, text: string, mine: boolean)
	local gui = bubbleFor(player)
	if not gui then
		return
	end
	local label = gui:FindFirstChild("Word", true) :: TextLabel
	label.Text = text
	label.TextColor3 = if mine then Color3.fromRGB(120, 120, 130) else Color3.fromRGB(30, 30, 36)
end

-- words: userId string -> word. Participants missing from the table are the local player (own word hidden).
function Billboards.show(words: { [string]: string }, participantIds: { number })
	local me = Players.LocalPlayer
	for _, userId in participantIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local word = words[tostring(userId)]
			if word then
				setText(player, word, player == me)
			elseif player == me then
				setText(player, "???", true)
			end
		end
	end
end

-- Elimination: the bubble turns red and swells (위험한 초대's red name card), then disappears.
function Billboards.alarm(userId: number)
	local gui = bubbles[userId]
	if not gui then
		return
	end
	local frame = gui:FindFirstChildOfClass("Frame") :: Frame
	local label = frame:FindFirstChild("Word") :: TextLabel
	frame.BackgroundColor3 = Color3.fromRGB(230, 40, 40)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	TweenService:Create(gui, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(6.6, 2),
	}):Play()
	task.delay(1.6, function()
		if bubbles[userId] == gui then
			Billboards.remove(userId)
		end
	end)
end

function Billboards.remove(userId: number)
	local gui = bubbles[userId]
	if gui then
		gui:Destroy()
		bubbles[userId] = nil
	end
end

function Billboards.clear()
	for userId in bubbles do
		Billboards.remove(userId)
	end
end

return Billboards
