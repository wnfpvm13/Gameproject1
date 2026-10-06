--!strict
-- Reconcile stale activity locks using server-owned location and travel state.
local Party = require(script.Parent.Parent.src.server.Services.PartyService)
local Activity = require(script.Parent.Parent.src.server.Services.PartyActivityService)

local function fixture(): any
	local sequence = 0
	return Party.new({
		MaxMembers = 4, InviteTTLSeconds = 30,
		Now = function(): number return 100 end,
		NewId = function(): string
			sequence += 1
			return "activity-test-" .. tostring(sequence)
		end,
	})
end

local function activeParty(service: any, memberIds: {number}): any
	local created = service:Create(memberIds[1], { Activity = "Restaurant", TargetId = "HostRestaurant" })
	for index = 2, #memberIds do service:JoinPublic(memberIds[index], created.PartyId) end
	local proposal = service:Propose(memberIds[1])
	for index = 2, #memberIds do service:Respond(memberIds[index], proposal.ProposalId, true) end
	service:Ready(memberIds[1], proposal.ProposalId)
	service:FinishProposal(memberIds[1], proposal.ProposalId)
	return service:SetStatus(memberIds[1], "InActivity")
end

local function reconcile(service: any, actorId: number, locations: {[number]: string},
	traveling: {[number]: boolean}?, present: {[number]: boolean}?): any
	return Activity.reconcile(service, actorId,
		function(userId: number): string return locations[userId] or "World" end,
		function(userId: number): boolean return traveling ~= nil and traveling[userId] == true end,
		function(userId: number): boolean return present == nil or present[userId] == true end)
end

return function(): number
	local passed = 0
	local function check(_name: string, callback: () -> ())
		callback()
		passed += 1
	end
	check("host-only Restaurant departure leaves STAY leader usable", function()
		local service = fixture()
		local created = service:Create(1, { Activity = "Restaurant", TargetId = "HostRestaurant" })
		service:JoinPublic(2, created.PartyId)
		local proposal = service:Propose(1)
		service:Respond(2, proposal.ProposalId, false)
		local selected = service:Ready(1, proposal.ProposalId)
		assert(#selected == 1 and selected[1] == 1)
		service:FinishProposal(1, proposal.ProposalId)
		service:SetStatus(1, "InActivity")
		assert(reconcile(service, 2, { [1] = "Restaurant", [2] = "World" }).Status == "InActivity")
		service:Leave(1)
		assert(service:Get(2).LeaderUserId == 2 and service:Get(2).Status == "InActivity")
		local recovered = reconcile(service, 2, { [1] = "Restaurant", [2] = "World" }, nil, { [2] = true })
		assert(recovered.Status == "Forming" and recovered.LeaderUserId == 2)
		assert(recovered.PartyId == created.PartyId and #recovered.MemberUserIds == 1)
		local nextProposal = service:Propose(2)
		assert(nextProposal.LeaderUserId == 2)
	end)
	check("Restaurant helper keeps party locked until every participant returns", function()
		local service = fixture()
		activeParty(service, { 1, 2, 3 })
		local locations = { [1] = "Restaurant", [2] = "Restaurant", [3] = "World" }
		assert(reconcile(service, 3, locations).Status == "InActivity")
		locations[1] = "World"
		assert(reconcile(service, 1, locations).Status == "InActivity")
		locations[2] = "World"
		assert(reconcile(service, 3, locations).Status == "Forming")
		assert(service:Propose(1).LeaderUserId == 1)
	end)
	check("Expedition location prevents premature activity unlock", function()
		local service = fixture()
		activeParty(service, { 1, 2 })
		assert(reconcile(service, 1, { [1] = "World", [2] = "Expedition" }).Status == "InActivity")
		assert(reconcile(service, 2, { [1] = "World", [2] = "World" }).Status == "Forming")
	end)
	check("World participant still traveling keeps activity locked", function()
		local service = fixture()
		activeParty(service, { 1, 2 })
		local moving = { [2] = true }
		assert(reconcile(service, 1, { [1] = "World", [2] = "World" }, moving).Status == "InActivity")
		moving[2] = false
		assert(reconcile(service, 2, { [1] = "World", [2] = "World" }, moving).Status == "Forming")
	end)
	check("absent members cannot hold locks with obsolete locations or travel flags", function()
		local service = fixture()
		activeParty(service, { 1, 2 })
		local observedAbsent = false
		local snapshot = Activity.reconcile(service, 1,
			function(userId: number): string
				if userId == 2 then observedAbsent = true; return "Restaurant" end
				return "World"
			end,
			function(userId: number): boolean
				if userId == 2 then observedAbsent = true; return true end
				return false
			end,
			function(userId: number): boolean return userId == 1 end)
		assert(snapshot ~= nil and snapshot.Status == "Forming" and not observedAbsent)
	end)
	check("missing party never inspects locations or travel state", function()
		local service = fixture()
		local function unused(): never error("No party should query a location callback") end
		assert(Activity.reconcile(service, 9, unused, unused, unused) == nil)
		service:Create(1)
		service:Leave(1)
		assert(Activity.reconcile(service, 1, unused, unused, unused) == nil)
	end)
	check("forming parties preserve new invitations", function()
		local service = fixture()
		service:Create(1)
		local invitation = service:Invite(1, 2)
		local function unused(): never error("Forming should not query an activity callback") end
		local snapshot = Activity.reconcile(service, 1, unused, unused, unused)
		assert(snapshot ~= nil and snapshot.Status == "Forming")
		assert(#service:GetInvites(2) == 1 and service:GetInvites(2)[1].InviteId == invitation.InviteId)
		assert(service:RespondInvite(2, invitation.InviteId, true).LeaderUserId == 1)
	end)
	check("new ReadyCheck consent and invitations survive reconciliation", function()
		local service = fixture()
		local created = service:Create(1)
		service:JoinPublic(2, created.PartyId)
		local invitation = service:Invite(1, 3)
		local proposal = service:Propose(1)
		service:Respond(2, proposal.ProposalId, false)
		local function unused(): never error("ReadyCheck should not query an activity callback") end
		local snapshot = Activity.reconcile(service, 2, unused, unused, unused)
		assert(snapshot ~= nil and snapshot.Status == "ReadyCheck" and snapshot.ProposalId == proposal.ProposalId)
		assert(snapshot.ReadyStates[2] == "Stayed")
		assert(#service:GetInvites(3) == 1 and service:GetInvites(3)[1].InviteId == invitation.InviteId)
		assert(service:GetProposal(1).Responses[2] == false)
	end)
	check("closed party remains closed", function()
		local service = fixture()
		service:Create(1)
		service:SetStatus(1, "Closed")
		local function unused(): never error("Closed should not query an activity callback") end
		local snapshot = Activity.reconcile(service, 1, unused, unused, unused)
		assert(snapshot ~= nil and snapshot.Status == "Closed" and service:Get(1).Status == "Closed")
	end)
	check("reconciliation is idempotent and returns independent snapshots", function()
		local service = fixture()
		local created = activeParty(service, { 1, 2 })
		local first = reconcile(service, 2, { [1] = "World", [2] = "World" })
		assert(first.Status == "Forming")
		first.MemberUserIds[1] = 99
		first.ReadyStates[2] = "Stayed"
		first.Visibility = "Private"
		local invitation = service:Invite(1, 3)
		local second = reconcile(service, 1, { [1] = "World", [2] = "World" })
		assert(second.PartyId == created.PartyId and second.MemberUserIds[1] == 1 and second.Visibility == "Public")
		assert(next(second.ReadyStates) == nil and second.Status == "Forming")
		assert(service:GetInvites(3)[1].InviteId == invitation.InviteId)
	end)
	check("callback-created newer proposal is not cleared by stale activity snapshot", function()
		local service = fixture()
		activeParty(service, { 1, 2 })
		local proposalId, invitationId = "", ""
		local changed = false
		local result = Activity.reconcile(service, 2,
			function(_userId: number): string
				if not changed then
					changed = true
					service:SetStatus(1, "Forming")
					invitationId = service:Invite(1, 3).InviteId
					proposalId = service:Propose(1).ProposalId
				end
				return "World"
			end,
			function(_userId: number): boolean return false end,
			function(_userId: number): boolean return true end)
		assert(result ~= nil and result.Status == "ReadyCheck" and result.ProposalId == proposalId)
		assert(service:Get(1).ProposalId == proposalId and service:GetInvites(3)[1].InviteId == invitationId)
	end)
	check("callback-added activity participant prevents stale membership unlock", function()
		local service = fixture()
		local created = activeParty(service, { 1, 2 })
		local changed = false
		local result = Activity.reconcile(service, 1,
			function(userId: number): string
				if not changed then
					changed = true
					service:SetStatus(1, "Forming")
					service:JoinPublic(3, created.PartyId)
					service:SetStatus(1, "InActivity")
				end
				return if userId == 3 then "Restaurant" else "World"
			end,
			function(_userId: number): boolean return false end,
			function(_userId: number): boolean return true end)
		assert(result ~= nil and result.Status == "InActivity" and #result.MemberUserIds == 3)
		assert(service:Get(3).Status == "InActivity")
	end)
	return passed
end
