--!strict
-- DataStore-backed host escrow is authoritative. The cross-server store is only
-- a discovery mirror: expiry or stale records must never determine inventory.
local SessionService = {}
SessionService.__index = SessionService

export type Options = {
	Data: any,
	Store: any,
	NewId: () -> string,
	Now: () -> number,
	ValidIngredient: (string) -> boolean,
	MaxPartySize: number,
	IsStudio: boolean?,
	Log: ((string, any) -> ())?,
}

local MAX_EXACT_INTEGER = 9007199254740991
local VALID_STATES = {
	Preparing = true, Teleporting = true, Active = true, Settling = true, Closed = true,
}

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in value do copy[key] = clone(child) end
	return copy
end

local function fail(message: string): never
	error("SessionService: " .. message, 3)
end

local function integer(value: any, allowZero: boolean): boolean
	return type(value) == "number" and value == value and value < math.huge
		and value <= MAX_EXACT_INTEGER and value % 1 == 0
		and (if allowZero then value >= 0 else value > 0)
end

local function validUserId(value: any, isStudio: boolean?): boolean
	return integer(value, false) or (isStudio == true and type(value) == "number"
		and value < 0 and value >= -MAX_EXACT_INTEGER and value % 1 == 0)
end

local function userId(value: any, isStudio: boolean?)
	if not validUserId(value, isStudio) then fail("invalid user id") end
end

local function sessionId(value: any)
	if type(value) ~= "string" or #value == 0 or #value > 128 then
		fail("invalid session id")
	end
end

local function destinationId(value: any)
	if value ~= nil and (type(value) ~= "string" or #value == 0 or #value > 256) then
		fail("invalid destination private server id")
	end
end

local function timestamp(now: () -> number): number
	local value = now()
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		fail("invalid server time")
	end
	return value
end

local function ownedSession(data: any, hostId: number, id: string): any
	local session = data.RestaurantSession
	if type(session) ~= "table" or session.SessionId ~= id or session.HostUserId ~= hostId then
		fail("session does not belong to host")
	end
	if not VALID_STATES[session.State] then fail("invalid persisted session state") end
	return session
end

local function ingredients(data: any): any
	if type(data.Inventory) ~= "table" or type(data.Inventory.Ingredients) ~= "table" then
		fail("invalid ingredient inventory")
	end
	return data.Inventory.Ingredients
end

local function receiptFor(data: any, hostId: number, id: string): any
	local receipts = data.SettlementReceipts
	if receipts == nil then return nil end
	if type(receipts) ~= "table" then fail("invalid settlement receipts") end
	local receipt = receipts[id]
	if receipt ~= nil and (type(receipt) ~= "table" or receipt.SessionId ~= id
		or receipt.HostUserId ~= hostId) then
		fail("receipt does not belong to host")
	end
	return receipt
end

function SessionService.new(options: Options): any
	assert(type(options) == "table", "SessionService: options required")
	assert(type(options.Data) == "table" and type(options.Data.Get) == "function"
		and type(options.Data.Update) == "function", "SessionService: Data adapter required")
	assert(type(options.Store) == "table" and type(options.Store.GetAsync) == "function"
		and type(options.Store.SetAsync) == "function", "SessionService: Store adapter required")
	assert(type(options.NewId) == "function" and type(options.Now) == "function",
		"SessionService: server id/time providers required")
	assert(type(options.ValidIngredient) == "function", "SessionService: ingredient validator required")
	assert(integer(options.MaxPartySize, false) and options.MaxPartySize <= 4,
		"SessionService: maximum party size must be 1 through 4")
	assert(options.IsStudio == nil or type(options.IsStudio) == "boolean", "SessionService: invalid Studio flag")
	return setmetatable({
		_data = options.Data, _store = options.Store, _newId = options.NewId,
		_now = options.Now, _validIngredient = options.ValidIngredient,
		_maxPartySize = options.MaxPartySize, _log = options.Log,
		_isStudio = options.IsStudio == true,
	}, SessionService)
end

function SessionService._logFailure(self: any, operation: string, detail: any)
	-- Logging and discovery outages cannot roll back an already durable commit.
	if self._log ~= nil then pcall(self._log, operation, detail) end
end

function SessionService._mirror(self: any, session: any)
	local ok, message = pcall(function()
		self._store:SetAsync(session.SessionId, clone(session))
	end)
	if not ok then self:_logFailure("SessionMirrorWriteFailed", tostring(message)) end
end

function SessionService.Prepare(self: any, hostId: number, memberIds: { number }, pantrySelection: { [string]: number }): any
	userId(hostId, self._isStudio)
	if type(memberIds) ~= "table" then fail("party must be an array") end
	local members, seen = {}, {}
	local count = 0
	for key, member in memberIds do
		if not integer(key, false) then fail("party must be a dense array") end
		userId(member, self._isStudio)
		if seen[member] then fail("duplicate party member") end
		seen[member] = true
		count += 1
	end
	if count < 1 or count > self._maxPartySize or not seen[hostId] then
		fail("party must contain host and fit maximum size")
	end
	for index = 1, count do
		if memberIds[index] == nil then fail("party must be a dense array") end
	end
	table.insert(members, hostId)
	for _, member in memberIds do
		if member ~= hostId then table.insert(members, member) end
	end
	if type(pantrySelection) ~= "table" then fail("pantry selection must be a table") end
	local pantry = {}
	for id, quantity in pantrySelection do
		if type(id) ~= "string" or #id == 0 or not self._validIngredient(id) then
			fail("unknown ingredient id")
		end
		if not integer(quantity, false) then fail("ingredient count must be a positive finite integer") end
		pantry[id] = quantity
	end
	local id = self._newId()
	sessionId(id)
	local createdAt = timestamp(self._now)
	local committed = self._data:Update(hostId, function(data: any): any
		local previous = data.RestaurantSession
		if previous ~= nil and (type(previous) ~= "table" or previous.State ~= "Closed") then
			fail("host already has an unfinished session")
		end
		if receiptFor(data, hostId, id) ~= nil or (previous ~= nil and previous.SessionId == id) then
			fail("session id was already used")
		end
		local inventory = ingredients(data)
		-- Validate the entire selection before any subtraction, including corrupt stock.
		for ingredient, quantity in pantry do
			local available = inventory[ingredient]
			if available == nil then available = 0 end
			if not integer(available, true) then fail("invalid persisted ingredient count") end
			if available < quantity then fail("insufficient ingredient stock") end
		end
		for ingredient, quantity in pantry do
			inventory[ingredient] -= quantity
		end
		data.RestaurantSession = {
			SessionId = id, HostUserId = hostId, PartyUserIds = clone(members),
			State = "Preparing", CreatedAt = createdAt, Pantry = clone(pantry),
			SettlementVersion = 0,
		}
		return data
	end)
	local session = clone(committed.RestaurantSession)
	self:_mirror(session)
	return session
end

local function transition(self: any, hostId: number, id: string, destination: string?, from: string, to: string): any
	userId(hostId, self._isStudio)
	sessionId(id)
	destinationId(destination)
	local committed = self._data:Update(hostId, function(data: any): any
		local session = ownedSession(data, hostId, id)
		if session.State ~= from and session.State ~= to then fail("invalid session transition") end
		if session.DestinationPrivateServerId ~= nil and session.DestinationPrivateServerId ~= destination then
			fail("destination private server does not match")
		end
		-- A repeated transition cannot bind an unbound already-active session elsewhere.
		if session.State == to and session.DestinationPrivateServerId ~= destination then
			fail("destination private server does not match")
		end
		session.DestinationPrivateServerId = destination
		session.State = to
		return data
	end)
	local session = clone(committed.RestaurantSession)
	self:_mirror(session)
	return session
end

function SessionService.MarkTeleporting(self: any, hostId: number, id: string, destination: string?): any
	return transition(self, hostId, id, destination, "Preparing", "Teleporting")
end

function SessionService.Activate(self: any, hostId: number, id: string, destination: string?): any
	return transition(self, hostId, id, destination, "Teleporting", "Active")
end

function SessionService.GetHostSession(self: any, hostId: number): any
	userId(hostId, self._isStudio)
	local data = self._data:Get(hostId)
	if data.RestaurantSession == nil then return nil end
	if type(data.RestaurantSession) ~= "table" then fail("invalid persisted session") end
	return clone(ownedSession(data, hostId, data.RestaurantSession.SessionId))
end

function SessionService.GetForMember(self: any, id: string, memberId: number): any
	sessionId(id)
	userId(memberId, self._isStudio)
	local ok, record = pcall(function() return self._store:GetAsync(id) end)
	if not ok then
		self:_logFailure("SessionMirrorReadFailed", tostring(record))
		return nil
	end
	if record == nil then return nil end
	if type(record) ~= "table" or record.SessionId ~= id or type(record.PartyUserIds) ~= "table"
		or not validUserId(record.HostUserId, self._isStudio) or not VALID_STATES[record.State] then
		fail("invalid session discovery record")
	end
	for _, member in record.PartyUserIds do
		if member == memberId then return clone(record) end
	end
	return fail("user is not a session member")
end

local function finish(self: any, hostId: number, id: string, kind: string): any
	userId(hostId, self._isStudio)
	sessionId(id)
	local settledAt = timestamp(self._now)
	local committed = self._data:Update(hostId, function(data: any): any
		-- This receipt, pantry return and Closed state commit in one host transaction.
		-- No read of MemoryStore and no reward arguments participate in economics.
		if receiptFor(data, hostId, id) ~= nil then return data end
		local session = ownedSession(data, hostId, id)
		if kind == "Rollback" then
			if session.State ~= "Preparing" and session.State ~= "Teleporting" then
				fail("rollback requires Preparing or Teleporting")
			end
		elseif session.State ~= "Active" then
			fail("settlement requires Active")
		end
		if session.SettlementVersion ~= 0 or type(session.Pantry) ~= "table" then
			fail("invalid persisted escrow")
		end
		local inventory = ingredients(data)
		local returned = clone(session.Pantry)
		for ingredient, quantity in returned do
			if type(ingredient) ~= "string" or not self._validIngredient(ingredient)
				or not integer(quantity, false) then fail("invalid persisted escrow ingredient") end
			local available = inventory[ingredient]
			if available == nil then available = 0 end
			if not integer(available, true) or available > MAX_EXACT_INTEGER - quantity then
				fail("invalid ingredient return balance")
			end
		end
		-- Settling is part of the single transaction; never expose a separate debit
		-- without its receipt. Future authoritative cooking/sales can replace these
		-- zero rewards and adjust Pantry through their own atomic server accounting.
		session.State = "Settling"
		for ingredient, quantity in returned do inventory[ingredient] = (inventory[ingredient] or 0) + quantity end
		data.SettlementReceipts = data.SettlementReceipts or {}
		data.SettlementReceipts[id] = {
			SessionId = id, HostUserId = hostId, Kind = kind,
			Gold = 0, Renown = 0, ReturnedPantry = returned,
			SettlementVersion = 1, SettledAt = settledAt,
		}
		session.State = "Closed"
		session.Pantry = {}
		session.SettlementVersion = 1
		session.ClosedAt = settledAt
		return data
	end)
	local session = committed.RestaurantSession
	if type(session) == "table" and session.SessionId == id then self:_mirror(session) end
	return clone(receiptFor(committed, hostId, id))
end

function SessionService.Rollback(self: any, hostId: number, id: string): any
	return finish(self, hostId, id, "Rollback")
end

function SessionService.Settle(self: any, hostId: number, id: string): any
	return finish(self, hostId, id, "Settlement")
end

return table.freeze(SessionService)
