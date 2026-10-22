--!strict
-- Spectators (docs/DESIGN_V3.md §8-10, was GhostService in V2): during a round everyone who is not an alive
-- participant (players who are out, late joiners, anyone who respawns) watches from the stands. Anyone found on the
-- stage (the chair row and the floor up to the show camera) is moved back to the stands, except players SeatService
-- still owns (flying). When the round is over the stands empty into the lobby. Spectators can send emoji reactions;
-- their voice is VoiceService's job. (The presenter, bundle 3, will stand at the podium on the stage and must be
-- exempted then.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local SpectatorService = {}

type Box = { min: Vector3, max: Vector3 }

local roundActive = false
local busy: (Player) -> boolean = function(_player: Player): boolean
	return false -- until start() gets the real check
end
local inStands: { [Player]: number } = {} -- player -> spot number
local lastReaction: { [Player]: number } = {}
local stage: Box? = nil

local function hall(): Instance
	return workspace:WaitForChild("PoolHall")
end

-- The stage from the map contract: across the row's HalfWidth (ShowCamera attribute), from the show camera to
-- STAGE_BEHIND_ROW studs behind the chairs, from below the deck up to the ceiling.
local function stageBox(): Box
	if stage then
		return stage
	end
	local map = hall()
	local camera = map:WaitForChild("ShowCamera") :: BasePart
	local halfWidth = (camera:GetAttribute("HalfWidth") or 30) :: number
	local ceiling = (map:GetAttribute("CeilingY") or 40) :: number
	local centerX, rowZ, count = 0, -math.huge, 0
	for _, chair in map:WaitForChild("Chairs"):GetChildren() do
		local seat = chair:FindFirstChild("Seat") :: BasePart?
		if seat then
			centerX += seat.Position.X
			count += 1
			rowZ = math.max(rowZ, seat.Position.Z)
		end
	end
	centerX = if count > 0 then centerX / count else 0
	local box: Box = {
		min = Vector3.new(centerX - halfWidth, -20, math.min(camera.Position.Z, rowZ)),
		max = Vector3.new(centerX + halfWidth, ceiling, rowZ + Config.STAGE_BEHIND_ROW),
	}
	stage = box
	return box
end

local function onStage(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local p, box = root.Position, stageBox()
	return p.X > box.min.X and p.X < box.max.X and p.Y > box.min.Y and p.Y < box.max.Y and p.Z > box.min.Z and p.Z < box.max.Z
end

local function freeSpot(): number
	local used: { [number]: boolean } = {}
	for _, taken in inStands do
		used[taken] = true
	end
	local spot = 1
	while used[spot] do
		spot += 1
	end
	return spot
end

-- Moves a player to their own spot in the stands, facing the pool. The Stands marker covers two tiers: spots run
-- along its length on the middle of each tier; past both rows each further pass sits a quarter spot further along.
function SpectatorService.toStands(player: Player)
	local character = player.Character
	local marker = hall():FindFirstChild("Stands") :: BasePart?
	if not (character and character:FindFirstChild("HumanoidRootPart") and marker) then
		return
	end
	local spot = inStands[player] or freeSpot()
	inStands[player] = spot
	local perRow = Config.STAND_SPOTS_PER_ROW
	local index = (spot - 1) % perRow
	local row = ((spot - 1) // perRow) % 2
	local pass = (spot - 1) // (perRow * 2)
	local face = (marker:GetAttribute("FaceX") or -1) :: number
	local spacing = marker.Size.Z / perRow
	-- Tier middles: the marker's centre (front tier) and half its width further back (the marker spans two tiers).
	local x = marker.Position.X - row * face * marker.Size.X / 2
	local z = marker.Position.Z - marker.Size.Z / 2 + (index + 0.5) * spacing + (pass % 4) * spacing / 4
	local position = Vector3.new(x, marker.Position.Y + 4, z) -- drops onto the tier below
	character:PivotTo(CFrame.lookAt(position, position + Vector3.new(face, 0, 0)))
end

local function onReaction(player: Player, index: any)
	if typeof(index) ~= "number" or not Config.REACTIONS[index] then
		return
	end
	local inRound = Match.phase == "Assign" or Match.phase == "Talk"
	if inRound and Match.isAlive(player) then
		return -- players on the chairs talk; reactions are for spectators
	end
	local now = os.clock()
	if now - (lastReaction[player] or 0) < Config.REACTION_COOLDOWN then
		return
	end
	lastReaction[player] = now
	Net.toAll("Reaction", { userId = player.UserId, emoji = Config.REACTIONS[index] })
end

-- Sends a player to the stands once their character is in place, if by then a round is running and they are still
-- only watching it. Covers late joiners, respawns and characters still loading when a round starts (the round may
-- begin while the character waits, so the check comes after the wait).
local function standsWhenReady(player: Player, character: Model)
	task.spawn(function()
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.5) -- let the engine finish placing it at the spawn
		if roundActive and player.Character == character and not Match.isAlive(player) and not busy(player) then
			SpectatorService.toStands(player)
		end
	end)
end

-- isBusy(player): true while another service owns the player's body (a flight); the stage guard skips them.
function SpectatorService.start(isBusy: (Player) -> boolean)
	busy = isBusy
	Players.RespawnTime = Config.RESPAWN_TIME
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			standsWhenReady(player, character)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		inStands[player] = nil
		lastReaction[player] = nil
	end)
	Net.listen("Reaction", onReaction)
	task.spawn(function()
		while true do
			task.wait(Config.STAGE_GUARD_CHECK)
			if roundActive then
				for _, player in Players:GetPlayers() do
					if not Match.isAlive(player) and not busy(player) and onStage(player) then
						SpectatorService.toStands(player)
					end
				end
			end
		end
	end)
end

-- Round start: everyone who did not get a chair goes to the stands (a character still loading goes once it is in
-- place).
function SpectatorService.beginRound()
	roundActive = true
	table.clear(inStands)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not Match.isAlive(player) and character then
			if character:FindFirstChild("HumanoidRootPart") then
				SpectatorService.toStands(player)
			else
				standsWhenReady(player, character)
			end
		end
	end
end

-- Round over: the stands empty into the lobby (around the Lobby spawn).
function SpectatorService.endRound()
	roundActive = false
	local lobby = hall():FindFirstChild("Lobby") :: BasePart?
	for player in inStands do
		local character = player.Character
		if lobby and character and character:FindFirstChild("HumanoidRootPart") then
			character:PivotTo(lobby.CFrame * CFrame.new(math.random(-4, 4), 3, math.random(-3, 3)))
		end
	end
	table.clear(inStands)
end

return SpectatorService
