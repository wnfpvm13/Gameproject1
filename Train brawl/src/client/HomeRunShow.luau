--!strict
-- The home run on screen (the smash that empties a fighter's health; its finishing sound is HitFeedback's): a big
-- "홈런!" where it was hit, a light trail behind the flying body, and a gold burst twinkling out with a pop where the body
-- was in the sky just before the server takes it to the stands (Config.Fall.HomeRunSeconds after the hit, which
-- reaches each client at its own moment, so the body is followed each frame until it shows up in the stands; the
-- trail goes off then, or it would draw a streak up to them). Shown on every client.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local SoundBank = require(shared:WaitForChild("SoundBank"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local HomeRunShow = {}

local GOLD = Config.Feedback.Gold
local LATE_SECONDS = 0.6 -- twinkle anyway this long after the flight should have ended
-- A body this high is in the stands (a home-run flight tops out about 50, 54 from a chimney top: tests).
local STANDS_Y = Config.Arena.WaitingRoomHeight - Config.Arena.StandsMargin

-- An invisible anchor at `at` holding a billboard of big text; it rises a little and fades over `seconds`.
local function billboard(at: Vector3, text: string, color: Color3, size: number, seconds: number)
	local anchor = Instance.new("Part")
	anchor.Name = "TrainBrawlHomeRunText"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(at)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 4, size)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Text = text
	UiStyle.text(label, color, 4)
	label.Parent = gui
	anchor.Parent = Workspace
	local fade = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	local outline = label:FindFirstChildOfClass("UIStroke")
	if outline then
		TweenService:Create(outline, fade, { Transparency = 1 }):Play()
	end
	TweenService:Create(gui, fade, { StudsOffset = Vector3.new(0, 7, 0) }):Play()
	Debris:AddItem(anchor, seconds + 0.1)
end

-- A light trail behind the flying body for the length of the flight (returned, to be turned off).
local function trail(body: CharacterParts.Body): Trail
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 1, 0)
	top.Parent = body.root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -1, 0)
	bottom.Parent = body.root
	local streak = Instance.new("Trail")
	streak.Attachment0 = top
	streak.Attachment1 = bottom
	streak.Lifetime = Config.Feedback.TrailSeconds
	streak.Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD)
	streak.Transparency = NumberSequence.new(0.2, 1)
	streak.LightEmission = 1
	streak.FaceCamera = true
	streak.Parent = body.root
	local seconds = Config.Fall.HomeRunSeconds + Config.Feedback.TrailSeconds
	Debris:AddItem(streak, seconds)
	Debris:AddItem(top, seconds)
	Debris:AddItem(bottom, seconds)
	return streak
end

-- A home run on `victim`, now. `sparkle(at)` draws the twinkle the flight ends in (ImpactBurst's gold burst, through
-- init: a drawn star instead of a "✦" letter, which read as a placeholder).
function HomeRunShow.play(victim: Model, sparkle: (Vector3) -> ())
	local body = CharacterParts.body(victim)
	if not body then
		return
	end
	billboard(body.root.Position, Words.HomeRun, GOLD, 70, Config.Feedback.HomeRunTextSeconds)
	local streak = trail(body)
	local last = body.root.Position
	local started = os.clock()
	local following: RBXScriptConnection
	local function twinkle()
		following:Disconnect()
		streak.Enabled = false
		streak:Clear()
		sparkle(last)
		SoundBank.play("StarPop")
	end
	following = RunService.Heartbeat:Connect(function()
		-- Gone (a sandbag is removed), in the stands, or late: twinkle where it last flew.
		local gone = not body.root.Parent
		local at = if gone then last else body.root.Position
		if gone or at.Y > STANDS_Y or os.clock() - started > Config.Fall.HomeRunSeconds + LATE_SECONDS then
			twinkle()
		else
			last = at
		end
	end)
end

return HomeRunShow
