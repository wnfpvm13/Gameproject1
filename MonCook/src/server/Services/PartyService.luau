--!strict
-- Pure server authority: callers supply the authenticated user ID, never a
-- client-selected actor. Membership edits invalidate outstanding consent.
export type PartySnapshot = {
	PartyId: string,
	LeaderUserId: number,
	MemberUserIds: { number },
	ProposalId: string?,
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
	return {
		PartyId = party.PartyId,
		LeaderUserId = party.LeaderUserId,
		MemberUserIds = copyMembers(party.MemberUserIds),
		ProposalId = party.ProposalId,
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
	return setmetatable({
		_newId = options.NewId,
		_maxMembers = options.MaxMembers,
		_parties = {} :: { [string]: PartySnapshot },
		_membership = {} :: { [number]: string },
		_proposals = {} :: { [string]: ProposalSnapshot },
		_issuedIds = {} :: { [string]: boolean },
	}, PartyService)
end

function PartyService.Create(self: any, userId: number): PartySnapshot
	validateUserId(userId)
	assert(self._membership[userId] == nil, "user already in a party")
	local party: PartySnapshot = {
		PartyId = issueId(self),
		LeaderUserId = userId,
		MemberUserIds = { userId },
	}
	self._parties[party.PartyId] = party
	self._membership[userId] = party.PartyId
	return partySnapshot(party)
end

function PartyService.Join(self: any, userId: number, partyId: string): PartySnapshot
	validateUserId(userId)
	assert(type(partyId) == "string", "invalid party ID")
	assert(self._membership[userId] == nil, "user already in a party")
	local party: PartySnapshot? = self._parties[partyId]
	assert(party ~= nil, "party is missing")
	assert(#party.MemberUserIds < self._maxMembers, "party is full")
	cancelProposal(self, party)
	table.insert(party.MemberUserIds, userId)
	self._membership[userId] = partyId
	return partySnapshot(party)
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
		self._parties[partyId] = nil
		return nil
	end
	if party.LeaderUserId == userId then party.LeaderUserId = party.MemberUserIds[1] end
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
	assert(party.ProposalId == nil, "proposal already active")
	local proposal: ProposalSnapshot = {
		ProposalId = issueId(self),
		PartyId = party.PartyId,
		LeaderUserId = leaderId,
		MemberUserIds = copyMembers(party.MemberUserIds),
		Responses = { [leaderId] = true },
	}
	party.ProposalId = proposal.ProposalId
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

return PartyService
