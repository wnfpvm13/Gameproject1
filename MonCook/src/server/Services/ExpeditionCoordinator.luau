--!strict
-- Studio-only activity orchestration. No combat, loot or PlayerData mutations;
-- a published destination cannot import these in-memory sessions yet.
local Coordinator = {}
Coordinator.__index = Coordinator

function Coordinator.new(options: any): any
	assert(type(options.NewId) == "function", "expedition attempt ID provider required")
	return setmetatable({
		Data = options.Data, Party = options.Party, Expeditions = options.Expeditions,
		Teleport = options.Teleport, IsFake = options.IsFake, NewId = options.NewId,
		IsOtherTraveling = options.IsOtherTraveling, OtherLocation = options.OtherLocation,
		Log = options.Log, _busy = {}, _locations = {}, _partyJobs = {},
	}, Coordinator)
end

function Coordinator.IsTraveling(self: any, userId: number): boolean
	return self._busy[userId] ~= nil
end

function Coordinator.GetForMember(self: any, userId: number): any
	return self.Expeditions:GetForMember(userId)
end

function Coordinator.Location(self: any, userId: number): string
	return self._locations[userId] or "World"
end

function Coordinator._studio(self: any)
	assert(self.IsFake == true, "expedition entry is available only in Studio fake mode")
end

function Coordinator._log(self: any, message: string)
	if self.Log then pcall(self.Log, message) end
end

function Coordinator._otherAvailable(self: any, userId: number, requireWorld: boolean)
	local isOtherTraveling: any = self.IsOtherTraveling
	assert(isOtherTraveling == nil or not (isOtherTraveling :: (number) -> boolean)(userId), "member is traveling in another activity")
	if requireWorld then
		local otherLocation: any = self.OtherLocation
		assert(otherLocation == nil or (otherLocation :: (number) -> string)(userId) == "World", "member must return to World before expedition entry")
	end
end

function Coordinator._reload(self: any, members: { number }, lookup: (number) -> any, job: any, allowIdle: boolean?)
	for _, id in members do
		local busy = self._busy[id]
		local current = self.Expeditions:GetForMember(id)
		local owned = self._partyJobs[job.PartyId] == job
			and (busy == job or (allowIdle == true and busy == nil))
			and (current == nil or current.SessionId == job.SessionId)
		if owned and lookup(id) and not self.Data:HasProfile(id) then
			local ok, reason = pcall(function() self.Data:Load(id) end)
			if not ok then self:_log("Expedition profile recovery: " .. tostring(reason)) end
		end
	end
end

function Coordinator._clear(self: any, job: any)
	for _, id in job.Members do
		if self._busy[id] == job then self._busy[id] = nil end
	end
end

function Coordinator._forming(self: any, job: any, allowIdle: boolean?)
	-- A suspended operation can resume after disconnect recovery and a fresh
	-- activity. Party identity alone cannot authorize cleanup of that new state.
	if self._partyJobs[job.PartyId] ~= job then return end
	local ownsBusy = false
	for _, id in job.Members do if self._busy[id] == job then ownsBusy = true end end
	if not ownsBusy and allowIdle ~= true then return end
	for _, id in job.Members do
		local party = self.Party:Get(id)
		if party and party.PartyId == job.PartyId then
			if party.ProposalId ~= nil then
				if party.ProposalId ~= job.ProposalId then return end
			elseif not job.EnteredActivity or party.Status ~= "InActivity" then
				return
			end
			for _, member in party.MemberUserIds do
				local current = self.Expeditions:GetForMember(member)
				if current and current.SessionId ~= job.SessionId then return end
			end
			self.Party:SetStatus(party.LeaderUserId, "Forming")
			return
		end
	end
end

function Coordinator._connected(self: any, job: any, lookup: (number) -> any)
	assert(not job.Cancelled, "expedition operation was cancelled")
	for _, id in job.Members do
		assert(self._busy[id] == job and lookup(id), "expedition party changed during preparation")
		self:_otherAvailable(id, job.Kind == "Start")
	end
end

function Coordinator._consent(self: any, job: any, proposalId: string, targetId: string, lookup: (number) -> any)
	self:_connected(job, lookup)
	local party = self.Party:Get(job.HostId)
	assert(party and party.PartyId == job.PartyId and party.Activity == "Expedition"
		and party.TargetId == targetId, "expedition activity changed during preparation")
	local current = self.Party:Ready(job.HostId, proposalId)
	assert(#current == #job.Members, "expedition consent changed during preparation")
	for index, id in job.Members do
		assert(current[index] == id, "expedition consent changed during preparation")
	end
end

function Coordinator.Start(self: any, hostId: number, proposalId: string, regionId: string, targetId: string, lookup: (number) -> any): any
	self:_studio()
	local party = self.Party:Get(hostId)
	assert(party and party.LeaderUserId == hostId and party.Activity == "Expedition"
		and party.TargetId == targetId, "matching expedition party and host required")
	local members = self.Party:Ready(hostId, proposalId)
	local players = {}
	for _, id in members do
		assert(not self:IsTraveling(id), "expedition member is already traveling")
		self:_otherAvailable(id, true)
		assert(self.Data:HasProfile(id) and lookup(id), "expedition member profile is not ready")
		table.insert(players, lookup(id))
	end
	local job = { HostId = hostId, PartyId = party.PartyId, Members = members,
		Kind = "Start", AttemptId = self.NewId(), ProposalId = proposalId,
		EnteredActivity = false, Cancelled = false }
	self._partyJobs[party.PartyId] = job
	for _, id in members do self._busy[id] = job end
	local session
	local ok, reason = pcall(function()
		session = self.Expeditions:Prepare(hostId, party.PartyId, members, regionId, targetId)
		job.SessionId = session.SessionId
		local reservation = self.Teleport:ReserveExpedition(regionId)
		self:_consent(job, proposalId, targetId, lookup)
		session = self.Expeditions:MarkTeleporting(hostId, session.SessionId, reservation.PrivateServerId)
		self:_consent(job, proposalId, targetId, lookup)
		self.Party:FinishProposal(hostId, proposalId)
		self.Party:SetStatus(hostId, "InActivity")
		job.EnteredActivity = true
		for _, id in members do
			self:_connected(job, lookup)
			self.Data:Release(id)
		end
		self:_connected(job, lookup)
		self.Teleport:ToExpedition(players, session.SessionId, regionId, reservation, job.AttemptId)
		self:_connected(job, lookup)
		for _, id in members do self.Data:Load(id) end
		self:_connected(job, lookup)
		session = self.Expeditions:Activate(hostId, session.SessionId, reservation.PrivateServerId)
		for _, id in members do self._locations[id] = "Expedition" end
	end)
	if not ok then
		self:_reload(members, lookup, job)
		if session then
			local current = self.Expeditions:Get(session.SessionId)
			if current and (current.State == "Preparing" or current.State == "Teleporting") then
				local cancelled, detail = pcall(function() self.Expeditions:Cancel(hostId, session.SessionId, job.AttemptId) end)
				if not cancelled then self:_log("Expedition cancellation: " .. tostring(detail)) end
			end
		end
		pcall(function() self:_forming(job) end)
		self:_clear(job)
		self:_log("Expedition departure failed: " .. tostring(reason))
		error(reason, 2)
	end
	self:_clear(job)
	return session
end

function Coordinator.Complete(self: any, hostId: number, sessionId: string): any
	self:_studio()
	local session = self.Expeditions:Get(sessionId)
	assert(session and session.HostUserId == hostId and session.State == "Active", "active expedition host required")
	assert(not self:IsTraveling(hostId), "expedition host is traveling")
	return self.Expeditions:Complete(hostId, sessionId)
end

function Coordinator.Result(self: any, hostId: number, sessionId: string, destination: string, actionId: string, lookup: (number) -> any): any
	self:_studio()
	local session = self.Expeditions:Get(sessionId)
	assert(session and session.HostUserId == hostId, "expedition host required")
	if session.State == "Closed" then
		-- Validate the original parameters before returning the immutable receipt.
		self.Expeditions:BeginReturn(hostId, sessionId, destination, actionId)
		return self.Expeditions:GetReceipt(hostId, sessionId)
	end
	assert(session.State == "Result", "expedition result is not ready")
	local party = self.Party:Get(hostId)
	assert(party and party.PartyId == session.PartyId and party.LeaderUserId == hostId, "expedition host party changed")
	local members, players = {}, {}
	for _, id in session.MemberUserIds do
		if lookup(id) then
			assert(not self:IsTraveling(id), "expedition member is already traveling")
			self:_otherAvailable(id, false)
			assert(self.Data:HasProfile(id), "expedition member profile is not ready")
			table.insert(members, id); table.insert(players, lookup(id))
		end
	end
	assert(lookup(hostId), "expedition host left server")
	local job = { HostId = hostId, PartyId = session.PartyId, Members = members,
		Kind = "Result", SessionId = sessionId, AttemptId = self.NewId(), EnteredActivity = true, Cancelled = false }
	self._partyJobs[session.PartyId] = job
	for _, id in members do self._busy[id] = job end
	local receipt
	local ok, reason = pcall(function()
		self.Expeditions:BeginReturn(hostId, sessionId, destination, actionId)
		for _, id in members do
			self:_connected(job, lookup)
			self.Data:Release(id)
		end
		self:_connected(job, lookup)
		self.Teleport:ToWorld(players, sessionId, job.AttemptId)
		self:_connected(job, lookup)
		for _, id in members do self.Data:Load(id) end
		self:_connected(job, lookup)
		receipt = self.Expeditions:Close(hostId, sessionId, actionId)
		for _, id in members do self._locations[id] = "World" end
		self.Party:SetStatus(hostId, "Forming")
		if destination == "Repeat" then
			self.Party:SetActivity(hostId, "Expedition", session.TargetId)
			self.Party:Propose(hostId)
		elseif destination == "HostRestaurant" then
			self.Party:SetActivity(hostId, "Restaurant", "HostRestaurant")
			self.Party:Propose(hostId)
		end
	end)
	if not ok then
		self:_reload(members, lookup, job)
		local current = self.Expeditions:Get(sessionId)
		if current and current.State == "Returning" then
			local restored, detail = pcall(function() self.Expeditions:RestoreResult(hostId, sessionId, actionId) end)
			if not restored then self:_log("Expedition result recovery: " .. tostring(detail)) end
		end
		self:_clear(job)
		self:_log("Expedition return failed: " .. tostring(reason))
		error(reason, 2)
	end
	self:_clear(job)
	return receipt
end

function Coordinator.Forget(self: any, userId: number, lookup: ((number) -> any)?)
	local job = self._busy[userId]
	local session = self.Expeditions:GetForMember(userId)
	if job then job.Cancelled = true end
	if session and (session.HostUserId == userId or job ~= nil) then
		local actionId = if job then job.AttemptId else self.NewId()
		local ok, reason = pcall(function()
			if session.State == "Preparing" or session.State == "Teleporting" then
				self.Expeditions:Cancel(session.HostUserId, session.SessionId, actionId)
			else
				self.Expeditions:Abandon(session.HostUserId, session.SessionId, actionId)
			end
		end)
		if not ok then self:_log("Expedition disconnect cleanup: " .. tostring(reason)) end
		local recovery = job or self._partyJobs[session.PartyId]
		if recovery and recovery.SessionId == session.SessionId then
			recovery.Cancelled = true
			if lookup then self:_reload(recovery.Members, lookup, recovery, true) end
			pcall(function() self:_forming(recovery, true) end)
			self:_clear(recovery)
			if self._partyJobs[session.PartyId] == recovery then
				for _, id in recovery.Members do
					local current = self.Expeditions:GetForMember(id)
					if self._busy[id] == nil and (current == nil or current.SessionId == session.SessionId) then
						self._locations[id] = nil
					end
				end
			end
		end
	end
	if self._busy[userId] == job then self._busy[userId] = nil end
	local current = self.Expeditions:GetForMember(userId)
	if current == nil or session and current.SessionId == session.SessionId then self._locations[userId] = nil end
end

return Coordinator
