--!strict
local Expedition = require(script.Parent.Parent.src.server.Services.ExpeditionService)
local Matchmaking = require(script.Parent.Parent.src.server.Services.MatchmakingService)
local Teleport = require(script.Parent.Parent.src.server.Services.TeleportServiceWrapper)
local Fake = require(script.Parent.Parent.src.server.Services.FakeTeleport)

local function rejects(callback: () -> (), fragment: string?)
	local ok, message = pcall(callback)
	assert(not ok, "Expected operation to reject")
	assert(fragment == nil or string.find(tostring(message), fragment, 1, true), tostring(message))
end

local function service(overrides: any?): any
	local nextId = 0
	local options: any = {
		NewId = function(): string nextId += 1; return "expedition-" .. tostring(nextId) end,
		Now = function(): number return 123 end, MaxMembers = 4,
		ValidTarget = function(region: string, target: string): boolean
			return region == "GreenwoodDeepRuins" and target == "TwinOgre"
		end,
	}
	for key, value in overrides or {} do options[key] = value end
	return Expedition.new(options)
end

local function prepare(expedition: any, host: number?, members: { number }?): any
	return expedition:Prepare(host or 1, "party", members or { 1, 2 }, "GreenwoodDeepRuins", "TwinOgre")
end

local function active(expedition: any): string
	local id = prepare(expedition).SessionId
	expedition:MarkTeleporting(1, id, "private")
	expedition:Activate(1, id, "private")
	return id
end

local function fakeWrapper(transport: any, placeIds: any?): any
	return Teleport.new({ IsStudio = true, UseFakeTeleport = true, WorldPlaceId = 0,
		RestaurantPlaceId = 0, ExpeditionPlaceIds = placeIds, Transport = transport })
end

return function(): number
	local passed = 0
	local function check(_name: string, callback: () -> ()) callback(); passed += 1 end
	check("selected members copied and snapshots frozen", function()
		local expedition, members = service(), { 1, 3, 2 }
		local created = prepare(expedition, 1, members)
		members[2] = 99
		assert(created.MemberUserIds[2] == 3 and expedition:GetForMember(3).SessionId == created.SessionId)
		assert(table.isfrozen(created) and table.isfrozen(created.MemberUserIds))
		rejects(function() created.MemberUserIds[1] = 99 end)
		assert(expedition:GetForMember(99) == nil and expedition:Get("missing") == nil)
	end)
	check("dense bounded unique finite selected IDs validated before mutation", function()
		for _, members: any in { {}, { 2 }, { 1, 1 }, { 1, 2, 3, 4, 5 }, { [1] = 1, [3] = 2 }, { ["1"] = 1 },
			{ 1, 0 }, { 1, 0.5 }, { 1, math.huge }, { 1, 0 / 0 }, { 1, 9007199254740992 }, { 1, "2" } } do
			local expedition = service()
			rejects(function() prepare(expedition, 1, members) end)
			assert(expedition:GetForMember(1) == nil)
			assert(prepare(expedition, 1, { 1 }).State == "Preparing")
		end
		local expedition = service()
		assert(prepare(expedition, -1, { -1, -2 }).HostUserId == -1)
	end)
	check("config pair and dependency failures cannot publish partial sessions", function()
		local expedition = service()
		rejects(function() expedition:Prepare(1, "party", { 1 }, "Missing", "TwinOgre") end, "invalid region/target")
		rejects(function() expedition:Prepare(1, "party", { 1 }, "GreenwoodDeepRuins", "Missing") end, "invalid region/target")
		assert(expedition:GetForMember(1) == nil)
		local badTime = service({ Now = function() return math.huge end })
		rejects(function() prepare(badTime) end, "server time")
		assert(badTime:GetForMember(1) == nil)
		local duplicate = service({ NewId = function() return "same" end })
		local first = prepare(duplicate)
		duplicate:Cancel(1, first.SessionId, "cancel")
		rejects(function() prepare(duplicate) end, "already issued")
		assert(duplicate:GetForMember(1) == nil)
	end)
	check("one unfinished expedition per member enforced atomically", function()
		local expedition = service()
		local first = prepare(expedition, 1, { 1, 2, 3, 4 })
		rejects(function() expedition:Prepare(5, "party2", { 5, 3 }, "GreenwoodDeepRuins", "TwinOgre") end, "unfinished")
		assert(expedition:GetForMember(5) == nil and expedition:GetForMember(3).SessionId == first.SessionId)
		expedition:Cancel(1, first.SessionId, "cancel")
		assert(expedition:Prepare(5, "party2", { 5, 3 }, "GreenwoodDeepRuins", "TwinOgre").State == "Preparing")
	end)
	check("host authority and destination binding survive duplicate transitions", function()
		local expedition, id = service(), ""
		id = prepare(expedition).SessionId
		rejects(function() expedition:MarkTeleporting(2, id, "private") end, "host required")
		rejects(function() expedition:Activate(1, id, "private") end, "transition")
		expedition:MarkTeleporting(1, id, "private")
		assert(expedition:MarkTeleporting(1, id, "private").State == "Teleporting")
		rejects(function() expedition:MarkTeleporting(1, id, "other") end, "mismatch")
		rejects(function() expedition:Activate(1, id, "other") end, "mismatch")
		expedition:Activate(1, id, "private")
		assert(expedition:Activate(1, id, "private").State == "Active")
		rejects(function() expedition:MarkTeleporting(1, id, "private") end, "transition")
		rejects(function() expedition:Complete(2, id) end, "host required")
	end)
	check("every result destination completes with duplicate-safe receipt", function()
		for _, destination in { "Repeat", "HostRestaurant", "Hearthcross" } do
			local expedition = service()
			local id = active(expedition)
			assert(expedition:Complete(1, id).State == "Result")
			assert(expedition:Complete(1, id).ResultAt == 123)
			assert(expedition:BeginReturn(1, id, destination, "return").State == "Returning")
			assert(expedition:BeginReturn(1, id, destination, "return").ReturnDestination == destination)
			local receipt = expedition:Close(1, id, "return")
			assert(receipt.Kind == "Return" and receipt.Destination == destination and receipt.ClosedAt == 123)
			assert(expedition:Close(1, id, "return").ActionId == "return")
			assert(expedition:GetReceipt(1, id).ActionId == "return")
			assert(expedition:BeginReturn(1, id, destination, "return").State == "Closed")
			assert(expedition:GetForMember(1) == nil and expedition:GetForMember(2) == nil)
			local nextSession = prepare(expedition)
			expedition:Close(1, id, "return")
			assert(expedition:GetForMember(1).SessionId == nextSession.SessionId)
		end
	end)
	check("stale duplicate and conflicting result actions cannot change the destination", function()
		local expedition = service()
		local id = active(expedition)
		rejects(function() expedition:BeginReturn(1, id, "Repeat", "return") end, "requires Result")
		expedition:Complete(1, id)
		rejects(function() expedition:BeginReturn(1, id, "Unknown", "return") end, "invalid return destination")
		assert(expedition:Get(id).State == "Result")
		expedition:BeginReturn(1, id, "Hearthcross", "return")
		rejects(function() expedition:BeginReturn(1, id, "Repeat", "return") end, "conflict")
		rejects(function() expedition:BeginReturn(1, id, "Repeat", "new") end, "requires Result")
		rejects(function() expedition:Close(1, id, "old") end, "current return action")
		rejects(function() expedition:RestoreResult(1, id, "old") end, "stale")
		expedition:Close(1, id, "return")
		rejects(function() expedition:Close(1, id, "old") end, "stale")
		rejects(function() expedition:Complete(1, id) end, "requires Active")
	end)
	check("return failure restores Result and retires failed attempt IDs", function()
		local expedition = service()
		local id = active(expedition)
		expedition:Complete(1, id)
		expedition:BeginReturn(1, id, "Hearthcross", "failed")
		assert(expedition:RestoreResult(1, id, "failed").State == "Result")
		assert(expedition:RestoreResult(1, id, "failed").ReturnActionId == nil)
		rejects(function() expedition:BeginReturn(1, id, "Hearthcross", "failed") end, "stale")
		expedition:BeginReturn(1, id, "Repeat", "retry")
		rejects(function() expedition:RestoreResult(1, id, "failed") end, "stale")
		expedition:RestoreResult(1, id, "retry")
		rejects(function() expedition:RestoreResult(1, id, "failed") end, "stale")
		expedition:BeginReturn(1, id, "Repeat", "final")
		assert(expedition:Close(1, id, "final").Kind == "Return")
	end)
	check("pre-active cancellation is duplicate-safe and preserves newer session indexes", function()
		local expedition = service()
		local id = prepare(expedition).SessionId
		expedition:MarkTeleporting(1, id, "private")
		assert(expedition:Cancel(1, id, "cancel").Kind == "Cancel")
		local nextSession = prepare(expedition)
		assert(expedition:Cancel(1, id, "cancel").Kind == "Cancel")
		assert(expedition:GetForMember(1).SessionId == nextSession.SessionId)
		rejects(function() expedition:Activate(1, id, "private") end, "transition")
		rejects(function() expedition:Cancel(1, id, "other") end, "conflicting")
		local started = service(); local startedId = active(started)
		rejects(function() started:Cancel(1, startedId, "cancel") end, "pre-active")
	end)
	check("started host-disconnect abandonment releases runtime identities without economy", function()
		local expedition = service(); local id = active(expedition)
		expedition:Complete(1, id); expedition:BeginReturn(1, id, "Repeat", "return")
		local receipt = expedition:Abandon(1, id, "disconnect")
		assert(receipt.Kind == "Abandon" and receipt.Gold == nil and receipt.Renown == nil)
		assert(expedition:GetForMember(1) == nil and expedition:GetForMember(2) == nil)
		assert(expedition:Abandon(1, id, "disconnect").ActionId == "disconnect")
		rejects(function() expedition:BeginReturn(1, id, "Repeat", "return") end, "stale")
		rejects(function() expedition:Close(1, id, "return") end, "conflicting")
	end)
	check("fake Expedition transport carries identifiers only and binds reservation region", function()
		local fake = Fake.new(); local wrapper = fakeWrapper(fake)
		local reservation = wrapper:ReserveExpedition("GreenwoodDeepRuins")
		wrapper:ToExpedition({ { UserId = 1 } }, "session", "GreenwoodDeepRuins", reservation, "attempt")
		local calls = fake:GetCalls(); local payload = calls[2].Payload
		assert(calls[1].PlaceId == 0 and calls[2].AccessCode == reservation.AccessCode)
		assert(payload.SessionId == "session" and payload.Destination == "Expedition"
			and payload.RegionId == "GreenwoodDeepRuins" and payload.AttemptId == "attempt")
		local count = 0
		for key in payload do
			assert(key == "SessionId" or key == "Destination" or key == "RegionId" or key == "AttemptId")
			count += 1
		end
		assert(count == 4)
		rejects(function() wrapper:ToExpedition({ 1 }, "session", "Other", reservation) end, "mismatch")
		rejects(function() wrapper:ToExpedition({ 1 }, "session", "GreenwoodDeepRuins", wrapper:ReserveRestaurant()) end, "mismatch")
		assert(#fake:GetCalls() == 3, "invalid routes must never send")
	end)
	check("fake transport failures support cancellation and return rollback", function()
		local fake = Fake.new(); local wrapper = fakeWrapper(fake); local expedition = service()
		local id = prepare(expedition).SessionId; local reservation = wrapper:ReserveExpedition("GreenwoodDeepRuins")
		expedition:MarkTeleporting(1, id, reservation.PrivateServerId)
		fake:FailNext("send failed")
		rejects(function() wrapper:ToExpedition({ 1, 2 }, id, "GreenwoodDeepRuins", reservation, "out") end, "send failed")
		expedition:Cancel(1, id, "cancel")
		local nextId = active(expedition); expedition:Complete(1, nextId)
		expedition:BeginReturn(1, nextId, "Hearthcross", "back")
		fake:FailNext("return failed")
		rejects(function() wrapper:ToWorld({ 1, 2 }, nextId, "back") end, "return failed")
		assert(expedition:RestoreResult(1, nextId, "back").State == "Result")
	end)
	check("published Expedition routes require positive configured place IDs at use", function()
		local calls = 0
		local transport = {
			Reserve = function(_self: any, _place: number): (string, string) calls += 1; return "access", "private" end,
			Send = function(_self: any, _place: number, _players: any, _payload: any, _access: any) calls += 1 end,
		}
		for _, invalid: any in { 0, -1, 1.5, math.huge, 0 / 0, "1" } do
			local wrapper = Teleport.new({ IsStudio = false, UseFakeTeleport = false, WorldPlaceId = 1,
				RestaurantPlaceId = 2, ExpeditionPlaceIds = { Region = invalid }, Transport = transport })
			rejects(function() wrapper:ReserveExpedition("Region") end, "ExpeditionPlaceId")
		end
		assert(calls == 0)
		local routes = { Region = 3 }
		local wrapper = Teleport.new({ IsStudio = false, UseFakeTeleport = false, WorldPlaceId = 1,
			RestaurantPlaceId = 2, ExpeditionPlaceIds = routes, Transport = transport })
		routes.Region = 9
		assert(wrapper:ReserveExpedition("Region").PlaceId == 3)
		rejects(function() wrapper:ReserveExpedition("Missing") end, "ExpeditionPlaceId")
		assert(calls == 1)
	end)
	check("disabled Quick Match cannot silently create a queue even when flag enabled", function()
		for _, enabled in { false, true } do
			local matchmaking = Matchmaking.new({ Enabled = enabled })
			local status = matchmaking:GetStatus()
			assert(status.Enabled == enabled and status.Available == false and status.Code == "NotAvailable")
			assert(matchmaking:Request(1, "GreenwoodDeepRuins", "TwinOgre").Code == "NotAvailable")
		end
	end)
	return passed
end
