--!strict
-- Pure orchestration. Teleport acceptance is not destination arrival; published
-- activation occurs after destination validation and acquisition of host data.
local Coordinator = {}
Coordinator.__index = Coordinator
function Coordinator.new(options: any): any
	local counter = 0
	return setmetatable({
		Data = options.Data, Sessions = options.Sessions, Party = options.Party,
		Teleport = options.Teleport, IsFake = options.IsFake, Log = options.Log,
		_traveling = {}, _locations = {},
		NewAttempt = options.NewId or function(): string counter += 1; return tostring(counter) end,
	}, Coordinator)
end
function Coordinator.IsTraveling(self: any, userId: number): boolean
	return self._traveling[userId] ~= nil
end
function Coordinator.Location(self: any, userId: number): string
	return self._locations[userId] or "World"
end
function Coordinator.Forget(self: any, userId: number)
	self._traveling[userId], self._locations[userId] = nil, nil
end
function Coordinator._log(self: any, message: string)
	if self.Log then pcall(self.Log, message) end
end
function Coordinator._reload(self: any, members: { number }, lookup: (number) -> any)
	for _, id in members do
		if lookup(id) and not self.Data:HasProfile(id) then
			local ok, err = pcall(function() self.Data:Load(id) end)
			if not ok then self:_log("Recovery profile load: " .. tostring(err)) end
		end
	end
end
function Coordinator.Start(self: any, hostId: number, proposalId: string, pantry: any, lookup: (number) -> any): any
	local members = self.Party:Ready(hostId, proposalId)
	local players = {}
	for _, id in members do
		assert(not self:IsTraveling(id), "party member is already traveling")
		assert(self.Data:HasProfile(id), "party member profile is not ready")
		local player = lookup(id)
		assert(player, "party member left server")
		table.insert(players, player)
	end
	for _, id in members do self._traveling[id] = true end
	local session
	local ok, reason = pcall(function()
		session = self.Sessions:Prepare(hostId, members, pantry)
		local reservation = self.Teleport:ReserveRestaurant()
		-- Revalidate consent after the potentially yielding reservation request.
		local current = self.Party:Ready(hostId, proposalId)
		assert(#current == #members, "party consent changed during preparation")
		for index, id in members do assert(current[index] == id and lookup(id), "party changed during preparation") end
		session = self.Sessions:MarkTeleporting(hostId, session.SessionId, reservation.PrivateServerId)
		current = self.Party:Ready(hostId, proposalId)
		assert(#current == #members, "party consent changed during session write")
		for index, id in members do assert(current[index] == id and lookup(id), "party changed during session write") end
		self.Party:FinishProposal(hostId, proposalId)
		local job = { SessionId = session.SessionId, HostId = hostId, Members = members, Direction = "Restaurant", AttemptId = self.NewAttempt() }
		for _, id in members do self._traveling[id] = job end
		for _, id in members do self.Data:Release(id) end
		self.Teleport:ToRestaurant(players, session.SessionId, reservation, job.AttemptId)
		if self.IsFake then
			for _, id in members do self.Data:Load(id) end
			session = self.Sessions:Activate(hostId, session.SessionId, reservation.PrivateServerId)
			for _, id in members do self._locations[id], self._traveling[id] = "Restaurant", nil end
		end
	end)
	if not ok then
		self:_reload(members, lookup)
		if session and self.Data:HasProfile(hostId) then
			local recovered, err = pcall(function() self.Sessions:Rollback(hostId, session.SessionId) end)
			if not recovered then self:_log("Pantry rollback pending durable recovery: " .. tostring(err)) end
		end
		for _, id in members do self._traveling[id] = nil end
		self:_log("Restaurant departure failed: " .. tostring(reason))
		error(reason, 2)
	end
	return session
end
function Coordinator.Return(self: any, hostId: number, lookup: (number) -> any): any
	local session = self.Sessions:GetHostSession(hostId)
	assert(session and session.State == "Active" or session and session.State == "Closed", "host has no active or settled session")
	local members, players = {}, {}
	for _, id in session.PartyUserIds do
		local player = lookup(id)
		if player then
			assert(not self:IsTraveling(id), "member already traveling")
			assert(self.Data:HasProfile(id), "member profile not ready")
			table.insert(members, id); table.insert(players, player)
		end
	end
	assert(lookup(hostId), "host left server")
	local receipt
	local job = { SessionId = session.SessionId, HostId = hostId, Members = members, Direction = "World", AttemptId = self.NewAttempt() }
	for _, id in members do self._traveling[id] = job end
	local ok, reason = pcall(function()
		receipt = self.Sessions:Settle(hostId, session.SessionId)
		for _, id in members do self.Data:Release(id) end
		self.Teleport:ToWorld(players, session.SessionId, job.AttemptId)
		if self.IsFake then
			for _, id in members do self.Data:Load(id); self._locations[id], self._traveling[id] = "World", nil end
		end
	end)
	if not ok then
		self:_reload(members, lookup)
		for _, id in members do self._traveling[id] = nil end
		self:_log((if receipt then "World return failed; settlement remains committed: " else "Settlement/return failed: ") .. tostring(reason))
		error(reason, 2)
	end
	return receipt
end
function Coordinator.ReturnMember(self: any, userId: number, sessionId: string, lookup: (number) -> any)
	-- The authenticated runtime binds SessionId after validated arrival. Leaving
	-- only releases this helper's own profile; it cannot close or spend host data.
	assert(type(sessionId) == "string" and #sessionId > 0, "session identity required")
	assert(not self:IsTraveling(userId), "member already traveling")
	local player = lookup(userId)
	assert(player and self.Data:HasProfile(userId), "member is not ready")
	self._traveling[userId] = true
	local job = { SessionId = sessionId, HostId = nil, Members = { userId }, Direction = "World", AttemptId = self.NewAttempt() }
	self._traveling[userId] = job
	local ok, reason = pcall(function()
		self.Data:Release(userId)
		self.Teleport:ToWorld({ player }, sessionId, job.AttemptId)
		if self.IsFake then
			self.Data:Load(userId)
			self._locations[userId], self._traveling[userId] = "World", nil
		end
	end)
	if not ok then
		self:_reload({ userId }, lookup)
		self._traveling[userId] = nil
		self:_log("Helper return failed: " .. tostring(reason))
		error(reason, 2)
	end
end
function Coordinator.RecoverFailure(self: any, userId: number, id: string, lookup: (number) -> any, attemptId: string?, destination: string?)
	local job = self._traveling[userId]
	if type(job) ~= "table" or job.SessionId ~= id or job.AttemptId ~= attemptId
		or job.Direction ~= destination or not table.find(job.Members, userId) then return end
	self:_reload({ userId }, lookup)
	if job.Direction == "Restaurant" and job.HostId == userId and self.Data:HasProfile(userId) then
		-- The destination's profile lock prevents a late failure from undoing
		-- a session the destination has already accepted.
		local ok, err = pcall(function() self.Sessions:Rollback(userId, id) end)
		if not ok then self:_log("Late teleport failure recovery: " .. tostring(err)) end
	end
	self._traveling[userId] = nil
end
return Coordinator
