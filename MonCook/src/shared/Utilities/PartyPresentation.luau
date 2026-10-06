--!strict
-- Presentation reads server snapshots. It never decides membership or travel consent.
local PartyPresentation = {}

function PartyPresentation.debugVisible(isStudio: boolean, features: any): boolean
	return isStudio and type(features) == "table" and features.ShowFoundationDebugUI == true
end

function PartyPresentation.readyState(party: any, proposal: any, actorId: number): string
	if type(party) == "table" and type(party.ReadyStates) == "table" then
		local value = party.ReadyStates[tostring(actorId)] or party.ReadyStates[actorId]
		if value == "Joined" or value == "Waiting" or value == "Stayed" then return value end
	end
	if type(proposal) == "table" and type(proposal.Responses) == "table" then
		local value = proposal.Responses[tostring(actorId)]
		if value == nil then value = proposal.Responses[actorId] end
		if value == true then return "Joined" elseif value == false then return "Stayed" end
		return "Waiting"
	end
	return "Idle"
end

function PartyPresentation.readyLabel(value: string): string
	if value == "Joined" then return "✓ 함께 이동" end
	if value == "Waiting" then return "… 응답 중" end
	if value == "Stayed" then return "— 이번엔 남음" end
	return "· 대기"
end

function PartyPresentation.summary(party: any, proposal: any): any
	local result = { Total = 0, Moving = 0, Waiting = 0, Staying = 0 }
	if type(party) ~= "table" or type(party.MemberUserIds) ~= "table" then return result end
	for _, id in party.MemberUserIds do
		result.Total += 1
		local value = PartyPresentation.readyState(party, proposal, id)
		if value == "Joined" then result.Moving += 1
		elseif value == "Waiting" then result.Waiting += 1
		elseif value == "Stayed" then result.Staying += 1 end
	end
	return result
end

function PartyPresentation.memberRows(snapshot: any): { any }
	local result = {}
	local party = snapshot and snapshot.Party
	if type(party) ~= "table" or type(party.MemberUserIds) ~= "table" then return result end
	local profiles = {}
	for _, profile in snapshot.Members or {} do
		if type(profile) == "table" then
			local id = profile.ActorId or profile.UserId
			if type(id) == "number" then profiles[id] = profile end
		end
	end
	for _, id in party.MemberUserIds do
		local profile = profiles[id] or {}
		table.insert(result, {
			ActorId = id, UserId = profile.UserId or id,
			Name = profile.DisplayName or profile.Name or "플레이어",
			IsLeader = id == party.LeaderUserId,
			Ready = PartyPresentation.readyState(party, snapshot.Proposal, id),
		})
	end
	return result
end

function PartyPresentation.publicDirectory(snapshot: any): { any }
	local result = {}
	for _, party in (snapshot and snapshot.Directory) or {} do
		if party.Visibility == "Public" and party.Status ~= "Closed" then table.insert(result, party) end
	end
	return result
end

function PartyPresentation.shortName(name: string, limit: number?): string
	local length = utf8.len(name)
	local maxLength = limit or 6
	if not length or length <= maxLength then return name end
	local offset = utf8.offset(name, maxLength + 1)
	return if offset then string.sub(name, 1, offset - 1) .. "…" else name
end

return table.freeze(PartyPresentation)
