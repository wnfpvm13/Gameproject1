--!strict
local Types = require(script.Parent.Parent.Types.PlayerData)
type PlayerData = Types.PlayerData
local Defaults = { SchemaVersion = 1 }

function Defaults.new(): PlayerData
	-- New tables on every call: profiles must never share mutable collections.
	return {
		SchemaVersion = Defaults.SchemaVersion,
		Currencies = { Gold = 0 },
		Progression = { RestaurantLevel = 1, RestaurantRenown = 0, RegionUnlocks = { "Greenwood" } },
		Inventory = { Ingredients = {}, Materials = {} },
		Equipment = {
			-- Built-in starter entitlement preserves the Foundation v1 default.
			-- Other equips resolve owned instance IDs; no ownership collection is reset.
			EquippedWeaponId = "StarterCleaver", Weapons = {}, Cookware = {},
		},
		Recipes = { Discovered = {}, Mastery = {} },
		Monsters = { Discovery = {}, Mastery = {} },
		Staff = { Owned = {}, ActiveRestaurantStaff = {}, RecruitmentReputation = 0 },
		Restaurant = {
			ExpansionPoints = 0, Floors = {}, BuiltModules = {}, DecorationPlacements = {},
			SignatureDishId = nil, FacadeStyle = "Default",
		},
		Cosmetics = { Owned = {}, Equipped = {} },
		Monetization = { BlessingTokens = {} },
		AnalyticsFlags = {},
	}
end

return table.freeze(Defaults)
