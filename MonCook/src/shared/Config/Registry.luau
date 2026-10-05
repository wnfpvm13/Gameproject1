--!strict
local definitions: any = require(script.Parent.Definitions)
local Registry = {}
local families = { "Region", "Monster", "Drop", "Ingredient", "Recipe", "Weapon", "Cookware",
	"StaffRarity", "StaffTrait", "RestaurantLevel", "Customer", "Enhancement", "Economy", "WorldBlessing" }
local categories = { Protein = true, Produce = true, Spice = true, Special = true, Material = true }

local function expect(condition: boolean, path: string, message: string)
	assert(condition, "Config " .. path .. ": " .. message)
end

function Registry.validate(config: any?): boolean
	local catalog: any = if config == nil then definitions else config
	expect(type(catalog) == "table", "root", "catalog must be a table")
	for _, family in families do
		expect(type(catalog[family]) == "table", family, "required family is missing")
		for key, entry in catalog[family] do
			expect(type(key) == "string" and key ~= "", family, "keys must be stable nonempty strings")
			expect(type(entry) == "table", family .. "." .. key, "entry must be a table")
		end
	end
	local function reference(family: string, id: any, path: string)
		expect(type(id) == "string" and catalog[family][id] ~= nil, path, "unknown " .. family .. " key " .. tostring(id))
	end
	for id, region in catalog.Region do
		expect(region.TravelMode == "Local" or region.TravelMode == "Teleport", "Region." .. id, "invalid TravelMode")
	end
	for id, ingredient in catalog.Ingredient do
		expect(categories[ingredient.Category] == true, "Ingredient." .. id, "invalid category")
	end
	for id, drop in catalog.Drop do
		expect(type(drop.Entries) == "table" and #drop.Entries > 0, "Drop." .. id, "requires entries")
		for index, entry in drop.Entries do
			local path = "Drop." .. id .. ".Entries." .. tostring(index)
			expect(type(entry) == "table", path, "entry must be a table")
			reference("Ingredient", entry.IngredientId, path)
			local material = catalog.Ingredient[entry.IngredientId].Category == "Material"
			expect(entry.InventoryBucket == (if material then "Materials" else "Ingredients"), path, "category/bucket mismatch")
			expect(type(entry.Guaranteed) == "boolean", path, "Guaranteed must be boolean")
		end
	end
	for id, monster in catalog.Monster do
		reference("Region", monster.RegionId, "Monster." .. id .. ".RegionId")
		reference("Drop", monster.DropId, "Monster." .. id .. ".DropId")
		expect(type(monster.Parts) == "table", "Monster." .. id .. ".Parts", "requires part definitions")
		for part, entry in monster.Parts do
			expect(type(entry) == "table", "Monster." .. id .. ".Parts." .. tostring(part), "part must be a table")
			reference("Drop", entry.DropId, "Monster." .. id .. ".Parts." .. tostring(part))
		end
	end
	for id, recipe in catalog.Recipe do
		local path = "Recipe." .. id
		expect(type(recipe.BasePriceGold) == "number" and recipe.BasePriceGold >= 0 and recipe.BasePriceGold < math.huge, path, "invalid BasePriceGold")
		reference("Region", recipe.RegionId, path .. ".RegionId")
		reference("Cookware", recipe.CookwareId, path .. ".CookwareId")
		reference("Ingredient", recipe.DiscoveryIngredientId, path .. ".DiscoveryIngredientId")
		expect(type(recipe.Ingredients) == "table" and next(recipe.Ingredients) ~= nil, path, "requires ingredients")
		for ingredientId, count in recipe.Ingredients do
			reference("Ingredient", ingredientId, path .. ".Ingredients")
			expect(catalog.Ingredient[ingredientId].Category ~= "Material", path, "materials cannot be cooked")
			expect(type(count) == "number" and count > 0 and count < math.huge and count % 1 == 0, path, "quantity must be a positive integer")
		end
	end
	for id, trait in catalog.StaffTrait do
		expect(trait.Role == "Chef" or trait.Role == "Server", "StaffTrait." .. id, "unsupported role")
		expect(categories[trait.IngredientCategory] == true, "StaffTrait." .. id, "invalid category")
	end
	for id, rarity in catalog.StaffRarity do
		expect(type(rarity.PerformanceMultiplier) == "number" and rarity.PerformanceMultiplier > 0 and rarity.PerformanceMultiplier < math.huge,
			"StaffRarity." .. id, "invalid PerformanceMultiplier")
	end
	expect(type(catalog.Testing) == "table" and type(catalog.Testing.UseFakeTeleport) == "boolean", "Testing", "requires UseFakeTeleport boolean")
	return true
end

local function freezeTree(value: any)
	if type(value) == "table" then
		for _, child in value do freezeTree(child) end
		table.freeze(value)
	end
end

Registry.validate()
freezeTree(definitions)
Registry.Definitions = definitions

function Registry.get(family: string, id: string): any
	local entries = definitions[family]
	assert(entries ~= nil, "Config: unknown family " .. family)
	local entry = entries[id]
	assert(entry ~= nil, "Config: unknown " .. family .. " key " .. id)
	return entry
end

return table.freeze(Registry)
