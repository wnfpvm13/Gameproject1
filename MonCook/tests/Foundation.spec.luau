--!strict
-- Pure runner; Studio can require this with tests mounted beside Shared, or a
-- CLI harness can resolve script.Parent.Parent.src.shared to the source tree.
local Registry = require(script.Parent.Parent.src.shared.Config.Registry)
local Defaults = require(script.Parent.Parent.src.shared.Utilities.PlayerDataDefaults)
local Migration = require(script.Parent.Parent.src.shared.Utilities.PlayerDataMigration)

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in value do copy[key] = clone(child) end
	return copy
end

local function rejects(callback: () -> (), fragment: string)
	local ok, message = pcall(callback)
	assert(not ok, "Expected rejection: " .. fragment)
	assert(string.find(tostring(message), fragment, 1, true), tostring(message))
end

return function(): number
	local passed = 0
	local function check(_name: string, callback: () -> ())
		callback()
		passed += 1
	end
	check("fresh defaults and equipment ambiguity", function()
		local first, second = Defaults.new(), Defaults.new()
		first.Currencies.Gold = 99
		first.Inventory.Ingredients.HornboarMeat = 3
		first.Progression.RegionUnlocks[1] = "Other"
		first.Restaurant.Floors[1] = { Name = "Changed" }
		assert(second.Currencies.Gold == 0 and next(second.Inventory.Ingredients) == nil)
		assert(second.Progression.RegionUnlocks[1] == "Greenwood" and next(second.Restaurant.Floors) == nil)
		assert(second.Equipment.EquippedWeaponId == "StarterCleaver" and next(second.Equipment.Weapons) == nil)
		assert(second.Restaurant.SignatureDishId == nil)
	end)
	check("legacy upgrade preserves data and unknown fields", function()
		local raw = {
			SchemaVersion = 0, Currencies = { Gold = 417, EventCredits = 12 },
			Inventory = { Ingredients = { HornboarMeat = 9 }, Materials = { HornCore = 2 } },
			FutureExtension = { Enabled = true }, Progression = { RegionUnlocks = {} },
		}
		local migrated = Migration.migrate(raw)
		assert(migrated.SchemaVersion == 1 and raw.SchemaVersion == 0)
		assert(migrated.Currencies.Gold == 417 and migrated.Currencies.EventCredits == 12)
		assert(migrated.Inventory.Ingredients.HornboarMeat == 9 and migrated.Inventory.Materials.HornCore == 2)
		assert(migrated.FutureExtension.Enabled and migrated.Progression.RestaurantLevel == 1)
		assert(#migrated.Progression.RegionUnlocks == 0)
		migrated.Inventory.Ingredients.HornboarMeat = 0
		assert(raw.Inventory.Ingredients.HornboarMeat == 9)
	end)
	check("unversioned profile gains known fields", function()
		local migrated = Migration.migrate({ Currencies = { Gold = 73 } })
		assert(migrated.SchemaVersion == 1 and migrated.Currencies.Gold == 73)
		assert(migrated.Staff.RecruitmentReputation == 0 and migrated.Restaurant.FacadeStyle == "Default")
	end)
	check("current schema is preserved on repeated migration", function()
		local original = Defaults.new()
		original.Restaurant.SignatureDishId = "HornboarSteak"
		original.Recipes.Mastery.HornboarSteak = 5
		local migrated = Migration.migrate(Migration.migrate(original))
		assert(migrated.Restaurant.SignatureDishId == "HornboarSteak" and migrated.Recipes.Mastery.HornboarSteak == 5)
	end)
	check("future schema rejected without resetting", function()
		local raw = { SchemaVersion = 2, Currencies = { Gold = 42 } }
		rejects(function() Migration.migrate(raw) end, "unsupported future version")
		assert(raw.Currencies.Gold == 42 and raw.SchemaVersion == 2)
	end)
	check("corrupt known types rejected without partial filling", function()
		local raw: any = { SchemaVersion = 1, Currencies = { Gold = "42" } }
		rejects(function() Migration.migrate(raw) end, "Currencies.Gold")
		assert(raw.Inventory == nil)
		rejects(function() Migration.migrate({ Inventory = false }) end, "Inventory")
		rejects(function() Migration.migrate({ Restaurant = { SignatureDishId = 12 } }) end, "SignatureDishId")
		rejects(function() Migration.migrate({ Progression = { RegionUnlocks = { false } } }) end, "array element")
	end)
	check("invalid version and unserializable trees rejected", function()
		rejects(function() Migration.migrate({ SchemaVersion = "1" }) end, "invalid version")
		rejects(function() Migration.migrate({ SchemaVersion = -1 }) end, "invalid version")
		rejects(function() Migration.migrate({ Currencies = { Gold = 0 / 0 } }) end, "non-finite")
		local cycle: any = {}; cycle.Self = cycle
		rejects(function() Migration.migrate(cycle) end, "cyclic data")
	end)
	check("all config references and readonly registry", function()
		assert(Registry.validate())
		assert(Registry.get("Monster", "Hornboar").RegionId == "Greenwood")
		assert(table.isfrozen(Registry.Definitions.Recipe.HornboarSteak.Ingredients))
		rejects(function() Registry.get("Weapon", "Missing") end, "unknown Weapon key")
	end)
	check("dangling monster/recipe/part/drop references rejected", function()
		local catalog = clone(Registry.Definitions)
		catalog.Monster.Hornboar.RegionId = "Missing"
		rejects(function() Registry.validate(catalog) end, "Monster.Hornboar.RegionId")
		catalog = clone(Registry.Definitions); catalog.Recipe.HornboarSteak.CookwareId = "Missing"
		rejects(function() Registry.validate(catalog) end, "Recipe.HornboarSteak.CookwareId")
		catalog = clone(Registry.Definitions); catalog.Monster.Hornboar.Parts.Horn.DropId = "Missing"
		rejects(function() Registry.validate(catalog) end, "Parts.Horn")
		catalog = clone(Registry.Definitions); catalog.Drop.Hornboar.Entries[1].IngredientId = "Missing"
		rejects(function() Registry.validate(catalog) end, "Drop.Hornboar.Entries.1")
	end)
	check("material cooking and mismatched inventory buckets rejected", function()
		local catalog = clone(Registry.Definitions)
		catalog.Recipe.HornboarSteak.Ingredients.HornCore = 1
		rejects(function() Registry.validate(catalog) end, "materials cannot be cooked")
		catalog = clone(Registry.Definitions); catalog.Drop.HornboarHorn.Entries[1].InventoryBucket = "Ingredients"
		rejects(function() Registry.validate(catalog) end, "category/bucket mismatch")
	end)
	return passed
end
