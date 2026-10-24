--!strict
-- How hits feel on this client: a whoosh when a bat swings, and for a hit a thwack at the victim, a short white flash
-- on them and, when the victim is the player, a little camera shake. The player's own swing shows its hits at once
-- (predict), and the server's word for the same hit is then not shown twice; a fighter just launched cannot be hit
-- for a moment (Config.Hit.LaunchImmune), so no hit is predicted on it then. A smash (health emptied) also raises a
-- column of steam where its fighter was and thumps lower.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local HitFeedback = {}

-- Victims the player's own swing already showed (os.clock); weak, so models that go away are dropped.
local predicted: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- Fighters launched lately, until when they cannot be hit (os.clock), from the server's word.
local unhittable: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local shakeUntil = 0

local function sound(id: string, volume: number, at: BasePart, speed: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 120
	s.Parent = at
	s:Play()
	Debris:AddItem(s, 2)
end

local function flash(model: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.25
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, Config.Feedback.FlashSeconds)
end

local function show(victim: Model)
	local body = CharacterParts.body(victim)
	if body then
		sound(Config.Feedback.HitSound, Config.Feedback.HitVolume, body.root)
		flash(victim)
	end
end

-- A column of steam rising where a smashed fighter stood.
local function steam(at: Vector3)
	local column = Instance.new("Part")
	column.Name = "SmashSteam"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.CastShadow = false
	column.Shape = Enum.PartType.Cylinder -- along its own X: stood up
	column.Material = Enum.Material.Neon
	column.Color = Color3.new(1, 1, 1)
	column.Transparency = 0.15
	column.Size = Vector3.new(36, 2.5, 2.5)
	column.CFrame = CFrame.new(at + Vector3.new(0, 16, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	column.Parent = Workspace
	local fade = TweenInfo.new(Config.Feedback.SmashSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(column, fade, { Transparency = 1, Size = Vector3.new(44, 7, 7) }):Play()
	Debris:AddItem(column, Config.Feedback.SmashSeconds + 0.1)
end

-- A bat swings (any character).
function HitFeedback.swing(model: Model)
	local body = CharacterParts.body(model)
	if body then
		sound(Config.Feedback.SwingSound, Config.Feedback.SwingVolume, body.root)
	end
end

-- The player's own swing hit this victim, as this client saw it.
function HitFeedback.predict(victim: Model)
	local endsAt = unhittable[victim]
	if endsAt and os.clock() < endsAt then
		return -- just launched: the server will not take this hit
	end
	predicted[victim] = os.clock()
	show(victim)
end

-- The server's word on a hit. mine: the swinger is the player; me: the victim is the player; kind: "light",
-- "launch" or "smash".
function HitFeedback.hit(victim: Model, mine: boolean, me: boolean, kind: string)
	if kind == "launch" then
		unhittable[victim] = os.clock() + Config.Hit.LaunchImmune
	end
	if kind == "smash" then
		local body = CharacterParts.body(victim)
		if body then
			steam(body.root.Position)
			sound(Config.Feedback.HitSound, 1, body.root, 0.6)
		end
	end
	-- The player's own hit: shown already if this client predicted it lately (one server word per prediction).
	local seen = if mine then predicted[victim] else nil
	if mine then
		predicted[victim] = nil
	end
	if not (seen and os.clock() - seen < Config.Knock.PredictForget) then
		show(victim)
	end
	if me then
		shakeUntil = os.clock() + Config.Feedback.ShakeSeconds
	end
end

-- Every frame, after the camera has moved: the shake for a hit on the player.
function HitFeedback.update()
	if os.clock() < shakeUntil then
		local s = Config.Feedback.ShakeStuds
		local camera = Workspace.CurrentCamera
		camera.CFrame *= CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
	end
end

return HitFeedback
