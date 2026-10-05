--!strict
-- Config IDs select catalog definitions; instance IDs select owned equipment/staff.
export type WeaponInstance = {
	InstanceId: string, WeaponConfigId: string, EnhancementLevel: number,
	StabilizedFloor: number, EnhancementFocus: number,
}
export type CookwareInstance = {
	InstanceId: string, CookwareConfigId: string, EnhancementLevel: number,
	StabilizedFloor: number, EnhancementFocus: number,
}
export type StaffInstance = {
	StaffId: string, ArchetypeId: string, Role: "Chef" | "Server", Rarity: string,
	Level: number, XP: number, Traits: { string },
}
-- TODO_SCHEMA: the concept spec does not fix collection indexing/stack/floor layouts.
-- Keep those persisted collections opaque until their owning system defines a migration.
export type Collection = { [string | number]: any }
-- Compact durable escrow/recovery contract; live simulation remains cross-server.
export type RestaurantSession = {
	SessionId: string, HostUserId: number, PartyUserIds: { number },
	State: "Preparing" | "Teleporting" | "Active" | "Settling" | "Closed",
	CreatedAt: number, Pantry: { [string]: number }, SettlementVersion: number,
	DestinationPrivateServerId: string?, ClosedAt: number?,
}
export type SettlementReceipt = {
	SessionId: string, HostUserId: number, Kind: "Rollback" | "Settlement",
	Gold: number, Renown: number, ReturnedPantry: { [string]: number },
	SettlementVersion: number, SettledAt: number,
}
export type PlayerData = {
	SchemaVersion: number,
	Currencies: { Gold: number },
	Progression: { RestaurantLevel: number, RestaurantRenown: number, RegionUnlocks: { string } },
	Inventory: { Ingredients: Collection, Materials: Collection },
	Equipment: { EquippedWeaponId: string, Weapons: Collection, Cookware: Collection },
	Recipes: { Discovered: Collection, Mastery: Collection },
	Monsters: { Discovery: Collection, Mastery: Collection },
	Staff: { Owned: Collection, ActiveRestaurantStaff: Collection, RecruitmentReputation: number },
	Restaurant: {
		ExpansionPoints: number, Floors: Collection, BuiltModules: Collection,
		DecorationPlacements: Collection, SignatureDishId: string?, FacadeStyle: string,
	},
	Cosmetics: { Owned: Collection, Equipped: Collection },
	Monetization: { BlessingTokens: Collection },
	AnalyticsFlags: Collection,
	RestaurantSession: RestaurantSession?,
	SettlementReceipts: { [string]: SettlementReceipt }?,
}
return {}
