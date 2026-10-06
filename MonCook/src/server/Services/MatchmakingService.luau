--!strict
-- TODO V1.5: cross-server queue, matching, reservations and receipt/recovery.
-- Config hook only. Enabling the flag cannot create an unimplemented queue.
local MatchmakingService = {}
MatchmakingService.__index = MatchmakingService

function MatchmakingService.new(options: { Enabled: boolean }): any
	assert(type(options) == "table" and type(options.Enabled) == "boolean", "MatchmakingService: Enabled hook required")
	return setmetatable({ _enabled = options.Enabled }, MatchmakingService)
end

function MatchmakingService.GetStatus(self: any): any
	return table.freeze({ Enabled = self._enabled, Available = false, Code = "NotAvailable", PlannedVersion = "V1.5" })
end

function MatchmakingService.Request(self: any, userId: number, regionId: string, targetId: string): any
	assert(type(userId) == "number" and userId ~= 0 and math.abs(userId) <= 9007199254740991
		and userId % 1 == 0, "MatchmakingService: invalid user ID")
	assert(type(regionId) == "string" and #regionId > 0 and #regionId <= 128, "MatchmakingService: invalid region ID")
	assert(type(targetId) == "string" and #targetId > 0 and #targetId <= 128, "MatchmakingService: invalid target ID")
	return self:GetStatus()
end

return table.freeze(MatchmakingService)
