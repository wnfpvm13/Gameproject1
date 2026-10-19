--!strict
-- Ghosts and spectators. During a round, eliminated players come back see-through, and everyone who is not an
-- alive participant (ghosts + late joiners) is kept outside the chair ring by a barrier only they collide with.
-- They can send emoji reactions. Their voice is handled by VoiceService (only other ghosts/spectators hear it).
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local GhostService = {}

local OUTSIDER_GROUP = "Outsiders"
local BARRIER_GROUP = "RingBarrier"

local roundActive = false
local ghosts: { [Player]: boolean } = {}
local launchedBody: { [Player]: Model } = {} -- the character that was launched (not a ghost yet)
local lastReaction: { [Player]: number } = {}
local connections: { [Player]: RBXScriptConnection } = {}
local moveOutOfRing: (Player) -> () -- defined below (used by the ring guard started in start())

local function isOutsider(player: Player): boolean
	return roundActive and not Match.isAlive(player)
end

local function styleBasePart(part: BasePart, ghost: boolean)
	part.CollisionGroup = OUTSIDER_GROUP
	if ghost and part.Name ~= "HumanoidRootPart" then
		part.Transparency = math.max(part.Transparency, Config.GHOST_TRANSPARENCY)
		part.CastShadow = false
	end
end

local function styleInstance(instance: Instance, ghost: boolean)
	if instance:IsA("BasePart") then
		styleBasePart(instance, ghost)
	elseif ghost and instance:IsA("Decal") then
		instance.Transparency = math.max(instance.Transparency, Config.GHOST_TRANSPARENCY)
	end
end

-- Outsider: barrier group (+ see-through if a ghost). Keeps styling parts added later (accessories load late).
local function applyOutsider(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local ghost = ghosts[player] == true
	for _, d in character:GetDescendants() do
		styleInstance(d, ghost)
	end
	if connections[player] then
		connections[player]:Disconnect()
	end
	connections[player] = character.DescendantAdded:Connect(function(d)
		if isOutsider(player) then
			styleInstance(d, ghosts[player] == true)
		end
	end)
end

local function onCharacterAdded(player: Player)
	if isOutsider(player) then
		task.defer(applyOutsider, player)
	end
end

local function onReaction(player: Player, index: any)
	if typeof(index) ~= "number" or not Config.REACTIONS[index] then
		return
	end
	local inRound = Match.phase == "Assign" or Match.phase == "Talk"
	if inRound and Match.isAlive(player) then
		return -- players at the table talk; reactions are for ghosts and spectators
	end
	local now = os.clock()
	if now - (lastReaction[player] or 0) < Config.REACTION_COOLDOWN then
		return
	end
	lastReaction[player] = now
	Net.toAll("Reaction", { userId = player.UserId, emoji = Config.REACTIONS[index] })
end

function GhostService.start()
	PhysicsService:RegisterCollisionGroup(OUTSIDER_GROUP)
	PhysicsService:RegisterCollisionGroup(BARRIER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(BARRIER_GROUP, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(BARRIER_GROUP, OUTSIDER_GROUP, true)
	local map = workspace:WaitForChild("LoungeMap")
	local barrier = map:WaitForChild("RingBarrier")
	for _, part in barrier:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = BARRIER_GROUP
		end
	end
	Players.RespawnTime = Config.RESPAWN_TIME

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacterAdded(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		ghosts[player] = nil
		launchedBody[player] = nil
		lastReaction[player] = nil
		if connections[player] then
			connections[player]:Disconnect()
			connections[player] = nil
		end
	end)
	Net.listen("Reaction", onReaction)

	-- Backup for the barrier (stacked players or furniture jumps): outsiders found inside the ring go back out.
	task.spawn(function()
		while true do
			task.wait(Config.GHOST_RING_CHECK)
			if roundActive then
				for _, player in Players:GetPlayers() do
					if isOutsider(player) and player.Character ~= launchedBody[player] then
						moveOutOfRing(player)
					end
				end
			end
		end
	end)
end

-- Anyone inside the ring who should not be there is moved to the spawn (the barrier would trap them inside).
moveOutOfRing = function(player: Player)
	local map = workspace:WaitForChild("LoungeMap")
	local center = (map:WaitForChild("Center") :: BasePart).Position
	local radius = (map:WaitForChild("RingBarrier"):GetAttribute("Radius") or 14) :: number
	local spawn = map:FindFirstChild("Spawn") :: BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and root and spawn) then
		return
	end
	local offset = root.Position - center
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < radius + 1.5 then
		character:PivotTo(spawn.CFrame * CFrame.new(math.random(-3, 3), 3, math.random(-3, 3)))
	end
end

-- Round start: everyone not seated becomes an outsider.
function GhostService.beginRound()
	roundActive = true
	table.clear(ghosts)
	for _, player in Players:GetPlayers() do
		if isOutsider(player) then
			moveOutOfRing(player)
			applyOutsider(player)
		end
	end
end

-- The player was eliminated: from their next character on they are a ghost.
function GhostService.markGhost(player: Player)
	ghosts[player] = true
	launchedBody[player] = player.Character
end

-- Round over: ghosts get a fresh, normal character at the lounge spawn; spectators just leave the barrier group.
function GhostService.endRound()
	roundActive = false
	for player, connection in connections do
		connection:Disconnect()
		connections[player] = nil
	end
	for _, player in Players:GetPlayers() do
		if ghosts[player] then
			Match.loading[player] = true
			task.spawn(function()
				pcall(function()
					player:LoadCharacter()
				end)
				local character = player.Character
				local deadline = os.clock() + 10
				while os.clock() < deadline and not (character and character.Parent == workspace and character:FindFirstChild("HumanoidRootPart")) do
					task.wait(0.1)
					character = player.Character
				end
				task.wait(0.5) -- let the engine finish placing it at the spawn
				Match.loading[player] = nil
			end)
		elseif player.Character then
			for _, d in player.Character:GetDescendants() do
				if d:IsA("BasePart") and d.CollisionGroup == OUTSIDER_GROUP then
					d.CollisionGroup = "Default"
				end
			end
		end
	end
	table.clear(ghosts)
	table.clear(launchedBody)
end

return GhostService
