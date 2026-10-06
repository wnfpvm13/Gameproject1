--!strict
-- TODO_BALANCE: Phase 1 playtest values. All combat/spawn/drop tuning lives here.
local Config: any = {
	Combat = {
		Rules = {
			PacketInterval = 0.08, ComboResetSeconds = 1.2, MaxSequence = 9007199254740991,
			MaxFacingCorrectionDegrees = 55, AimAssistDegrees = 24, VerticalTolerance = 6,
			DodgeDistance = 10, DodgeSeconds = 0.24, DodgeCooldown = 1.4,
			DodgeCollisionSize = { X = 2.4, Y = 4, Z = 2.4 }, DodgeObstacleMargin = 0.15,
			DodgeGroundProbeUp = 2, DodgeGroundProbeDown = 12,
			DodgeProtectionSeconds = 0, -- Positional dodge; no stamina or i-frames.
			TickSeconds = 0.05, StateRequestInterval = 0.4, StatePushInterval = 0.25,
		},
	},
	Weapon = {
		StarterCleaver = {
			AssetId = "WPN_StarterCleaver_V1", Reach = 8, ArcDegrees = 110,
			Basic = {
				{ Damage = 12, PartPower = 8, Windup = 0.12, Window = 0.16, Recovery = 0.14 },
				{ Damage = 14, PartPower = 10, Windup = 0.14, Window = 0.16, Recovery = 0.16 },
				{ Damage = 18, PartPower = 14, Windup = 0.20, Window = 0.20, Recovery = 0.20 },
			},
			Heavy = { Damage = 20, PartPower = 55, Windup = 0.42, Window = 0.20, Recovery = 0.38 },
		},
	},
	Monster = {
		Hornboar = {
			AssetId = "MON_Hornboar_V1", MaxHealth = 140, MoveSpeed = 7, RoamSpeed = 3,
			AlertDistance = 28, AlertSeconds = 0.55, LeashDistance = 46, RoamRadius = 9,
			IdleSeconds = 1.2, RoamSeconds = 2.5, StaggerSeconds = 0.65,
			RoamArrivalDistance = 0.1,
			DeathDespawnSeconds = 2.2, HitFlashSeconds = 0.16,
			ContributionMinimum = 1, ContributionExpirySeconds = 90,
			BodyHitbox = { Offset = { X = 0, Y = 2.6, Z = 0 }, Size = { X = 5.2, Y = 3.8, Z = 6.4 } },
			HornHitbox = { Offset = { X = 0, Y = 3.6, Z = -5.4 }, Size = { X = 2.6, Y = 3.3, Z = 4.9 } },
			HornHealth = 80,
			Attacks = {
				Headbutt = { Windup = 0.7, Duration = 0.3, HitStart = 0.08, HitEnd = 0.25,
					Range = 7, Radius = 3, ArcDegrees = 105, Damage = 10, Recover = 1.0 },
				Charge = { Windup = 1.25, Duration = 0.9, HitStart = 0, HitEnd = 0.9,
					Range = 28, MinimumRange = 8, Radius = 3, Speed = 24, Damage = 18, Recover = 1.3, ContactForwardOffset = 5.4 },
			},
		},
	},
	Drop = {
		Hornboar = {
			HornboarMeat = { Chance = 1, MinQuantity = 1, MaxQuantity = 2 },
			ArcaneFat = { Chance = 0.4, MinQuantity = 1, MaxQuantity = 1 },
			MarbledLoin = { Chance = 0.08, MinQuantity = 1, MaxQuantity = 1 },
		},
		HornboarHorn = { HornCore = { Chance = 1, MinQuantity = 1, MaxQuantity = 1 } },
	},
	Ingredient = {
		HornboarMeat = { AssetId = "ING_HornboarMeat_V1", Rarity = "Common" },
		ArcaneFat = { AssetId = "ING_ArcaneFat_V1", Rarity = "Uncommon" },
		MarbledLoin = { AssetId = "ING_MarbledLoin_V1", Rarity = "Rare" },
		HornCore = { AssetId = "MAT_HornCore_V1", Rarity = "Part" },
	},
	Spawn = {
		GreenwoodOutskirts = {
			DisplayName = "Greenwood Outskirts_PLACEHOLDER", RegionId = "Greenwood", MonsterId = "Hornboar",
			Center = { X = 0, Y = 0, Z = -28 }, Radius = 14, MaxAlive = 2, RespawnDelay = 7,
			Offsets = { { X = -8, Y = 0, Z = 0 }, { X = 8, Y = 0, Z = -5 } },
		},
	},
	Hunting = {
		Rewards = { RetrySeconds = 1, RetryLifetimeSeconds = 600, ReceiptRetentionSeconds = 3600,
			MaxPending = 256, MaxStack = 2147483647, DepartureFlushSeconds = 5 },
	},
}
return Config
