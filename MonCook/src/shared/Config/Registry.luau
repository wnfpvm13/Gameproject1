--!strict
local definitions: any = require(script.Parent.Definitions)
local Registry = {}
local families = { "Region", "Monster", "Drop", "Ingredient", "Recipe", "Weapon", "Cookware",
	"StaffRarity", "StaffTrait", "RestaurantLevel", "Customer", "Enhancement", "Economy", "WorldBlessing", "PartyTarget",
	"Combat", "Spawn", "Hunting" }
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
	local function positive(value: any, path: string)
		expect(type(value) == "number" and value == value and value > 0 and value < math.huge, path, "requires positive finite number")
	end
	local function point(value: any, path: string, size: boolean?)
		expect(type(value) == "table", path, "requires point")
		for _, axis in { "X", "Y", "Z" } do
			local n = value[axis]
			expect(type(n) == "number" and n == n and math.abs(n) < math.huge and (not size or n > 0), path, "invalid point component")
		end
	end
	for _, key in { "PacketInterval", "ComboResetSeconds", "MaxSequence", "MaxFacingCorrectionDegrees", "AimAssistDegrees",
		"VerticalTolerance", "DodgeDistance", "DodgeSeconds", "DodgeCooldown", "TickSeconds", "StateRequestInterval", "StatePushInterval",
		"DodgeObstacleMargin", "DodgeGroundProbeUp", "DodgeGroundProbeDown" } do positive(catalog.Combat.Rules[key], "Combat.Rules." .. key) end
	point(catalog.Combat.Rules.DodgeCollisionSize, "Combat.Rules.DodgeCollisionSize", true)
	expect(catalog.Combat.Rules.MaxFacingCorrectionDegrees <= 180 and catalog.Combat.Rules.AimAssistDegrees <= 180,
		"Combat.Rules", "invalid facing correction")
	expect(type(catalog.Combat.Rules.DodgeProtectionSeconds) == "number" and catalog.Combat.Rules.DodgeProtectionSeconds == 0,
		"Combat.Rules", "Phase 1 dodge is positional")
	for id, region in catalog.Region do
		expect(region.TravelMode == "Local" or region.TravelMode == "Teleport", "Region." .. id, "invalid TravelMode")
		expect(region.ActivityMode == "Shared" or region.ActivityMode == "Expedition", "Region." .. id, "invalid ActivityMode")
		expect(region.ActivityMode ~= "Expedition" or region.TravelMode == "Teleport", "Region." .. id, "Expedition requires Teleport")
	end
	local activities = { Free = true, SharedHunt = true, Expedition = true, Restaurant = true }
	for id, target in catalog.PartyTarget do
		local path = "PartyTarget." .. id
		expect(activities[target.Activity] == true, path, "invalid activity")
		expect(type(target.DisplayName) == "string" and target.DisplayName ~= "", path, "requires DisplayName")
		if target.Activity == "Expedition" or target.Activity == "SharedHunt" then
			reference("Region", target.RegionId, path .. ".RegionId")
			expect(catalog.Region[target.RegionId].ActivityMode == (if target.Activity == "Expedition" then "Expedition" else "Shared"), path, "region activity mismatch")
		end
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
			expect(type(entry.Chance) == "number" and entry.Chance >= 0 and entry.Chance <= 1, path, "invalid Chance")
			expect(not entry.Guaranteed or entry.Chance == 1, path, "guaranteed drop requires Chance 1")
			positive(entry.MinQuantity, path .. ".MinQuantity")
			expect(entry.MinQuantity % 1 == 0 and type(entry.MaxQuantity) == "number" and entry.MaxQuantity >= entry.MinQuantity
				and entry.MaxQuantity < math.huge and entry.MaxQuantity % 1 == 0, path, "invalid quantity range")
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
		positive(monster.MaxHealth, "Monster." .. id .. ".MaxHealth")
		positive(monster.MoveSpeed, "Monster." .. id .. ".MoveSpeed")
		positive(monster.HornHealth, "Monster." .. id .. ".HornHealth")
		positive(monster.HeavyHitStaggerSeconds, "Monster." .. id .. ".HeavyHitStaggerSeconds")
		for _, key in { "RoamSpeed", "AlertDistance", "AlertSeconds", "LeashDistance", "RoamRadius", "IdleSeconds", "RoamSeconds",
			"StaggerSeconds", "DeathDespawnSeconds", "ContributionMinimum", "ContributionExpirySeconds", "RoamArrivalDistance" } do positive(monster[key], "Monster." .. id .. "." .. key) end
		for _, key in { "BodyHitbox", "HornHitbox" } do
			point(monster[key].Offset, "Monster." .. id .. "." .. key .. ".Offset")
			point(monster[key].Size, "Monster." .. id .. "." .. key .. ".Size", true)
		end
		for attackId, attack in monster.Attacks do
			local path = "Monster." .. id .. ".Attacks." .. attackId
			for _, key in { "Windup", "Duration", "Damage", "Recover", "Range", "Radius" } do positive(attack[key], path .. "." .. key) end
			expect(type(attack.HitStart) == "number" and attack.HitStart >= 0 and attack.HitStart <= attack.HitEnd
				and attack.HitEnd <= attack.Duration, path, "invalid hit window")
		end
	end
	for id, weapon in catalog.Weapon do
		local path = "Weapon." .. id
		expect(type(weapon.Basic) == "table" and #weapon.Basic == 3, path, "requires three-hit combo")
		positive(weapon.Reach, path .. ".Reach")
		positive(weapon.ArcDegrees, path .. ".ArcDegrees")
		expect(weapon.ArcDegrees < 180, path, "attack arc must remain forward")
		for _, attack in { weapon.Basic[1], weapon.Basic[2], weapon.Basic[3], weapon.Heavy } do
			for _, key in { "Damage", "PartPower", "Windup", "Window", "Recovery" } do positive(attack[key], path .. "." .. key) end
		end
		positive(weapon.Heavy.Reach, path .. ".Heavy.Reach")
		positive(weapon.Heavy.ArcDegrees, path .. ".Heavy.ArcDegrees")
		expect(weapon.Heavy.Reach > weapon.Reach and weapon.Heavy.ArcDegrees > weapon.ArcDegrees
			and weapon.Heavy.ArcDegrees < 180, path, "heavy requires a longer forward reach and wider arc")
		expect(weapon.Heavy.PartPower > weapon.Basic[3].PartPower and weapon.Heavy.Damage > weapon.Basic[1].Damage,
			path, "heavy must have higher damage and part power")
	end
	for id, zone in catalog.Spawn do
		local path = "Spawn." .. id
		reference("Monster", zone.MonsterId, path)
		reference("Region", zone.RegionId, path)
		expect(catalog.Region[zone.RegionId].ActivityMode == "Shared", path, "hunting spawn requires shared region")
		for _, key in { "Radius", "MaxAlive", "RespawnDelay" } do positive(zone[key], path .. "." .. key) end
		point(zone.Center, path .. ".Center")
		expect(zone.MaxAlive % 1 == 0 and type(zone.Center) == "table" and type(zone.Offsets) == "table"
			and #zone.Offsets >= zone.MaxAlive, path, "invalid spawn slots")
		for _, offset in zone.Offsets do
			point(offset, path .. ".Offsets")
			expect(offset.X^2+offset.Z^2 <= zone.Radius^2, path, "spawn slot outside zone radius")
		end
	end
	positive(catalog.Hunting.Rewards.RetryLifetimeSeconds, "Hunting.Rewards.RetryLifetimeSeconds")
	positive(catalog.Hunting.Rewards.ReceiptRetentionSeconds, "Hunting.Rewards.ReceiptRetentionSeconds")
	for _, key in { "RetrySeconds", "MaxPending", "MaxStack", "DepartureFlushSeconds" } do positive(catalog.Hunting.Rewards[key], "Hunting.Rewards." .. key) end
	expect(catalog.Hunting.Rewards.ReceiptRetentionSeconds > catalog.Hunting.Rewards.RetryLifetimeSeconds,
			"Hunting.Rewards", "receipt retention must exceed retry lifetime")
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
	expect(type(catalog.Testing.ShowFoundationDebugUI) == "boolean", "Testing", "requires ShowFoundationDebugUI boolean")
	expect(type(catalog.Testing.ShowCombatHitboxes) == "boolean", "Testing", "requires ShowCombatHitboxes boolean")
	expect(type(catalog.Matchmaking) == "table" and type(catalog.Matchmaking.Enabled) == "boolean", "Matchmaking", "requires Enabled hook")
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
