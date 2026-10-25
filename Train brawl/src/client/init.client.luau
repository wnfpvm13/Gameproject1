--!strict
-- Train brawl client entry point: only wiring. The trackside and the canyon slide past (Scenery, Canyon), the cars,
-- locomotives (their rods turning, chimneys smoking) and the stands are dressed (CarDecor, LocomotiveDecor, Stands:
-- drawn only, on top of what the server built); the mouse is locked with a shoulder
-- camera unless the player shows the cursor (AimLock); the attack control (SwingInput) starts the player's own attack
-- with fists or the weapon held (OwnSwing: drawn at once by SwingPose and HitFeedback, judged by the server; a mouse
-- click attacks only while the mouse is locked); every character's attacks are drawn from their Names.SwingAt; what
-- everyone holds shows (WeaponHud), crates and lit sticks are heard (DropShow), dynamite bursts show (ExplosionShow);
-- a hit from the server flinches or
-- launches the player's own character (KnockFlight) and is shown for everyone (HitFeedback; a home run also
-- HomeRunShow); a fall lays the player down behind the train (FallDrift); health shows over heads and at the bottom
-- (HealthBars), the round at the top (RoundHud) with the knock-off feed under it (FeedHud) and the round's sound
-- (RoundAudio), and a player who is out watches the others from the stands (SpectateCam; a home-run flight or a fall
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
local Scenery = require(script:WaitForChild("Scenery"))
local Canyon = require(script:WaitForChild("Canyon"))
local CarDecor = require(script:WaitForChild("CarDecor"))
local LocomotiveDecor = require(script:WaitForChild("LocomotiveDecor"))
local Stands = require(script:WaitForChild("Stands"))
local SwingInput = require(script:WaitForChild("SwingInput"))
local SwingPose = require(script:WaitForChild("SwingPose"))
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
DropShow.start(Workspace:WaitForChild(Names.CratesFolder), Workspace:WaitForChild(Names.ArenaFolder))

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

local own = OwnSwing.new(swingRemote, {
	fighters = fighters,
	stunned = function(): boolean
		return knock:stunned()
	end,
	draw = function(model: Model, at: number, weapon: string)
		SwingPose.play(model, at, weapon)
		HitFeedback.swing(model, weapon)
	end,
	predict = HitFeedback.predict,
})
SwingInput.bind(function(mouse: boolean)
	if not mouse or aim:clickSwings() then
		own:press(player.Character)
	end
end)

-- Every character's attacks, drawn from the server's word (the player's own was drawn when pressed).
local function follow(model: Model)
	SwingPose.follow(model, function(at: number): boolean
		return model == player.Character and own:drawn(at)
	end, function(weapon: string)
		HitFeedback.swing(model, weapon)
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
hitRemote.OnClientEvent:Connect(function(victim: unknown, velocity: unknown, swinger: unknown, kind: unknown, weapon: unknown)
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then
		return
	end
	local hitKind = if typeof(kind) == "string" then kind else "launch"
	local me = victim == player.Character
	if me and typeof(velocity) == "Vector3" then
		knock:hit(victim, velocity, hitKind)
	end
	HitFeedback.hit(victim, swinger == player.Character, me, hitKind, if typeof(weapon) == "string" then weapon else WeaponRules.FIST)
	if hitKind == "smash" then
		HomeRunShow.play(victim)
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
end)
-- After the camera has moved for the frame: the mouse lock (the Roblox camera resets the mouse every frame), then the
-- shake for a hit on the player.
RunService:BindToRenderStep("TrainBrawlAim", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local character = player.Character
	local camera = Workspace.CurrentCamera
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local onSelf = humanoid ~= nil and camera.CameraSubject == humanoid
	aim:update(character, onSelf and not drift:active(), not knock:stunned(), dt)
end)
RunService:BindToRenderStep("TrainBrawlShake", Enum.RenderPriority.Camera.Value + 2, HitFeedback.update)
