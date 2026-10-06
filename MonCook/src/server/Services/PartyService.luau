--!strict
-- Pure server authority: callers supply the authenticated user ID, never a
-- client-selected actor. Membership edits invalidate outstanding consent.
export type PartySnapshot = {
	PartyId: string,
	LeaderUserId: number,
	MemberUserIds: { number },
	ProposalId: string?,
	MaxMembers: number,
	Visibility: string,
	Activity: string,
	TargetId: string,
	Status: string,
	ReadyStates: { [number]: string },
}

export type ProposalSnapshot = {
	ProposalId: string,
	PartyId: string,
	LeaderUserId: number,
	MemberUserIds: { number },
	Responses: { [number]: boolean },
}

export type Options = {
	NewId: () -> string,
	MaxMembers: number,
	Now: (() -> number)?,
	InviteTTLSeconds: number?,
	ValidActivityTarget: ((string, string) -> boolean)?,
}

export type Settings = { Visibility: string?, Activity: string?, TargetId: string? }
export type InviteSnapshot = {
	InviteId: string,
	PartyId: string,
	LeaderUserId: number,
	TargetUserId: number,
	ExpiresAt: number,
}

local PartyService = {}
PartyService.__index = PartyService

local function validateUserId(userId: number)
	-- Studio multi-client test players may use negative IDs.
	assert(type(userId) == "number" and userId == math.floor(userId)
		and userId ~= 0 and math.abs(userId) < math.huge, "invalid user ID")
end

local function copyMembers(members: { number }): { number }
	local result: { number } = {}
	for _, userId in members do table.insert(result, userId) end
	return result
end

local function partySnapshot(party: PartySnapshot): PartySnapshot
	local readyStates: { [number]: string } = {}
	for userId, state in party.ReadyStates do readyStates[userId] = state end
	return {
		PartyId = party.PartyId,
		LeaderUserId = party.LeaderUserId,
		MemberUserIds = copyMembers(party.MemberUserIds),
		ProposalId = party.ProposalId,
		MaxMembers = party.MaxMembers,
		Visibility = party.Visibility,
		Activity = party.Activity,
		TargetId = party.TargetId,
		Status = party.Status,
		ReadyStates = readyStates,
	}
end

local function proposalSnapshot(proposal: ProposalSnapshot): ProposalSnapshot
	local responses: { [number]: boolean } = {}
	for userId, joined in proposal.Responses do responses[userId] = joined end
	return {
		ProposalId = proposal.ProposalId,
		PartyId = proposal.PartyId,
		LeaderUserId = proposal.LeaderUserId,
		MemberUserIds = copyMembers(proposal.MemberUserIds),
		Responses = responses,
	}
end

local function issueId(self: any): string
	local id = self._newId()
	assert(type(id) == "string" and #id > 0, "NewId must return a nonempty string")
	assert(not self._issuedIds[id], "NewId returned an already issued ID")
	self._issuedIds[id] = true
	return id
end

local function cancelProposal(self: any, party: PartySnapshot)
	if party.ProposalId then
		self._proposals[party.ProposalId] = nil
		party.ProposalId = nil
	end
	party.ReadyStates = {}
	if party.Status == "ReadyCheck" then party.Status = "Forming" end
end

local function mutableParty(party: PartySnapshot)
	assert(party.Status ~= "InActivity" and party.Status ~= "Closed", "party activity is locked")
end

local function visibilityValid(visibility: string)
	assert(visibility == "Public" or visibility == "Private", "invalid party visibility")
end

local function activityTargetValid(self: any, activity: string, targetId: string)
	assert(activity == "Free" or activity == "SharedHunt" or activity == "Expedition" or activity == "Restaurant",
		"invalid party activity")
	assert(type(targetId) == "string" and #targetId > 0 and #targetId <= 128, "invalid activity target")
	local validator: ((string, string) -> boolean)? = self._validActivityTarget
	if validator ~= nil then
		assert(validator(activity, targetId) == true, "unknown activity target")
	end
end

local function inviteSnapshot(invite: InviteSnapshot): InviteSnapshot
	return {
		InviteId = invite.InviteId, PartyId = invite.PartyId,
		LeaderUserId = invite.LeaderUserId, TargetUserId = invite.TargetUserId,
		ExpiresAt = invite.ExpiresAt,
	}
end

local function clearPartyInvites(self: any, partyId: string)
	for inviteId, invite in self._invites do
		if invite.PartyId == partyId then self._invites[inviteId] = nil end
	end
end

local function clearTargetInvites(self: any, userId: number)
	for inviteId, invite in self._invites do
		if invite.TargetUserId == userId then self._invites[inviteId] = nil end
	end
end

local function currentTime(self: any): number
	local now = self._now()
	assert(type(now) == "number" and now >= 0 and now < math.huge, "invalid invite clock")
	return now
end

local function pruneInvites(self: any, now: number)
	for inviteId, invite in self._invites do
		local party = self._parties[invite.PartyId]
		if now >= invite.ExpiresAt or party == nil or party.LeaderUserId ~= invite.LeaderUserId
			or party.Status == "InActivity" or party.Status == "Closed"
			or self._membership[invite.TargetUserId] ~= nil then
			self._invites[inviteId] = nil
		end
	end
end

local function joinParty(self: any, userId: number, party: PartySnapshot): PartySnapshot
	validateUserId(userId)
	assert(self._membership[userId] == nil, "user already in a party")
	mutableParty(party)
	assert(#party.MemberUserIds < party.MaxMembers, "party is full")
	cancelProposal(self, party)
	table.insert(party.MemberUserIds, userId)
	self._membership[userId] = party.PartyId
	clearTargetInvites(self, userId)
	return partySnapshot(party)
end

local function requireLeaderParty(self: any, userId: number): PartySnapshot
	validateUserId(userId)
	local partyId = self._membership[userId]
	assert(partyId ~= nil, "user is not in a party")
	local party: PartySnapshot = self._parties[partyId]
	assert(party.LeaderUserId == userId, "party leader required")
	return party
end

local function requireProposal(self: any, proposalId: string): ProposalSnapshot
	assert(type(proposalId) == "string" and #proposalId > 0, "invalid proposal ID")
	local proposal: ProposalSnapshot? = self._proposals[proposalId]
	assert(proposal ~= nil, "proposal is stale or missing")
	return proposal
end

local function requireLeaderProposal(self: any, leaderId: number, proposalId: string): ProposalSnapshot
	local party = requireLeaderParty(self, leaderId)
	local proposal = requireProposal(self, proposalId)
	assert(proposal.PartyId == party.PartyId and party.ProposalId == proposalId,
		"proposal does not belong to this party")
	return proposal
end

function PartyService.new(options: Options)
	assert(type(options) == "table" and type(options.NewId) == "function", "NewId required")
	assert(type(options.MaxMembers) == "number" and options.MaxMembers == math.floor(options.MaxMembers)
		and options.MaxMembers >= 1 and options.MaxMembers <= 4, "MaxMembers must be between 1 and 4")
	assert(options.Now == nil or type(options.Now) == "function", "Now must be a function")
	assert(options.InviteTTLSeconds == nil or (type(options.InviteTTLSeconds) == "number"
		and options.InviteTTLSeconds > 0 and options.InviteTTLSeconds < math.huge), "invalid InviteTTLSeconds")
	assert(options.ValidActivityTarget == nil or type(options.ValidActivityTarget) == "function",
		"ValidActivityTarget must be a function")
	return setmetatable({
		_newId = options.NewId,
		_maxMembers = options.MaxMembers,
		_parties = {} :: { [string]: PartySnapshot },
		_membership = {} :: { [number]: string },
		_proposals = {} :: { [string]: ProposalSnapshot },
		_issuedIds = {} :: { [string]: boolean },
		_invites = {} :: { [string]: InviteSnapshot },
		_now = options.Now or os.clock,
		_inviteTTL = options.InviteTTLSeconds,
		_validActivityTarget = options.ValidActivityTarget,
	}, PartyService)
end

function PartyService.Create(self: any, userId: number, settings: Settings?): PartySnapshot
	validateUserId(userId)
	assert(self._membership[userId] == nil, "user already in a party")
	assert(settings == nil or type(settings) == "table", "invalid party settings")
	local chosen: Settings = settings or {}
	for key in chosen :: any do
		assert(key == "Visibility" or key == "Activity" or key == "TargetId", "unknown party setting")
	end
	local visibility = if chosen.Visibility == nil then "Public" else chosen.Visibility
	local activity = if chosen.Activity == nil then "Free" else chosen.Activity
	local targetId = if chosen.TargetId == nil then "Free" else chosen.TargetId
	visibilityValid(visibility)
	activityTargetValid(self, activity, targetId)
	local party: PartySnapshot = {
		PartyId = issueId(self),
		LeaderUserId = userId,
		MemberUserIds = { userId },
		MaxMembers = self._maxMembers,
		Visibility = visibility,
		Activity = activity,
		TargetId = targetId,
		Status = "Forming",
		ReadyStates = {},
	}
	self._parties[party.PartyId] = party
	self._membership[userId] = party.PartyId
	clearTargetInvites(self, userId)
	return partySnapshot(party)
end

function PartyService.Join(self: any, userId: number, partyId: string): PartySnapshot
	-- Even the legacy/debug ID path cannot bypass Private invite authority.
	return self:JoinPublic(userId, partyId)
end

function PartyService.JoinPublic(self: any, userId: number, partyId: string): PartySnapshot
	validateUserId(userId)
	assert(type(partyId) == "string", "invalid party ID")
	local party: PartySnapshot? = self._parties[partyId]
	assert(party ~= nil, "party is missing")
	assert(party.Visibility == "Public", "Private party requires an invitation")
	return joinParty(self, userId, party)
end

function PartyService.ListPublic(self: any): { PartySnapshot }
	local listed: { PartySnapshot } = {}
	for _, party in self._parties do
		if party.Visibility == "Public" and party.Status ~= "Closed" then
			table.insert(listed, partySnapshot(party))
		end
	end
	table.sort(listed, function(left: PartySnapshot, right: PartySnapshot): boolean
		return left.PartyId < right.PartyId
	end)
	return listed
end

function PartyService.Leave(self: any, userId: number): PartySnapshot?
	validateUserId(userId)
	local partyId: string? = self._membership[userId]
	if partyId == nil then return nil end
	local party: PartySnapshot = self._parties[partyId]
	cancelProposal(self, party)
	self._membership[userId] = nil
	local index = table.find(party.MemberUserIds, userId)
	assert(index ~= nil, "party membership invariant failed")
	table.remove(party.MemberUserIds, index)
	if #party.MemberUserIds == 0 then
		clearPartyInvites(self, partyId)
		self._parties[partyId] = nil
		return nil
	end
	if party.LeaderUserId == userId then
		clearPartyInvites(self, partyId)
		party.LeaderUserId = party.MemberUserIds[1]
	end
	return partySnapshot(party)
end

function PartyService.Get(self: any, userId: number): PartySnapshot?
	validateUserId(userId)
	local partyId = self._membership[userId]
	if partyId == nil then return nil end
	return partySnapshot(self._parties[partyId])
end

function PartyService.GetProposal(self: any, userId: number): ProposalSnapshot?
	validateUserId(userId)
	local partyId = self._membership[userId]
	if partyId == nil then return nil end
	local party: PartySnapshot = self._parties[partyId]
	if party.ProposalId == nil then return nil end
	return proposalSnapshot(self._proposals[party.ProposalId])
end

function PartyService.Propose(self: any, leaderId: number): ProposalSnapshot
	local party = requireLeaderParty(self, leaderId)
	mutableParty(party)
	assert(party.ProposalId == nil, "proposal already active")
	local proposal: ProposalSnapshot = {
		ProposalId = issueId(self),
		PartyId = party.PartyId,
		LeaderUserId = leaderId,
		MemberUserIds = copyMembers(party.MemberUserIds),
		Responses = { [leaderId] = true },
	}
	party.ProposalId = proposal.ProposalId
	party.Status = "ReadyCheck"
	party.ReadyStates = {}
	for _, userId in party.MemberUserIds do
		party.ReadyStates[userId] = if userId == leaderId then "Joined" else "Waiting"
	end
	self._proposals[proposal.ProposalId] = proposal
	return proposalSnapshot(proposal)
end

function PartyService.Respond(self: any, userId: number, proposalId: string, join: boolean): ProposalSnapshot
	validateUserId(userId)
	assert(type(join) == "boolean", "JOIN or STAY response must be boolean")
	local proposal = requireProposal(self, proposalId)
	assert(self._membership[userId] == proposal.PartyId
		and table.find(proposal.MemberUserIds, userId) ~= nil, "user is not an invited party member")
	assert(userId ~= proposal.LeaderUserId or join, "party leader cannot STAY on their own proposal")
	proposal.Responses[userId] = join
	self._parties[proposal.PartyId].ReadyStates[userId] = if join then "Joined" else "Stayed"
	return proposalSnapshot(proposal)
end

function PartyService.Ready(self: any, leaderId: number, proposalId: string): { number }
	local proposal = requireLeaderProposal(self, leaderId, proposalId)
	local selected: { number } = {}
	for _, userId in proposal.MemberUserIds do
		assert(proposal.Responses[userId] ~= nil, "proposal has pending responses")
		if proposal.Responses[userId] then table.insert(selected, userId) end
	end
	return selected
end

function PartyService.FinishProposal(self: any, leaderId: number, proposalId: string)
	local proposal = requireLeaderProposal(self, leaderId, proposalId)
	cancelProposal(self, self._parties[proposal.PartyId])
end

function PartyService.SetVisibility(self: any, leaderId: number, visibility: string): PartySnapshot
	local party = requireLeaderParty(self, leaderId)
	mutableParty(party)
	visibilityValid(visibility)
	cancelProposal(self, party)
	clearPartyInvites(self, party.PartyId)
	party.Visibility = visibility
	return partySnapshot(party)
end

function PartyService.SetActivity(self: any, leaderId: number, activity: string, targetId: string): PartySnapshot
	local party = requireLeaderParty(self, leaderId)
	mutableParty(party)
	activityTargetValid(self, activity, targetId)
	cancelProposal(self, party)
	clearPartyInvites(self, party.PartyId)
	party.Activity = activity
	party.TargetId = targetId
	return partySnapshot(party)
end

function PartyService.Invite(self: any, leaderId: number, targetUserId: number): InviteSnapshot
	local party = requireLeaderParty(self, leaderId)
	mutableParty(party)
	validateUserId(targetUserId)
	assert(self._membership[targetUserId] == nil, "user already in a party")
	assert(#party.MemberUserIds < party.MaxMembers, "party is full")
	assert(self._inviteTTL ~= nil, "InviteTTLSeconds configuration required")
	local now = currentTime(self)
	pruneInvites(self, now)
	for _, invite in self._invites do
		assert(invite.PartyId ~= party.PartyId or invite.TargetUserId ~= targetUserId,
			"invitation already pending")
	end
	local invite: InviteSnapshot = {
		InviteId = issueId(self), PartyId = party.PartyId,
		LeaderUserId = party.LeaderUserId, TargetUserId = targetUserId,
		ExpiresAt = now + self._inviteTTL,
	}
	assert(invite.ExpiresAt < math.huge, "invalid invite expiry")
	self._invites[invite.InviteId] = invite
	return inviteSnapshot(invite)
end

function PartyService.GetInvites(self: any, userId: number): { InviteSnapshot }
	validateUserId(userId)
	pruneInvites(self, currentTime(self))
	local invitations: { InviteSnapshot } = {}
	for _, invite in self._invites do
		if invite.TargetUserId == userId then table.insert(invitations, inviteSnapshot(invite)) end
	end
	table.sort(invitations, function(left: InviteSnapshot, right: InviteSnapshot): boolean
		return left.InviteId < right.InviteId
	end)
	return invitations
end

function PartyService.RespondInvite(self: any, userId: number, inviteId: string, accept: boolean): PartySnapshot?
	validateUserId(userId)
	assert(type(inviteId) == "string" and #inviteId > 0, "invalid invitation ID")
	assert(type(accept) == "boolean", "invitation response must be boolean")
	pruneInvites(self, currentTime(self))
	local invite: InviteSnapshot? = self._invites[inviteId]
	assert(invite ~= nil, "invitation is stale or expired")
	assert(invite.TargetUserId == userId, "invitation target required")
	if not accept then
		self._invites[inviteId] = nil
		return nil
	end
	local party: PartySnapshot? = self._parties[invite.PartyId]
	assert(party ~= nil and party.LeaderUserId == invite.LeaderUserId, "invitation is stale")
	return joinParty(self, userId, party)
end

function PartyService.SetStatus(self: any, leaderId: number, status: string): PartySnapshot
	-- Runtime coordinator owns this transition; clients send activity intents.
	local party = requireLeaderParty(self, leaderId)
	assert(status == "Forming" or status == "ReadyCheck" or status == "InActivity" or status == "Closed",
		"invalid party status")
	if status == "ReadyCheck" then
		assert(party.ProposalId ~= nil, "ReadyCheck requires a proposal")
	else
		cancelProposal(self, party)
		clearPartyInvites(self, party.PartyId)
	end
	party.Status = status
	return partySnapshot(party)
end

return PartyService
