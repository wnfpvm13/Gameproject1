--!strict
-- Train brawl client entry point: only wiring. The trackside and the canyon slide past (Scenery, Canyon), the cars,
-- locomotives (their rods turning, chimneys smoking) and the stands are dressed (CarDecor, LocomotiveDecor, Stands:
-- drawn only, on top of what the server built); the mouse is locked with a shoulder
-- camera unless the player shows the cursor (AimLock); the attack control (SwingInput) starts the player's own attack
-- with fists or the weapon held (OwnSwing: drawn at once by SwingPose, SwingTrail and HitFeedback, the character
-- stepping in (BodyMotion.lunge), judged by the server; a mouse click attacks only while the mouse is locked); every
-- character's attacks are drawn from their Names.SwingAt (with a streak behind each blow: SwingTrail); what
-- everyone holds shows (WeaponHud), crates and lit sticks are heard (DropShow), where a stick will burst and a crate
-- will land is drawn on the roofs (GroundMarks), dynamite bursts show (ExplosionShow) (the roof wind, WindDust, is not
-- built for now: nearly invisible in Studio, to be redone - docs/FEEL_REVIEW_2026-10-26.md);
-- a hit from the server flinches or
-- launches the player's own character (KnockFlight) and is shown for everyone (HitFeedback with the camera kick, a
-- flinch or flail pose and the attacker's hold in SwingPose, a hit spark from ImpactBurst, a launch's streak and
-- landing dust from LaunchShow; a home run also HomeRunShow); a fall lays the player down behind the train (FallDrift); health shows over heads and at the bottom
-- (HealthBars), the round at the top (RoundHud) with the knock-off feed under it (FeedHud) and the round's sound
-- (RoundAudio), the first-ride card shows the controls once (RideCard), and a player who is out watches the others from the stands (SpectateCam; a home-run flight or a fall
-- is watched first).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local SoundBank = require(shared:WaitForChild("SoundBank"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local AttackString = require(shared:WaitForChild("AttackString"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local BodyMotion = require(shared:WaitForChild("BodyMotion"))
local Scenery = require(script:WaitForChild("Scenery"))
local Canyon = require(script:WaitForChild("Canyon"))
local CarDecor = require(script:WaitForChild("CarDecor"))
local LocomotiveDecor = require(script:WaitForChild("LocomotiveDecor"))
local Stands = require(script:WaitForChild("Stands"))
local SwingInput = require(script:WaitForChild("SwingInput"))
local SwingPose = require(script:WaitForChild("SwingPose"))
local SwingTrail = require(script:WaitForChild("SwingTrail"))
local OwnSwing = require(script:WaitForChild("OwnSwing"))
local KnockFlight = require(script:WaitForChild("KnockFlight"))
local HitFeedback = require(script:WaitForChild("HitFeedback"))
local FallDrift = require(script:WaitForChild("FallDrift"))
local RoundHud = require(script:WaitForChild("RoundHud"))
local SpectateCam = require(script:WaitForChild("SpectateCam"))
local AimLock = require(script:WaitForChild("AimLock"))
local HealthBars = require(script:WaitForChild("HealthBars"))
local HomeRunShow = require(script:WaitForChild("HomeRunShow"))
local FeedHud = require(script:WaitForChild("FeedHud"))
local RoundAudio = require(script:WaitForChild("RoundAudio"))
local WeaponHud = require(script:WaitForChild("WeaponHud"))
local DropShow = require(script:WaitForChild("DropShow"))
local ExplosionShow = require(script:WaitForChild("ExplosionShow"))
local ImpactBurst = require(script:WaitForChild("ImpactBurst"))
local LaunchShow = require(script:WaitForChild("LaunchShow"))
local GroundMarks = require(script:WaitForChild("GroundMarks"))
local RideCard = require(script:WaitForChild("RideCard"))

local player = Players.LocalPlayer
local remotes = shared:WaitForChild(Names.RemotesFolder)
local swingRemote = remotes:WaitForChild(Names.SwingRemote) :: RemoteEvent
local hitRemote = remotes:WaitForChild(Names.HitRemote) :: RemoteEvent
local feedRemote = remotes:WaitForChild(Names.FeedRemote) :: RemoteEvent
local blastRemote = remotes:WaitForChild(Names.BlastRemote) :: RemoteEvent

SoundBank.preload()
-- The same arena the server built (ArenaLayout is pure math from the shared Config).
local layout = ArenaLayout.layout(Config.Arena, Config.Fall.Margin)
local scenery = Scenery.new(layout)
local canyon = Canyon.new()
CarDecor.build(layout)
local locomotives = LocomotiveDecor.new(layout)
Stands.build()
local knock = KnockFlight.new()
local drift = FallDrift.new(layout.fallLine)
local playerGui = player:WaitForChild("PlayerGui")
local hud = RoundHud.new(playerGui)
local spectate = SpectateCam.new()
local aim = AimLock.new(playerGui)
local bars = HealthBars.new(playerGui)
local feed = FeedHud.new(playerGui)
local audio = RoundAudio.new(playerGui)
local weaponHud = WeaponHud.new(playerGui)
local card = RideCard.new(playerGui)
DropShow.start(Workspace:WaitForChild(Names.CratesFolder), Workspace:WaitForChild(Names.ArenaFolder))
GroundMarks.start({ Workspace:WaitForChild(Names.ArenaFolder), Workspace:WaitForChild(Names.CratesFolder) })

-- The characters still in the round, as this client sees them (players' and sandbags').
local function fighters(): { Model }
	local list = {}
	for _, other in Players:GetPlayers() do
		local model = other.Character
		if model and model:GetAttribute(Names.Alive) == true then
			table.insert(list, model)
		end
	end
	for _, model in CollectionService:GetTagged(Names.SandbagTag) do
		if model:IsA("Model") and model:GetAttribute(Names.Alive) == true then
			table.insert(list, model)
		end
	end
	return list
end

local STRING = AttackString.rules(Config.Attack)
-- How big each kind of hit burst is, to tell a server's word that made the player's own hit bigger than shown.
local BURST_SIZE: { [string]: number } = { light = 1, launch = 2, crowd = 3 }

local own = OwnSwing.new(swingRemote, {
	fighters = fighters,
	stunned = function(): boolean
		return knock:stunned()
	end,
	launched = function(): boolean
		return knock:launched()
	end,
	draw = function(model: Model, at: number, weapon: string, step: number)
		SwingPose.play(model, at, weapon, step)
		SwingTrail.play(model, weapon, step, at)
		HitFeedback.swing(model, weapon, AttackString.launches(STRING, step, Config.Weapons[weapon].style))
	end,
	lunge = function(model: Model, facing: Vector3, weapon: string, step: number)
		local body = CharacterParts.body(model)
		local style = Config.Weapons[weapon].style
		if body then
			BodyMotion.lunge(body, facing, WeaponRules.lunge(style, AttackString.launches(STRING, step, style), Config.Attack))
		end
	end,
	restep = SwingPose.restep,
	predict = function(victim: Model, weapon: string, finisher: boolean): string?
		local character = player.Character
		local from = if character then character:GetPivot().Position else victim:GetPivot().Position
		local kind = if finisher then "launch" else "light"
		if not HitFeedback.predict(victim, weapon, from, kind) then
			return nil
		end
		ImpactBurst.play(ImpactBurst.at(victim, from), kind, weapon, victim:GetPivot().Position - from)
		if character then
			SwingPose.hold(character, Config.Feedback.AttackerHold[kind])
		end
		return kind
	end,
})
SwingInput.bind(function(mouse: boolean)
	if not mouse or aim:clickSwings() then
		own:press(player.Character)
	end
end)

-- Every character's attacks, drawn from the server's word (the player's own was drawn when pressed).
local function follow(model: Model)
	SwingPose.follow(model, function(_at: number, step: number): boolean
		local tag = if model == player.Character then model:GetAttribute(Names.SwingTag) else nil
		if typeof(tag) == "number" and own:drawn(tag) then
			own:settle(tag, step) -- count on from the server's step (and redraw) if it counted differently
			return true
		end
		return false
	end, function(weapon: string, step: number, at: number)
		SwingTrail.play(model, weapon, step, at)
		HitFeedback.swing(model, weapon, AttackString.launches(STRING, step, Config.Weapons[weapon].style))
	end)
end
local function onPlayer(other: Player)
	other.CharacterAdded:Connect(follow)
	if other.Character then
		follow(other.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, other in Players:GetPlayers() do
	onPlayer(other)
end
CollectionService:GetInstanceAddedSignal(Names.SandbagTag):Connect(function(instance)
	if instance:IsA("Model") then
		follow(instance)
	end
end)
for _, instance in CollectionService:GetTagged(Names.SandbagTag) do
	if instance:IsA("Model") then
		follow(instance)
	end
end

-- A hit, from the server: the victim's own client knocks it; everyone shows it.
hitRemote.OnClientEvent:Connect(function(victim: unknown, velocity: unknown, swinger: unknown, kind: unknown, weapon: unknown, ganged: unknown, tag: unknown)
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then
		return
	end
	local hitKind = if typeof(kind) == "string" then kind else "launch"
	local push = if typeof(velocity) == "Vector3" then velocity else nil
	local me = victim == player.Character
	if me and push then
		knock:hit(victim, push, hitKind)
		own:broken() -- being hit breaks the player's own string, as on the server
	end
	SwingPose.react(victim, hitKind, push)
	local hitWeapon = if typeof(weapon) == "string" then weapon else WeaponRules.FIST
	local mine = swinger == player.Character
	-- What this screen showed at once for that attack of the player's on this victim (nil: nothing), and whether it is
	-- the attack drawn now.
	local guess, latest = nil, false
	if mine then
		guess, latest = own:serverHit(if typeof(tag) == "number" then tag else nil, victim)
	end
	local shown = HitFeedback.hit(victim, guess ~= nil, mine, me, hitKind, hitWeapon, push)
	local attacker = if typeof(swinger) == "Instance" and swinger:IsA("Model") then swinger else nil
	local thrown = Config.Weapons[hitWeapon] ~= nil and Config.Weapons[hitWeapon].style == "throw"
	local burst = if ganged == true then "crowd" elseif hitKind == "light" then "light" else "launch"
	-- The player's own hit shown at once as a lighter one than the server made it (a crowd's launch, or a light hit
	-- that emptied health: a home run) shows the bigger burst now too.
	local bigger = guess ~= nil and BURST_SIZE[burst] > (BURST_SIZE[guess] or 0)
	if shown or bigger then
		-- A blast's burst is on the victim (its thrower is far away); a blow's toward whoever struck it.
		local from = if attacker and not thrown then attacker:GetPivot().Position else nil
		ImpactBurst.play(ImpactBurst.at(victim, from), burst, hitWeapon, push)
	end
	if attacker and not thrown and (latest or not mine) then
		-- One hold per attack, as long as the longest: the player's own hit held at once is held longer when the server
		-- made it bigger (a home run off the third). A thrower is long done, and a word on an older attack of the
		-- player's comes while the next one is drawn (it is not held for this).
		SwingPose.hold(attacker, Config.Feedback.AttackerHold[hitKind] or 0)
	end
	if hitKind == "launch" then
		LaunchShow.play(victim)
	end
	if hitKind == "smash" then
		HomeRunShow.play(victim, function(at: Vector3)
			ImpactBurst.play(at, "launch", WeaponRules.FIST, nil) -- the twinkle the flight ends in
		end)
	end
end)

-- A dynamite burst, from the server.
blastRemote.OnClientEvent:Connect(function(at: unknown, radius: unknown)
	if typeof(at) == "Vector3" and typeof(radius) == "number" then
		ExplosionShow.play(at, radius)
	end
end)

-- A knock-out, from the server: a line in the feed.
feedRemote.OnClientEvent:Connect(function(victim: unknown, by: unknown, how: unknown)
	if typeof(victim) == "string" and typeof(how) == "string" then
		feed:add(victim, if typeof(by) == "string" then by else nil, how)
	end
end)

RunService.RenderStepped:Connect(function(dt: number)
	local list = fighters()
	scenery:update(dt)
	canyon:update(dt)
	locomotives:update(dt, list)
	knock:update()
	local character = player.Character
	own:update(character) -- a press kept from a moment ago, once the weapon is ready or a flinch is over
	drift:update(character, knock:launched())
	local state = if character then character:GetAttribute(Names.Alive) else nil
	local alive = state == true
	spectate:update(Workspace:GetAttribute(Names.Phase) == "Fight" and not alive and not drift:active() and not knock:launched(), character, list)
	bars:update(list, character, os.clock())
	weaponHud:update(list, character, Workspace:GetServerTimeNow())
	feed:update()
	audio:update(Workspace:GetServerTimeNow())
	local standing = if alive then "in" elseif state == false then "out" else "watching"
	hud:update(Workspace:GetServerTimeNow(), standing, if character then PartUtil.number(character, Names.KOs) or 0 else 0)
	local phase = Workspace:GetAttribute(Names.Phase)
	card:update(if typeof(phase) == "string" then phase else "Waiting", alive)
end)
-- After the camera has moved for the frame: the mouse lock (the Roblox camera resets the mouse every frame), then the
-- camera kick for a hit.
RunService:BindToRenderStep("TrainBrawlAim", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local character = player.Character
	local camera = Workspace.CurrentCamera
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local onSelf = humanoid ~= nil and camera.CameraSubject == humanoid
	aim:update(character, onSelf and not drift:active(), not knock:stunned(), dt)
end)
RunService:BindToRenderStep("TrainBrawlKick", Enum.RenderPriority.Camera.Value + 2, HitFeedback.update)
