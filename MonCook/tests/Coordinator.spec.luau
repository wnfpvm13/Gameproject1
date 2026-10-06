--!strict
-- Integration of the real pure services; no Roblox Instances or live teleports.
local Coordinator = require(script.Parent.Parent.src.server.Services.FoundationCoordinator)
local DataService = require(script.Parent.Parent.src.server.Services.DataService)
local PartyService = require(script.Parent.Parent.src.server.Services.PartyService)
local SessionService = require(script.Parent.Parent.src.server.Services.SessionService)
local Teleport = require(script.Parent.Parent.src.server.Services.TeleportServiceWrapper)
local Fake = require(script.Parent.Parent.src.server.Services.FakeTeleport)
local Store = require(script.Parent.Support.InMemoryStore)
local Defaults = require(script.Parent.Parent.src.shared.Utilities.PlayerDataDefaults)
local Migration = require(script.Parent.Parent.src.shared.Utilities.PlayerDataMigration)

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local copied = {}
	for key, child in value do copied[key] = clone(child) end
	return copied
end

local function equal(left: any, right: any): boolean
	if type(left) ~= type(right) then return false end
	if type(left) ~= "table" then return left == right end
	for key, child in left do if not equal(child, right[key]) then return false end end
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
		Mirrors = {}, ReleasedAtSend = {}, OnReserve = nil, OnSend = nil,
	}
	state.Store = Store.new()
	state.Data = DataService.new({
		Store = state.Store, OwnerId = "StudioFake", LockSeconds = 180,
		Now = function(): number return state.Time end,
		NewData = Defaults.new, Migrate = Migration.migrate,
		Log = function(message: string) table.insert(state.Logs, message) end,
	})
	local function nextId(): string
		state.NextId += 1
		return "coordinator-" .. tostring(state.NextId)
	end
	state.Party = PartyService.new({ MaxMembers = 4, NewId = nextId })
	local mirror: any = {}
	function mirror:GetAsync(id: string): any return clone(state.Mirrors[id]) end
	function mirror:SetAsync(id: string, session: any) state.Mirrors[id] = clone(session) end
	state.Sessions = SessionService.new({
		Data = state.Data, Store = mirror, NewId = nextId, MaxPartySize = 4,
		IsStudio = true, Now = function(): number return state.Time end,
		ValidIngredient = function(id: string): boolean return id == "HornboarMeat" or id == "WildHerb" end,
	})
	state.Transport = Fake.new()
	function state.Transport:Reserve(placeId: number): (string, string)
		local onReserve: any = state.OnReserve
		if onReserve ~= nil then (onReserve :: () -> ())() end
		return Fake.Reserve(self, placeId)
	end
	function state.Transport:Send(placeId: number, players: { any }, payload: any, accessCode: string?)
		local released = {}
		for _, player in players do
			local id = player.UserId
			assert(not state.Data:HasProfile(id), "sender still holds a cached profile")
			assert(state.Store:Read("Player_" .. tostring(id)).Lock == nil, "sender still holds the durable lease")
			table.insert(released, id)
		end
		table.insert(state.ReleasedAtSend, { Destination = payload.Destination, Members = released })
		local onSend: any = state.OnSend
		if onSend ~= nil then (onSend :: (any) -> ())(payload) end
		Fake.Send(self, placeId, players, payload, accessCode)
	end
	state.Teleport = Teleport.new({
		IsStudio = true, UseFakeTeleport = true, WorldPlaceId = 0, RestaurantPlaceId = 0,
		Transport = state.Transport,
	})
	state.Coordinator = Coordinator.new({
		Data = state.Data, Party = state.Party, Sessions = state.Sessions,
		Teleport = state.Teleport, IsFake = true,
		Log = function(message: string) table.insert(state.Logs, message) end,
	})
	state.Lookup = function(id: number): any return state.Players[id] end
	for _, id in { 11, 22, 33, 44, 55 } do
		state.Players[id] = { UserId = id }
		state.Data:Load(id)
		state.Data:Update(id, function(data: any)
			data.Currencies.Gold = 100 + id
			data.Progression.RestaurantRenown = id
			data.Inventory.Ingredients = { HornboarMeat = 10, WildHerb = 6 }
			data.Inventory.Materials = { HornCore = 2 }
		end)
		state.Original[id] = state.Data:Get(id)
	end
	return state
end

local function proposal(state: any): string
	local party = state.Party:Create(11)
	state.Party:Join(22, party.PartyId)
	state.Party:Join(33, party.PartyId)
	local departure = state.Party:Propose(11)
	state.Party:Respond(22, departure.ProposalId, true)
	state.Party:Respond(33, departure.ProposalId, false)
	return departure.ProposalId
end

local function assertLoaded(state: any, members: { number }, location: string)
	for _, id in members do
		assert(state.Data:HasProfile(id), "profile was not reloaded")
		local lock = state.Store:Read("Player_" .. tostring(id)).Lock
		assert(lock.OwnerId == "StudioFake" and lock.ExpiresAt == state.Time + 180)
		assert(not state.Coordinator:IsTraveling(id), "travel flag was not cleared")
		assert(state.Coordinator:Location(id) == location)
	end
end

local function assertEconomyPreserved(state: any, members: { number })
	for _, id in members do
		local data, original = state.Data:Get(id), state.Original[id]
		assert(equal(data.Inventory, original.Inventory), "inventory changed across travel")
		assert(equal(data.Currencies, original.Currencies), "currencies changed across travel")
		assert(equal(data.Progression, original.Progression), "progression changed across travel")
	end
end

local function publishedCoordinator(state: any): any
	-- Keep the deterministic Studio transport but wait for explicit failure/
	-- arrival callbacks, as the published orchestration does after Send accepts.
	return Coordinator.new({
		Data = state.Data, Party = state.Party, Sessions = state.Sessions,
		Teleport = state.Teleport, IsFake = false,
		Log = function(message: string) table.insert(state.Logs, message) end,
	})
end

return function(): number
	local passed = 0
	local function check(_name: string, test: () -> ()) test(); passed += 1 end
	check("consenting party World-Restaurant-World preserves data and leases", function()
		local state = fixture()
		local departure = proposal(state)
		local stayEnvelope = state.Store:Read("Player_33")
		local session = state.Coordinator:Start(11, departure, { HornboarMeat = 3, WildHerb = 2 }, state.Lookup)
		assert(session.State == "Active" and #session.PartyUserIds == 2)
		assert(session.PartyUserIds[1] == 11 and session.PartyUserIds[2] == 22)
		assert(state.Sessions:GetForMember(session.SessionId, 22).State == "Active")
		assert(state.Data:Get(11).Inventory.Ingredients.HornboarMeat == 7)
		assert(state.Data:Get(11).Inventory.Ingredients.WildHerb == 4)
		assert(equal(state.Data:Get(22), state.Original[22]))
		assert(equal(state.Store:Read("Player_33"), stayEnvelope))
		assertLoaded(state, { 11, 22 }, "Restaurant")
		assertLoaded(state, { 33 }, "World")
		local outbound = state.Transport:GetCalls()[2]
		assert(#outbound.Players == 2 and outbound.Players[1].UserId == 11 and outbound.Players[2].UserId == 22)
		assert(outbound.Payload.SessionId == session.SessionId and outbound.Payload.Destination == "Restaurant")
		local receipt = state.Coordinator:Return(11, state.Lookup)
		assert(receipt.Kind == "Settlement" and receipt.Gold == 0 and receipt.Renown == 0)
		assert(equal(receipt.ReturnedPantry, { HornboarMeat = 3, WildHerb = 2 }))
		assert(state.Sessions:GetHostSession(11).State == "Closed")
		assert(next(state.Sessions:GetHostSession(11).Pantry) == nil)
		assertLoaded(state, { 11, 22, 33 }, "World")
		assertEconomyPreserved(state, { 11, 22, 33 })
		assert(equal(state.Store:Read("Player_33"), stayEnvelope))
		assert(#state.ReleasedAtSend == 2 and state.ReleasedAtSend[1].Destination == "Restaurant")
		assert(state.ReleasedAtSend[2].Destination == "World" and #state.ReleasedAtSend[2].Members == 2)
		assert(state.Party:GetProposal(11) == nil)
	end)
	check("reservation failure refunds committed escrow", function()
		local state = fixture()
		local departure = proposal(state)
		state.Transport:FailNext("reservation unavailable")
		rejects(function() state.Coordinator:Start(11, departure, { HornboarMeat = 4 }, state.Lookup) end, "reservation unavailable")
		local session = state.Sessions:GetHostSession(11)
		assert(session.State == "Closed" and next(session.Pantry) == nil)
		local receipt = state.Data:Get(11).SettlementReceipts[session.SessionId]
		assert(receipt.Kind == "Rollback" and receipt.ReturnedPantry.HornboarMeat == 4)
		assert(receipt.Gold == 0 and receipt.Renown == 0)
		assertLoaded(state, { 11, 22, 33 }, "World")
		assertEconomyPreserved(state, { 11, 22, 33 })
		assert(#state.Transport:GetCalls() == 1 and #state.ReleasedAtSend == 0)
	end)
	check("restaurant send failure reloads released profiles and refunds once", function()
		local state = fixture()
		local departure = proposal(state)
		state.OnSend = function(payload: any)
			if payload.Destination == "Restaurant" then state.Transport:FailNext("restaurant send rejected") end
		end
		rejects(function() state.Coordinator:Start(11, departure, { HornboarMeat = 4, WildHerb = 1 }, state.Lookup) end, "restaurant send rejected")
		local session = state.Sessions:GetHostSession(11)
		assert(session.State == "Closed" and session.DestinationPrivateServerId ~= nil)
		local receipt = state.Sessions:Rollback(11, session.SessionId)
		assert(receipt.Kind == "Rollback" and receipt.ReturnedPantry.HornboarMeat == 4)
		assertLoaded(state, { 11, 22, 33 }, "World")
		assertEconomyPreserved(state, { 11, 22, 33 })
		assert(#state.ReleasedAtSend == 1 and #state.ReleasedAtSend[1].Members == 2)
		assert(#state.Transport:GetCalls() == 2)
	end)
	check("world send failure retains receipt and retry cannot duplicate inventory", function()
		local state = fixture()
		local session = state.Coordinator:Start(11, proposal(state), { HornboarMeat = 5, WildHerb = 2 }, state.Lookup)
		state.OnSend = function(payload: any)
			if payload.Destination == "World" then state.Transport:FailNext("world send rejected") end
		end
		rejects(function() state.Coordinator:Return(11, state.Lookup) end, "world send rejected")
		local committed = state.Data:Get(11).SettlementReceipts[session.SessionId]
		assert(committed.Kind == "Settlement" and committed.Gold == 0 and committed.Renown == 0)
		assert(committed.SettledAt == 1000 and state.Sessions:GetHostSession(11).State == "Closed")
		assertLoaded(state, { 11, 22 }, "Restaurant")
		assertEconomyPreserved(state, { 11, 22, 33 })
		state.OnSend = nil
		state.Time = 1001
		local retried = state.Coordinator:Return(11, state.Lookup)
		assert(equal(committed, retried), "retry changed the committed settlement receipt")
		assertLoaded(state, { 11, 22 }, "World")
		assertEconomyPreserved(state, { 11, 22, 33 })
		local receiptCount = 0
		for _ in state.Data:Get(11).SettlementReceipts do receiptCount += 1 end
		assert(receiptCount == 1 and #state.ReleasedAtSend == 3)
	end)
	check("insufficient pantry changes no profile, lease, session, or transport", function()
		local state = fixture()
		local departure = proposal(state)
		local before = clone(state.Store.Values)
		rejects(function() state.Coordinator:Start(11, departure, { HornboarMeat = 4, WildHerb = 7 }, state.Lookup) end, "insufficient")
		assert(equal(state.Store.Values, before) and next(state.Mirrors) == nil)
		assert(state.Sessions:GetHostSession(11) == nil and #state.Transport:GetCalls() == 0)
		assertLoaded(state, { 11, 22, 33 }, "World")
		assertEconomyPreserved(state, { 11, 22, 33 })
		assert(#state.Party:Ready(11, departure) == 2)
	end)
	check("consent changes during reservation abort departure and refund escrow", function()
		local state = fixture()
		local departure = proposal(state)
		state.OnReserve = function() state.Party:Respond(22, departure, false) end
		rejects(function() state.Coordinator:Start(11, departure, { HornboarMeat = 2 }, state.Lookup) end, "consent changed")
		local session = state.Sessions:GetHostSession(11)
		assert(session.State == "Closed" and session.DestinationPrivateServerId == nil)
		assert(state.Data:Get(11).SettlementReceipts[session.SessionId].Kind == "Rollback")
		assertLoaded(state, { 11, 22, 33 }, "World")
		assertEconomyPreserved(state, { 11, 22, 33 })
		assert(#state.Transport:GetCalls() == 1 and #state.ReleasedAtSend == 0)
		local selected = state.Party:Ready(11, departure)
		assert(#selected == 1 and selected[1] == 11)
	end)
	check("fake arrival activates each host session independently", function()
		local state = fixture()
		local first = state.Coordinator:Start(11, proposal(state), { HornboarMeat = 2 }, state.Lookup)
		local otherParty = state.Party:Create(44)
		state.Party:Join(55, otherParty.PartyId)
		local otherProposal = state.Party:Propose(44)
		state.Party:Respond(55, otherProposal.ProposalId, true)
		local second = state.Coordinator:Start(44, otherProposal.ProposalId, { WildHerb = 3 }, state.Lookup)
		assert(first.State == "Active" and second.State == "Active" and first.SessionId ~= second.SessionId)
		assert(first.DestinationPrivateServerId ~= second.DestinationPrivateServerId)
		assert(state.Sessions:GetHostSession(11).State == "Active" and state.Sessions:GetHostSession(44).State == "Active")
		assertLoaded(state, { 11, 22, 44, 55 }, "Restaurant")
		state.Coordinator:Return(11, state.Lookup)
		assert(state.Sessions:GetHostSession(44).State == "Active")
		assert(state.Data:Get(44).Inventory.Ingredients.WildHerb == 3)
		assertLoaded(state, { 44, 55 }, "Restaurant")
		state.Coordinator:Return(44, state.Lookup)
		assert(state.Sessions:GetHostSession(11).State == "Closed" and state.Sessions:GetHostSession(44).State == "Closed")
		assertLoaded(state, { 11, 22, 33, 44, 55 }, "World")
		assertEconomyPreserved(state, { 11, 22, 33, 44, 55 })
	end)
	check("helper return leaves both host sessions and their pantry untouched", function()
		local state = fixture()
		local session = state.Coordinator:Start(11, proposal(state), { HornboarMeat = 4 }, state.Lookup)
		state.Party:Create(44)
		local otherProposal = state.Party:Propose(44)
		state.Coordinator:Start(44, otherProposal.ProposalId, { WildHerb = 2 }, state.Lookup)
		local hostBefore, otherBefore = state.Store:Read("Player_11"), state.Store:Read("Player_44")
		state.Coordinator:ReturnMember(22, session.SessionId, state.Lookup)
		assertLoaded(state, { 22 }, "World")
		assertLoaded(state, { 11, 44 }, "Restaurant")
		assert(equal(state.Store:Read("Player_11"), hostBefore), "helper return changed the host escrow or lease")
		assert(equal(state.Store:Read("Player_44"), otherBefore), "helper return changed an independent session")
		assert(state.Sessions:GetHostSession(11).State == "Active" and state.Sessions:GetHostSession(44).State == "Active")
		assertEconomyPreserved(state, { 22 })
		local calls = state.Transport:GetCalls()
		local sent = calls[#calls]
		assert(sent.Payload.Destination == "World" and sent.Payload.SessionId == session.SessionId)
		assert(#sent.Players == 1 and sent.Players[1].UserId == 22)
	end)
	check("simultaneous accepted helper returns recover independently", function()
		local state = fixture()
		local departure = proposal(state)
		state.Party:Respond(33, departure, true)
		local session = state.Coordinator:Start(11, departure, { HornboarMeat = 3 }, state.Lookup)
		local hostBefore = state.Store:Read("Player_11")
		state.Coordinator = publishedCoordinator(state)
		state.Coordinator:ReturnMember(22, session.SessionId, state.Lookup)
		state.Coordinator:ReturnMember(33, session.SessionId, state.Lookup)
		local calls = state.Transport:GetCalls()
		local first, second = calls[#calls - 1].Payload, calls[#calls].Payload
		assert(first.AttemptId ~= second.AttemptId and first.SessionId == second.SessionId)
		assert(state.Coordinator:IsTraveling(22) and state.Coordinator:IsTraveling(33))
		assert(not state.Data:HasProfile(22) and not state.Data:HasProfile(33))
		state.Coordinator:RecoverFailure(22, session.SessionId, state.Lookup, first.AttemptId, "World")
		assert(state.Data:HasProfile(22) and not state.Coordinator:IsTraveling(22))
		assert(not state.Data:HasProfile(33) and state.Coordinator:IsTraveling(33))
		state.Coordinator:RecoverFailure(33, session.SessionId, state.Lookup, second.AttemptId, "World")
		assert(state.Data:HasProfile(33) and not state.Coordinator:IsTraveling(33))
		assert(equal(state.Store:Read("Player_11"), hostBefore))
		assert(state.Sessions:GetHostSession(11).State == "Active")
		assertEconomyPreserved(state, { 22, 33 })
	end)
	check("stale attempt and wrong destination cannot recover a pending retry", function()
		local state = fixture()
		local session = state.Coordinator:Start(11, proposal(state), { HornboarMeat = 1 }, state.Lookup)
		state.Coordinator = publishedCoordinator(state)
		state.Coordinator:ReturnMember(22, session.SessionId, state.Lookup)
		local calls = state.Transport:GetCalls()
		local first = calls[#calls].Payload
		state.Coordinator:RecoverFailure(22, session.SessionId, state.Lookup, first.AttemptId, "World")
		state.Coordinator:ReturnMember(22, session.SessionId, state.Lookup)
		calls = state.Transport:GetCalls()
		local current = calls[#calls].Payload
		assert(first.AttemptId ~= current.AttemptId)
		local released = state.Store:Read("Player_22")
		state.Coordinator:RecoverFailure(22, session.SessionId, state.Lookup, first.AttemptId, "World")
		state.Coordinator:RecoverFailure(22, session.SessionId, state.Lookup, current.AttemptId, "Restaurant")
		state.Coordinator:RecoverFailure(22, "other-session", state.Lookup, current.AttemptId, "World")
		state.Coordinator:RecoverFailure(22, session.SessionId, state.Lookup, nil, "World")
		assert(state.Coordinator:IsTraveling(22) and not state.Data:HasProfile(22))
		assert(equal(state.Store:Read("Player_22"), released), "unrelated callback reacquired the pending profile")
		state.Coordinator:RecoverFailure(22, session.SessionId, state.Lookup, current.AttemptId, "World")
		assert(state.Data:HasProfile(22) and not state.Coordinator:IsTraveling(22))
		local recovered = state.Store:Read("Player_22")
		state.Coordinator:RecoverFailure(22, session.SessionId, state.Lookup, first.AttemptId, "World")
		assert(equal(state.Store:Read("Player_22"), recovered))
		assert(state.Sessions:GetHostSession(11).State == "Active")
		assertEconomyPreserved(state, { 22 })
	end)
	check("yielding group settlement blocks helper return and clears flags on failure", function()
		local state = fixture()
		local session = state.Coordinator:Start(11, proposal(state), { HornboarMeat = 2 }, state.Lookup)
		local realSettle = state.Sessions.Settle
		state.Sessions.Settle = function(_self: any, _hostId: number, _sessionId: string): any
			coroutine.yield("settlement pending")
			error("injected settlement failure")
		end
		local returning = coroutine.create(function()
			rejects(function() state.Coordinator:Return(11, state.Lookup) end, "injected settlement failure")
		end)
		local started, pending = coroutine.resume(returning)
		assert(started and pending == "settlement pending" and coroutine.status(returning) == "suspended")
		assert(state.Coordinator:IsTraveling(11) and state.Coordinator:IsTraveling(22))
		rejects(function() state.Coordinator:ReturnMember(22, session.SessionId, state.Lookup) end, "already traveling")
		assert(#state.Transport:GetCalls() == 2)
		local resumed, message = coroutine.resume(returning)
		assert(resumed, tostring(message))
		assert(coroutine.status(returning) == "dead")
		assertLoaded(state, { 11, 22 }, "Restaurant")
		assert(state.Sessions:GetHostSession(11).State == "Active")
		assert(state.Data:Get(11).Inventory.Ingredients.HornboarMeat == 8)
		state.Sessions.Settle = realSettle
		state.Coordinator:Return(11, state.Lookup)
		assertLoaded(state, { 11, 22 }, "World")
		assertEconomyPreserved(state, { 11, 22 })
	end)
	check("consent change while session write yields prevents any send", function()
		local state = fixture()
		local departure = proposal(state)
		local realMark = state.Sessions.MarkTeleporting
		state.Sessions.MarkTeleporting = function(self: any, hostId: number, id: string, destination: string): any
			local session = realMark(self, hostId, id, destination)
			coroutine.yield("session write pending")
			return session
		end
		local departing = coroutine.create(function()
			rejects(function() state.Coordinator:Start(11, departure, { HornboarMeat = 3 }, state.Lookup) end, "consent changed during session write")
		end)
		local started, pending = coroutine.resume(departing)
		assert(started and pending == "session write pending")
		assert(state.Sessions:GetHostSession(11).State == "Teleporting")
		state.Party:Respond(22, departure, false)
		local resumed, message = coroutine.resume(departing)
		assert(resumed, tostring(message))
		assert(coroutine.status(departing) == "dead")
		assert(state.Sessions:GetHostSession(11).State == "Closed")
		assert(#state.Transport:GetCalls() == 1 and #state.ReleasedAtSend == 0)
		assertLoaded(state, { 11, 22, 33 }, "World")
		assertEconomyPreserved(state, { 11, 22, 33 })
	end)
	return passed
end
