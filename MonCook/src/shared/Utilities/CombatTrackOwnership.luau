--!strict
-- Engine-replicated published tracks belong to their originating player.
local Ownership = {}
function Ownership.createsTrack(isOwner: boolean, publishedId: string?): boolean
	return isOwner or publishedId == nil or publishedId == ""
end
return Ownership
