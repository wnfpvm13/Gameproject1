--!strict
-- Who a launch vote picks (docs/DESIGN_V3.md §5 "한마디 투표"): rules only, no remotes. The ballot lists the
-- candidates (1..n), then "nobody" (n + 1) and "I could not hear / see" (n + 2, an abstention). Voters cannot pick
-- themselves (such a vote does not count). The top choice wins when there are at least VOTE_MIN_VALID valid votes
-- (a candidate or "nobody"), the valid votes are at least half of the voters who did not abstain, and it beats the
-- second; if "nobody" wins or a rule is not met, nobody is launched. With fewer than VOTE_MIN_VOTERS voters there is
-- no vote at all.
local Config = require(script.Parent:WaitForChild("Config"))

local VoteRules = {}

-- Whether a vote can be held with this many voters.
function VoteRules.canVote(voters: number): boolean
	return voters >= Config.VOTE_MIN_VOTERS
end

-- The ballot size for `candidates` (+ "nobody" + abstain).
function VoteRules.choices(candidates: number): number
	return candidates + 2
end

-- `answers[voter]` = the ballot number each voter chose. Returns the candidate picked (its index), or nil.
function VoteRules.decide(answers: { [Player]: number }, candidates: { Player }, voters: { Player }): number?
	if not VoteRules.canVote(#voters) then
		return nil
	end
	local n = #candidates
	local counts: { [number]: number } = {}
	local valid, abstained = 0, 0
	for _, voter in voters do
		local choice = answers[voter]
		if choice == n + 2 then
			abstained += 1
		elseif choice and choice >= 1 and choice <= n + 1 and candidates[choice] ~= voter then
			valid += 1
			counts[choice] = (counts[choice] or 0) + 1
		end
	end
	if valid < Config.VOTE_MIN_VALID or valid * 2 < #voters - abstained then
		return nil
	end
	local top, topCount, second = nil :: number?, 0, 0
	for choice, count in counts do
		if count > topCount then
			second = topCount
			top, topCount = choice, count
		elseif count > second then
			second = count
		end
	end
	if top == nil or topCount == second or top == n + 1 then
		return nil
	end
	return top
end

return VoteRules
