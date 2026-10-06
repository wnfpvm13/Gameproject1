--!strict
-- In-memory, server-owned activity skeleton. No persistence, loot or PlayerData
-- writes. Destination import/recovery across live servers is a later integration.
export type Options = {
	NewId: () -> string, Now: () -> number, MaxMembers: number,
	-- Omit only when the trusted caller already validates the catalog pair.
	ValidTarget: ((string, string) -> boolean)?,
}

local ExpeditionService = {}
ExpeditionService.__index = ExpeditionService
local MAX_EXACT_INTEGER = 9007199254740991
local destinations = { Repeat = true, HostRestaurant = true, Hearthcross = true }

local function userId(value: any)
	-- Negative Studio test IDs are supported; zero/non-exact identities are not.
	assert(type(value) == "number" and value ~= 0 and math.abs(value) <= MAX_EXACT_INTEGER
		and value % 1 == 0, "ExpeditionService: invalid user ID")
end

local function identity(value: any, name: string)
	assert(type(value) == "string" and #value > 0 and #value <= 128,
		"ExpeditionService: invalid " .. name)
end

local function snapshot(value: any): any
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in value do copy[key] = snapshot(child) end
	return table.freeze(copy)
end

local function now(self: any): number
	local value = self._now()
	assert(type(value) == "number" and value == value and value >= 0 and value < math.huge,
		"ExpeditionService: invalid server time")
	return value
end

local function owned(self: any, hostId: number, id: string): any
	userId(hostId); identity(id, "session ID")
	local session = self._sessions[id]
	assert(session ~= nil, "ExpeditionService: session is stale or missing")
	assert(session.HostUserId == hostId, "ExpeditionService: host required")
	return session
end

local function releaseMembers(self: any, session: any)
	for _, memberId in session.MemberUserIds do
		if self._membership[memberId] == session.SessionId then self._membership[memberId] = nil end
	end
end

function ExpeditionService.new(options: Options): any
	assert(type(options) == "table" and type(options.NewId) == "function" and type(options.Now) == "function",
		"ExpeditionService: server ID/time providers required")
	assert(type(options.MaxMembers) == "number" and options.MaxMembers % 1 == 0
		and options.MaxMembers >= 1 and options.MaxMembers <= 4, "ExpeditionService: MaxMembers must be 1 through 4")
	assert(options.ValidTarget == nil or type(options.ValidTarget) == "function", "ExpeditionService: invalid target validator")
	return setmetatable({
		_newId = options.NewId, _now = options.Now, _maxMembers = options.MaxMembers,
		_validTarget = options.ValidTarget, _sessions = {}, _membership = {}, _returns = {}, _receipts = {}, _latestReturn = {},
	}, ExpeditionService)
end

function ExpeditionService.Prepare(self: any, hostId: number, partyId: string, members: { number }, regionId: string, targetId: string): any
	userId(hostId); identity(partyId, "party ID"); identity(regionId, "region ID"); identity(targetId, "target ID")
	assert(type(members) == "table", "ExpeditionService: members must be a dense array")
	local copied, seen, count = {}, {}, 0
	for key, memberId in members do
		assert(type(key) == "number" and key % 1 == 0 and key >= 1, "ExpeditionService: members must be a dense array")
		userId(memberId)
		assert(not seen[memberId], "ExpeditionService: duplicate member")
		seen[memberId] = true; count += 1
	end
	assert(count >= 1 and count <= self._maxMembers and seen[hostId], "ExpeditionService: members must include host and fit capacity")
	for index = 1, count do
		assert(members[index] ~= nil, "ExpeditionService: members must be a dense array")
		copied[index] = members[index]
	end
	local validTarget: ((string, string) -> boolean)? = self._validTarget
	assert(validTarget == nil or validTarget(regionId, targetId) == true, "ExpeditionService: invalid region/target pair")
	local id, createdAt = self._newId(), now(self)
	identity(id, "generated session ID")
	assert(self._sessions[id] == nil, "ExpeditionService: session ID already issued")
	-- Validate all membership before publishing anything, including callbacks failing.
	for _, memberId in copied do
		assert(self._membership[memberId] == nil, "ExpeditionService: member already has an unfinished expedition")
	end
	local session = {
		SessionId = id, PartyId = partyId, HostUserId = hostId, MemberUserIds = copied,
		RegionId = regionId, TargetId = targetId, State = "Preparing", CreatedAt = createdAt,
	}
	self._sessions[id] = session; self._returns[id] = {}
	for _, memberId in copied do self._membership[memberId] = id end
	return snapshot(session)
end

function ExpeditionService.Get(self: any, id: string): any
	identity(id, "session ID")
	return snapshot(self._sessions[id])
end

function ExpeditionService.GetForMember(self: any, memberId: number): any
	userId(memberId)
	local id = self._membership[memberId]
	return if id == nil then nil else snapshot(self._sessions[id])
end

function ExpeditionService.GetReceipt(self: any, hostId: number, id: string): any
	owned(self, hostId, id)
	return snapshot(self._receipts[id])
end

local function transition(self: any, hostId: number, id: string, privateId: string, from: string, to: string): any
	local session = owned(self, hostId, id)
	identity(privateId, "destination private server ID")
	assert(session.State == from or session.State == to, "ExpeditionService: stale or invalid transition")
	assert(session.DestinationPrivateServerId == nil or session.DestinationPrivateServerId == privateId,
		"ExpeditionService: destination private server mismatch")
	assert(session.State ~= to or session.DestinationPrivateServerId == privateId,
		"ExpeditionService: destination private server mismatch")
	session.DestinationPrivateServerId = privateId; session.State = to
	return snapshot(session)
end

function ExpeditionService.MarkTeleporting(self: any, hostId: number, id: string, privateId: string): any
	return transition(self, hostId, id, privateId, "Preparing", "Teleporting")
end

function ExpeditionService.Activate(self: any, hostId: number, id: string, privateId: string): any
	return transition(self, hostId, id, privateId, "Teleporting", "Active")
end

-- Trusted encounter completion, never a client-authoritative remote action.
function ExpeditionService.Complete(self: any, hostId: number, id: string): any
	local session = owned(self, hostId, id)
	assert(session.State == "Active" or session.State == "Result", "ExpeditionService: completion requires Active")
	if session.State == "Active" then
		local completedAt = now(self)
		session.ResultAt = completedAt; session.State = "Result"
	end
	return snapshot(session)
end

function ExpeditionService.BeginReturn(self: any, hostId: number, id: string, destination: string, actionId: string): any
	local session = owned(self, hostId, id)
	identity(actionId, "return action ID")
	assert(destinations[destination] == true, "ExpeditionService: invalid return destination")
	local previous = self._returns[id][actionId]
	if previous ~= nil then
		assert(previous.Destination == destination, "ExpeditionService: return action parameters conflict")
		assert((previous.Status == "Returning" or previous.Status == "Closed") and session.ReturnActionId == actionId,
			"ExpeditionService: return action is stale")
		assert(session.State == "Returning" or session.State == "Closed", "ExpeditionService: return action is stale")
		return snapshot(session)
	end
	assert(session.State == "Result", "ExpeditionService: return requires Result")
	self._returns[id][actionId] = { Destination = destination, Status = "Returning" }
	self._latestReturn[id] = actionId
	session.ReturnActionId = actionId; session.ReturnDestination = destination; session.State = "Returning"
	return snapshot(session)
end

function ExpeditionService.RestoreResult(self: any, hostId: number, id: string, actionId: string): any
	local session = owned(self, hostId, id)
	identity(actionId, "return action ID")
	local action = self._returns[id][actionId]
	assert(action ~= nil, "ExpeditionService: return action is stale")
	if session.State == "Result" and action.Status == "Failed" and self._latestReturn[id] == actionId then return snapshot(session) end
	assert(session.State == "Returning" and session.ReturnActionId == actionId, "ExpeditionService: return action is stale")
	action.Status = "Failed"
	session.ReturnActionId = nil; session.ReturnDestination = nil; session.State = "Result"
	return snapshot(session)
end

local function finish(self: any, hostId: number, id: string, actionId: string, kind: string): any
	local session = owned(self, hostId, id)
	identity(actionId, "close action ID")
	local receipt = self._receipts[id]
	if receipt ~= nil then
		assert(receipt.ActionId == actionId and receipt.Kind == kind, "ExpeditionService: close action is stale or conflicting")
		return snapshot(receipt)
	end
	if kind == "Cancel" then
		assert(session.State == "Preparing" or session.State == "Teleporting", "ExpeditionService: cancellation requires pre-active session")
	elseif kind == "Abandon" then
		assert(session.State == "Active" or session.State == "Result" or session.State == "Returning",
			"ExpeditionService: abandonment requires started session")
	else
		assert(session.State == "Returning" and session.ReturnActionId == actionId, "ExpeditionService: close requires current return action")
	end
	local closedAt = now(self)
	receipt = { SessionId = id, HostUserId = hostId, ActionId = actionId, Kind = kind,
		Destination = session.ReturnDestination, ClosedAt = closedAt }
	self._receipts[id] = receipt
	if kind == "Return" then
		self._returns[id][actionId].Status = "Closed"
	elseif kind == "Abandon" and session.ReturnActionId ~= nil then
		self._returns[id][session.ReturnActionId].Status = "Abandoned"
	end
	session.State = "Closed"; session.ClosedAt = closedAt
	releaseMembers(self, session)
	return snapshot(receipt)
end

function ExpeditionService.Close(self: any, hostId: number, id: string, actionId: string): any
	return finish(self, hostId, id, actionId, "Return")
end

function ExpeditionService.Cancel(self: any, hostId: number, id: string, actionId: string): any
	return finish(self, hostId, id, actionId, "Cancel")
end

-- Trusted host-disconnect cleanup; cannot grant loot/rewards or settle Restaurant.
function ExpeditionService.Abandon(self: any, hostId: number, id: string, actionId: string): any
	return finish(self, hostId, id, actionId, "Abandon")
end

return table.freeze(ExpeditionService)
