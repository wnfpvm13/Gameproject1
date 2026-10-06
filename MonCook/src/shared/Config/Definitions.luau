--!strict
-- Minimal Phase 0 catalog. Unspecified tuning stays absent until the owning system exists.
return {
	Region = {
		Greenwood = { DisplayName = "Greenwood Wilds", TravelMode = "Local", ActivityMode = "Shared", StartingRegion = true },
		GreenwoodDeepRuins = { DisplayName = "Greenwood Deep Ruins", TravelMode = "Teleport", ActivityMode = "Expedition" },
	},
	Monster = {
		Hornboar = {
			RegionId = "Greenwood", DropId = "Hornboar", RigFamily = "BeastQuadruped",
			AssetId = "Hornboar_PLACEHOLDER", Patterns = { "Headbutt", "Charge" },
			Parts = { Horn = { DropId = "HornboarHorn" } },
		},
	},
	Ingredient = {
		HornboarMeat = { DisplayName = "Hornboar Meat", Category = "Protein" },
		ArcaneFat = { DisplayName = "Arcane Fat", Category = "Special" },
		MarbledLoin = { DisplayName = "Marbled Loin", Category = "Protein" },
		HornCore = { DisplayName = "Horn Core", Category = "Material" },
		Salt = { DisplayName = "Salt", Category = "Spice", PantryStaple = true },
	},
	Drop = {
		-- Loot probabilities and quantities deliberately await the loot slice: TODO_BALANCE.
		Hornboar = { Entries = {
			{ IngredientId = "HornboarMeat", InventoryBucket = "Ingredients", Guaranteed = true },
			{ IngredientId = "ArcaneFat", InventoryBucket = "Ingredients", Guaranteed = false },
			{ IngredientId = "MarbledLoin", InventoryBucket = "Ingredients", Guaranteed = false },
		} },
		HornboarHorn = { Entries = {
			{ IngredientId = "HornCore", InventoryBucket = "Materials", Guaranteed = true },
		} },
	},
	Recipe = {
		HornboarSteak = {
			DisplayName = "Hornboar Steak", RegionId = "Greenwood", CookwareId = "BasicGrill",
			DiscoveryIngredientId = "HornboarMeat", AssetId = "HornboarSteak_PLACEHOLDER",
			-- TODO_BALANCE: exact portions and staple cost need cooking/economy tests.
			Ingredients = { HornboarMeat = 1, Salt = 1 }, BasePriceGold = 24,
		},
	},
	Weapon = {
		StarterCleaver = { Class = "Cleaver", Tier = "Starter", AssetId = "StarterCleaver_PLACEHOLDER" },
	},
	Cookware = {
		BasicGrill = { Class = "Grill", AssetId = "BasicGrill_PLACEHOLDER" },
	},
	StaffRarity = {
		-- TODO_BALANCE: spec's initial performance multipliers, not final tuning.
		Common = { PerformanceMultiplier = 1.00 }, Rare = { PerformanceMultiplier = 1.15 },
		Epic = { PerformanceMultiplier = 1.35 }, Legendary = { PerformanceMultiplier = 1.60 },
		Mythic = { PerformanceMultiplier = 1.90 },
	},
	StaffTrait = {
		MonsterMeatExpert = { Role = "Chef", IngredientCategory = "Protein" },
	},
	RestaurantLevel = {
		Progression = {
			Unbounded = true, Currency = "RestaurantRenown", ExpansionPointsPerLevel = 1,
			FloorPermitInterval = 10, -- TODO_BALANCE: permit cadence from spec.
		},
	},
	Customer = { Villager = { DisplayName = "Villager", StartingTier = true } },
	Enhancement = {
		Rules = { Unbounded = true, DestroyOnFailure = false, FailureResults = { "Maintain", "DecreaseOne" },
			StabilizationInterval = 10 }, -- TODO_BALANCE: stabilization cadence from spec.
	},
	Economy = {
		Rules = { SpendableCurrency = "Gold", MonsterGoldDrops = false, OfflineRevenue = false },
		-- TODO_BALANCE: spec's initial quality multipliers.
		Quality = { Normal = 1.00, Good = 1.10, Great = 1.25, Perfect = 1.50 },
	},
	WorldBlessing = {
		-- Duration/magnitude/product IDs await Phase 8: TODO_BALANCE. No purchases implemented.
		Tailwind = { Effect = "NonCombatMovement", Stacking = "ExtendDuration" },
		HuntersRhythm = { Effect = "AttackSpeedCapped", Stacking = "ExtendDuration" },
		Bounty = { Effect = "GuaranteedBasicIngredients", Stacking = "ExtendDuration" },
	},
	-- Targets are stable activity contracts; Twin Ogre combat/loot is a later slice.
	PartyTarget = {
		Free = { DisplayName = "자유 파티", Activity = "Free" },
		GreenwoodFarm = { DisplayName = "Greenwood 재료 사냥", Activity = "SharedHunt", RegionId = "Greenwood" },
		TwinOgre = { DisplayName = "Twin Ogre 원정", Activity = "Expedition", RegionId = "GreenwoodDeepRuins" },
		HostRestaurant = { DisplayName = "호스트 식당", Activity = "Restaurant" },
	},
	Matchmaking = { Enabled = false, Version = "V1.5" }, -- TODO: cross-server queue interface only.
	Testing = { UseFakeTeleport = true, ShowFoundationDebugUI = false },
}
