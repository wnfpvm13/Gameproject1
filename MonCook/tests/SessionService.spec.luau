--!strict
local SessionService = require(script.Parent.Parent.src.server.Services.SessionService)

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in value do copy[key] = clone(child) end
	return copy
end

local function equal(left: any, right: any): boolean
	if type(left) ~= type(right) then return false end
	if type(left) ~= "table" then return left == right end
	for key, value in left do if not equal(value, right[key]) then return false end end
	for key in right do if left[key] == nil then return false end end
	return true
end

local function rejects(callback: () -> (), fragment: string)
	local ok, message = pcall(callback)
	assert(not ok, "Expected rejection: " .. fragment)
	assert(string.find(tostring(message), fragment, 1, true), tostring(message))
end

local function harness(): any
	local state: any = {
		Profiles = {}, Mirrors = {}, Logs = {}, NextId = 0, Time = 100,
		FailRead = false, FailWrite = false, FailCommit = false, Retry = false,
	}
	for _, id in { 11, 22, 33, 44, 55, -1, -2 } do
		state.Profiles[id] = {
			SchemaVersion = 1, Currencies = { Gold = 17 },
			Progression = { RestaurantRenown = 8 },
			Inventory = { Ingredients = { HornboarMeat = 10, WildHerb = 6 }, Materials = { HornCore = 2 } },
			FutureField = { Preserved = true }, SettlementReceipts = {},
		}
	end
	local data: any = {}
	function data:Get(id: number): any
		assert(state.Profiles[id] ~= nil, "profile not loaded")
		return clone(state.Profiles[id])
	end
	function data:Update(id: number, transform: (any) -> any): any
		assert(state.Profiles[id] ~= nil, "profile not loaded")
		local original = clone(state.Profiles[id])
		if state.Retry then
			-- Exercise a discarded transaction attempt; no closure side effects may
			-- influence the eventual authoritative update or receipt.
			transform(clone(original))
		end
		local working = clone(original)
		local replacement = transform(working)
		if state.FailCommit then error("durable write failed") end
		state.Profiles[id] = clone(replacement or working)
		return clone(state.Profiles[id])
	end
	local store: any = {}
	function store:GetAsync(id: string): any
		if state.FailRead then error("mirror unavailable") end
		return clone(state.Mirrors[id])
	end
	function store:SetAsync(id: string, record: any)
		if state.FailWrite then error("mirror unavailable") end
		state.Mirrors[id] = clone(record)
	end
	function state.NewService(isStudio: boolean?): any
		return SessionService.new({
			Data = data, Store = store, MaxPartySize = 4, IsStudio = isStudio,
			NewId = function(): string state.NextId += 1; return "session-" .. tostring(state.NextId) end,
			Now = function(): number return state.Time end,
			ValidIngredient = function(id: string): boolean return id == "HornboarMeat" or id == "WildHerb" end,
			Log = function(operation: string, detail: any) table.insert(state.Logs, { operation, detail }) end,
		})
	end
	state.Data = data
	state.Store = store
	return state
end

local function active(state: any, pantry: any): (any, any)
	local service = state.NewService()
	local session = service:Prepare(11, { 11, 22 }, pantry)
	service:MarkTeleporting(11, session.SessionId, "reserved-A")
	service:Activate(11, session.SessionId, "reserved-A")
	return service, session
end

return function(): number
	local passed = 0
	local function check(_name: string, callback: () -> ())
		callback()
		passed += 1
	end
	check("atomic escrow, canonical party, detached snapshots and unknown fields", function()
		local state = harness()
		local service = state.NewService()
		local members, selected = { 22, 11 }, { HornboarMeat = 3, WildHerb = 2 }
		local session = service:Prepare(11, members, selected)
		assert(session.State == "Preparing" and session.SettlementVersion == 0)
		assert(session.HostUserId == 11 and session.PartyUserIds[1] == 11 and session.PartyUserIds[2] == 22)
		assert(state.Profiles[11].Inventory.Ingredients.HornboarMeat == 7)
		assert(state.Profiles[11].Inventory.Ingredients.WildHerb == 4)
		assert(state.Profiles[22].Inventory.Ingredients.HornboarMeat == 10)
		assert(state.Profiles[11].FutureField.Preserved and state.Profiles[11].Inventory.Materials.HornCore == 2)
		selected.HornboarMeat = 99; members[2] = 33; session.Pantry.HornboarMeat = 99
		local durable = service:GetHostSession(11)
		assert(durable.Pantry.HornboarMeat == 3 and durable.PartyUserIds[1] == 11)
		durable.PartyUserIds[2] = 33
		assert(service:GetForMember(session.SessionId, 22).PartyUserIds[2] == 22)
	end)
	check("insufficient stock rejects whole selection", function()
		local state = harness()
		local original = clone(state.Profiles[11])
		rejects(function() state.NewService():Prepare(11, { 11 }, { HornboarMeat = 4, WildHerb = 7 }) end, "insufficient")
		assert(equal(original, state.Profiles[11]) and next(state.Mirrors) == nil)
	end)
	check("strict pantry ids and finite positive integer quantities", function()
		for _, quantity in { 0, -1, 1.5, math.huge, -math.huge, 0 / 0 } do
			local state = harness()
			rejects(function() state.NewService():Prepare(11, { 11 }, { HornboarMeat = quantity }) end, "positive finite integer")
			assert(state.Profiles[11].RestaurantSession == nil)
		end
		local state = harness()
		rejects(function() state.NewService():Prepare(11, { 11 }, { HornCore = 1 }) end, "unknown ingredient")
		rejects(function() state.NewService():Prepare(11, { 11 }, { [5] = 1 }) end, "unknown ingredient")
	end)
	check("party validation and explicitly gated Studio negative ids", function()
		local state = harness()
		local service = state.NewService()
		for _, party in { {}, { 22 }, { 11, 11 }, { 11, 0 }, { 11, 1.5 }, { 11, 22, 33, 44, 55 } } do
			rejects(function() service:Prepare(11, party, {}) end, "SessionService")
		end
		rejects(function() service:Prepare(11, { [1] = 11, [3] = 22 }, {}) end, "dense array")
		rejects(function() service:Prepare(11, { [1] = 11, Extra = 22 }, {}) end, "dense array")
		rejects(function() service:Prepare(-1, { -1 }, {}) end, "invalid user id")
		local fake = state.NewService(true):Prepare(-1, { -2, -1 }, {})
		assert(fake.PartyUserIds[1] == -1 and fake.PartyUserIds[2] == -2)
	end)
	check("unfinished sessions block another debit and empty pantry works", function()
		local state = harness()
		local service = state.NewService()
		local session = service:Prepare(11, { 11 }, {})
		rejects(function() service:Prepare(11, { 11 }, { HornboarMeat = 1 }) end, "unfinished session")
		assert(state.Profiles[11].Inventory.Ingredients.HornboarMeat == 10)
		local receipt = service:Rollback(11, session.SessionId)
		assert(next(receipt.ReturnedPantry) == nil)
		assert(service:Prepare(11, { 11 }, {}).SessionId ~= session.SessionId)
	end)
	check("legal transitions, replay and destination binding", function()
		local state = harness()
		local service = state.NewService()
		local session = service:Prepare(11, { 11, 22 }, {})
		rejects(function() service:Activate(11, session.SessionId, "reserved-A") end, "transition")
		rejects(function() service:MarkTeleporting(11, session.SessionId, "") end, "invalid destination")
		assert(service:MarkTeleporting(11, session.SessionId, "reserved-A").State == "Teleporting")
		assert(service:MarkTeleporting(11, session.SessionId, "reserved-A").State == "Teleporting")
		rejects(function() service:Activate(11, session.SessionId, "reserved-B") end, "does not match")
		rejects(function() service:Activate(11, session.SessionId) end, "does not match")
		assert(service:Activate(11, session.SessionId, "reserved-A").State == "Active")
		assert(service:Activate(11, session.SessionId, "reserved-A").State == "Active")
		rejects(function() service:MarkTeleporting(11, session.SessionId, "reserved-A") end, "transition")
		rejects(function() service:Rollback(11, session.SessionId) end, "rollback requires")
	end)
	check("foreign hosts and nonmember discovery cannot mutate escrow", function()
		local state = harness()
		local service = state.NewService()
		local session = service:Prepare(11, { 11, 22 }, { HornboarMeat = 2 })
		local before = clone(state.Profiles)
		rejects(function() service:MarkTeleporting(22, session.SessionId) end, "does not belong")
		rejects(function() service:Rollback(22, session.SessionId) end, "does not belong")
		rejects(function() service:GetForMember(session.SessionId, 33) end, "not a session member")
		assert(equal(before, state.Profiles) and service:GetHostSession(22) == nil)
	end)
	check("rollback returns escrow once across new service instances", function()
		local state = harness()
		local service = state.NewService()
		local session = service:Prepare(11, { 11 }, { HornboarMeat = 4 })
		service:MarkTeleporting(11, session.SessionId)
		local receipt = service:Rollback(11, session.SessionId)
		assert(receipt.Kind == "Rollback" and receipt.ReturnedPantry.HornboarMeat == 4)
		assert(receipt.Gold == 0 and receipt.Renown == 0 and receipt.SettlementVersion == 1)
		state.Time = 999
		assert(equal(receipt, state.NewService():Rollback(11, session.SessionId)))
		assert(equal(receipt, state.NewService():Settle(11, session.SessionId)))
		assert(state.Profiles[11].Inventory.Ingredients.HornboarMeat == 10)
	end)
	check("settlement once, zero rewards and retry-safe atomic transactions", function()
		local state = harness()
		state.Retry = true
		local service, session = active(state, { HornboarMeat = 5, WildHerb = 1 })
		assert(state.Profiles[11].Inventory.Ingredients.HornboarMeat == 5)
		local receipt = service:Settle(11, session.SessionId)
		assert(receipt.Kind == "Settlement" and receipt.SettledAt == 100)
		assert(state.Profiles[11].RestaurantSession.State == "Closed")
		assert(next(state.Profiles[11].RestaurantSession.Pantry) == nil)
		assert(state.Profiles[11].Inventory.Ingredients.HornboarMeat == 10)
		assert(state.Profiles[11].Inventory.Ingredients.WildHerb == 6)
		assert(state.Profiles[11].Currencies.Gold == 17 and state.Profiles[11].Progression.RestaurantRenown == 8)
		state.Time = 200
		assert(equal(receipt, state.NewService():Settle(11, session.SessionId)))
		receipt.ReturnedPantry.HornboarMeat = 999
		assert(state.NewService():Settle(11, session.SessionId).ReturnedPantry.HornboarMeat == 5)
	end)
	check("old receipt remains stable when a newer session is active", function()
		local state = harness()
		local service, session = active(state, { HornboarMeat = 2 })
		local first = service:Settle(11, session.SessionId)
		local second = service:Prepare(11, { 11 }, { HornboarMeat = 3 })
		assert(equal(first, state.NewService():Settle(11, session.SessionId)))
		assert(service:GetHostSession(11).SessionId == second.SessionId)
		assert(state.Profiles[11].Inventory.Ingredients.HornboarMeat == 7)
	end)
	check("discovery mirror failure or expiry cannot lose pantry", function()
		local state = harness()
		state.FailWrite = true
		local service = state.NewService()
		local session = service:Prepare(11, { 11, 22 }, { HornboarMeat = 3 })
		assert(#state.Logs == 1 and service:GetForMember(session.SessionId, 22) == nil)
		state.Mirrors = {}
		local restored = state.NewService()
		assert(restored:GetHostSession(11).Pantry.HornboarMeat == 3)
		assert(restored:Rollback(11, session.SessionId).ReturnedPantry.HornboarMeat == 3)
		assert(state.Profiles[11].Inventory.Ingredients.HornboarMeat == 10)
		state.FailRead = true
		assert(restored:GetForMember(session.SessionId, 22) == nil)
		assert(state.Logs[#state.Logs][1] == "SessionMirrorReadFailed")
	end)
	check("stale or tampered discovery mirror cannot authorize economics", function()
		local state = harness()
		local service, session = active(state, { HornboarMeat = 2 })
		state.Mirrors[session.SessionId].Pantry.HornboarMeat = 999
		state.Mirrors[session.SessionId].State = "Preparing"
		assert(service:GetForMember(session.SessionId, 22).Pantry.HornboarMeat == 999)
		rejects(function() service:Rollback(11, session.SessionId) end, "rollback requires")
		assert(service:Settle(11, session.SessionId).ReturnedPantry.HornboarMeat == 2)
		assert(state.Profiles[11].Inventory.Ingredients.HornboarMeat == 10)
	end)
	check("durable commit failures and invalid escrow never partially publish", function()
		local state = harness()
		state.FailCommit = true
		local before = clone(state.Profiles[11])
		rejects(function() state.NewService():Prepare(11, { 11 }, { HornboarMeat = 1 }) end, "durable write failed")
		assert(equal(before, state.Profiles[11]) and next(state.Mirrors) == nil)
		state.FailCommit = false
		local service, session = active(state, { HornboarMeat = 4 })
		state.FailCommit = true
		before = clone(state.Profiles[11])
		rejects(function() service:Settle(11, session.SessionId) end, "durable write failed")
		assert(equal(before, state.Profiles[11]))
		state.FailCommit = false
		state.Profiles[11].RestaurantSession.Pantry.HornboarMeat = -1
		before = clone(state.Profiles[11])
		rejects(function() service:Settle(11, session.SessionId) end, "invalid persisted escrow")
		assert(equal(before, state.Profiles[11]))
	end)
	check("wrong settlement state, reused ids and malformed persisted data reject", function()
		local state = harness()
		local service = state.NewService()
		local session = service:Prepare(11, { 11 }, {})
		rejects(function() service:Settle(11, session.SessionId) end, "settlement requires Active")
		service:Rollback(11, session.SessionId)
		state.NextId = 0
		rejects(function() state.NewService():Prepare(11, { 11 }, {}) end, "already used")
		state.Profiles[11].RestaurantSession = false
		rejects(function() service:GetHostSession(11) end, "invalid persisted session")
		state.Profiles[11].RestaurantSession = nil
		state.Profiles[11].Inventory.Ingredients.HornboarMeat = false
		rejects(function() service:Prepare(11, { 11 }, { HornboarMeat = 1 }) end, "invalid persisted ingredient count")
	end)
	return passed
end
