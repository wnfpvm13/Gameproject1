--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared.Config.Registry)
local Defaults = require(Shared.Utilities.PlayerDataDefaults)
local Migration = require(Shared.Utilities.PlayerDataMigration)
local Config = require(script.Parent.ServerConfig)
local Services = script.Parent.Services
local DataService = require(Services.DataService)
local PartyService = require(Services.PartyService)
local PartyActivityService = require(Services.PartyActivityService)
local SessionService = require(Services.SessionService)
local TeleportWrapper = require(Services.TeleportServiceWrapper)
local Coordinator = require(Services.FoundationCoordinator)
local ExpeditionService = require(Services.ExpeditionService)
local ExpeditionCoordinator = require(Services.ExpeditionCoordinator)
local MatchmakingService = require(Services.MatchmakingService)
local RuntimeAdapters = require(script.Parent.Adapters.RuntimeAdapters)
local studio = RunService:IsStudio()
local fake = studio and Registry.Definitions.Testing.UseFakeTeleport
local restaurant = not studio and game.PlaceId == Config.RestaurantPlaceId
local function log(message: string) warn("[MonCook] " .. message) end
local function newId(): string return HttpService:GenerateGUID(false) end
Registry.validate()
local adapters = RuntimeAdapters.new(studio, fake, Config)
local teleport = TeleportWrapper.new({
	IsStudio = studio, UseFakeTeleport = fake, Transport = adapters.Transport, Log = log,
	WorldPlaceId = Config.WorldPlaceId, RestaurantPlaceId = Config.RestaurantPlaceId,
	ExpeditionPlaceIds = Config.ExpeditionPlaceIds,
})
if not studio then
	assert(game.PlaceId == Config.WorldPlaceId or restaurant, "MonCook: this Place is not configured")
	if restaurant then assert(game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0, "Reserved Restaurant server required") end
end
local data = DataService.new({
	Store = adapters.Profiles, OwnerId = (if game.JobId ~= "" then game.JobId else newId()),
	Now = adapters.Now, LockSeconds = Config.ProfileLockSeconds, Migrate = Migration.migrate, Log = log,
	NewData = function()
		local profile = Defaults.new()
		if studio then for id, count in Config.StudioProfileIngredients do profile.Inventory.Ingredients[id] = count end end
		return profile
	end,
})
local function validActivityTarget(activity: string, targetId: string): boolean
	local target = Registry.Definitions.PartyTarget[targetId]
	return target ~= nil and target.Activity == activity
end
local party = PartyService.new({
	NewId = newId, MaxMembers = Config.MaxPartySize, Now = adapters.Now,
	InviteTTLSeconds = Config.InviteTTLSeconds, ValidActivityTarget = validActivityTarget,
})
local sessions = SessionService.new({
	Data = data, Store = adapters.Sessions, NewId = newId, Now = adapters.Now,
	MaxPartySize = Config.MaxPartySize, IsStudio = studio,
	ValidIngredient = function(id: string): boolean
		local entry = Registry.Definitions.Ingredient[id]
		return entry ~= nil and entry.Category ~= "Material"
	end,
	Log = function(operation: string, detail: any) log(operation .. ": " .. tostring(detail)) end,
})
local travel = Coordinator.new({ Data = data, Sessions = sessions, Party = party, Teleport = teleport, IsFake = fake, Log = log, NewId = newId })
local expeditions = ExpeditionService.new({
	NewId = newId, Now = adapters.Now, MaxMembers = Config.MaxPartySize,
	ValidTarget = function(regionId: string, targetId: string): boolean
		local target = Registry.Definitions.PartyTarget[targetId]
		return target ~= nil and target.Activity == "Expedition" and target.RegionId == regionId
	end,
})
local expeditionTravel = ExpeditionCoordinator.new({
	Data = data, Party = party, Expeditions = expeditions, Teleport = teleport,
	IsFake = fake, NewId = newId, Log = log,
	IsOtherTraveling = function(id: number): boolean return travel:IsTraveling(id) end,
	OtherLocation = function(id: number): string return travel:Location(id) end,
})
local matchmaking = MatchmakingService.new({ Enabled = Registry.Definitions.Matchmaking.Enabled })
local actorByPlayer: { [Player]: number } = {}
local playerByActor: { [number]: Player } = {}
local sessionByActor: { [number]: string } = {}
local lastRequest, busy = {}, {}
local nextStudioId = -1000000
local network = Instance.new("Folder")
network.Name = "MonCookNetwork"
local command = Instance.new("RemoteFunction")
command.Name, command.Parent = "Command", network
local changed = Instance.new("RemoteEvent")
changed.Name, changed.Parent = "Changed", network
local function lookup(id: number): Player? return playerByActor[id] end
local function isTraveling(id: number): boolean
	return travel:IsTraveling(id) or expeditionTravel:IsTraveling(id)
end
local function location(id: number): string
	if restaurant then return "Restaurant" end
	local active = expeditions:GetForMember(id)
	if active and active.State ~= "Closed" then return "Expedition" end
	return travel:Location(id)
end
local function playerInfo(id: number): any
	local member = lookup(id)
	return {
		ActorId = id, UserId = if member then member.UserId else id,
		Name = if member then member.Name else "Player",
		DisplayName = if member then member.DisplayName else "Player",
	}
end
local function remoteParty(value: any): any
	if not value then return nil end
	local ready = {}
	for member, response in value.ReadyStates do ready[tostring(member)] = response end
	value.ReadyStates = ready
	return value
end
local function localSession(token: string): any
	for id, sid in sessionByActor do
		if sid == token and lookup(id) and data:HasProfile(id) then
			local ok, actual = pcall(function() return sessions:GetHostSession(id) end)
			if ok and actual and actual.SessionId == token then return actual end
		end
	end
	return nil
end
local function snapshot(id: number): any
	local ok, profile = false, nil
	if data:HasProfile(id) then ok, profile = pcall(function() return data:Get(id) end) end
	local session
	if ok then session = profile.RestaurantSession end
	if sessionByActor[id] then
		local actual = localSession(sessionByActor[id])
		local found, record = pcall(function() return sessions:GetForMember(sessionByActor[id], id) end)
		if found and record then
			session = record
			if data:HasProfile(record.HostUserId) then
				local loaded, actual = pcall(function() return sessions:GetHostSession(record.HostUserId) end)
				if loaded and actual and actual.SessionId == record.SessionId then session = actual end
			end
		end
		if actual then session = actual end
	end
	local proposal = party:GetProposal(id)
	if proposal then
		local responses = {}
		for member, response in proposal.Responses do responses[tostring(member)] = response end
		proposal.Responses = responses
	end
	local currentParty = party:Get(id)
	-- Published Restaurant members have validated session membership, while the
	-- World party registry remains local to its server. This view grants no API authority.
	if not currentParty and restaurant and sessionByActor[id] and session
		and session.SessionId == sessionByActor[id] then
		currentParty = {
			PartyId = "Restaurant:" .. session.SessionId, LeaderUserId = session.HostUserId,
			MemberUserIds = table.clone(session.PartyUserIds), MaxMembers = Config.MaxPartySize,
			Visibility = "Private", Activity = "Restaurant", TargetId = "HostRestaurant",
			Status = "InActivity", ReadyStates = {},
		}
	end
	local members, nearby, directory = {}, {}, {}
	if currentParty then for _, member in currentParty.MemberUserIds do table.insert(members, playerInfo(member)) end end
	if location(id) == "World" then
		for member in playerByActor do
			if location(member) == "World" then table.insert(nearby, playerInfo(member)) end
		end
		table.sort(nearby, function(a, b) return a.ActorId < b.ActorId end)
		for _, listed in party:ListPublic() do
			listed.HostName = playerInfo(listed.LeaderUserId).DisplayName
			listed.TargetName = Registry.Definitions.PartyTarget[listed.TargetId].DisplayName
			table.insert(directory, remoteParty(listed))
		end
	end
	local invitations = party:GetInvites(id)
	for _, invitation in invitations do invitation.HostName = playerInfo(invitation.LeaderUserId).DisplayName end
	local targets = {}
	for targetId, target in Registry.Definitions.PartyTarget do
		if target.Activity ~= "Expedition" or fake then
			table.insert(targets, { TargetId = targetId, Activity = target.Activity, DisplayName = target.DisplayName, RegionId = target.RegionId })
		end
	end
	table.sort(targets, function(a, b) return a.TargetId < b.TargetId end)
	local expedition = expeditions:GetForMember(id)
	return {
		ActorId = id, Ready = ok, Traveling = isTraveling(id), Party = remoteParty(currentParty), Proposal = proposal,
		Location = location(id), Members = members, NearbyPlayers = nearby, Directory = directory,
		Invites = invitations, Targets = targets, Expedition = expedition,
		Features = { ShowFoundationDebugUI = studio and Registry.Definitions.Testing.ShowFoundationDebugUI,
			ExpeditionPrototype = fake, QuickMatchEnabled = matchmaking:GetStatus().Available },
		Gold = if ok then profile.Currencies.Gold else nil,
		Renown = if ok then profile.Progression.RestaurantRenown else nil,
		Ingredients = if ok then profile.Inventory.Ingredients else {},
		Session = if session then { SessionId = session.SessionId, HostUserId = session.HostUserId, State = session.State } else nil,
	}
end
local function pushAll()
	local checked = {}
	for id in playerByActor do
		local current = party:Get(id)
		if current and not checked[current.PartyId] then
			checked[current.PartyId] = true
			PartyActivityService.reconcile(party, id, location, isTraveling, function(member) return lookup(member) ~= nil end)
		end
	end
	for id, player in playerByActor do
		local ok, state = pcall(snapshot, id)
		if ok and player.Parent == Players then changed:FireClient(player, state) end
	end
end
local function ensurePartyIdle(id: number, targetPartyId: string?)
	local current = party:Get(id)
	if not current and targetPartyId then
		for other in playerByActor do
			local candidate = party:Get(other)
			if candidate and candidate.PartyId == targetPartyId then current = candidate; break end
		end
	end
	if current then for _, member in current.MemberUserIds do assert(not isTraveling(member), "party is traveling") end end
end
local function validToken(value: any): string
	assert(type(value) == "string" and #value > 0 and #value <= 128, "invalid request identifier")
	return value
end
command.OnServerInvoke = function(player: Player, action: any, payload: any): any
	local id = actorByPlayer[player]
	if not id or type(action) ~= "string" or (payload ~= nil and type(payload) ~= "table") then return { Ok = false } end
	local now = os.clock()
	if busy[id] or (lastRequest[id] and now - lastRequest[id] < Config.RequestIntervalSeconds) then return { Ok = false, Error = "잠시 후 다시 시도하세요." } end
	lastRequest[id], busy[id] = now, true
	local ok, reason = pcall(function()
		if action == "State" then return end
		assert(data:HasProfile(id) and not isTraveling(id), "profile not ready or traveling")
		local currentLocation = location(id)
		if action == "CompleteExpedition" then
			assert(fake and currentLocation == "Expedition", "Studio expedition required")
			expeditionTravel:Complete(id, validToken(payload and payload.SessionId))
			return
		elseif action == "ExpeditionResult" then
			assert(fake and payload, "Studio expedition result required")
			expeditionTravel:Result(id, validToken(payload.SessionId), validToken(payload.Destination), validToken(payload.ActionId), lookup)
			return
		end
		if action == "Return" then
			assert(currentLocation == "Restaurant", "return requires Restaurant")
			local token = sessionByActor[id]
			assert(token, "validated Restaurant arrival required")
			local own = sessions:GetHostSession(id)
			if own and own.SessionId == token then
				travel:Return(id, function(member)
					return if sessionByActor[member] == token then lookup(member) else nil
				end)
				if fake then for member, sid in sessionByActor do if sid == token then sessionByActor[member] = nil end end end
			else
				travel:ReturnMember(id, token, lookup)
				if fake then sessionByActor[id] = nil end
			end
			return
		end
		assert(currentLocation == "World", "party preparation requires World")
		ensurePartyIdle(id, if (action == "Join" or action == "JoinPublic") and payload then validToken(payload.PartyId) else nil)
		if action == "Create" then
			assert(not payload or payload.Activity ~= "Expedition" or fake, "published expeditions are not connected yet")
			party:Create(id, payload)
		elseif action == "Join" then
			assert(studio and Registry.Definitions.Testing.ShowFoundationDebugUI, "Party ID join is Studio debug only")
			party:Join(id, validToken(payload and payload.PartyId))
		elseif action == "JoinPublic" then party:JoinPublic(id, validToken(payload and payload.PartyId))
		elseif action == "SetVisibility" then party:SetVisibility(id, validToken(payload and payload.Visibility))
		elseif action == "SetActivity" then
			assert(payload, "activity required")
			assert(payload.Activity ~= "Expedition" or fake, "published expeditions are not connected yet")
			party:SetActivity(id, validToken(payload.Activity), validToken(payload.TargetId))
		elseif action == "Invite" then
			local targetId = payload and payload.TargetUserId
			assert(type(targetId) == "number" and targetId ~= 0 and targetId % 1 == 0 and math.abs(targetId) <= 9007199254740991, "invalid invite target")
			assert(lookup(targetId) and location(targetId) == "World" and data:HasProfile(targetId) and not isTraveling(targetId), "invite target unavailable")
			party:Invite(id, targetId)
		elseif action == "RespondInvite" then
			assert(payload and type(payload.Accept) == "boolean", "invitation response required")
			local invitation
			for _, candidate in party:GetInvites(id) do if candidate.InviteId == payload.InviteId then invitation = candidate; break end end
			assert(invitation, "invitation expired or missing")
			ensurePartyIdle(id, invitation.PartyId)
			assert(lookup(invitation.LeaderUserId) and location(invitation.LeaderUserId) == "World", "invite host unavailable")
			party:RespondInvite(id, validToken(payload.InviteId), payload.Accept)
		elseif action == "Leave" then party:Leave(id)
		elseif action == "Propose" then
			local currentParty = party:Get(id)
			assert(currentParty, "party required")
			if currentParty.Activity == "Free" then party:SetActivity(id, "Restaurant", "HostRestaurant"); currentParty = party:Get(id) end
			assert(currentParty.Activity == "Restaurant" or (fake and currentParty.Activity == "Expedition"), "activity has no transport yet")
			party:Propose(id)
		elseif action == "Respond" then
			assert(payload and type(payload.Join) == "boolean", "JOIN/STAY response required")
			party:Respond(id, validToken(payload.ProposalId), payload.Join)
		elseif action == "Enter" then
			local currentParty = party:Get(id)
			assert(currentParty, "party required")
			local proposalId = validToken(payload and payload.ProposalId)
			if currentParty.Activity == "Expedition" then
				local target = Registry.Definitions.PartyTarget[currentParty.TargetId]
				expeditionTravel:Start(id, proposalId, target.RegionId, currentParty.TargetId, lookup)
			else
				assert(currentParty.Activity == "Restaurant", "Restaurant proposal required")
				local selected = party:Ready(id, proposalId)
				for _, member in selected do assert(not expeditionTravel:IsTraveling(member) and location(member) == "World", "member is in another activity") end
				local pantry = {}
				for ingredient, count in data:Get(id).Inventory.Ingredients do if count ~= 0 then pantry[ingredient] = count end end
				local session = travel:Start(id, proposalId, pantry, lookup)
				if fake then
					for _, member in session.PartyUserIds do sessionByActor[member] = session.SessionId end
					party:SetStatus(id, "InActivity")
				end
			end
		else error("unknown command") end
	end)
	busy[id] = nil
	if not ok then log("Command " .. action .. " user " .. tostring(id) .. ": " .. tostring(reason)) end
	pushAll()
	return { Ok = ok, Error = if ok then nil else "요청을 처리하지 못했습니다. 상태를 확인하고 다시 시도하세요.", State = snapshot(id) }
end
network.Parent = ReplicatedStorage
-- Additive World presentation/gameplay boundary; existing Party and travel APIs are unchanged.
local hunting = require(script.Parent.Adapters.HuntingRuntime).start({
	Data = data, IsRestaurant = restaurant,
	ActorId = function(player: Player): number? return actorByPlayer[player] end,
	Lookup = lookup, Location = location, IsTraveling = isTraveling,
})
local function arrival(player: Player, id: number)
	if not restaurant then
		local previous = sessions:GetHostSession(id)
		if previous and (previous.State == "Preparing" or previous.State == "Teleporting") then sessions:Rollback(id, previous.SessionId) end
		-- Acquiring this profile proves the former Restaurant owner released or
		-- lost its lease. Recover the Phase 0 zero-reward orphaned active escrow.
		if previous and previous.State == "Active" then sessions:Settle(id, previous.SessionId) end
		return
	end
	local token = player:GetJoinData().TeleportData
	assert(type(token) == "table" and token.Destination == "Restaurant", "Restaurant arrival token required")
	local sessionId = validToken(token.SessionId)
	local own = sessions:GetHostSession(id)
	if own and own.SessionId == sessionId then
		assert(table.find(own.PartyUserIds, id), "host is not a session member")
		sessions:Activate(id, sessionId, game.PrivateServerId)
	else
		local deadline = os.clock() + Config.ArrivalWaitSeconds
		local accepted = false
		repeat
			assert(player.Parent == Players, "helper left during arrival")
			local actual = localSession(sessionId)
			if actual and actual.State == "Active" and table.find(actual.PartyUserIds, id)
				and actual.DestinationPrivateServerId == game.PrivateServerId then accepted = true; break end
			task.wait(0.5)
		until os.clock() >= deadline
		assert(accepted, "Restaurant host did not arrive")
	end
	sessionByActor[id] = sessionId
end
local function added(player: Player)
	if actorByPlayer[player] then return end
	local id = player.UserId
	if studio and id == 0 then nextStudioId -= 1; id = nextStudioId end
	assert(studio or id > 0, "published user id required")
	actorByPlayer[player], playerByActor[id] = id, player
	local ok, reason = pcall(function()
		data:Load(id)
		assert(player.Parent == Players, "player left during profile load")
		arrival(player, id)
		assert(player.Parent == Players, "player left during arrival validation")
	end)
	if not ok then
		log("Player initialization: " .. tostring(reason))
		if data:HasProfile(id) then pcall(function() data:Release(id) end) end
		if player.Parent == Players then player:Kick("데이터 또는 식당 연결을 준비하지 못했습니다. 다시 접속해 주세요.") end
	end
	pushAll()
end
Players.PlayerAdded:Connect(function(player) task.spawn(added, player) end)
local detached = {}
local function releaseDetached(id: number)
	if detached[id] then return end
	detached[id] = true
	task.spawn(function()
		local deadline = os.clock() + Config.DetachedReleaseRetrySeconds
		while not lookup(id) and data:HasProfile(id) do
			if pcall(function() data:Release(id) end) then break end
			if os.clock() >= deadline then
				-- No further renewal for departed actors. Preserve durable data;
				-- an unavailable store's persisted lease will expire naturally.
				if pcall(function() data:Abandon(id) end) then break end
			end
			task.wait(0.5)
		end
		detached[id] = nil
	end)
end
Players.PlayerRemoving:Connect(function(player)
	local id = actorByPlayer[player]
	if not id then return end
	if hunting then
		local ok, reason = pcall(hunting.FlushActor, id)
		if not ok then log("Hunting departure flush: " .. tostring(reason)) end
	end
	playerByActor[id], actorByPlayer[player], sessionByActor[id], lastRequest[id] = nil, nil, nil, nil
	party:Leave(id); travel:Forget(id)
	expeditionTravel:Forget(id, lookup)
	releaseDetached(id)
	pushAll()
end)
game:GetService("TeleportService").TeleportInitFailed:Connect(function(player, _result, message, _placeId, options)
	local id = actorByPlayer[player]
	if not id then return end
	local ok, reason = pcall(function()
		local token = options:GetTeleportData()
		if type(token) == "table" and type(token.SessionId) == "string" then
			travel:RecoverFailure(id, token.SessionId, lookup, token.AttemptId, token.Destination)
		end
	end)
	log("TeleportInitFailed: " .. tostring(message))
	if not ok then log("Teleport recovery: " .. tostring(reason)) end
	pushAll()
end)
task.spawn(function()
	while true do
		task.wait(Config.HeartbeatSeconds)
		for _, id in data:LoadedUserIds() do if not lookup(id) then releaseDetached(id) end end
		for _, id in data:HeartbeatAll(function(userId) return lookup(userId) ~= nil end) do
			local player = lookup(id); if player then player:Kick("데이터 연결이 중단되었습니다. 다시 접속해 주세요.") end
		end
		pushAll()
	end
end)
game:BindToClose(function()
	if hunting then
		local ok, reason = pcall(hunting.Close)
		if not ok then log("Hunting close flush: " .. tostring(reason)) end
	end
	for id in playerByActor do if data:HasProfile(id) then pcall(function() data:Release(id) end) end end
end)
for _, player in Players:GetPlayers() do task.spawn(added, player) end
print("[MonCook] Foundation services ready; " .. (if fake then "Studio fake transport" else "published transport"))
