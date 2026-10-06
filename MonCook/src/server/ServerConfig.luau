--!strict
return table.freeze({
	WorldPlaceId = 0, -- TODO_SETUP: two Places in the same published Experience.
	RestaurantPlaceId = 0,
	ExpeditionPlaceIds = table.freeze({ GreenwoodDeepRuins = 0 }), -- TODO_SETUP: future published expedition Place.
	ProfileStoreName = "MonCook_Player_v1",
	SessionMapName = "MonCook_Sessions_v1",
	MaxPartySize = 4,
	InviteTTLSeconds = 60, -- TODO_BALANCE: same-server invitation duration.
	ProfileLockSeconds = 180,
	HeartbeatSeconds = 45,
	SessionTTLSeconds = 3600,
	ArrivalWaitSeconds = 30,
	RequestIntervalSeconds = 0.25,
	DetachedReleaseRetrySeconds = 20,
	StudioProfileIngredients = table.freeze({ HornboarMeat = 5, Salt = 5 }), -- TODO_BALANCE: Studio test seed only.
})
