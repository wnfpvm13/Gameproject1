--!strict
-- How hits feel on this client: a whoosh when someone attacks (a punch's or a swing's), and for a hit a thump at the
-- victim (each weapon's own: a punch, a bat, a hammer's slam, a gold bar's clang; a dynamite blast is heard from
-- ExplosionShow), a short white flash on them and, when the victim is the player, a little camera shake. A launch
-- adds a heavier whack, a home run (the smash that empties health) the bat's crack and a cheer (its flight is
-- HomeRunShow's). The player's own swing shows
-- its hits at once (predict), and the server's word for the same hit then shows only what it adds; a fighter just
-- launched cannot be hit for a moment (Config.Hit.LaunchImmune), so no hit is predicted on it then. Sounds:
-- Config.Sounds through SoundBank.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local SoundBank = require(shared:WaitForChild("SoundBank"))

local HitFeedback = {}

-- Victims the player's own swing already showed (os.clock); weak, so models that go away are dropped.
local predicted: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- Fighters launched lately, until when they cannot be hit (os.clock), from the server's word.
local unhittable: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local shakeUntil = 0

local function flash(model: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.25
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, Config.Feedback.FlashSeconds)
end

-- Each weapon's thump when it lands (none for a blast: its boom is the sound).
local THUMPS: { [string]: string? } = { Fist = "PunchHit", Bat = "HitLight", Hammer = "HammerHit", GoldBar = "GoldHit" }
-- Each weapon's whoosh when it is used.
local WHOOSHES: { [string]: string? } = { Fist = "Punch", Bat = "Swing", Hammer = "Swing", GoldBar = "Swing", Dynamite = "Punch" }

-- The plain hit: the weapon's thump and a flash.
local function show(victim: Model, weapon: string)
	local body = CharacterParts.body(victim)
	if body then
		local thump = THUMPS[weapon]
		if thump then
			SoundBank.play(thump, body.root)
		end
		flash(victim)
	end
end

-- Someone attacks with `weapon` (any character).
function HitFeedback.swing(model: Model, weapon: string)
	local body = CharacterParts.body(model)
	local whoosh = WHOOSHES[weapon]
	if body and whoosh then
		SoundBank.play(whoosh, body.root)
	end
end

-- The player's own attack with `weapon` hit this victim, as this client saw it.
function HitFeedback.predict(victim: Model, weapon: string)
	local endsAt = unhittable[victim]
	if endsAt and os.clock() < endsAt then
		return -- just launched: the server will not take this hit
	end
	predicted[victim] = os.clock()
	show(victim, weapon)
end

-- The server's word on a hit. mine: the attacker is the player; me: the victim is the player; kind: "light",
-- "launch" or "smash"; weapon: what hit.
function HitFeedback.hit(victim: Model, mine: boolean, me: boolean, kind: string, weapon: string)
	if kind == "launch" then
		unhittable[victim] = os.clock() + Config.Hit.LaunchImmune
	end
	-- The player's own hit: the thump and flash were shown already if this client predicted it lately (one server word
	-- per prediction); what the kind adds is shown either way.
	local seen = if mine then predicted[victim] else nil
	if mine then
		predicted[victim] = nil
	end
	if not (seen and os.clock() - seen < Config.Knock.PredictForget) then
		show(victim, weapon)
	end
	local body = CharacterParts.body(victim)
	if body and kind == "launch" then
		SoundBank.play("HitLaunch", body.root)
	elseif kind == "smash" then
		SoundBank.play("HomeRun") -- for the whole screen: the body flies off (and a sandbag is removed) mid-sound
		if not SoundBank.playing("Cheer") then -- the round's win cheer may have started first
			SoundBank.play("Cheer")
		end
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
