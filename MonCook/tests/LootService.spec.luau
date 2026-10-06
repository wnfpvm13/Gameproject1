--!strict
local Loot = require(script.Parent.Parent.src.server.Services.LootService)
local Inventory = require(script.Parent.Parent.src.server.Services.InventoryService)
local Data = require(script.Parent.Parent.src.server.Services.DataService)
local Store = require(script.Parent.Support.InMemoryStore)
local Registry = require(script.Parent.Parent.src.shared.Config.Registry)
local Contracts = require(script.Parent.Parent.src.shared.Utilities.HuntingContracts)
local Math = require(script.Parent.Parent.src.shared.Utilities.HuntingMath)
local Defaults = require(script.Parent.Parent.src.shared.Utilities.PlayerDataDefaults)
local Migration = require(script.Parent.Parent.src.shared.Utilities.PlayerDataMigration)
return function(): number
	local count = 0
	local function check(_name: string, test: () -> ()) test(); count += 1 end
	local function fixture(rolls: { number }?): (any, any, any, any, any)
		local store, clock, analytics = Store.new(), { Now = 100, Rolls = 0, CanAward = true }, {}
		local data = Data.new({ Store = store, OwnerId = "loot-A", Now = function() return clock.Now end,
			LockSeconds = 180, NewData = Defaults.new, Migrate = Migration.migrate })
		data:Load(1); data:Load(2)
		local inventory = Inventory.new({ Data = data, Definitions = Registry.Definitions, Geometry = Math, Contracts = Contracts, Now = function() return clock.Now end })
		local loot = Loot.new({ Definitions = Registry.Definitions, Inventory = inventory, Now = function() return clock.Now end,
			Roll = function() clock.Rolls += 1; return if rolls then rolls[clock.Rolls] or 0.99 else 0.99 end,
			CanAward = function() return clock.CanAward end, OnEvent = function(event: any) table.insert(analytics, event) end })
		return loot, data, store, clock, analytics
	end
	local function event(id: string?, members: { number }?, kind: string?): any
		local part = kind == "PartBroken"
		return { EventId = id or "encounter:Death", EncounterId = "encounter", MonsterId = "Hornboar", Kind = kind or "Dead",
			PartId = if part then "Horn" else nil, DropId = if part then "HornboarHorn" else "Hornboar",
			Members = members or { 1 }, At = 100, Origin = { X = 0, Y = 0, Z = 0 } }
	end
	check("guaranteed meat regardless of rare RNG", function()
		local loot, data = fixture(); assert(loot:Enqueue(event())); loot:Tick()
		local p = data:Get(1); assert(p.Inventory.Ingredients.HornboarMeat == 2 and p.Inventory.Ingredients.MarbledLoin == nil)
	end)
	check("rare and common independent rolls", function()
		local loot, data = fixture({ 0, 0, 0 }); loot:Enqueue(event()); loot:Tick()
		local p = data:Get(1); assert(p.Inventory.Ingredients.HornboarMeat == 1 and p.Inventory.Ingredients.ArcaneFat == 1 and p.Inventory.Ingredients.MarbledLoin == 1)
	end)
	check("two contributors receive personal loot without party", function()
		local loot, data, _, clock = fixture({ 0, 0.2, 0.9, 0.9, 0.9, 0.01 }); loot:Enqueue(event(nil, { 1, 2 })); loot:Tick()
		assert(data:Get(1).Inventory.Ingredients.HornboarMeat and data:Get(2).Inventory.Ingredients.HornboarMeat)
		assert(data:Get(1).Inventory.Ingredients.ArcaneFat == 1 and data:Get(1).Inventory.Ingredients.MarbledLoin == nil)
		assert(data:Get(2).Inventory.Ingredients.MarbledLoin == 1 and data:Get(2).Inventory.Ingredients.ArcaneFat == nil)
		assert(clock.Rolls == 6 and data:Get(1).Currencies.Gold == 0 and data:Get(2).Currencies.Gold == 0)
	end)
	check("noncontributor receives nothing", function()
		local loot, data = fixture(); loot:Enqueue(event(nil, { 1 })); loot:Tick(); assert(next(data:Get(2).Inventory.Ingredients) == nil)
	end)
	check("part reward grants material once without random roll", function()
		local loot, data, _, clock = fixture(); local e = event("encounter:Part:Horn", { 1, 2 }, "PartBroken")
		loot:Enqueue(e); loot:Enqueue(e); loot:Tick()
		assert(data:Get(1).Inventory.Materials.HornCore == 1 and data:Get(2).Inventory.Materials.HornCore == 1 and clock.Rolls == 0)
	end)
	check("part and death rewards use separate receipts", function()
		local loot, data = fixture(); loot:Enqueue(event("encounter:Part:Horn", { 1 }, "PartBroken")); loot:Enqueue(event()); loot:Tick()
		local p = data:Get(1); assert(p.Inventory.Materials.HornCore == 1 and p.Inventory.Ingredients.HornboarMeat == 2)
		assert(p.HuntingReceipts["encounter:Part:Horn"] and p.HuntingReceipts["encounter:Death"])
	end)
	check("duplicate member list does not duplicate rolls or awards", function()
		local loot, data, _, clock = fixture(); loot:Enqueue(event(nil, { 1, 1, 1 })); loot:Tick()
		assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 2 and clock.Rolls == 3)
	end)
	check("failed store retains rolled result for retry", function()
		local loot, data, store, clock = fixture({ 0, 0, 0 }); loot:Enqueue(event()); store.FailNext = true; loot:Tick()
		assert(loot:PendingCount() == 1 and clock.Rolls == 3 and data:Get(1).HuntingReceipts == nil)
		clock.Now = 101.1; loot:Tick()
		assert(loot:PendingCount() == 0 and clock.Rolls == 3 and data:Get(1).Inventory.Ingredients.MarbledLoin == 1)
	end)
	check("repeated event does not reroll after successful grant", function()
		local loot, data, _, clock = fixture(); local e = event(); loot:Enqueue(e); loot:Tick(); loot:Enqueue(e); loot:Tick()
		assert(clock.Rolls == 3 and data:Get(1).Inventory.Ingredients.HornboarMeat == 2)
	end)
	check("temporary actor unavailability retains reward", function()
		local loot, data, _, clock = fixture(); clock.CanAward = false; loot:Enqueue(event()); loot:Tick()
		assert(loot:PendingCount() == 1 and next(data:Get(1).Inventory.Ingredients) == nil)
		clock.CanAward = true; loot:Tick(); assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 2)
	end)
	check("expired reward does not grant or resurrect after reenqueuing", function()
		local loot, data, _, clock = fixture(); clock.CanAward = false; loot:Enqueue(event()); clock.Now = 701; loot:Tick()
		assert(loot:PendingCount() == 0); assert(loot:Enqueue(event()) and loot:PendingCount() == 0)
		-- Reading a persisted store rather than an expired profile lease.
		assert(next(data.Store:Read("Player_1").Data.Inventory.Ingredients) == nil)
	end)
	check("capacity refusal does not consume rolls or part of an event", function()
		local loot, _, _, clock = fixture(); loot.Definitions = { Monster = Registry.Definitions.Monster, Drop = Registry.Definitions.Drop,
			Hunting = { Rewards = { MaxPending = 1, RetryLifetimeSeconds = 600 } } }
		assert(not loot:Enqueue(event(nil, { 1, 2 })) and loot:PendingCount() == 0 and clock.Rolls == 0)
	end)
	check("invalid drop source and pickup event rejected", function()
		local loot = fixture(); local e = event(); e.DropId = "HornboarHorn"
		assert(not pcall(function() loot:Enqueue(e) end)); e = event(); e.Kind = "ClientPickup"
		assert(not pcall(function() loot:Enqueue(e) end))
	end)
	check("first and rare analytics emitted on commit only", function()
		local loot, _, store, clock, analytics = fixture({ 0, 0, 0 }); loot:Enqueue(event()); store.FailNext = true; loot:Tick(); assert(#analytics == 0)
		clock.Now = 101.1; loot:Tick(); local names: { [string]: number } = {}
		for _, e in analytics do names[e.Name] = (names[e.Name] or 0) + 1 end
		assert(names.FirstHornboarKilled == 1 and names.FirstIngredientObtained == 1 and names.RareIngredientObtained == 1)
	end)
	check("duplicate persisted award never emits another pickup", function()
		local loot, data, _, _, analytics = fixture(); local e = event(); loot:Enqueue(e); loot:Tick(); local previous = #analytics
		loot._queued = {}; loot:Enqueue(e); loot:Tick()
		assert(#analytics == previous and data:Get(1).Inventory.Ingredients.HornboarMeat == 2)
	end)
	check("reentrant tick during a yielding store cannot duplicate reward", function()
		local loot, data, store = fixture(); loot:Enqueue(event())
		store.BeforeTransform = function() coroutine.yield("store pending") end
		local worker = coroutine.create(function() loot:Tick() end)
		local ok, waiting = coroutine.resume(worker); assert(ok and waiting == "store pending")
		loot:Tick(); assert(loot:PendingCount() == 1)
		assert(coroutine.resume(worker) and coroutine.status(worker) == "dead")
		assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 2 and loot:PendingCount() == 0)
	end)
	return count
end
