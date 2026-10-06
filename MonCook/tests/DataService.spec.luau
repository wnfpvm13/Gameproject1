--!strict
local DataService = require(script.Parent.Parent.src.server.Services.DataService)
local Store = require(script.Parent.Support.InMemoryStore)
local Defaults = require(script.Parent.Parent.src.shared.Utilities.PlayerDataDefaults)
local Migration = require(script.Parent.Parent.src.shared.Utilities.PlayerDataMigration)

local function rejects(callback: () -> (), fragment: string)
	local ok, message = pcall(callback)
	assert(not ok and string.find(tostring(message), fragment, 1, true), tostring(message))
end

return function(): number
	local passed = 0
	local function check(_name: string, test: () -> ()) test(); passed += 1 end
	local function fixture(): (any, any, any, any)
		local store, clock, logs = Store.new(), { Now = 100 }, {}
		local function service(owner: string): any
			return DataService.new({ Store = store, OwnerId = owner, Now = function() return clock.Now end,
				LockSeconds = 30, NewData = Defaults.new, Migrate = Migration.migrate,
				Log = function(message: string) table.insert(logs, message) end })
		end
		return service("A"), service("B"), store, clock
	end
	check("load/update/save/release/reload", function()
		local a, b, store = fixture()
		assert(a:Load(123).Currencies.Gold == 0 and a:HasProfile(123))
		assert(a:Update(123, function(data: any) data.Currencies.Gold += 10 end).Currencies.Gold == 10)
		assert(a:Save(123).Currencies.Gold == 10 and store:Read("Player_123").Revision == 3)
		a:Release(123)
		assert(not a:HasProfile(123) and store:Read("Player_123").Lock == nil)
		assert(b:Load(123).Currencies.Gold == 10)
	end)
	check("simultaneous ownership denied", function()
		local a, b = fixture(); a:Load(1)
		rejects(function() b:Load(1) end, "owned by another server")
		assert(not b:HasProfile(1))
	end)
	check("expired owner cannot mutate or release before takeover", function()
		local a, b, store, clock = fixture(); a:Load(1); clock.Now = 130
		rejects(function() a:Update(1, function(data: any) data.Currencies.Gold = 20 end) end, "lease expired")
		rejects(function() a:Release(1) end, "lease expired")
		b:Load(1); assert(store:Read("Player_1").Lock.OwnerId == "B")
		rejects(function() a:Save(1) end, "lease expired")
	end)
	check("clock advances while write waits", function()
		local a, _, store, clock = fixture(); a:Load(1)
		store.BeforeTransform = function() clock.Now = 130 end
		rejects(function() a:Save(1) end, "lease lost")
		assert(store:Read("Player_1").Revision == 1)
	end)
	check("store owner and revision protect stale cached writes", function()
		local a, _, store = fixture(); a:Load(1)
		store.Values.Player_1.Revision += 1
		rejects(function() a:Save(1) end, "revision changed")
		store.Values.Player_1.Lock.OwnerId = "B"
		rejects(function() a:Update(1, function(data: any) data.Currencies.Gold = 25 end) end, "lease lost")
		assert(store:Read("Player_1").Data.Currencies.Gold == 0 and a:Get(1).Currencies.Gold == 0)
	end)
	check("failed writes leave committed cache and store unchanged", function()
		local a, _, store = fixture(); a:Load(1); store.FailNext = true
		rejects(function() a:Update(1, function(data: any) data.Currencies.Gold = 999 end) end, "store failure")
		assert(a:Get(1).Currencies.Gold == 0 and store:Read("Player_1").Data.Currencies.Gold == 0)
		store.FailNext = true; rejects(function() a:Release(1) end, "store failure")
		assert(a:HasProfile(1)); store.FailNext = true
		assert(a:HeartbeatAll()[1] == 1 and a:Get(1).Currencies.Gold == 0)
	end)
	check("heartbeat skips pending writes and releases but reports expired leases", function()
		local a, _, store, clock = fixture(); a:Load(1)
		local ids = a:LoadedUserIds(); ids[1] = 999
		assert(a:LoadedUserIds()[1] == 1)
		store.BeforeTransform = function() coroutine.yield("store waiting") end
		local update = coroutine.create(function()
			a:Update(1, function(data: any) data.Currencies.Gold = 12 end)
		end)
		local ok, waiting = coroutine.resume(update)
		assert(ok and waiting == "store waiting" and #a:HeartbeatAll() == 0)
		clock.Now = 110
		assert(coroutine.resume(update) and coroutine.status(update) == "dead")
		assert(a:Get(1).Currencies.Gold == 12 and store:Read("Player_1").Lock.ExpiresAt == 140)
		local release = coroutine.create(function() a:Release(1) end)
		ok, waiting = coroutine.resume(release)
		assert(ok and waiting == "store waiting" and #a:HeartbeatAll() == 0)
		assert(coroutine.resume(release) and coroutine.status(release) == "dead")
		assert(#a:LoadedUserIds() == 0)
		store.BeforeTransform = nil; a:Load(2); clock.Now = 140
		local failures = a:HeartbeatAll()
		assert(#failures == 1 and failures[1] == 2)
	end)
	check("detached heartbeat predicate leaves lease to expire for another owner", function()
		local a, b, store, clock = fixture(); a:Load(1); a:Load(2)
		clock.Now = 110
		assert(#a:HeartbeatAll(function(userId: number) return userId == 2 end) == 0)
		assert(store:Read("Player_1").Lock.ExpiresAt == 130 and store:Read("Player_1").Revision == 1)
		assert(store:Read("Player_2").Lock.ExpiresAt == 140)
		clock.Now = 130
		assert(b:Load(1).Currencies.Gold == 0 and store:Read("Player_1").Lock.OwnerId == "B")
		assert(#a:HeartbeatAll(function(userId: number) return userId == 2 end) == 0)
	end)
	check("abandon rejects busy writes and only discards local cache", function()
		local a, b, store, clock = fixture(); a:Load(1)
		store.BeforeTransform = function() coroutine.yield() end
		local update = coroutine.create(function()
			a:Update(1, function(data: any) data.Currencies.Gold = 8 end)
		end)
		assert(coroutine.resume(update))
		rejects(function() a:Abandon(1) end, "already in progress")
		assert(a:HasProfile(1) and coroutine.resume(update))
		store.BeforeTransform = nil; store.FailNext = true
		a:Abandon(1)
		assert(not a:HasProfile(1) and store.FailNext)
		local stored = store:Read("Player_1")
		assert(stored.Data.Currencies.Gold == 8 and stored.Lock.OwnerId == "A" and stored.Revision == 2)
		store.FailNext = false; clock.Now = 130
		assert(b:Load(1).Currencies.Gold == 8)
	end)
	check("retried transforms do not repeat mutation", function()
		local a, _, store = fixture(); a:Load(1); store.RetryNext = true
		local calls = 0
		a:Update(1, function(data: any) calls += 1; data.Currencies.Gold += 7 end)
		assert(calls == 1 and a:Get(1).Currencies.Gold == 7)
	end)
	check("snapshots and retained mutator drafts cannot edit cache", function()
		local a = fixture(); local loaded = a:Load(-1); loaded.Currencies.Gold = 50
		local retained: any
		local updated = a:Update(-1, function(data: any) retained = data; data.Currencies.Gold = 3 end)
		retained.Currencies.Gold = 200; updated.Currencies.Gold = 300
		local read = a:Get(-1); read.Currencies.Gold = 400
		assert(a:Get(-1).Currencies.Gold == 3)
	end)
	check("legacy and unknown fields survive migration and writes", function()
		local a, _, store = fixture()
		store.Values.Player_1 = { SchemaVersion = 0, Currencies = { Gold = 81 }, FutureExtension = { Flag = true } }
		assert(a:Load(1).Currencies.Gold == 81)
		a:Update(1, function(data: any) data.Currencies.Gold += 1; return data end)
		assert(store:Read("Player_1").Data.FutureExtension.Flag)
	end)
	check("corrupt/future/store errors never reset existing data", function()
		local a, _, store = fixture(); store.Values.Player_1 = { SchemaVersion = 99, Currencies = { Gold = 81 } }
		rejects(function() a:Load(1) end, "unsupported future version")
		assert(store:Read("Player_1").Currencies.Gold == 81 and not a:HasProfile(1))
		store.Values.Player_2 = { Data = {}, Revision = "bad" }
		rejects(function() a:Load(2) end, "corrupt stored revision")
		store.FailNext = true; rejects(function() a:Load(3) end, "store failure")
		assert(not a:HasProfile(3) and store:Read("Player_3") == nil)
	end)
	check("reentrant/yielding/invalid mutations cannot publish", function()
		local a = fixture(); a:Load(1)
		rejects(function() a:Update(1, function(_data: any) a:Save(1) end) end, "already in progress")
		rejects(function() a:Update(1, function(_data: any) coroutine.yield() end) end, "must not yield")
		rejects(function() a:Update(1, function(data: any) data.Currencies.Gold = "bad" end) end, "Currencies.Gold")
		assert(a:Get(1).Currencies.Gold == 0)
	end)
	return passed
end
