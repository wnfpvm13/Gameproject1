--!strict
-- Real service integration, deterministic Studio transport, no live Roblox APIs.
local Coordinator = require(script.Parent.Parent.src.server.Services.ExpeditionCoordinator)
local ExpeditionService = require(script.Parent.Parent.src.server.Services.ExpeditionService)
local DataService = require(script.Parent.Parent.src.server.Services.DataService)
local PartyService = require(script.Parent.Parent.src.server.Services.PartyService)
local Teleport = require(script.Parent.Parent.src.server.Services.TeleportServiceWrapper)
local Fake = require(script.Parent.Parent.src.server.Services.FakeTeleport)
local Store = require(script.Parent.Support.InMemoryStore)
local Defaults = require(script.Parent.Parent.src.shared.Utilities.PlayerDataDefaults)
local Migration = require(script.Parent.Parent.src.shared.Utilities.PlayerDataMigration)

local REGION, TARGET = "GreenwoodDeepRuins", "TwinOgre"

local function equal(left: any, right: any): boolean
	if type(left) ~= type(right) then return false end
	if type(left) ~= "table" then return left == right end
	for key, value in left do if not equal(value, right[key]) then return false end end
	for key in right do if left[key] == nil then return false end end
	return true
end

local function rejects(callback: () -> (), fragment: string)
	local ok, message = pcall(callback)
	assert(not ok and string.find(tostring(message), fragment, 1, true), tostring(message))
end

local function fixture(): any
	local state: any = {
		Time = 1000, NextId = 0, Players = {}, Original = {}, Logs = {},
		OnReserve = nil, OnSend = nil, OtherBusy = {}, OtherLocations = {},
	}
	local function newId(): string
		state.NextId += 1
		return "expedition-integration-" .. tostring(state.NextId)
	end
	state.Store = Store.new()
	state.Data = DataService.new({
		Store = state.Store, OwnerId = "ExpeditionStudio", LockSeconds = 180,
		Now = function(): number return state.Time end,
		NewData = Defaults.new, Migrate = Migration.migrate,
	})
	for _, id in { 11, 22, 33 } do
		state.Players[id] = { UserId = id }
		state.Data:Load(id)
		state.Data:Update(id, function(data: any)
			data.Currencies.Gold = 100 + id
			data.Inventory.Ingredients = { HornboarMeat = 9, WildHerb = 5 }
			data.Inventory.Materials = { HornCore = 2 }
			data.FutureExtension = { Preserved = true }
			data.RestaurantSession = { SessionId = "old-restaurant", HostUserId = id,
				PartyUserIds = { id }, State = "Closed", Pantry = {}, SettlementVersion = 1 }
			data.SettlementReceipts = { ["old-restaurant"] = { SessionId = "old-restaurant",
				HostUserId = id, Kind = "Settlement", Gold = 0, Renown = 0,
				ReturnedPantry = { WildHerb = 2 }, SettlementVersion = 1, SettledAt = 800 } }
		end)
		state.Original[id] = state.Data:Get(id)
	end
	state.Party = PartyService.new({ NewId = newId, MaxMembers = 4,
		Now = function(): number return state.Time end, InviteTTLSeconds = 60,
		ValidActivityTarget = function(activity: string, target: string): boolean
			return (activity == "Expedition" and target == TARGET)
				or (activity == "Restaurant" and target == "HostRestaurant")
		end,
	})
	state.Expeditions = ExpeditionService.new({ NewId = newId, MaxMembers = 4,
		Now = function(): number return state.Time end,
		ValidTarget = function(region: string, target: string): boolean return region == REGION and target == TARGET end,
	})
	state.Transport = Fake.new()
	function state.Transport:Reserve(placeId: number): (string, string)
		local onReserve: any = state.OnReserve
		if onReserve ~= nil then (onReserve :: () -> ())() end
		return Fake.Reserve(self, placeId)
	end
	function state.Transport:Send(placeId: number, players: { any }, payload: any, accessCode: string?)
		for _, player in players do
			assert(not state.Data:HasProfile(player.UserId), "profile retained at send")
			assert(state.Store:Read("Player_" .. tostring(player.UserId)).Lock == nil, "durable lease retained at send")
		end
		local onSend: any = state.OnSend
		if onSend ~= nil then (onSend :: (any) -> ())(payload) end
		Fake.Send(self, placeId, players, payload, accessCode)
	end
	state.Teleport = Teleport.new({ IsStudio = true, UseFakeTeleport = true,
		WorldPlaceId = 0, RestaurantPlaceId = 0, ExpeditionPlaceIds = { [REGION] = 0 }, Transport = state.Transport })
	state.Coordinator = Coordinator.new({ Data = state.Data, Party = state.Party, Expeditions = state.Expeditions,
		Teleport = state.Teleport, IsFake = true, NewId = newId,
		IsOtherTraveling = function(id: number): boolean return state.OtherBusy[id] == true end,
		OtherLocation = function(id: number): string return state.OtherLocations[id] or "World" end,
		Log = function(message: string) table.insert(state.Logs, message) end,
	})
	state.Lookup = function(id: number): any return state.Players[id] end
	local party = state.Party:Create(11, { Activity = "Expedition", TargetId = TARGET })
	state.Party:Join(22, party.PartyId)
	state.Party:Join(33, party.PartyId)
	local proposal = state.Party:Propose(11)
	state.Party:Respond(22, proposal.ProposalId, true)
	state.Party:Respond(33, proposal.ProposalId, false)
	state.ProposalId = proposal.ProposalId
	return state
end

local function start(state: any): any
	return state.Coordinator:Start(11, state.ProposalId, REGION, TARGET, state.Lookup)
end

local function preserved(state: any)
	for _, id in { 11, 22, 33 } do
		assert(state.Data:HasProfile(id), "connected profile was not recovered")
		assert(equal(state.Data:Get(id), state.Original[id]), "expedition changed PlayerData or an old receipt")
		assert(state.Store:Read("Player_" .. tostring(id)).Lock.OwnerId == "ExpeditionStudio")
		assert(not state.Coordinator:IsTraveling(id), "activity left a busy flag")
	end
end

local function disconnectedDeparture(state: any): thread
	local realRelease = state.Data.Release
	state.Data.Release = function(self: any, id: number): any
		if id == 11 then coroutine.yield("host release pending") end
		return realRelease(self, id)
	end
	local departing = coroutine.create(function()
		rejects(function() start(state) end, "operation was cancelled")
	end)
	local ok, reason = coroutine.resume(departing)
	assert(ok and reason == "host release pending")
	state.Players[11] = nil
	state.Party:Leave(11)
	state.Coordinator:Forget(11, state.Lookup)
	assert(state.Party:Get(22).LeaderUserId == 22 and state.Party:Get(22).Status == "Forming")
	assert(state.Coordinator:GetForMember(22) == nil and not state.Coordinator:IsTraveling(22))
	return departing
end

local function finishCancelled(departing: thread)
	local ok, reason = coroutine.resume(departing)
	assert(ok, tostring(reason))
	assert(coroutine.status(departing) == "dead")
end

return function(): number
	local passed = 0
	local function check(_name: string, callback: () -> ()) callback(); passed += 1 end
	check("selected JOIN members enter fake expedition with released leases", function()
		local state = fixture()
		local stayEnvelope = state.Store:Read("Player_33")
		local session = start(state)
		assert(session.State == "Active" and session.RegionId == REGION and session.TargetId == TARGET)
		assert(#session.MemberUserIds == 2 and session.MemberUserIds[1] == 11 and session.MemberUserIds[2] == 22)
		assert(state.Coordinator:GetForMember(22).SessionId == session.SessionId)
		assert(state.Coordinator:GetForMember(33) == nil)
		assert(state.Coordinator:Location(11) == "Expedition" and state.Coordinator:Location(22) == "Expedition")
		assert(state.Coordinator:Location(33) == "World" and state.Party:Get(11).Status == "InActivity")
		local sent = state.Transport:GetCalls()[2]
		assert(sent.Payload.Destination == "Expedition" and sent.Payload.RegionId == REGION)
		assert(sent.Payload.SessionId == session.SessionId and sent.Payload.AttemptId ~= nil)
		assert(#sent.Players == 2 and sent.Players[2].UserId == 22)
		assert(equal(state.Store:Read("Player_33"), stayEnvelope))
		preserved(state)
	end)
	check("reservation failure cancels indexes and restores the forming party", function()
		local state = fixture()
		state.Transport:FailNext("expedition reserve failed")
		rejects(function() start(state) end, "expedition reserve failed")
		assert(state.Coordinator:GetForMember(11) == nil and state.Coordinator:GetForMember(22) == nil)
		assert(state.Party:Get(11).Status == "Forming" and state.Party:GetProposal(11) == nil)
		assert(#state.Transport:GetCalls() == 1)
		preserved(state)
	end)
	check("consent changed during reservation never sends a member", function()
		local state = fixture()
		state.OnReserve = function() state.Party:Respond(22, state.ProposalId, false) end
		rejects(function() start(state) end, "consent changed")
		assert(#state.Transport:GetCalls() == 1 and state.Coordinator:GetForMember(11) == nil)
		assert(state.Party:Get(11).Status == "Forming")
		preserved(state)
	end)
	check("send failure reloads profiles without changing restaurant receipts", function()
		local state = fixture()
		state.OnSend = function(payload: any)
			if payload.Destination == "Expedition" then state.Transport:FailNext("expedition send failed") end
		end
		rejects(function() start(state) end, "expedition send failed")
		assert(#state.Transport:GetCalls() == 2)
		assert(state.Coordinator:GetForMember(11) == nil and state.Coordinator:GetForMember(22) == nil)
		assert(state.Party:Get(11).Status == "Forming")
		preserved(state)
	end)
	check("second consent check catches a change while marking teleporting", function()
		local state = fixture()
		local realMark = state.Expeditions.MarkTeleporting
		state.Expeditions.MarkTeleporting = function(self: any, hostId: number, id: string, privateId: string): any
			local result = realMark(self, hostId, id, privateId)
			coroutine.yield("mark pending")
			return result
		end
		local thread = coroutine.create(function() rejects(function() start(state) end, "consent changed") end)
		local ok, reason = coroutine.resume(thread)
		assert(ok and reason == "mark pending")
		assert(state.Coordinator:IsTraveling(11) and state.Coordinator:IsTraveling(22))
		state.Party:Respond(22, state.ProposalId, false)
		ok, reason = coroutine.resume(thread)
		assert(ok, tostring(reason))
		assert(coroutine.status(thread) == "dead" and #state.Transport:GetCalls() == 1)
		assert(state.Coordinator:GetForMember(11) == nil)
		preserved(state)
	end)
	check("result routes close once and require fresh consent before another activity", function()
		for _, destination in { "Repeat", "HostRestaurant", "Hearthcross" } do
			local state = fixture()
			local session = start(state)
			state.Coordinator:Complete(11, session.SessionId)
			rejects(function() state.Coordinator:Complete(11, session.SessionId) end, "active expedition host")
			local receipt = state.Coordinator:Result(11, session.SessionId, destination, "result-action", state.Lookup)
			assert(receipt.Kind == "Return" and receipt.Destination == destination)
			assert(state.Expeditions:Get(session.SessionId).State == "Closed" and state.Coordinator:GetForMember(11) == nil)
			assert(state.Coordinator:Location(11) == "World" and state.Coordinator:Location(22) == "World")
			local fresh = state.Party:GetProposal(11)
			if destination == "Hearthcross" then
				assert(fresh == nil and state.Party:Get(11).Status == "Forming")
			else
				assert(fresh ~= nil and fresh.ProposalId ~= state.ProposalId)
				assert(fresh.Responses[11] == true and fresh.Responses[22] == nil and fresh.Responses[33] == nil)
				rejects(function() state.Party:Ready(11, fresh.ProposalId) end, "pending responses")
				local party = state.Party:Get(11)
				assert(party.Status == "ReadyCheck")
				assert(party.Activity == (if destination == "Repeat" then "Expedition" else "Restaurant"))
				assert(party.TargetId == (if destination == "Repeat" then TARGET else "HostRestaurant"))
			end
			local callsBefore = #state.Transport:GetCalls()
			assert(equal(receipt, state.Coordinator:Result(11, session.SessionId, destination, "result-action", state.Lookup)))
			assert(#state.Transport:GetCalls() == callsBefore, "duplicate result resent the party")
			assert(equal(state.Party:GetProposal(11), fresh), "duplicate result replaced the ready check")
			rejects(function() state.Coordinator:Result(11, session.SessionId, destination, "different-action", state.Lookup) end, "return requires Result")
			local conflicting = if destination == "Hearthcross" then "Repeat" else "Hearthcross"
			rejects(function() state.Coordinator:Result(11, session.SessionId, conflicting, "result-action", state.Lookup) end, "conflict")
			preserved(state)
			if destination == "Repeat" then
				state.Party:Respond(22, fresh.ProposalId, true)
				state.Party:Respond(33, fresh.ProposalId, false)
				local repeated = state.Coordinator:Start(11, fresh.ProposalId, REGION, TARGET, state.Lookup)
				assert(repeated.State == "Active" and repeated.SessionId ~= session.SessionId)
				preserved(state)
			end
		end
	end)
	check("failed result send restores Result and retires its action before retry", function()
		local state = fixture()
		local session = start(state)
		state.Coordinator:Complete(11, session.SessionId)
		state.OnSend = function(payload: any)
			if payload.Destination == "World" then state.Transport:FailNext("expedition return failed") end
		end
		rejects(function() state.Coordinator:Result(11, session.SessionId, "Repeat", "failed-action", state.Lookup) end, "expedition return failed")
		assert(state.Expeditions:Get(session.SessionId).State == "Result" and state.Party:Get(11).Status == "InActivity")
		assert(state.Party:GetProposal(11) == nil and state.Expeditions:GetReceipt(11, session.SessionId) == nil)
		assert(state.Coordinator:Location(11) == "Expedition")
		preserved(state)
		state.OnSend = nil
		local callsBefore = #state.Transport:GetCalls()
		rejects(function() state.Coordinator:Result(11, session.SessionId, "Repeat", "failed-action", state.Lookup) end, "stale")
		assert(#state.Transport:GetCalls() == callsBefore)
		local receipt = state.Coordinator:Result(11, session.SessionId, "Hearthcross", "retry-action", state.Lookup)
		assert(receipt.Kind == "Return" and #state.Transport:GetCalls() == callsBefore + 1)
		preserved(state)
	end)
	check("other activity travel and restaurant location block entry before mutation", function()
		for _, guard in { "Travel", "Location" } do
			local state = fixture()
			local before = state.Party:GetProposal(11)
			if guard == "Travel" then state.OtherBusy[22] = true else state.OtherLocations[22] = "Restaurant" end
			rejects(function() start(state) end, if guard == "Travel" then "another activity" else "return to World")
			assert(equal(before, state.Party:GetProposal(11)) and #state.Transport:GetCalls() == 0)
			assert(state.Coordinator:GetForMember(11) == nil)
			preserved(state)
		end
	end)
	check("published expedition entry and result are blocked before state changes", function()
		local state = fixture()
		state.Coordinator.IsFake = false
		rejects(function() start(state) end, "Studio fake mode")
		assert(#state.Transport:GetCalls() == 0 and state.Coordinator:GetForMember(11) == nil)
		state.Coordinator.IsFake = true
		local session = start(state)
		state.Coordinator.IsFake = false
		rejects(function() state.Coordinator:Complete(11, session.SessionId) end, "Studio fake mode")
		assert(state.Expeditions:Get(session.SessionId).State == "Active")
		state.Coordinator.IsFake = true
		state.Coordinator:Complete(11, session.SessionId)
		state.Coordinator.IsFake = false
		rejects(function() state.Coordinator:Result(11, session.SessionId, "Repeat", "action", state.Lookup) end, "Studio fake mode")
		assert(state.Expeditions:Get(session.SessionId).State == "Result" and #state.Transport:GetCalls() == 2)
		preserved(state)
	end)
	check("host disconnect releases active expedition indexes for remaining members", function()
		local state = fixture()
		local session = start(state)
		state.Players[11] = nil
		state.Coordinator:Forget(11, state.Lookup)
		state.Party:Leave(11)
		assert(state.Expeditions:Get(session.SessionId).State == "Closed")
		assert(state.Expeditions:GetReceipt(11, session.SessionId).Kind == "Abandon")
		assert(state.Coordinator:GetForMember(11) == nil and state.Coordinator:GetForMember(22) == nil)
		assert(state.Party:Get(22).Status == "Forming" and state.Party:Get(22).LeaderUserId == 22)
		assert(state.Coordinator:Location(22) == "World" and #state.Transport:GetCalls() == 2)
		preserved(state)
	end)
	check("cancelled departure cannot reset its successor active party", function()
		local state = fixture()
		local departing = disconnectedDeparture(state)
		local proposal = state.Party:Propose(22)
		state.Party:Respond(33, proposal.ProposalId, false)
		local successor = state.Coordinator:Start(22, proposal.ProposalId, REGION, TARGET, state.Lookup)
		local partyBefore, profileBefore = state.Party:Get(22), state.Store:Read("Player_22")
		local callsBefore = #state.Transport:GetCalls()
		finishCancelled(departing)
		assert(state.Expeditions:Get(successor.SessionId).State == "Active")
		assert(state.Party:Get(22).Status == "InActivity" and equal(state.Party:Get(22), partyBefore))
		assert(equal(state.Store:Read("Player_22"), profileBefore))
		assert(state.Coordinator:Location(22) == "Expedition" and #state.Transport:GetCalls() == callsBefore)
	end)
	check("cancelled departure preserves a successor ready check and invitation", function()
		local state = fixture()
		local departing = disconnectedDeparture(state)
		local proposal = state.Party:Propose(22)
		state.Party:Respond(33, proposal.ProposalId, false)
		state.Party:Invite(22, 44)
		local partyBefore, invitesBefore = state.Party:Get(22), state.Party:GetInvites(44)
		finishCancelled(departing)
		assert(state.Party:Get(22).Status == "ReadyCheck" and equal(state.Party:Get(22), partyBefore))
		assert(equal(state.Party:GetInvites(44), invitesBefore) and #invitesBefore == 1)
		assert(state.Party:GetProposal(22).ProposalId == proposal.ProposalId)
		assert(#state.Transport:GetCalls() == 1)
	end)
	check("old recovery cannot reacquire a successor departure profile lease", function()
		local state = fixture()
		local departing = disconnectedDeparture(state)
		local proposal = state.Party:Propose(22)
		state.Party:Respond(33, proposal.ProposalId, false)
		local realRelease = state.Data.Release
		state.Data.Release = function(self: any, id: number): any
			local value = realRelease(self, id)
			if id == 22 then coroutine.yield("successor lease released") end
			return value
		end
		local successorSession: any
		local successor = coroutine.create(function()
			successorSession = state.Coordinator:Start(22, proposal.ProposalId, REGION, TARGET, state.Lookup)
		end)
		local ok, reason = coroutine.resume(successor)
		assert(ok and reason == "successor lease released")
		assert(not state.Data:HasProfile(22) and state.Coordinator:IsTraveling(22))
		finishCancelled(departing)
		assert(not state.Data:HasProfile(22) and state.Store:Read("Player_22").Lock == nil)
		assert(state.Coordinator:IsTraveling(22) and state.Party:Get(22).Status == "InActivity")
		ok, reason = coroutine.resume(successor)
		assert(ok, tostring(reason))
		assert(coroutine.status(successor) == "dead" and successorSession.State == "Active")
		assert(state.Data:HasProfile(22) and not state.Coordinator:IsTraveling(22))
		assert(equal(state.Data:Get(22), state.Original[22]))
	end)
	check("failed reservation keeps a newly replaced ready check and its invitation", function()
		local state = fixture()
		state.OnReserve = function() coroutine.yield("reservation pending") end
		local departing = coroutine.create(function() rejects(function() start(state) end, "stale") end)
		local ok, reason = coroutine.resume(departing)
		assert(ok and reason == "reservation pending")
		state.Party:SetActivity(11, "Expedition", TARGET)
		local fresh = state.Party:Propose(11)
		state.Party:Respond(22, fresh.ProposalId, true)
		state.Party:Respond(33, fresh.ProposalId, false)
		state.Party:Invite(11, 44)
		local partyBefore, invitesBefore = state.Party:Get(11), state.Party:GetInvites(44)
		ok, reason = coroutine.resume(departing)
		assert(ok, tostring(reason))
		assert(coroutine.status(departing) == "dead")
		assert(equal(state.Party:Get(11), partyBefore) and state.Party:Get(11).Status == "ReadyCheck")
		assert(equal(state.Party:GetInvites(44), invitesBefore) and #invitesBefore == 1)
		assert(state.Coordinator:GetForMember(11) == nil and #state.Transport:GetCalls() == 1)
		preserved(state)
	end)
	return passed
end
