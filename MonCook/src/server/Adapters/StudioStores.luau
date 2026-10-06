--!strict
-- Only constructed by the Studio branch of RuntimeAdapters.
local StudioStores = {}
local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = clone(child) end
	return result
end
function StudioStores.new(now: () -> number, ttl: number): any
	local profiles, sessions = {}, {}
	return {
		Profiles = {
			UpdateAsync = function(_self: any, key: string, transform: (any) -> any): any
				local result = transform(clone(profiles[key]))
				if result ~= nil then profiles[key] = clone(result) end
				return clone(result)
			end,
		},
		Sessions = {
			GetAsync = function(_self: any, key: string): any
				local entry = sessions[key]
				if not entry or entry.ExpiresAt <= now() then return nil end
				return clone(entry.Value)
			end,
			SetAsync = function(_self: any, key: string, value: any)
				sessions[key] = { Value = clone(value), ExpiresAt = now() + ttl }
			end,
		},
	}
end
return StudioStores
