--!strict
-- Train brawl server entry point: only wiring. The arena is built once (ArenaBuilder); rounds run on their own
-- (RoundService); attacks with fists or a picked-up weapon are judged by WeaponService (a thrown stick burns and
-- bursts in Dynamite); weapon crates drop onto the trains during a fight (WeaponDrops); falls are noticed by FallWatch
-- and end that fighter's round, as does a home run (health emptied, kept by FighterHealth); knock-offs and dynamite
-- bursts go to every client; every character holds its weapon in its hand (WeaponGear), and every player's body is
-- made the standard size with the standard animations (AvatarRules). For testing alone in Studio, the Workspace
-- attribute Names.Solo makes practice bots (bodies: Sandbags, minds: BotBrain) join every round and fight.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent:WaitForChild("Net"))
local ArenaBuilder = require(script.Parent:WaitForChild("ArenaBuilder"))
local WeaponGear = require(script.Parent:WaitForChild("WeaponGear"))
local Sandbags = require(script.Parent:WaitForChild("Sandbags"))
local BotBrain = require(script.Parent:WaitForChild("BotBrain"))
local AvatarRules = require(script.Parent:WaitForChild("AvatarRules"))
local FighterHealth = require(script.Parent:WaitForChild("FighterHealth"))
local FallWatch = require(script.Parent:WaitForChild("FallWatch"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))
local WeaponDrops = require(script.Parent:WaitForChild("WeaponDrops"))
local Dynamite = require(script.Parent:WaitForChild("Dynamite"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))
local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))

local remotes = Net.create()
local arena = ArenaBuilder.build()
-- The bots' minds need the round and the attacks, made below.
local brain: BotBrain.Brain? = nil
local sandbags = Sandbags.start(arena.fallLine, function(model: Model, body, now: number)
	if brain then
		brain.think(model, body, now)
	end
end)
local health = FighterHealth.start()

local function equip(model: Model)
	if not WeaponGear.equip(model) then
		warn("[TrainBrawl] no hand to hold a weapon on " .. model.Name)
	end
end

local round = RoundService.start(arena.spots, #arena.layout.trains, arena.waitingSpot, {
	-- The solo-practice switch only works in Studio, so it can never be left on in the published game.
	sandbagCount = function(): number
		return if RunService:IsStudio() and Workspace:GetAttribute(Names.Solo) == true then Config.Sandbag.Count else 0
	end,
	spawnSandbags = function(count: number): { Model }
		return sandbags.spawn(count, arena.folder, equip)
	end,
	clearSandbags = sandbags.clear,
	resetHealth = health.reset,
	announce = function(victim: string, by: string?, how: string)
		remotes.Feed:FireAllClients(victim, by, how)
	end,
})
FallWatch.start(arena.fallLine, round.fighters, function(model: Model)
	if round.isFighting(model) then -- a winner falling during the result stays the winner
		round.eliminate(model, "fall")
	end
end)

local weapons = WeaponService.start(remotes.Swing, remotes.Hit, {
	canSwing = round.isFighting,
	fighters = round.fighters,
	hit = health.hit,
	knockHere = sandbags.knock,
	onHit = round.noteHit,
	onSmash = function(victim: Model)
		round.eliminate(victim, "homerun")
	end,
	equip = equip,
	throw = function(from: Vector3, facing: Vector3, burst: (Vector3) -> ())
		Dynamite.throw(arena.folder, arena.folder, from, facing, burst)
	end,
	putOut = Dynamite.clear,
	blast = function(at: Vector3, radius: number)
		remotes.Blast:FireAllClients(at, radius)
	end,
})
brain = BotBrain.new(arena.layout.surfaces, {
	fighters = round.fighters,
	attack = weapons.attack,
})
WeaponDrops.start(arena.layout.surfaces, PartUtil.folder(Workspace, Names.CratesFolder), {
	fighters = round.fighters,
	-- Players only (the practice bots do not pick crates up yet), with bare fists.
	canTake = function(model: Model): boolean
		return Players:GetPlayerFromCharacter(model) ~= nil and weapons.holding(model) == WeaponRules.FIST
	end,
	give = weapons.give,
})

local function onCharacter(model: Model)
	if model:WaitForChild("RightHand", 10) or model:FindFirstChild("Right Arm") then
		equip(model)
	end
end
local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	-- The avatar's own body parts arrive after the character and replace the default hand: the body is made standard,
	-- then the weapon goes on again (also for a character that loaded before this ran, as in a Studio test).
	local function onAppearance(model: Model)
		AvatarRules.apply(model)
		equip(model)
	end
	player.CharacterAppearanceLoaded:Connect(onAppearance)
	if player.Character then
		task.spawn(onCharacter, player.Character)
		if player:HasAppearanceLoaded() then
			task.spawn(onAppearance, player.Character)
		end
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
