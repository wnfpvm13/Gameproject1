--!strict
-- How hits feel on this client: a whoosh when a bat swings, and for a hit a thwack at the victim, a short white flash
-- on them and, when the victim is the player, a little camera shake. The player's own swing shows its hits at once
-- (predict), and the server's word for the same hit is then not shown twice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local HitFeedback = {}

-- Victims the player's own swing already showed (os.clock); weak, so models that go away are dropped.
local predicted: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local shakeUntil = 0

local function sound(id: string, volume: number, at: BasePart)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
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

-- A bat swings (any character).
function HitFeedback.swing(model: Model)
	local body = CharacterParts.body(model)
	if body then
		sound(Config.Feedback.SwingSound, Config.Feedback.SwingVolume, body.root)
	end
end

-- The player's own swing hit this victim, as this client saw it.
function HitFeedback.predict(victim: Model)
	predicted[victim] = os.clock()
	show(victim)
end

-- The server's word on a hit. mine: the swinger is the player; me: the victim is the player.
function HitFeedback.hit(victim: Model, mine: boolean, me: boolean)
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
