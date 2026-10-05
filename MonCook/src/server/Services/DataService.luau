--!strict
-- Store is injected; no gameplay or Roblox globals. All writes are atomic.
local DataService = {}
DataService.__index = DataService

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = clone(child) end
	return result
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function userKey(userId: number): string
	-- Studio's simulated players use negative IDs; real account IDs are positive.
	assert(finite(userId) and userId ~= 0 and userId % 1 == 0, "invalid userId")
	return "Player_" .. tostring(userId)
end

function DataService.new(options: any): any
	assert(type(options.OwnerId) == "string" and options.OwnerId ~= "", "OwnerId required")
	assert(finite(options.LockSeconds) and options.LockSeconds > 0, "positive LockSeconds required")
	assert(options.Store and type(options.Store.UpdateAsync) == "function", "Store.UpdateAsync required")
	assert(type(options.Now) == "function" and type(options.NewData) == "function" and type(options.Migrate) == "function", "data/clock dependencies required")
	return setmetatable({
		Store = options.Store, OwnerId = options.OwnerId, Now = options.Now,
		LockSeconds = options.LockSeconds, NewData = options.NewData, Migrate = options.Migrate,
		Log = options.Log, _profiles = {}, _busy = {},
	}, DataService)
end

function DataService._time(self: any): number
	local now = self.Now()
	assert(finite(now), "invalid clock")
	return now
end

function DataService._decode(self: any, raw: any): (any, any, number, any)
	if raw == nil then return self.Migrate(self.NewData()), nil, 0, {} end
	assert(type(raw) == "table", "corrupt stored profile")
	if raw.Data == nil and raw.Lock == nil and raw.Revision == nil then
		return self.Migrate(raw), nil, 0, {}
	end
	assert(type(raw.Data) == "table", "corrupt stored envelope Data")
	assert(finite(raw.Revision) and raw.Revision >= 0 and raw.Revision % 1 == 0, "corrupt stored revision")
	local lock = raw.Lock
	if lock ~= nil then
		assert(type(lock) == "table" and type(lock.OwnerId) == "string" and lock.OwnerId ~= "" and finite(lock.ExpiresAt), "corrupt stored lock")
	end
	return self.Migrate(raw.Data), lock, raw.Revision, clone(raw)
end

function DataService._run(self: any, userId: number, operation: string, callback: () -> any): any
	local key = userKey(userId)
	assert(not self._busy[key], "DataService operation already in progress")
	self._busy[key] = true
	local ok, result = pcall(callback)
	self._busy[key] = nil
	if not ok then
		local message = "DataService " .. operation .. " user " .. tostring(userId) .. ": " .. tostring(result)
		if self.Log then pcall(self.Log, message) end
		error(message, 2)
	end
	return result
end

function DataService._profile(self: any, userId: number): any
	local profile = self._profiles[userKey(userId)]
	assert(profile, "profile not loaded")
	assert(profile.Lock.ExpiresAt > self:_time(), "profile lease expired")
	return profile
end

function DataService.Load(self: any, userId: number): any
	return self:_run(userId, "Load", function()
		local key = userKey(userId)
		if self._profiles[key] then return clone(self:_profile(userId).Data) end
		local result = self.Store:UpdateAsync(key, function(raw: any)
			local data, lock, revision, envelope = self:_decode(raw)
			local now = self:_time()
			assert(not lock or lock.OwnerId == self.OwnerId or lock.ExpiresAt <= now, "profile owned by another server")
			envelope.Data, envelope.Revision = data, revision + 1
			envelope.Lock = { OwnerId = self.OwnerId, ExpiresAt = now + self.LockSeconds }
			return envelope
		end)
		local data, lock, revision = self:_decode(result)
		assert(lock and lock.OwnerId == self.OwnerId and lock.ExpiresAt > self:_time(), "load did not acquire active lease")
		self._profiles[key] = { Data = clone(data), Lock = clone(lock), Revision = revision }
		return clone(data)
	end)
end

function DataService.Get(self: any, userId: number): any
	return self:_run(userId, "Get", function() return clone(self:_profile(userId).Data) end)
end

function DataService.HasProfile(self: any, userId: number): boolean
	return self._profiles[userKey(userId)] ~= nil
end

function DataService.LoadedUserIds(self: any): { number }
	local userIds = {}
	for key in self._profiles do table.insert(userIds, tonumber(string.sub(key, 8)) :: number) end
	table.sort(userIds)
	return userIds
end

function DataService._commit(self: any, userId: number, candidate: any, release: boolean): any
	local key, profile = userKey(userId), self:_profile(userId)
	local result = self.Store:UpdateAsync(key, function(raw: any)
		local data, lock, revision, envelope = self:_decode(raw)
		local now = self:_time()
		assert(lock and lock.OwnerId == self.OwnerId and lock.ExpiresAt > now, "profile lease lost")
		assert(revision == profile.Revision, "profile revision changed")
		envelope.Data, envelope.Revision = candidate or data, revision + 1
		if release then envelope.Lock = nil
		else envelope.Lock = { OwnerId = self.OwnerId, ExpiresAt = now + self.LockSeconds } end
		return envelope
	end)
	local data, lock, revision = self:_decode(result)
	assert(revision == profile.Revision + 1, "write did not commit expected revision")
	if release then
		assert(lock == nil, "release did not unlock profile")
		self._profiles[key] = nil
	else
		assert(lock and lock.OwnerId == self.OwnerId and lock.ExpiresAt > self:_time(), "write did not preserve active lease")
		self._profiles[key] = { Data = clone(data), Lock = clone(lock), Revision = revision }
	end
	return clone(data)
end

function DataService.Update(self: any, userId: number, mutator: (any) -> any): any
	return self:_run(userId, "Update", function()
		assert(type(mutator) == "function", "mutator required")
		local draft = clone(self:_profile(userId).Data)
		-- Run once outside UpdateAsync; callback retries cannot repeat economic effects.
		-- Mutators must be pure and non-yielding, and may mutate or return a replacement.
		local thread = coroutine.create(mutator)
		local ok, replacement = coroutine.resume(thread, draft)
		if coroutine.status(thread) ~= "dead" then
			coroutine.close(thread)
			error("mutator must not yield")
		end
		assert(ok, tostring(replacement))
		local candidate = self.Migrate(if replacement == nil then draft else replacement)
		return self:_commit(userId, clone(candidate), false)
	end)
end

function DataService.Save(self: any, userId: number): any
	return self:_run(userId, "Save", function() return self:_commit(userId, nil, false) end)
end

function DataService.Release(self: any, userId: number): any
	return self:_run(userId, "Release", function() return self:_commit(userId, nil, true) end)
end

function DataService.Abandon(self: any, userId: number)
	-- Local detachment only: never unlock, overwrite, or delete persisted data.
	-- The caller must stop renewing this user's lease; it expires naturally.
	self:_run(userId, "Abandon", function() self._profiles[userKey(userId)] = nil end)
end

function DataService.HeartbeatAll(self: any, shouldRenew: ((number) -> boolean)?): { number }
	local failures = {}
	for _, userId in self:LoadedUserIds() do
		local key = userKey(userId)
		-- An ongoing write renews or releases its own lease. Busy is not a failure.
		-- Use a snapshot and recheck presence: another operation may release while
		-- a previous heartbeat's store request yields.
		local active = shouldRenew == nil or shouldRenew(userId)
		if active and self._profiles[key] and not self._busy[key] then
			if not pcall(function() self:Save(userId) end) then table.insert(failures, userId) end
		end
	end
	return failures
end

return DataService
