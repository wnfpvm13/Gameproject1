--!strict
-- Train brawl client entry point: only wiring. The scenery slides past (Scenery); the swing control (SwingInput)
-- starts the player's own swing (OwnSwing: drawn at once by SwingPose and HitFeedback, judged by the server); every
-- character's swings are drawn from their Names.SwingAt; a hit from the server knocks the player's own character
-- (KnockFlight) and is shown for everyone (HitFeedback); a fall lays the player down behind the train (FallDrift); the
-- round shows at the top (RoundHud), and a player who is out watches the others from the stands (SpectateCam; the
-- fall itself is watched first).
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
local Scenery = require(script:WaitForChild("Scenery"))
local SwingInput = require(script:WaitForChild("SwingInput"))
local SwingPose = require(script:WaitForChild("SwingPose"))
local OwnSwing = require(script:WaitForChild("OwnSwing"))
local KnockFlight = require(script:WaitForChild("KnockFlight"))
local HitFeedback = require(script:WaitForChild("HitFeedback"))
local FallDrift = require(script:WaitForChild("FallDrift"))
local RoundHud = require(script:WaitForChild("RoundHud"))
local SpectateCam = require(script:WaitForChild("SpectateCam"))

local player = Players.LocalPlayer
local remotes = shared:WaitForChild(Names.RemotesFolder)
local swingRemote = remotes:WaitForChild(Names.SwingRemote) :: RemoteEvent
local hitRemote = remotes:WaitForChild(Names.HitRemote) :: RemoteEvent

local scenery = Scenery.new()
local knock = KnockFlight.new()
local drift = FallDrift.new(ArenaLayout.fallLine(ArenaLayout.carPlaces(Config.Arena.Cars, Config.Arena.CarGap), Config.Fall.Margin))
local hud = RoundHud.new(player:WaitForChild("PlayerGui"))
local spectate = SpectateCam.new()

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
	flying = function(): boolean
		return knock:flying()
	end,
	draw = function(model: Model, at: number)
		SwingPose.play(model, at)
		HitFeedback.swing(model)
	end,
	predict = HitFeedback.predict,
})
SwingInput.bind(function()
	own:press(player.Character)
end)

-- Every character's swings, drawn from the server's word (the player's own was drawn when pressed).
local function follow(model: Model)
	SwingPose.follow(model, function(at: number): boolean
		if model == player.Character and own:drawn(at) then
			return true
		end
		HitFeedback.swing(model)
		return false
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
hitRemote.OnClientEvent:Connect(function(victim: unknown, velocity: unknown, swinger: unknown)
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then
		return
	end
	local me = victim == player.Character
	if me and typeof(velocity) == "Vector3" then
		knock:knock(victim, velocity)
	end
	HitFeedback.hit(victim, swinger == player.Character, me)
end)

RunService.RenderStepped:Connect(function(dt: number)
	scenery:update(dt)
	knock:update()
	local character = player.Character
	drift:update(character, knock:flying())
	local state = if character then character:GetAttribute(Names.Alive) else nil
	local alive = state == true
	spectate:update(Workspace:GetAttribute(Names.Phase) == "Fight" and not alive and not drift:active(), character, fighters())
	local standing = if alive then "in" elseif state == false then "out" else "watching"
	hud:update(Workspace:GetServerTimeNow(), standing, if character then PartUtil.number(character, Names.KOs) or 0 else 0)
end)
-- After the camera has moved for the frame: the shake for a hit on the player.
RunService:BindToRenderStep("TrainBrawlShake", Enum.RenderPriority.Camera.Value + 1, HitFeedback.update)
