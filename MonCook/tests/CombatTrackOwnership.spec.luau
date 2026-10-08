--!strict
local Ownership = require(script.Parent.Parent.src.shared.Utilities.CombatTrackOwnership)
return function(): number
	assert(Ownership.createsTrack(true, "rbxassetid://123"), "Owner must start the predicted published track")
	assert(not Ownership.createsTrack(false, "rbxassetid://123"), "Observers must consume engine replication, without creating a second track")
	assert(Ownership.createsTrack(true, ""), "Owner keeps authored Studio previews")
	assert(Ownership.createsTrack(false, ""), "Studio preview hashes need a local observer preview")
	assert(Ownership.createsTrack(false, nil), "Missing publication keeps the existing fallback path")
	return 5
end
