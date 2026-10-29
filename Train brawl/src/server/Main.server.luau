--!strict
-- Train brawl server entry point: only wiring. The arena is built once (ArenaBuilder); rounds run on their own
-- (RoundService); attacks with fists or a picked-up weapon are judged by WeaponService (a thrown stick burns and
-- bursts in Dynamite; coal lumps fly in Missiles, bowled wheels roll in Wheels, oil slicks lie in Slicks); weapon crates drop onto the trains during a fight (WeaponDrops); falls are noticed by FallWatch
-- and cost that fighter a ticket, as does a home run (health emptied, kept by FighterHealth): with one left it comes
-- back by balloon and parachute (Comebacks, full health, a short guard on landing), with none it is out; a held block
-- softens hits from the front (Guarding, judged in WeaponService); late in a fight the back cars come off (Uncoupling); knock-offs and dynamite
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
local Missiles = require(script.Parent:WaitForChild("Missiles"))
local Wheels = require(script.Parent:WaitForChild("Wheels"))
local Slicks = require(script.Parent:WaitForChild("Slicks"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))
local Comebacks = require(script.Parent:WaitForChild("Comebacks"))
local Guarding = require(script.Parent:WaitForChild("Guarding"))
local Uncoupling = require(script.Parent:WaitForChild("Uncoupling"))
local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local BodyMotion = require(shared:WaitForChild("BodyMotion"))
local AttackString = require(shared:WaitForChild("AttackString"))

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
local uncoupling = Uncoupling.start(arena.folder, arena.layout)
-- The way back after a fall needs the round's fighters and stands, made below.
local comebacks: Comebacks.Service? = nil

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
	announce = function(victim: string, by: string?, how: string, out: boolean, streak: number)
		remotes.Feed:FireAllClients(victim, by, how, out, streak)
	end,
	-- Full health for the way back (its bar shows it full), and unhittable for a moment once it has landed.
	comeback = function(model: Model, after: number, back: () -> ()): () -> ()
		health.reset(model)
		-- (Made right below; the first fight starts well after.)
		return assert(comebacks, "comebacks").send(model, after, function()
			health.guard(model, Workspace:GetServerTimeNow(), Config.Comeback.GuardSeconds)
			back()
		end)
	end,
})
comebacks = Comebacks.start(arena.spots, arena.folder, {
	fighters = round.fighters,
	stands = round.stands,
	isPlayer = function(model: Model): boolean
		return Players:GetPlayerFromCharacter(model) ~= nil
	end,
	away = uncoupling.away,
})
FallWatch.start(arena.fallLine, round.fighters, function(model: Model)
	if round.isFighting(model) then -- a winner falling during the result stays the winner
		round.eliminate(model, "fall")
	end
end)

-- Blocking needs the weapons (a blocker walks slower), made right below.
local weaponsMade: WeaponService.Service? = nil
local guarding = Guarding.start(remotes.Block, {
	canBlock = round.isFighting,
	repace = function(model: Model)
		if weaponsMade then
			weaponsMade.repace(model)
		end
	end,
})
local weapons = WeaponService.start(remotes.Swing, remotes.Hit, {
	canSwing = round.isFighting,
	fighters = round.fighters,
	hit = health.hit,
	knockHere = sandbags.knock,
	onHit = round.noteHit,
	attacked = function(model: Model)
		health.unguard(model, Workspace:GetServerTimeNow())
	end,
	blocking = guarding.blocking,
	guardBroken = guarding.breakGuard,
	onSmash = function(victim: Model)
		round.eliminate(victim, "homerun")
	end,
	equip = equip,
	throw = function(from: Vector3, facing: Vector3, burst: (Vector3) -> ())
		Dynamite.throw(arena.folder, arena.folder, from, facing, burst)
	end,
	send = function(weapon: string, attacker: Model, from: Vector3, facing: Vector3, hit: (Model, Vector3) -> ())
		local w = Config.Weapons[weapon]
		if w.style == "toss" then
			Missiles.toss(arena.folder, arena.folder, round.fighters, attacker, from, facing, w, hit)
		elseif w.style == "roll" then
			Wheels.roll(arena.folder, arena.folder, round.fighters, attacker, from, facing, w, hit)
		elseif w.style == "pour" then
			Slicks.pour(arena.folder, arena.folder, round.fighters, attacker, from, facing, w, hit)
		end
	end,
	putOut = function()
		Dynamite.clear()
		Missiles.clear()
		Wheels.clear()
		Slicks.clear()
	end,
	blast = function(at: Vector3, radius: number)
		remotes.Blast:FireAllClients(at, radius)
	end,
})
weaponsMade = weapons
local drops = WeaponDrops.start(arena.layout.surfaces, PartUtil.folder(Workspace, Names.CratesFolder), {
	fighters = round.fighters,
	-- Anyone with bare fists (players, and practice bots since persona fix 3).
	canTake = function(model: Model): boolean
		return weapons.holding(model) == WeaponRules.FIST
	end,
	give = weapons.give,
	away = uncoupling.away,
})
local stringRules = AttackString.rules(Config.Attack)
brain = BotBrain.new(arena.layout.surfaces, {
	fighters = round.fighters,
	-- A bot's attack steps it in as a player's own client steps the player in (BodyMotion.lunge, by the weapon and step
	-- the attack was taken with).
	attack = function(model: Model, facing: Vector3): number?
		if not weapons.attack(model, facing) then
			return nil
		end
		local body = CharacterParts.body(model)
		if not body then
			return 0
		end
		local style = Config.Weapons[WeaponRules.named(Config.Weapons, model:GetAttribute(Names.SwingWeapon))].style
		local step = PartUtil.number(model, Names.SwingStep) or 1
		return BodyMotion.lunge(body, facing, WeaponRules.lunge(style, AttackString.launches(stringRules, step, style), Config.Attack))
	end,
	crates = drops.landed,
})

-- The avatar's own body parts arrive after the character and replace the default hand: the body is made standard,
-- then the weapon goes on again. One at a time per character: an appearance arriving while its body is being made
-- standard is made standard once more right after ("busy", then "again").
local applying: { [Model]: string } = setmetatable({}, { __mode = "k" }) :: any
local function onAppearance(model: Model)
	if applying[model] then
		applying[model] = "again"
		return
	end
	repeat
		applying[model] = "busy"
		AvatarRules.apply(model)
		equip(model)
	until applying[model] == "busy"
	applying[model] = nil
end

local function onCharacter(model: Model)
	-- An appearance that never says it loaded (a failed asset) is made standard anyway after a while, so the player is
	-- not kept out of the rounds (they take only standard bodies, Names.BodyReady).
	task.delay(10, function()
		if model.Parent and model:GetAttribute(Names.BodyReady) ~= true and not applying[model] then
			onAppearance(model)
		end
	end)
	if model:WaitForChild("RightHand", 10) or model:FindFirstChild("Right Arm") then
		equip(model)
	end
end
local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	-- (Also for a character that loaded before this ran, as in a Studio test.)
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
