--!strict
-- Recover the same-server party after its last activity participant returns or
-- disconnects. Locations/presence come from authoritative runtime providers.
local PartyService = require(script.Parent.PartyService)
local PartyActivityService = {}

function PartyActivityService.reconcile(
	partyService: any,
	actorId: number,
	location: (number) -> string,
	traveling: (number) -> boolean,
	present: (number) -> boolean
): PartyService.PartySnapshot?
	local party: PartyService.PartySnapshot? = partyService:Get(actorId)
	if party == nil or party.Status ~= "InActivity" then return party end
	for _, userId in party.MemberUserIds do
		if present(userId) and (traveling(userId) or location(userId) ~= "World") then
			return partyService:Get(actorId)
		end
	end
	-- A newer proposal or a transferred/replaced party must not be cleared by
	-- an older observation, even if an injected provider changed state.
	local current: PartyService.PartySnapshot? = partyService:Get(actorId)
	if current == nil or current.Status ~= "InActivity" or current.PartyId ~= party.PartyId
		or current.LeaderUserId ~= party.LeaderUserId or #current.MemberUserIds ~= #party.MemberUserIds then
		return current
	end
	for index, userId in party.MemberUserIds do
		if current.MemberUserIds[index] ~= userId then return current end
	end
	return partyService:SetStatus(current.LeaderUserId, "Forming")
end

return PartyActivityService
