--!strict
local StudioStores = require(script.Parent.StudioStores)
local FakeTeleport = require(script.Parent.Parent.Services.FakeTeleport)
local RuntimeAdapters = {}
function RuntimeAdapters.new(isStudio: boolean, fakeTeleport: boolean, config: any): any
	local now = os.time
	local profiles, sessions, transport
	if isStudio then
		local stores = StudioStores.new(now, config.SessionTTLSeconds)
		profiles, sessions = stores.Profiles, stores.Sessions
	else
		profiles = game:GetService("DataStoreService"):GetDataStore(config.ProfileStoreName)
		local map = game:GetService("MemoryStoreService"):GetHashMap(config.SessionMapName)
		sessions = {
			GetAsync = function(_self: any, id: string) return map:GetAsync(id) end,
			SetAsync = function(_self: any, id: string, record: any) map:SetAsync(id, record, config.SessionTTLSeconds) end,
		}
	end
	if isStudio and fakeTeleport then
		transport = FakeTeleport.new()
	else
		local service = game:GetService("TeleportService")
		transport = {
			IsFake = false,
			Reserve = function(_self: any, placeId: number)
				return service:ReserveServerAsync(placeId)
			end,
			Send = function(_self: any, placeId: number, players: { Player }, payload: any, accessCode: string?)
				local options = Instance.new("TeleportOptions")
				options:SetTeleportData(payload)
				if accessCode then options.ReservedServerAccessCode = accessCode end
				service:TeleportAsync(placeId, players, options)
			end,
		}
	end
	return { Profiles = profiles, Sessions = sessions, Transport = transport, Now = now }
end
return RuntimeAdapters
