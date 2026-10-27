--!strict
-- How hits feel on this client: a whoosh when someone attacks (each weapon's own: a punch, a bat's swing, a hammer's
-- heavy swing, a gold bar's, a throw; a string's launching last step deeper and longer), and for a hit a thump at the
-- victim (each weapon's own: a punch, a bat, a hammer's slam, a gold bar's clang; a dynamite blast is heard from
-- ExplosionShow), a hard white flash on them (all white for a frame or two, then gone), and a camera kick: the player
-- hit is knocked the way the hit pushed (harder and with the view narrowing for a moment on a launch or smash), the
-- player who hit gets a small push toward the blow (bigger, with the view narrowing a little, when it launches). A
-- launch adds a heavier layer (the bat's whack, a heavy body
-- blow for the rest), a home run (the smash that empties health) a finishing sound for the whole screen over the
-- weapon's own thump (the bat's crack, a heavy blow for the rest: never the thump's own recording twice) and a cartoon
-- slide whistle as the body flies off (its flight is HomeRunShow's). The player's own swing shows
-- its hits at once (predict), and the server's word for the same hit then shows only what it adds; a fighter just
-- launched cannot be hit for a moment (Config.Hit.LaunchImmune), so no hit is predicted on it then. Sounds:
-- Config.Sounds through SoundBank.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local SoundBank = require(shared:WaitForChild("SoundBank"))

local HitFeedback = {}

-- Fighters launched lately, until when they cannot be hit (os.clock), from the server's word.
local unhittable: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- The camera kick running now: which way (world), how far at its peak, when it started, how much the view narrows,
-- and the view's own width (kept while any narrowing is on, so it always comes back).
local kick = { dir = Vector3.zero, studs = 0, start = -math.huge, fov = 0, baseFov = 70, narrowed = false }
local PEAK = 0.2 -- the kick is out at its farthest this share of the way through

local function flash(model: Model)
	local f = Config.Feedback
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	local fade = TweenInfo.new(f.FlashFade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, f.FlashHold)
	TweenService:Create(highlight, fade, { FillTransparency = 1 }):Play()
	Debris:AddItem(highlight, f.FlashHold + f.FlashFade + 0.02)
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

-- How far out the kick is, 0..1, `s` of the way through: out fast, then easing back.
local function kickAmount(s: number): number
	if s < 0 or s >= 1 then
		return 0
	end
	return if s < PEAK then s / PEAK else (1 - (s - PEAK) / (1 - PEAK)) ^ 2
end

-- Starts a camera kick along world `dir`, `studs` at its peak, narrowing the view `fov` degrees. A kick arriving while
-- one is still out carries on from where that one is (no jump back to the middle, nor out to the new peak at once:
-- it starts part way along its way out) and reaches the larger of the two, with the larger narrowing (the old one's
-- whole reach while it is still on its way out).
local function startKick(dir: Vector3, studs: number, fov: number)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 or studs <= 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	local s = (now - kick.start) / Config.Feedback.KickSeconds
	local before = kickAmount(s)
	local rising = s >= 0 and s < PEAK -- the kick running now is still on its way out
	if not kick.narrowed then
		kick.baseFov = camera.FieldOfView -- no narrowing on: this is the real width
	end
	local carried = kick.dir * kick.studs * before
	local wanted = flat.Unit * studs
	local both = carried + wanted
	kick.dir = if both.Magnitude > 1e-3 then both.Unit else flat.Unit
	local reach = math.max(studs, if rising then kick.studs else carried.Magnitude)
	kick.fov = math.max(fov, if rising then kick.fov else kick.fov * before)
	kick.studs = reach
	-- Start where the view is now along the new kick's way out (from the middle when nothing is out).
	kick.start = now - PEAK * Config.Feedback.KickSeconds * math.clamp(carried.Magnitude / reach, 0, 1)
	kick.narrowed = kick.narrowed or kick.fov > 0
end

-- The attacker's own kick toward a blow of `kind` it landed along `dir`: small, bigger with the view narrowing a
-- little when it launches.
local function dealt(dir: Vector3, kind: string)
	local f = Config.Feedback
	if kind == "light" then
		startKick(dir, f.KickStuds.dealt, 0)
	else
		startKick(dir, f.KickStuds.dealtLaunch, f.DealtFov)
	end
end

-- Someone attacks with `weapon` (any character); `finisher`: the launching last step of a string.
function HitFeedback.swing(model: Model, weapon: string, finisher: boolean)
	local body = CharacterParts.body(model)
	local whoosh = WHOOSHES[weapon]
	if body and whoosh then
		-- Deeper and longer for the big one (still a little different each time).
		SoundBank.play(whoosh, body.root, if finisher then 0.8 * (0.96 + math.random() * 0.08) else nil)
	end
end

-- The player's own attack with `weapon` hit this victim, as this client saw it, from `from` (the player's position),
-- as a hit of `kind` ("light" or "launch"). Returns whether it was shown (not while the victim cannot be hit).
function HitFeedback.predict(victim: Model, weapon: string, from: Vector3, kind: string): boolean
	local endsAt = unhittable[victim]
	if endsAt and os.clock() < endsAt then
		return false -- just launched: the server will not take this hit
	end
	show(victim, weapon)
	local body = CharacterParts.body(victim)
	if body then
		dealt(body.root.Position - from, kind)
	end
	return true
end

-- The server's word on a hit. seen: this client showed it already from the player's own attack (OwnSwing knows); mine:
-- the attacker is the player; me: the victim is the player; kind: "light", "launch" or "smash"; weapon: what hit; push:
-- the knock's velocity. Returns whether the plain hit (thump, flash) was shown now - not when it was seen already.
function HitFeedback.hit(victim: Model, seen: boolean, mine: boolean, me: boolean, kind: string, weapon: string, push: Vector3?): boolean
	if kind == "launch" then
		unhittable[victim] = os.clock() + Config.Hit.LaunchImmune
	end
	-- The player's own hit shown at once: what the kind adds is shown now either way.
	local shownNow = not seen
	if shownNow then
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
	if me and push then
		startKick(push, Config.Feedback.KickStuds[kind] or 0, if kind == "light" then 0 else Config.Feedback.FovPunch)
	elseif mine and shownNow and push then
		dealt(push, kind) -- a hit this client did not show at once (a slam, a blast)
	end
	return shownNow
end

-- Every frame, after the camera has moved: the kick running now. A push across the view moves the camera sideways and
-- tilts it a little; a push along the view (hit from the front or behind) dips it instead of sliding it forward or
-- back, which the narrowing would cancel out. The view's width always comes back when the kick ends.
function HitFeedback.update()
	local camera = Workspace.CurrentCamera
	local s = (os.clock() - kick.start) / Config.Feedback.KickSeconds
	local amount = kickAmount(s)
	if amount <= 0 then
		if kick.narrowed and s >= 1 then
			camera.FieldOfView = kick.baseFov
			kick.narrowed, kick.fov = false, 0
		end
		return
	end
	local frame = camera.CFrame
	local across = kick.dir:Dot(frame.RightVector)
	local along = kick.dir:Dot(frame.LookVector)
	local offset = frame.RightVector * across - frame.UpVector * (0.6 * math.abs(along)) + frame.LookVector * (0.25 * along)
	camera.CFrame = (frame + offset * kick.studs * amount) * CFrame.Angles(0, 0, math.rad(-4 * across * amount))
	if kick.narrowed then
		camera.FieldOfView = kick.baseFov - kick.fov * amount
	end
end

return HitFeedback
