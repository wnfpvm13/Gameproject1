--!strict
-- My seat bell (docs/DESIGN_V3.md §5.1, §9; bundle 6b): a ProximityPrompt on my own chair's bell only (E, gamepad X,
-- touch; the chairs stand 5 studs apart, so a prompt on every bell would reach the neighbours' too). It is enabled
-- while the server has my bell open; a press asks the server to ring it (the server checks everything). Also finds any
-- player's bell, by the chair their character sits on, for the ding and the light. The prompt draws nothing (Custom
-- style, review 2026-10-25: its "E 벨" box sat over the seated players); E still rings, and the screen bell button
-- shows the key.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))

local Bell = {}

local PROMPT_DISTANCE = 10 -- studs (a seated player is about 2.5 studs from their bell)

local prompt: ProximityPrompt? = nil
local promptOn: BasePart? = nil
local onRing: () -> () = function() end

-- The bell model next to the chair `player` sits on (map contract: PoolHall.Chairs.ChairNN.Bell), or nil.
function Bell.bellOf(player: Player): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hall = workspace:FindFirstChild("PoolHall")
	local chairs = hall and hall:FindFirstChild("Chairs")
	if not (humanoid and chairs) then
		return nil
	end
	for _, chair in chairs:GetChildren() do
		local seat = chair:FindFirstChild("Seat")
		if seat and seat:IsA("Seat") and seat.Occupant == humanoid then
			local bell = chair:FindFirstChild("Bell")
			return if bell and bell:IsA("Model") then bell else nil
		end
	end
	return nil
end

-- ring(): I pressed my bell (prompt or the screen button).
function Bell.start(ring: () -> ())
	onRing = ring
end

-- Whether I may ring now (my bell is open and I sit on my chair): the prompt goes to my chair's bell and is enabled.
function Bell.set(canRing: boolean)
	local bell = if canRing then Bell.bellOf(Players.LocalPlayer) else nil
	local button = bell and bell.PrimaryPart
	if button ~= promptOn then
		if prompt then
			prompt:Destroy()
			prompt = nil
		end
		promptOn = button
		if button then
			local p = Instance.new("ProximityPrompt")
			p.ActionText = Config.TEXT.BELL_BUTTON
			p.KeyboardKeyCode = Enum.KeyCode.E
			p.HoldDuration = 0
			p.MaxActivationDistance = PROMPT_DISTANCE
			p.RequiresLineOfSight = false
			p.Style = Enum.ProximityPromptStyle.Custom
			p.Triggered:Connect(function()
				onRing()
			end)
			p.Parent = button
			prompt = p
		end
	end
	if prompt then
		prompt.Enabled = canRing
	end
end

return Bell
