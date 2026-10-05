--!strict
-- Pure logic tests: Roblox Player objects and live teleports are not exercised.
local Party = require(script.Parent.Parent.src.server.Services.PartyService)
local Teleport = require(script.Parent.Parent.src.server.Services.TeleportServiceWrapper)
local Fake = require(script.Parent.Parent.src.server.Services.FakeTeleport)

local function rejects(callback: () -> ())
	local ok = pcall(callback)
	assert(not ok, "Expected operation to reject")
end

local function party(maxMembers: number?): any
	local nextId = 0
	return Party.new({
		MaxMembers = maxMembers or 4,
		NewId = function(): string
			nextId += 1
			return "party-test-" .. tostring(nextId)
		end,
	})
end

local function wrapper(transport: any, log: ((string) -> ())?): any
	return Teleport.new({
		IsStudio = true, UseFakeTeleport = true,
		WorldPlaceId = 0, RestaurantPlaceId = 0,
		Transport = transport, Log = log,
	})
end

local function idsEqual(actual: {number}, expected: {number})
	assert(#actual == #expected, "Unexpected member count")
	for index, userId in expected do
		assert(actual[index] == userId, "Unexpected member order")
	end
end

local function payloadOnly(payload: any, sessionId: string, destination: string, attemptId: string?)
	assert(payload.SessionId == sessionId and payload.Destination == destination)
	assert(payload.AttemptId == attemptId)
	local count = 0
	for key in payload do
		assert(key == "SessionId" or key == "Destination" or (attemptId ~= nil and key == "AttemptId"),
			"Sensitive/unexpected teleport field")
		count += 1
	end
	assert(count == (if attemptId == nil then 2 else 3))
end

return function(): number
	local passed = 0
	local function check(_name: string, callback: () -> ())
		callback()
		passed += 1
	end
	check("bounded configured party size", function()
		local missingOptions: any = { NewId = function() return "id" end }
		rejects(function() Party.new(missingOptions) end)
		for _, invalid in { 0, 5, 1.5, math.huge, 0 / 0 } do
			rejects(function() party(invalid) end)
		end
		local one = party(1)
		local created = one:Create(1)
		rejects(function() one:Join(2, created.PartyId) end)
		local four = party()
		local full = four:Create(1)
		for userId = 2, 4 do four:Join(userId, full.PartyId) end
		idsEqual(four:Get(4).MemberUserIds, { 1, 2, 3, 4 })
		rejects(function() four:Join(5, full.PartyId) end)
	end)
	check("signed Studio IDs and invalid user IDs", function()
		local service = party()
		local created = service:Create(-1)
		service:Join(-2, created.PartyId)
		idsEqual(service:Get(-2).MemberUserIds, { -1, -2 })
		for _, invalid in { 0, 0.5, math.huge, -math.huge, 0 / 0 } do
			rejects(function() service:Create(invalid) end)
			rejects(function() service:Join(invalid, created.PartyId) end)
		end
		rejects(function() service:Create("1") end)
		rejects(function() service:Join({}, created.PartyId) end)
	end)
	check("duplicate membership cannot cross parties", function()
		local service = party()
		local first, second = service:Create(1), service:Create(2)
		service:Join(3, first.PartyId)
		rejects(function() service:Create(1) end)
		rejects(function() service:Join(3, first.PartyId) end)
		rejects(function() service:Join(3, second.PartyId) end)
		rejects(function() service:Join(4, "missing-party") end)
		idsEqual(service:Get(3).MemberUserIds, { 1, 3 })
		idsEqual(service:Get(2).MemberUserIds, { 2 })
	end)
	check("party snapshots cannot mutate membership or authority", function()
		local service = party()
		local created = service:Create(1)
		service:Join(2, created.PartyId)
		created.MemberUserIds[1] = 99
		created.LeaderUserId = 99
		local snapshot = service:Get(2)
		snapshot.MemberUserIds[2] = 99
		snapshot.PartyId = "tampered"
		local unchanged = service:Get(1)
		assert(unchanged.LeaderUserId == 1 and unchanged.PartyId ~= "tampered")
		idsEqual(unchanged.MemberUserIds, { 1, 2 })
	end)
	check("leader departure transfers to first remaining member", function()
		local service = party()
		local created = service:Create(1)
		service:Join(3, created.PartyId)
		service:Join(2, created.PartyId)
		service:Leave(1)
		local transferred = service:Get(2)
		assert(transferred.LeaderUserId == 3)
		idsEqual(transferred.MemberUserIds, { 3, 2 })
		service:Leave(3)
		assert(service:Get(2).LeaderUserId == 2)
		service:Leave(2)
		service:Create(2)
	end)
	check("solo leader can consent and finish proposal", function()
		local service = party()
		service:Create(1)
		local proposal = service:Propose(1)
		assert(proposal.Responses[1] == true and proposal.LeaderUserId == 1)
		idsEqual(service:Ready(1, proposal.ProposalId), { 1 })
		service:FinishProposal(1, proposal.ProposalId)
		rejects(function() service:Ready(1, proposal.ProposalId) end)
		assert(service:Get(1).ProposalId == nil)
	end)
	check("all invitees choose JOIN or STAY before teleport", function()
		local service = party()
		local created = service:Create(1)
		service:Join(2, created.PartyId)
		service:Join(3, created.PartyId)
		service:Join(4, created.PartyId)
		local proposal = service:Propose(1)
		rejects(function() service:Ready(1, proposal.ProposalId) end)
		service:Respond(2, proposal.ProposalId, true)
		service:Respond(3, proposal.ProposalId, false)
		rejects(function() service:Ready(1, proposal.ProposalId) end)
		service:Respond(4, proposal.ProposalId, true)
		idsEqual(service:Ready(1, proposal.ProposalId), { 1, 2, 4 })
		idsEqual(service:Get(3).MemberUserIds, { 1, 2, 3, 4 })
	end)
	check("proposal authority and consent validation", function()
		local service = party()
		local created = service:Create(1)
		service:Join(2, created.PartyId)
		rejects(function() service:Propose(2) end)
		local proposal = service:Propose(1)
		rejects(function() service:Respond(3, proposal.ProposalId, true) end)
		rejects(function() service:Respond(2, "stale", true) end)
		rejects(function() service:Respond(2, proposal.ProposalId, "JOIN") end)
		service:Respond(2, proposal.ProposalId, true)
		rejects(function() service:Ready(2, proposal.ProposalId) end)
		rejects(function() service:FinishProposal(2, proposal.ProposalId) end)
		idsEqual(service:Ready(1, proposal.ProposalId), { 1, 2 })
	end)
	check("proposal snapshots preserve consent and member list", function()
		local service = party()
		local created = service:Create(1)
		service:Join(2, created.PartyId)
		assert(service:GetProposal(2) == nil and service:GetProposal(3) == nil)
		local proposal = service:Propose(1)
		local fetched = service:GetProposal(2)
		assert(fetched.ProposalId == proposal.ProposalId)
		fetched.Responses[2] = true
		fetched.MemberUserIds[2] = 3
		proposal.Responses[2] = true
		proposal.MemberUserIds[2] = 3
		rejects(function() service:Ready(1, proposal.ProposalId) end)
		local response = service:Respond(2, proposal.ProposalId, false)
		response.Responses[2] = true
		idsEqual(service:Ready(1, proposal.ProposalId), { 1 })
	end)
	check("membership changes invalidate pending proposals", function()
		local service = party()
		local created = service:Create(1)
		service:Join(2, created.PartyId)
		local first = service:Propose(1)
		service:Join(3, created.PartyId)
		rejects(function() service:Respond(2, first.ProposalId, true) end)
		rejects(function() service:Ready(1, first.ProposalId) end)
		assert(service:Get(1).ProposalId == nil)
		assert(service:GetProposal(2) == nil)
		local second = service:Propose(1)
		service:Leave(3)
		rejects(function() service:Respond(2, second.ProposalId, true) end)
		assert(service:Get(1).ProposalId == nil)
		local third = service:Propose(1)
		service:Leave(1)
		rejects(function() service:Ready(2, third.ProposalId) end)
		assert(service:Get(2).LeaderUserId == 2)
	end)
	check("fake reservations and minimal teleport identifiers", function()
		local transport = Fake.new()
		local service = wrapper(transport)
		local reservation = service:ReserveRestaurant()
		assert(string.find(reservation.AccessCode, "FAKE", 1, true) ~= nil)
		assert(string.find(reservation.PrivateServerId, "FAKE", 1, true) ~= nil)
		local players = { { UserId = 1 }, { UserId = 2 } }
		service:ToRestaurant(players, "session-1", reservation)
		service:ToWorld(players, "session-1")
		local calls = transport:GetCalls()
		assert(#calls == 3 and calls[1].Operation == "Reserve" and calls[1].PlaceId == 0)
		assert(calls[2].Operation == "Send" and #calls[2].Players == 2)
		assert(calls[2].AccessCode == reservation.AccessCode)
		payloadOnly(calls[2].Payload, "session-1", "Restaurant")
		payloadOnly(calls[3].Payload, "session-1", "World")
		assert(calls[3].AccessCode == nil)
	end)
	check("fake call snapshots and unique reservations", function()
		local transport = Fake.new()
		local firstCode, firstPrivate = transport:Reserve(0)
		local secondCode, secondPrivate = transport:Reserve(0)
		assert(firstCode ~= secondCode and firstPrivate ~= secondPrivate)
		local players = { { UserId = 1 } }
		local payload = { SessionId = "session", Destination = "World" }
		transport:Send(0, players, payload)
		payload.SessionId = "tampered"
		players[1] = { UserId = 99 }
		local snapshot = transport:GetCalls()
		assert(snapshot[3].Payload.SessionId == "session")
		snapshot[3].Payload.SessionId = "mutated snapshot"
		snapshot[3].Players[1] = { UserId = 99 }
		assert(transport:GetCalls()[3].Payload.SessionId == "session")
		assert(transport:GetCalls()[3].Players[1].UserId == 1)
	end)
	check("optional attempt identity correlates each teleport without economic payload", function()
		local transport = Fake.new()
		local service = wrapper(transport)
		local reservation = service:ReserveRestaurant()
		local players = { { UserId = 1 } }
		service:ToRestaurant(players, "session", reservation, "restaurant-attempt")
		service:ToWorld(players, "session", "world-attempt")
		local calls = transport:GetCalls()
		payloadOnly(calls[2].Payload, "session", "Restaurant", "restaurant-attempt")
		payloadOnly(calls[3].Payload, "session", "World", "world-attempt")
		for _, invalid: any in { "", string.rep("x", 129), 123, false } do
			rejects(function() service:ToRestaurant(players, "session", reservation, invalid) end)
			rejects(function() service:ToWorld(players, "session", invalid) end)
		end
		assert(#transport:GetCalls() == 3, "invalid attempt IDs must not reach transport")
	end)
	check("fake failures log and consume exactly one operation", function()
		local transport = Fake.new()
		local messages: {string} = {}
		local service = wrapper(transport, function(message: string) table.insert(messages, message) end)
		transport:FailNext("reserve failure")
		rejects(function() service:ReserveRestaurant() end)
		assert(#transport:GetCalls() == 1 and #messages == 1)
		assert(string.find(messages[1], "reserve failure", 1, true) ~= nil)
		local reservation = service:ReserveRestaurant()
		transport:FailNext("send failure")
		rejects(function() service:ToRestaurant({ { UserId = 1 } }, "session", reservation) end)
		assert(#transport:GetCalls() == 3 and #messages == 2)
		assert(string.find(messages[2], "send failure", 1, true) ~= nil)
		service:ToWorld({ { UserId = 1 } }, "session")
		assert(#transport:GetCalls() == 4 and #messages == 2)
	end)
	check("fake teleport is confined to enabled Studio mode", function()
		for _, flags in { { false, false }, { false, true }, { true, false } } do
			rejects(function()
				Teleport.new({ IsStudio = flags[1], UseFakeTeleport = flags[2],
					WorldPlaceId = 1, RestaurantPlaceId = 2, Transport = Fake.new() })
			end)
		end
	end)
	check("published place IDs are positive finite integers", function()
		local transport = {
			Reserve = function(_self: any, _placeId: number): (string, string) return "real-code", "real-private" end,
			Send = function(_self: any, _placeId: number, _players: any, _payload: any, _accessCode: string?) end,
		}
		for _, invalid in { 0, -1, 1.5, math.huge, 0 / 0 } do
			for _, field in { "WorldPlaceId", "RestaurantPlaceId" } do
				local config: any = { IsStudio = false, UseFakeTeleport = false,
					WorldPlaceId = 1, RestaurantPlaceId = 2, Transport = transport }
				config[field] = invalid
				rejects(function() Teleport.new(config) end)
			end
		end
		local service = Teleport.new({ IsStudio = false, UseFakeTeleport = false,
			WorldPlaceId = 1, RestaurantPlaceId = 2, Transport = transport })
		local reservation = service:ReserveRestaurant()
		assert(reservation.AccessCode == "real-code" and reservation.PrivateServerId == "real-private")
	end)
	return passed
end
