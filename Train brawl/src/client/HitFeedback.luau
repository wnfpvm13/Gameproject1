--!strict
-- How hits feel on this client: a whoosh when someone attacks (each weapon's own: a punch, a bat's swing, a hammer's
-- heavy swing, a gold bar's, a throw), and for a hit a thump at the victim (each weapon's own: a punch, a bat, a
-- hammer's slam, a gold bar's clang; a dynamite blast is heard from ExplosionShow), a short white flash on them and,
-- when the victim is the player, a little camera shake. A launch adds a heavier layer (the bat's whack, a heavy body
-- blow for the rest), a home run (the smash that empties health) a finishing sound for the whole screen over the
-- weapon's own thump (the bat's crack, a heavy blow for the rest: never the thump's own recording twice) and a cartoon
-- slide whistle as the body flies off (its flight is HomeRunShow's). The player's own swing shows
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
local THUMPS: { [string]: string? } = { Fist = "PunchHit", Bat = "BatHit", Hammer = "HammerHit", GoldBar = "GoldHit" }
-- Each weapon's whoosh when it is used.
local WHOOSHES: { [string]: string? } = { Fist = "Punch", Bat = "Swing", Hammer = "HeavySwing", GoldBar = "GoldSwing", Dynamite = "Throw" }
-- The heavier layer a launch adds at the victim.
local LAUNCHES: { [string]: string? } = { Fist = "BodyLaunch", Bat = "HitLaunch", Hammer = "BodyLaunch", GoldBar = "BodyLaunch" }
-- A home run's finishing sound, for the whole screen, over the weapon's thump (a different recording from it).
local SMASHES: { [string]: string? } = { Fist = "BodyLaunch", Bat = "HomeRun", Hammer = "BodyLaunch", GoldBar = "BodyLaunch" }

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
	local launch = LAUNCHES[weapon]
	local smash = SMASHES[weapon]
	if body and kind == "launch" and launch then
		SoundBank.play(launch, body.root)
	elseif kind == "smash" then
		-- For the whole screen: the body flies off (and a sandbag is removed) mid-sound.
		if smash then
			SoundBank.play(smash)
		end
		SoundBank.play("FlyOff")
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
