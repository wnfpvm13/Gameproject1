--!strict
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
	local function fixture(): (any, any, any, any, any)
		local store, clock, notices = Store.new(), { Now = 100 }, {}
		local data = Data.new({ Store = store, OwnerId = "inventory-A", Now = function() return clock.Now end,
			LockSeconds = 180, NewData = Defaults.new, Migrate = Migration.migrate })
		data:Load(1); data:Load(2)
		local inventory = Inventory.new({ Data = data, Definitions = Registry.Definitions, Contracts = Contracts, Geometry = Math,
			Now = function() return clock.Now end, OnGranted = function(actor: number, receipt: any) table.insert(notices, { Actor = actor, Receipt = receipt }) end })
		return inventory, data, store, clock, notices
	end
	local function reward(receipt: string, id: string?, quantity: number?, kind: string?): any
		return { ReceiptId = receipt, MonsterId = "Hornboar", Kind = kind or "Dead",
			Items = { { IngredientId = id or "HornboarMeat", Quantity = quantity or 1 } } }
	end
	check("server add and stack", function()
		local inventory, data = fixture(); inventory:Grant(1, reward("a", nil, 2)); inventory:Grant(1, reward("b", nil, 3))
		assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 5)
	end)
	check("correct ingredient and material buckets", function()
		local inventory, data = fixture(); inventory:Grant(1, reward("a", "ArcaneFat")); inventory:Grant(1, reward("b", "MarbledLoin"))
		inventory:Grant(1, reward("c", "HornCore", 1, "PartBroken"))
		local p = data:Get(1); assert(p.Inventory.Ingredients.ArcaneFat == 1 and p.Inventory.Ingredients.MarbledLoin == 1)
		assert(p.Inventory.Materials.HornCore == 1 and p.Inventory.Ingredients.HornCore == nil)
	end)
	check("invalid item and Gold cannot mutate profile", function()
		local inventory, data = fixture(); assert(not pcall(function() inventory:Grant(1, reward("a", "Gold", 9999)) end))
		assert(not pcall(function() inventory:Grant(1, reward("b", "Missing")) end))
		assert(data:Get(1).Currencies.Gold == 0 and data:Get(1).HuntingReceipts == nil)
	end)
	check("invalid negative fractional nonfinite quantities rejected", function()
		local inventory, data = fixture()
		for _, quantity in { -1, 0, 1.5, math.huge, 0/0 } do
			local r = reward("bad"); r.Items[1].Quantity = quantity
			assert(not pcall(function() inventory:Grant(1, r) end))
		end
		assert(next(data:Get(1).Inventory.Ingredients) == nil)
	end)
	check("unloaded actor and invalid reward source rejected", function()
		local inventory = fixture(); assert(not pcall(function() inventory:Grant(3, reward("a")) end))
		local r = reward("a"); r.Kind = "ClientPickup"; assert(not pcall(function() inventory:Grant(1, r) end))
	end)
	check("receipt idempotency", function()
		local inventory, data, _, _, notices = fixture(); assert(not inventory:Grant(1, reward("a", nil, 2)).Duplicate)
		assert(inventory:Grant(1, reward("a", nil, 2)).Duplicate)
		assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 2 and #notices == 1)
	end)
	check("receipt collision fails rather than grants different items", function()
		local inventory, data = fixture(); inventory:Grant(1, reward("a"))
		assert(not pcall(function() inventory:Grant(1, reward("a", "HornCore", 4)) end))
		assert(data:Get(1).Inventory.Materials.HornCore == nil)
	end)
	check("same encounter reward is personal for each actor", function()
		local inventory, data = fixture(); inventory:Grant(1, reward("same", nil, 2)); inventory:Grant(2, reward("same", nil, 1))
		assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 2 and data:Get(2).Inventory.Ingredients.HornboarMeat == 1)
	end)
	check("store retry cannot repeat addition", function()
		local inventory, data, store = fixture(); store.RetryNext = true; inventory:Grant(1, reward("a", nil, 3))
		assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 3 and store:Read("Player_1").Data.HuntingReceipts.a)
	end)
	check("failure leaves stacks receipts and notifications untouched", function()
		local inventory, data, store, _, notices = fixture(); store.FailNext = true
		assert(not pcall(function() inventory:Grant(1, reward("a")) end))
		assert(data:Get(1).HuntingReceipts == nil and next(data:Get(1).Inventory.Ingredients) == nil and #notices == 0)
		inventory:Grant(1, reward("a")); assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 1 and #notices == 1)
	end)
	check("persist and reload preserves stacks and receipt", function()
		local inventory, data = fixture(); inventory:Grant(1, reward("a", "HornCore", 1, "PartBroken")); data:Release(1); data:Load(1)
		assert(data:Get(1).Inventory.Materials.HornCore == 1 and inventory:Grant(1, reward("a", "HornCore", 1, "PartBroken")).Duplicate)
	end)
	check("preserves restaurant economy escrow and legacy collections", function()
		local inventory, data = fixture(); data:Update(1, function(p: any)
			p.Currencies.Gold = 55; p.SettlementReceipts = { old = { Kind = "Settlement" } }
			p.RestaurantSession = { SessionId = "restaurant", Pantry = { Salt = 3 } }
			p.Inventory.Materials.LegacyUnknown = { Metadata = "keep" }
		end)
		inventory:Grant(1, reward("a")); local p = data:Get(1)
		assert(p.Currencies.Gold == 55 and p.SettlementReceipts.old.Kind == "Settlement")
		assert(p.RestaurantSession.Pantry.Salt == 3 and p.Inventory.Materials.LegacyUnknown.Metadata == "keep" and p.SchemaVersion == 1)
	end)
	check("first flags occur once and horn material is not an ingredient", function()
		local inventory, data = fixture(); local core = inventory:Grant(1, reward("part", "HornCore", 1, "PartBroken"))
		assert(not core.Receipt.FirstIngredient and not core.Receipt.FirstHornboar)
		local first = inventory:Grant(1, reward("death")); local nextReward = inventory:Grant(1, reward("death2"))
		assert(first.Receipt.FirstIngredient and first.Receipt.FirstHornboar and not nextReward.Receipt.FirstIngredient and not nextReward.Receipt.FirstHornboar)
		assert(data:Get(1).AnalyticsFlags.FirstIngredientObtained and data:Get(1).AnalyticsFlags.FirstHornboarKilled)
	end)
	check("snapshot contains only display data and is isolated", function()
		local inventory, data = fixture(); inventory:Grant(1, reward("a")); local view = inventory:Snapshot(1)
		assert(view.Ingredients[1].DisplayName == "Hornboar Meat" and view.HuntingReceipts == nil and view.AnalyticsFlags == nil)
		view.Ingredients[1].Quantity = 99; assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 1)
	end)
	check("duplicate item entries merge before atomic grant", function()
		local inventory, data = fixture(); local r = reward("a", nil, 2); table.insert(r.Items, { IngredientId = "HornboarMeat", Quantity = 3 })
		inventory:Grant(1, r); assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 5)
	end)
	check("overflow and corrupt existing stack do not overwrite data", function()
		local inventory, data = fixture(); data:Update(1, function(p: any) p.Inventory.Ingredients.HornboarMeat = Registry.Definitions.Hunting.Rewards.MaxStack end)
		assert(not pcall(function() inventory:Grant(1, reward("a")) end))
		data:Update(1, function(p: any) p.Inventory.Ingredients.HornboarMeat = { Legacy = true } end)
		assert(not pcall(function() inventory:Grant(1, reward("b")) end)); assert(data:Get(1).Inventory.Ingredients.HornboarMeat.Legacy)
	end)
	check("only expired receipts are pruned", function()
		local inventory, data = fixture(); data:Update(1, function(p: any)
			p.HuntingReceipts = { old = { GrantedAt = -604800 }, recent = { GrantedAt = 90 } }
		end)
		inventory:Grant(1, reward("a")); local r = data:Get(1).HuntingReceipts
		assert(r.old == nil and r.recent and r.a)
	end)
	check("presentation error cannot undo committed data", function()
		local inventory, data = fixture(); inventory.OnGranted = function() error("UI down") end
		inventory:Grant(1, reward("a")); assert(data:Get(1).Inventory.Ingredients.HornboarMeat == 1)
		assert(inventory:Grant(1, reward("a")).Duplicate)
	end)
	check("lost store acknowledgement recovers persisted receipt after reconnect", function()
		local inventory, _, store, clock = fixture()
		local update = store.UpdateAsync
		local loseAcknowledgement = true
		store.UpdateAsync = function(self: any, key: string, transform: any): any
			local result = update(self, key, transform)
			if loseAcknowledgement then loseAcknowledgement = false; error("acknowledgement lost after commit") end
			return result
		end
		assert(not pcall(function() inventory:Grant(1, reward("durable", nil, 2)) end))
		assert(store:Read("Player_1").Data.Inventory.Ingredients.HornboarMeat == 2)
		clock.Now = 281
		local recovered = Data.new({ Store = store, OwnerId = "inventory-B", Now = function() return clock.Now end,
			LockSeconds = 180, NewData = Defaults.new, Migrate = Migration.migrate })
		recovered:Load(1)
		local fresh = Inventory.new({ Data = recovered, Definitions = Registry.Definitions, Contracts = Contracts,
			Geometry = Math, Now = function() return clock.Now end })
		assert(fresh:Grant(1, reward("durable", nil, 2)).Duplicate and recovered:Get(1).Inventory.Ingredients.HornboarMeat == 2)
	end)
	return count
end
