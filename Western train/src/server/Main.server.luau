--!strict
-- Western train server entry point (squash prototype): wiring, plus each player's track slot and locomotive lifetime.
-- Every time a character spawns, it is hidden on its track and the player's avatar is rebuilt as a locomotive there.
local Players = game:GetService("Players")

local Net = require(script.Parent:WaitForChild("Net"))
local PrototypeStage = require(script.Parent:WaitForChild("PrototypeStage"))
local AvatarBody = require(script.Parent:WaitForChild("AvatarBody"))
local LocomotiveBuilder = require(script.Parent:WaitForChild("LocomotiveBuilder"))
local CharacterHider = require(script.Parent:WaitForChild("CharacterHider"))
local SquashService = require(script.Parent:WaitForChild("SquashService"))
local Names = require(game:GetService("ReplicatedStorage"):WaitForChild("WesternTrain"):WaitForChild("Names"))

local remotes = Net.create()
local stage = PrototypeStage.build()
local locomotives: { [Player]: Model } = {}
local slots: { [Player]: number } = {}
local builds: { [Player]: number } = {} -- latest build number, so a slow build for an old character is dropped
local hidden: { [Player]: CharacterHider.Hidden } = {}

SquashService.start(remotes.Squash, function(player: Player): Model?
	return locomotives[player]
end)

local function freeSlot(): number
	local used = {}
	for _, slot in slots do
		used[slot] = true
	end
	local slot = 1
	while used[slot] do
		slot += 1
	end
	return slot
end

local function clear(player: Player)
	local old = locomotives[player]
	locomotives[player] = nil
	if old then
		old:Destroy()
	end
	local hider = hidden[player]
	hidden[player] = nil
	if hider then
		hider.stop()
	end
end

local function onCharacter(player: Player, character: Model)
	local build = (builds[player] or 0) + 1
	builds[player] = build
	clear(player)
	local base = stage.slotCFrame(slots[player])
	-- Hide first: building the avatar waits on the web for a moment and the character must not stand around meanwhile.
	local hider = CharacterHider.hide(character, base)
	hidden[player] = hider
	local avatar = AvatarBody.build(AvatarBody.describe(player))
	if not avatar then
		avatar = AvatarBody.build(Instance.new("HumanoidDescription")) -- the default look, so a locomotive still appears
	end
	if builds[player] ~= build or player.Character ~= character then
		if avatar then
			avatar:Destroy() -- a newer character (or leaving) took over; clear() already stopped this hider
		end
		return
	end
	if not avatar then
		warn("[WesternTrain] no locomotive for " .. player.Name .. "; showing the character again")
		hider.restore()
		hidden[player] = nil
		return
	end
	local locomotive = LocomotiveBuilder.build(avatar, base)
	locomotive.Name = "Locomotive_" .. player.Name
	locomotive:SetAttribute(Names.OwnerUserId, player.UserId)
	locomotive.Parent = stage.folder
	locomotives[player] = locomotive
end

local function onPlayer(player: Player)
	slots[player] = freeSlot()
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
	clear(player)
	slots[player] = nil
	builds[player] = nil
end)
