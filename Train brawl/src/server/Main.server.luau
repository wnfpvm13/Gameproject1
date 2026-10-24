--!strict
-- Train brawl server entry point: only wiring. The arena is built once (ArenaBuilder); rounds run on their own
-- (RoundService); swings are judged by BatService; falls are noticed by FallWatch and end that fighter's round, as
-- does a home run (health emptied, kept by FighterHealth); knock-offs go to every client as a feed;
-- every character gets a bat (BatGear). For testing alone in Studio, the Workspace attribute Names.Solo makes
-- sandbags (Sandbags) join every round as fighters.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent:WaitForChild("Net"))
local ArenaBuilder = require(script.Parent:WaitForChild("ArenaBuilder"))
local BatGear = require(script.Parent:WaitForChild("BatGear"))
local Sandbags = require(script.Parent:WaitForChild("Sandbags"))
local FighterHealth = require(script.Parent:WaitForChild("FighterHealth"))
local FallWatch = require(script.Parent:WaitForChild("FallWatch"))
local BatService = require(script.Parent:WaitForChild("BatService"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))
local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))

local remotes = Net.create()
local arena = ArenaBuilder.build()
local sandbags = Sandbags.start(arena.fallLine)
local health = FighterHealth.start()

local function equip(model: Model)
	if not BatGear.equip(model) then
		warn("[TrainBrawl] no hand to hold a bat on " .. model.Name)
	end
end

local round = RoundService.start(arena.spots, arena.waitingSpot, {
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

BatService.start(remotes.Swing, remotes.Hit, {
	canSwing = round.isFighting,
	fighters = round.fighters,
	hit = health.hit,
	knockHere = sandbags.knock,
	onHit = round.noteHit,
	onSmash = function(victim: Model)
		round.eliminate(victim, "homerun")
	end,
})

local function onCharacter(model: Model)
	if model:WaitForChild("RightHand", 10) or model:FindFirstChild("Right Arm") then
		equip(model)
	end
end
local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	-- The avatar's own body parts arrive after the character and replace the default hand: the bat goes on again.
	player.CharacterAppearanceLoaded:Connect(equip)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
