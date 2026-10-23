--!strict
-- Western train server entry point: wiring, plus each crew's train lifetime. Players pair up as they join (CrewBook):
-- a driver's avatar is rebuilt as the train on their track (their character hidden inside), and the next player rides
-- that train's roof as the cowboy. Every new train starts its run toward the low bridges (CourseService), the mail
-- cranes (a MailService for the required bags: a missed bag sends the run back through CourseService) and the gold
-- cranes (a MailService for the optional gold bags); drivers squash (SquashService) and jump (JumpService). For testing
-- alone in Studio, the Workspace attribute Names.SoloCowboy makes a lone player a cowboy on a train with a stand-in
-- driver (BotDriver), built from that player's own avatar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent:WaitForChild("Net"))
local PrototypeStage = require(script.Parent:WaitForChild("PrototypeStage"))
local AvatarBody = require(script.Parent:WaitForChild("AvatarBody"))
local LocomotiveBuilder = require(script.Parent:WaitForChild("LocomotiveBuilder"))
local CharacterHider = require(script.Parent:WaitForChild("CharacterHider"))
local SquashService = require(script.Parent:WaitForChild("SquashService"))
local CourseService = require(script.Parent:WaitForChild("CourseService"))
local CrewBook = require(script.Parent:WaitForChild("CrewBook"))
local BotDriver = require(script.Parent:WaitForChild("BotDriver"))
local MailService = require(script.Parent:WaitForChild("MailService"))
local JumpService = require(script.Parent:WaitForChild("JumpService"))
local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CourseMath = require(shared:WaitForChild("CourseMath"))
local GoldTrack = require(shared:WaitForChild("GoldTrack"))

local remotes = Net.create()
local stage = PrototypeStage.build()
local crews = CrewBook.new(Config.Stage.Slots)
local trains: { [number]: Model } = {} -- by slot
local builds: { [Player]: number } = {} -- latest build number, so a slow build for an old character is dropped
local hidden: { [Player]: CharacterHider.Hidden } = {}
local course = CourseService.start(remotes.Bridge)
local mail = MailService.start(remotes.Mail, {
	at = function(i: number): number
		return (CourseMath.mailAt(i, Config.Bridge.FirstAt, Config.Bridge.Gaps))
	end,
	next = Names.MailNext,
	taken = Names.MailTaken,
	onMissed = course.missMail,
})
local gold = MailService.start(remotes.Gold, {
	at = function(k: number): number
		return (GoldTrack.at(k))
	end,
	next = Names.GoldNext,
	taken = Names.GoldTaken,
	onMissed = nil,
})
local bot = BotDriver.start(JumpService.jump)

local function drivenTrain(player: Player): Model?
	local slot, role = crews:find(player)
	return if slot and role == "driver" then trains[slot] else nil
end
SquashService.start(remotes.Squash, drivenTrain)
JumpService.start(remotes.Jump, drivenTrain)

local function removeTrain(slot: number)
	local train = trains[slot]
	trains[slot] = nil
	if train then
		course.finish(train)
		mail.untrack(train)
		gold.untrack(train)
		bot.stop(train)
		train:Destroy()
	end
end

local function unhide(player: Player)
	local hider = hidden[player]
	hidden[player] = nil
	if hider then
		hider.stop()
	end
end

-- The crew's cowboy goes onto the train's last roof (when both are there).
local function placeCowboy(slot: number)
	local crew = crews:crew(slot)
	local train = trains[slot]
	local cowboy = crew and crew.cowboy
	if not (train and cowboy) then
		return
	end
	train:SetAttribute(Names.CowboyUserId, cowboy.UserId)
	local character = cowboy.Character
	local floor = PartUtil.lastRoofFloor(train, Names.Walkable, Names.RestCFrame)
	local rest = floor and floor:GetAttribute(Names.RestCFrame)
	if character and floor and typeof(rest) == "CFrame" then
		PartUtil.pivotAfterSpawn(character, stage.slotCFrame(slot) * PartUtil.aboveFloor(rest, floor.Size, Config.Cowboy.SpawnLift))
	end
end

-- Builds the slot's train from this player's avatar (the driver's, or a lone cowboy's for the stand-in driver).
-- Building waits on the web, so afterwards it checks again that it is still wanted: the same character, and
-- `stillWanted()` (the player's role there has not changed - e.g. a player took over from the stand-in driver
-- meanwhile, whose own train must not be replaced). Returns nil when stale.
local function buildTrain(player: Player, slot: number, build: number, character: Model, stillWanted: () -> boolean): Model?
	local avatar = AvatarBody.build(AvatarBody.describe(player))
	if not avatar then
		avatar = AvatarBody.build(Instance.new("HumanoidDescription")) -- the default look, so a train still appears
	end
	if builds[player] ~= build or player.Character ~= character or not stillWanted() then
		if avatar then
			avatar:Destroy() -- a newer character (or leaving, or a new role) took over
		end
		return nil
	end
	if not avatar then
		return nil
	end
	removeTrain(slot)
	local train = LocomotiveBuilder.build(avatar, stage.slotCFrame(slot))
	train.Name = "Locomotive_" .. player.Name
	train:SetAttribute(Names.CowboyUserId, 0)
	return train
end

local function onCharacter(player: Player, character: Model)
	local build = (builds[player] or 0) + 1
	builds[player] = build
	unhide(player)
	local slot, role = crews:find(player)
	if not slot then
		return -- every track is taken: the player just walks around
	end
	if role == "driver" then
		-- Hide first: building the avatar waits on the web for a moment and the character must not stand around meanwhile.
		local hider = CharacterHider.hide(character, stage.slotCFrame(slot))
		hidden[player] = hider
		local train = buildTrain(player, slot, build, character, function()
			local nowSlot, nowRole = crews:find(player)
			return nowSlot == slot and nowRole == "driver"
		end)
		if not train then
			if builds[player] == build and crews:find(player) == slot then
				warn("[WesternTrain] no locomotive for " .. player.Name .. "; showing the character again")
				hider.restore()
				hidden[player] = nil
			end
			return
		end
		train:SetAttribute(Names.OwnerUserId, player.UserId)
		train.Parent = stage.folder
		trains[slot] = train
		course.begin(train, player)
		mail.track(train)
		gold.track(train)
		placeCowboy(slot)
	else
		local crew = crews:crew(slot)
		if crew and crew.bot and not trains[slot] then
			local train = buildTrain(player, slot, build, character, function()
				local now = crews:crew(slot)
				return now ~= nil and now.bot and now.cowboy == player and not trains[slot]
			end)
			if not train then
				return
			end
			train:SetAttribute(Names.OwnerUserId, 0)
			train.Parent = stage.folder
			trains[slot] = train
			course.begin(train, nil)
			mail.track(train)
			gold.track(train)
			bot.drive(train)
		end
		placeCowboy(slot) -- with a player driver whose train is not built yet, their build places the cowboy
	end
end

local function onPlayer(player: Player)
	-- The solo-cowboy test switch only works in Studio, so it can never be left on in the published game.
	crews:join(player, RunService:IsStudio() and Workspace:GetAttribute(Names.SoloCowboy) == true)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	unhide(player)
	builds[player] = nil
	local slot, change, promoted = crews:leave(player)
	if not slot then
		return
	end
	if change == "freed" then
		removeTrain(slot)
	elseif change == "promoted" and promoted then
		removeTrain(slot)
		if promoted.Parent then
			-- The former cowboy respawns as the driver and their train is built.
			local ok, problem = pcall(promoted.LoadCharacter, promoted)
			if not ok then
				warn("[WesternTrain] could not respawn " .. promoted.Name .. " as the driver: " .. tostring(problem))
			end
		end
	else
		local train = trains[slot]
		if train then
			train:SetAttribute(Names.CowboyUserId, 0)
		end
	end
end)
