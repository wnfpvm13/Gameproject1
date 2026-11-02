--!strict
-- Train brawl client entry point: only wiring. The trackside and the canyon slide past (Scenery, Canyon), the cars,
-- locomotives (their rods turning, chimneys smoking) and the stands are dressed (CarDecor, LocomotiveDecor, Stands:
-- drawn only, on top of what the server built); the mouse is locked with a shoulder
-- camera unless the player shows the cursor (AimLock); the attack control (SwingInput) starts the player's own attack
-- with fists or the weapon held (OwnSwing: drawn at once by SwingPose, SwingTrail and HitFeedback, the character
-- stepping in (BodyMotion.lunge), judged by the server; a mouse click attacks only while the mouse is locked); every
-- character's attacks are drawn from their Names.SwingAt (with a streak behind each blow: SwingTrail, and a steam
-- blast, firecrackers' pops or a lasso's rope: AttackShow); what everyone holds shows (WeaponHud), crates, lit sticks,
-- wheels, slicks and coal lumps are heard (DropShow), where a stick will burst and a crate
-- will land is drawn on the roofs (GroundMarks), dynamite bursts show (ExplosionShow) (the roof wind, WindDust, is not
-- built for now: nearly invisible in Studio, to be redone - docs/FEEL_REVIEW_2026-10-26.md);
-- a hit from the server flinches or
-- launches the player's own character (KnockFlight) and is shown for everyone (HitFeedback with the camera kick, a
-- flinch or flail pose and the attacker's hold in SwingPose, a hit spark from ImpactBurst, a launch's streak and
-- blast, tumble trail and landing dust from LaunchShow; a home run also HomeRunShow); a fall lays the player down behind the train (FallDrift); health shows over heads and at the bottom
-- (HealthBars) with the tickets left (TicketHud), the round at the top (RoundHud) with the knock-off feed under it (FeedHud) and the round's sound
-- (RoundAudio), the first-ride card shows the controls once (RideCard), a fighter coming back after a fall drops in under a parachute and
-- shimmers while guarded (ComebackShow), the player's own 1-2-3 string shows by the aim dot (StringHud), crates out of sight get an arrow
-- at the screen's edge (CrateArrows), the block control (BlockInput) raises the guard drawn with a shield (BlockShow; its blocked and
-- broken hits clang in HitFeedback, a hit through it says why), the roll control (DodgeInput) rolls the player at once (OwnDodge:
-- BodyMotion.roll, judged by the server) and everyone's rolls are drawn (DodgeShow) with the cooldown shown (DodgeHud), a roof edge that drops into nothing gets a warning band near the player (EdgeWarning), the player's
-- own numbers are counted (RoundStats) for the line on who knocked it off (RoundHud) and the card at the round's end (ResultCard), a back car
-- coming off is warned of and its dressing follows it (UncoupleShow), accessories pop off as fighters are worn down (AccessoryPop), and a player who is out watches the others from the stands (SpectateCam; a home-run flight or a fall
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
local Words = require(shared:WaitForChild("Words"))
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
local AttackShow = require(script:WaitForChild("AttackShow"))
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
local TicketHud = require(script:WaitForChild("TicketHud"))
local ComebackShow = require(script:WaitForChild("ComebackShow"))
local StringHud = require(script:WaitForChild("StringHud"))
local CrateArrows = require(script:WaitForChild("CrateArrows"))
local BlockInput = require(script:WaitForChild("BlockInput"))
local BlockShow = require(script:WaitForChild("BlockShow"))
local BlockRules = require(shared:WaitForChild("BlockRules"))
local EdgeWarning = require(script:WaitForChild("EdgeWarning"))
local RoundStats = require(script:WaitForChild("RoundStats"))
local ResultCard = require(script:WaitForChild("ResultCard"))
local UncoupleShow = require(script:WaitForChild("UncoupleShow"))
local AccessoryPop = require(script:WaitForChild("AccessoryPop"))
local DodgeInput = require(script:WaitForChild("DodgeInput"))
local OwnDodge = require(script:WaitForChild("OwnDodge"))
local DodgeShow = require(script:WaitForChild("DodgeShow"))
local DodgeHud = require(script:WaitForChild("DodgeHud"))

local player = Players.LocalPlayer
local remotes = shared:WaitForChild(Names.RemotesFolder)
local swingRemote = remotes:WaitForChild(Names.SwingRemote) :: RemoteEvent
local hitRemote = remotes:WaitForChild(Names.HitRemote) :: RemoteEvent
local feedRemote = remotes:WaitForChild(Names.FeedRemote) :: RemoteEvent
local blastRemote = remotes:WaitForChild(Names.BlastRemote) :: RemoteEvent
local blockRemote = remotes:WaitForChild(Names.BlockRemote) :: RemoteEvent
local dodgeRemote = remotes:WaitForChild(Names.DodgeRemote) :: RemoteEvent

SoundBank.preload()
-- The same arena the server built (ArenaLayout is pure math from the shared Config).
local layout = ArenaLayout.layout(Config.Arena, Config.Fall.Margin)
local scenery = Scenery.new(layout)
local canyon = Canyon.new()
local carDecor = CarDecor.build(layout)
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
local tickets = TicketHud.new(playerGui)
local stringHud = StringHud.new(playerGui)
local crateArrows = CrateArrows.new(playerGui, Workspace:WaitForChild(Names.CratesFolder))
local edges = EdgeWarning.new(layout)
local stats = RoundStats.new()
local results = ResultCard.new(playerGui)
local pops = AccessoryPop.new()
local dodgeHud = DodgeHud.new(playerGui)
local uncoupling = UncoupleShow.new(playerGui, Workspace:WaitForChild(Names.ArenaFolder), carDecor, layout)
local function away(train: number, car: number): boolean
	return uncoupling:away(train, car)
end
DropShow.start(Workspace:WaitForChild(Names.CratesFolder), Workspace:WaitForChild(Names.ArenaFolder))
GroundMarks.start({ Workspace:WaitForChild(Names.ArenaFolder), Workspace:WaitForChild(Names.CratesFolder) })

-- The characters still in the round, as this client sees them (players' and sandbags'), those on their way back after
-- a fall too.
local function everyone(): { Model }
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

-- Of those, the ones on the trains (not on their way back): the ones to hit, follow and show bars over.
local function onTrains(list: { Model }): { Model }
	local on = {}
	for _, model in list do
		if model:GetAttribute(Names.ReturnPhase) == nil then
			table.insert(on, model)
		end
	end
	return on
end

local function fighters(): { Model }
	return onTrains(everyone())
end

local STRING = AttackString.rules(Config.Attack)
local guard = BlockInput.bind(blockRemote)
-- A roll drawn: the tucked turn, a low swoosh, a puff of dust where it starts.
local function drawRoll(model: Model, at: number, direction: Vector3)
	SwingPose.roll(model, at, direction)
	local body = CharacterParts.body(model)
	if body then
		SoundBank.play("Roll", body.root, 0.85)
		local p = body.root.Position
		LaunchShow.dust(Vector3.new(p.X, CharacterParts.feetY(body), p.Z), 6)
	end
end
local rolls = DodgeShow.new(drawRoll)
-- The player's own roll: when it fights on the trains (not on its way back) and no hit stuns it.
local dodge = OwnDodge.new(dodgeRemote, {
	may = function(): boolean
		local character = player.Character
		return Workspace:GetAttribute(Names.Phase) == "Fight" and character ~= nil and character:GetAttribute(Names.Alive) == true
			and character:GetAttribute(Names.ReturnPhase) == nil
	end,
	stunned = function(): boolean
		return knock:stunned()
	end,
	roll = function(model: Model, at: number, direction: Vector3)
		local body = CharacterParts.body(model)
		if body then
			BodyMotion.roll(body, direction)
		end
		drawRoll(model, at, direction)
	end,
})
local dodgeInput = DodgeInput.bind(function()
	dodge:press(player.Character)
end)

-- Whether `victim` blocks an attack with `weapon` from `from` now, as this client sees it (BlockRules, as the server
-- judges it).
local function blocks(victim: Model, weapon: string, from: Vector3): boolean
	if victim:GetAttribute(Names.Blocking) ~= true or not BlockRules.blockable(Config.Weapons[weapon].launch) then
		return false
	end
	local at = victim:GetPivot()
	return BlockRules.covers(at.Position.X, at.Position.Z, at.LookVector.X, at.LookVector.Z, from.X, from.Z, Config.Block.Arc)
end
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
	blocking = function(): boolean
		return guard:held() or dodge:busy(Workspace:GetServerTimeNow()) -- (no attacking mid-roll either)
	end,
	draw = function(model: Model, at: number, weapon: string, step: number)
		SwingPose.play(model, at, weapon, step)
		SwingTrail.play(model, weapon, step, at)
		AttackShow.play(model, weapon, step, at)
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
		if blocks(victim, weapon, from) then
			-- On the block: its clang and the shield's flash at once instead of the hit (a third breaks the guard).
			local met = if finisher then "broken" else "blocked"
			if not HitFeedback.guarded(victim, met, false, true, victim:GetPivot().Position - from) then
				return nil
			end
			BlockShow.hit(victim, met)
			if character then
				SwingPose.hold(character, Config.Feedback.AttackerHold.light)
			end
			return "blocked"
		end
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
		AttackShow.play(model, weapon, step, at)
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
hitRemote.OnClientEvent:Connect(function(victim: unknown, velocity: unknown, swinger: unknown, kind: unknown, weapon: unknown, ganged: unknown, tag: unknown, guarded: unknown)
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then
		return
	end
	local hitKind = if typeof(kind) == "string" then kind else "launch"
	local push = if typeof(velocity) == "Vector3" then velocity else nil
	local me = victim == player.Character
	local hitWeapon = WeaponRules.named(Config.Weapons, weapon)
	local w = Config.Weapons[hitWeapon]
	-- On a block (the server says "blocked" or "broken"): a short flinch (a broken guard: a light hit's).
	local met = if guarded == "blocked" or guarded == "broken" then guarded else nil
	stats:hit(swinger == player.Character, me, met)
	local stun = if met == "blocked" then Config.Block.Stun elseif met == "broken" then Config.Hit.LightStun else w.stun or Config.Hit.LightStun
	if me and push then
		knock:hit(victim, push, hitKind, stun)
		own:broken() -- being hit breaks the player's own string, as on the server
	end
	local mine = swinger == player.Character
	-- What this screen showed at once for that attack of the player's on this victim (nil: nothing), and whether it is
	-- the attack drawn now.
	local guess, latest = nil, false
	if mine then
		guess, latest = own:serverHit(if typeof(tag) == "number" then tag else nil, victim)
	end
	if met then
		if met == "broken" then
			SwingPose.react(victim, "light", push) -- (a blocked hit keeps the block's pose)
		end
		-- (The player's own attack may have shown it at once; shown as a plain hit, the block still shows now, without a
		-- second kick.)
		if guess ~= "blocked" then
			HitFeedback.guarded(victim, met, me, mine and guess == nil, push)
			BlockShow.hit(victim, met)
		end
		local by = if typeof(swinger) == "Instance" and swinger:IsA("Model") then swinger else nil
		if by and not WeaponRules.fromAfar(w.style) and (latest or not mine) then
			SwingPose.hold(by, Config.Feedback.AttackerHold.light or 0)
		end
		return
	end
	-- A hit through a block: why (from the side, from behind, a weapon no block stops).
	local hitter = if typeof(swinger) == "Instance" and swinger:IsA("Model") then swinger else nil
	if hitter and victim:GetAttribute(Names.Blocking) == true then
		local at, from = victim:GetPivot(), hitter:GetPivot().Position
		local why = BlockRules.through(BlockRules.blockable(w.launch), at.Position.X, at.Position.Z, at.LookVector.X, at.LookVector.Z, from.X, from.Z, Config.Block.Arc)
		if why then
			BlockShow.through(victim, why)
		end
	end
	SwingPose.react(victim, hitKind, push)
	-- (Shown at once as met by a block that the server says was not: the plain hit shows now.)
	local shown = HitFeedback.hit(victim, guess ~= nil and guess ~= "blocked", mine, me, hitKind, hitWeapon, push)
	local attacker = if typeof(swinger) == "Instance" and swinger:IsA("Model") then swinger else nil
	local thrown = WeaponRules.fromAfar(w.style)
	if w.pull and attacker and hitKind == "light" then
		AttackShow.caught(attacker, victim, stun) -- a lasso's catch: pulled in and tied
	end
	local burst = if ganged == true then "crowd" elseif hitKind == "light" then "light" else "launch"
	-- The player's own hit shown at once as a lighter one than the server made it (a crowd's launch, or a light hit
	-- that emptied health: a home run) shows the bigger burst now too.
	local bigger = guess ~= nil and BURST_SIZE[burst] > (BURST_SIZE[guess] or 0)
	if shown or bigger then
		-- A burst from afar (a blast, a lump, a wheel, a slick) is on the victim; a blow's toward whoever struck it.
		local from = if attacker and not thrown then attacker:GetPivot().Position else nil
		ImpactBurst.play(ImpactBurst.at(victim, from), burst, hitWeapon, push)
	end
	if attacker and not thrown and (latest or not mine) then
		-- One hold per attack, as long as the longest: the player's own hit held at once is held longer when the server
		-- made it bigger (a home run off the third). A thrower is long done, and a word on an older attack of the
		-- player's comes while the next one is drawn (it is not held for this).
		SwingPose.hold(attacker, Config.Feedback.AttackerHold[hitKind] or 0)
	end
	if hitKind ~= "light" then
		-- It goes off like a blast where it was hit (a home run bigger).
		LaunchShow.blast(victim:GetPivot().Position, push, hitKind == "smash")
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
feedRemote.OnClientEvent:Connect(function(victim: unknown, by: unknown, how: unknown, out: unknown, streak: unknown)
	if typeof(victim) == "string" and typeof(how) == "string" then
		local credited = if typeof(by) == "string" then by else nil
		local row = if typeof(streak) == "number" then streak else 0
		feed:add(victim, credited, how, out ~= false, row)
		-- (Names as shown: the feed carries display names.)
		local byMe = credited == player.DisplayName
		local hits = stats:feed(credited, byMe, victim == player.DisplayName, how, out ~= false)
		if hits then
			hud:knockedOff(Words.knockedOff(credited, how, hits))
		end
		if byMe and how == "homerun" and row >= 2 then
			hud:callout(Words.homerunStreak(row))
		end
	end
end)

RunService.RenderStepped:Connect(function(dt: number)
	local all = everyone()
	local list = onTrains(all)
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
	tickets:update(list, character)
	ComebackShow.update(all)
	BlockShow.update(all)
	rolls:update(all, function(model: Model, at: number): boolean
		local mine = dodge:rolledAt()
		return model == player.Character and mine ~= nil and math.abs(at - mine) < 1 -- drawn when pressed
	end)
	weaponHud:update(list, character, Workspace:GetServerTimeNow())
	feed:update()
	audio:update(Workspace:GetServerTimeNow())
	local back = alive and character ~= nil and character:GetAttribute(Names.ReturnPhase) ~= nil
	local serverNow = Workspace:GetServerTimeNow()
	local holding = WeaponRules.named(Config.Weapons, if character then character:GetAttribute(Names.Weapon) else nil)
	local stringing = Workspace:GetAttribute(Names.Phase) == "Fight" and alive and not back and AttackString.uses(Config.Weapons[holding].style)
	stringHud:update(own:stringView(serverNow, holding), stringing, Config.Attack.StringGap, serverNow, os.clock(), character)
	crateArrows:update(Workspace:GetAttribute(Names.Phase) == "Fight" and alive and not back)
	local rollWait = dodge:wait(serverNow)
	dodgeHud:update(Workspace:GetAttribute(Names.Phase) == "Fight" and alive and not back, rollWait)
	dodgeInput:show(rollWait)
	uncoupling:update()
	edges:update(character, Workspace:GetAttribute(Names.Phase) == "Fight" and alive and not back, away)
	local phaseNow = Workspace:GetAttribute(Names.Phase)
	local phaseName = if typeof(phaseNow) == "string" then phaseNow else "Waiting"
	stats:update(phaseName, alive)
	pops:update(all, phaseName)
	results:update(phaseName, stats:summary(character, player.DisplayName))
	local standing = if back then "back" elseif alive then "in" elseif state == false then "out" else "watching"
	hud:update(Workspace:GetServerTimeNow(), standing, if character then PartUtil.number(character, Names.KOs) or 0 else 0, character)
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
