--!strict
-- Deterministic transport for Studio and pure tests. It never touches Roblox.
local FakeTeleport = {}
FakeTeleport.__index = FakeTeleport

local function clone(value: any, seen: { [any]: any }?): any
	if type(value) ~= "table" then return value end
	local visited = seen or {}
	if visited[value] then return visited[value] end
	local copied = {}
	visited[value] = copied
	for key, child in value do copied[key] = clone(child, visited) end
	return copied
end

local function throwPendingFailure(self: any, call: any)
	if self._failure ~= nil then
		local message = self._failure
		self._failure = nil
		call.Error = message
		error(message, 0)
	end
end

function FakeTeleport.new()
	return setmetatable({
		IsFake = true,
		_calls = {} :: { any },
		_reservations = 0,
		_failure = nil :: string?,
	}, FakeTeleport)
end

function FakeTeleport.Reserve(self: any, placeId: number): (string, string)
	local call: any = { Operation = "Reserve", PlaceId = placeId }
	table.insert(self._calls, call)
	throwPendingFailure(self, call)
	self._reservations += 1
	local suffix = tostring(self._reservations)
	local accessCode = "FAKE_ACCESS_" .. suffix
	local privateServerId = "FAKE_PRIVATE_" .. suffix
	call.AccessCode = accessCode
	call.PrivateServerId = privateServerId
	return accessCode, privateServerId
end

function FakeTeleport.Send(self: any, placeId: number, players: { any }, payload: any, accessCode: string?)
	local call: any = {
		Operation = "Send",
		PlaceId = placeId,
		Players = clone(players),
		Payload = clone(payload),
		AccessCode = accessCode,
	}
	table.insert(self._calls, call)
	throwPendingFailure(self, call)
end

function FakeTeleport.FailNext(self: any, message: string)
	assert(type(message) == "string" and #message > 0, "failure message must be a nonempty string")
	self._failure = message
end

function FakeTeleport.GetCalls(self: any): { any }
	return clone(self._calls)
end

return FakeTeleport
