--!strict
-- Platform transport is injected. Session/economic authority stays server-side;
-- only session identity and destination cross the TeleportData boundary.
export type Reservation = { AccessCode: string, PrivateServerId: string, RegionId: string?, PlaceId: number? }
export type Options = {
	IsStudio: boolean,
	UseFakeTeleport: boolean,
	WorldPlaceId: number,
	RestaurantPlaceId: number,
	ExpeditionPlaceIds: { [string]: number }?,
	Transport: any,
	Log: ((string) -> ())?,
}

local TeleportServiceWrapper = {}
TeleportServiceWrapper.__index = TeleportServiceWrapper

local function placeIdValid(placeId: number, allowZero: boolean): boolean
	return type(placeId) == "number" and placeId == math.floor(placeId)
		and placeId < math.huge and (placeId > 0 or (allowZero and placeId == 0))
end

local function sessionIdValid(sessionId: string)
	assert(type(sessionId) == "string" and #sessionId > 0, "SessionId must be a nonempty string")
end

local function teleportData(sessionId: string, destination: string, attemptId: string?): { [string]: string }
	sessionIdValid(sessionId)
	assert(attemptId == nil or (type(attemptId) == "string" and #attemptId > 0 and #attemptId <= 128),
		"AttemptId must be a nonempty string of at most 128 characters")
	local payload = { SessionId = sessionId, Destination = destination }
	if attemptId ~= nil then payload.AttemptId = attemptId end
	return payload
end

local function copyPlayers(players: { any }): { any }
	assert(type(players) == "table" and #players > 0, "players must be a nonempty array")
	local result: { any } = {}
	local seen: { [any]: boolean } = {}
	for key, player in players do
		assert(type(key) == "number" and key == math.floor(key) and key >= 1 and key <= #players,
			"players must be a dense array")
		assert(player ~= nil and player ~= false and not seen[player], "invalid or duplicate player")
		seen[player] = true
		result[key] = player
	end
	for index = 1, #players do assert(result[index] ~= nil, "players must be a dense array") end
	return result
end

local function failure(self: any, operation: string, message: any): never
	if self._log then
		-- A diagnostic failure must not hide the transport failure needed to
		-- trigger the caller's pantry rollback.
		pcall(self._log, "TeleportServiceWrapper." .. operation .. ": " .. tostring(message))
	end
	error(message, 0)
end

function TeleportServiceWrapper.new(options: Options)
	assert(type(options) == "table", "teleport options required")
	assert(type(options.IsStudio) == "boolean" and type(options.UseFakeTeleport) == "boolean",
		"IsStudio and UseFakeTeleport must be boolean")
	assert(type(options.Transport) == "table" and type(options.Transport.Reserve) == "function"
		and type(options.Transport.Send) == "function", "teleport transport required")
	local fakeMode = options.IsStudio and options.UseFakeTeleport
	assert(not options.UseFakeTeleport or options.IsStudio, "fake teleport is restricted to Studio")
	assert(options.Transport.IsFake ~= true or fakeMode, "fake transport requires Studio fake mode")
	assert(not fakeMode or options.Transport.IsFake == true, "Studio fake mode requires a fake transport")
	assert(placeIdValid(options.WorldPlaceId, fakeMode), "invalid WorldPlaceId")
	assert(placeIdValid(options.RestaurantPlaceId, fakeMode), "invalid RestaurantPlaceId")
	assert(options.Log == nil or type(options.Log) == "function", "Log must be a function")
	assert(options.ExpeditionPlaceIds == nil or type(options.ExpeditionPlaceIds) == "table", "ExpeditionPlaceIds must be a map")
	local expeditionPlaceIds = {}
	for region, placeId in options.ExpeditionPlaceIds or {} do
		assert(type(region) == "string" and #region > 0 and #region <= 128, "invalid expedition region ID")
		expeditionPlaceIds[region] = placeId
	end
	return setmetatable({
		_worldPlaceId = options.WorldPlaceId,
		_restaurantPlaceId = options.RestaurantPlaceId,
		_expeditionPlaceIds = expeditionPlaceIds,
		_fakeMode = fakeMode,
		_transport = options.Transport,
		_log = options.Log,
	}, TeleportServiceWrapper)
end

local function expeditionPlaceId(self: any, regionId: string): number
	assert(type(regionId) == "string" and #regionId > 0 and #regionId <= 128, "invalid expedition region ID")
	local placeId = self._expeditionPlaceIds[regionId]
	if placeId == nil and self._fakeMode then placeId = 0 end
	assert(placeIdValid(placeId, self._fakeMode), "invalid or missing ExpeditionPlaceId for " .. regionId)
	return placeId
end

function TeleportServiceWrapper.ReserveExpedition(self: any, regionId: string): Reservation
	local ok, reservation = pcall(function(): Reservation
		local placeId = expeditionPlaceId(self, regionId)
		local code, privateId = self._transport:Reserve(placeId)
		assert(type(code) == "string" and #code > 0, "transport returned an invalid access code")
		assert(type(privateId) == "string" and #privateId > 0, "transport returned an invalid private server ID")
		return { AccessCode = code, PrivateServerId = privateId, RegionId = regionId, PlaceId = placeId }
	end)
	if not ok then failure(self, "ReserveExpedition", reservation) end
	return reservation
end

function TeleportServiceWrapper.ToExpedition(self: any, players: { any }, sessionId: string, regionId: string, reservation: Reservation, attemptId: string?)
	local ok, message = pcall(function()
		local placeId = expeditionPlaceId(self, regionId)
		local payload = teleportData(sessionId, "Expedition", attemptId)
		payload.RegionId = regionId -- Catalog identity only; no inventory/economy data.
		assert(type(reservation) == "table" and type(reservation.AccessCode) == "string" and #reservation.AccessCode > 0,
			"expedition reservation access code required")
		assert(type(reservation.PrivateServerId) == "string" and #reservation.PrivateServerId > 0, "expedition private server ID required")
		assert(reservation.RegionId == regionId and reservation.PlaceId == placeId, "expedition reservation destination mismatch")
		self._transport:Send(placeId, copyPlayers(players), payload, reservation.AccessCode)
	end)
	if not ok then failure(self, "ToExpedition", message) end
end

function TeleportServiceWrapper.ReserveRestaurant(self: any): Reservation
	local ok, accessCode, privateServerId = pcall(function()
		local code, serverId = self._transport:Reserve(self._restaurantPlaceId)
		assert(type(code) == "string" and #code > 0, "transport returned an invalid access code")
		assert(type(serverId) == "string" and #serverId > 0, "transport returned an invalid private server ID")
		return code, serverId
	end)
	if not ok then failure(self, "ReserveRestaurant", accessCode) end
	return { AccessCode = accessCode, PrivateServerId = privateServerId }
end

function TeleportServiceWrapper.ToRestaurant(self: any, players: { any }, sessionId: string, reservation: Reservation, attemptId: string?)
	local ok, message = pcall(function()
		local payload = teleportData(sessionId, "Restaurant", attemptId)
		assert(type(reservation) == "table" and type(reservation.AccessCode) == "string"
			and #reservation.AccessCode > 0, "restaurant reservation access code required")
		assert(type(reservation.PrivateServerId) == "string" and #reservation.PrivateServerId > 0,
			"restaurant private server ID required")
		self._transport:Send(self._restaurantPlaceId, copyPlayers(players), payload, reservation.AccessCode)
	end)
	if not ok then failure(self, "ToRestaurant", message) end
end

function TeleportServiceWrapper.ToWorld(self: any, players: { any }, sessionId: string, attemptId: string?)
	local ok, message = pcall(function()
		self._transport:Send(self._worldPlaceId, copyPlayers(players), teleportData(sessionId, "World", attemptId))
	end)
	if not ok then failure(self, "ToWorld", message) end
end

return TeleportServiceWrapper
