--!strict
-- Short mission votes (V2.1): open for a few seconds, alive participants may vote (and change their vote) whether
-- or not they spoke; counts stay hidden until it closes. One option with the most votes wins; a tie or no votes
-- is "undecided" (a neutral follow-up, never a penalty). Talk and judging go on during the vote.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local VoteService = {}

type Option = { id: string, text: string }
type Ballot = { voteKey: string, options: { Option }, endsAt: number, votes: { [Player]: string } }

local current: Ballot? = nil
local lastClosed: any = nil -- { payload, at = os.clock() } for late joiners
local pendingKey: string? = nil -- closed and counted, result not shown yet
local serial = 0

local function isOption(ballot: Ballot, id: any): boolean
	for _, option in ballot.options do
		if option.id == id then
			return true
		end
	end
	return false
end

local function openPayload(ballot: Ballot)
	local options = {}
	for _, option in ballot.options do
		table.insert(options, { id = option.id, text = option.text })
	end
	return { kind = "open", voteKey = ballot.voteKey, options = options, endsAt = ballot.endsAt }
end

local function onVote(player: Player, voteKey: any, optionId: any)
	local ballot = current
	if not ballot or voteKey ~= ballot.voteKey or Match.phase ~= "Talk" or not Match.isAlive(player) or not isOption(ballot, optionId) then
		return
	end
	if Match.now() > ballot.endsAt then
		return
	end
	ballot.votes[player] = optionId
end

function VoteService.start()
	Net.listen("Vote", onVote)
	Players.PlayerRemoving:Connect(function(player)
		if current then
			current.votes[player] = nil -- leaving before the close: the vote no longer counts
		end
	end)
end

local function noop() end

-- Blocks until the vote closes (or the talk ends). Returns the winning option id (or "undecided") and a function
-- that shows the result to everyone (the host calls it when nothing else is on screen; counts are fixed already).
function VoteService.run(spec: { id: string, options: { Option }, seconds: number }, stillTalking: () -> boolean): (string, () -> ())
	serial += 1
	local ballot: Ballot = {
		voteKey = string.format("%d:%d:%s", Match.roundId, serial, spec.id),
		options = spec.options,
		endsAt = Match.now() + spec.seconds,
		votes = {},
	}
	current = ballot
	lastClosed = nil
	Net.toAll("VoteState", openPayload(ballot))
	while Match.now() < ballot.endsAt and stillTalking() and current == ballot do
		task.wait(math.min(0.2, math.max(0, ballot.endsAt - Match.now())))
	end
	if current ~= ballot or not stillTalking() then
		-- The round stopped (or was cleared) during the vote: no result, nothing changes.
		if current == ballot then
			current = nil
			Net.toAll("VoteState", { kind = "cancel", voteKey = ballot.voteKey })
		end
		return "undecided", noop
	end
	current = nil
	pendingKey = ballot.voteKey
	Net.toAll("VoteState", { kind = "pending", voteKey = ballot.voteKey })

	-- Counted right at the close: only votes of players alive at this moment.
	local counts: { [string]: number } = {}
	for _, option in ballot.options do
		counts[option.id] = 0
	end
	for player, optionId in ballot.votes do
		if Match.isAlive(player) then
			counts[optionId] += 1
		end
	end
	local best, bestCount, tie = "undecided", 0, false
	for _, option in ballot.options do
		local n = counts[option.id]
		if n > bestCount then
			best, bestCount, tie = option.id, n, false
		elseif n == bestCount and n > 0 then
			tie = true
		end
	end
	local outcome = if tie or bestCount == 0 then "undecided" else best
	local result = {
		kind = "closed",
		voteKey = ballot.voteKey,
		outcome = outcome,
		counts = counts,
		options = openPayload(ballot).options,
	}
	local function announce()
		if pendingKey ~= ballot.voteKey then
			return -- cleared meanwhile (round over)
		end
		pendingKey = nil
		result.expiresAt = Match.now() + Config.VOTE_RESULT_SECONDS
		lastClosed = { payload = result, at = os.clock() }
		Net.toAll("VoteState", result)
	end
	return outcome, announce
end

-- Late joiners: the open vote, a vote waiting for its result, or a result that is still on everyone's screen.
function VoteService.send(player: Player)
	if current then
		Net.to(player, "VoteState", openPayload(current))
	elseif pendingKey then
		Net.to(player, "VoteState", { kind = "pending", voteKey = pendingKey })
	elseif lastClosed and os.clock() - lastClosed.at < Config.VOTE_RESULT_SECONDS then
		Net.to(player, "VoteState", lastClosed.payload)
	end
end

function VoteService.clear()
	current = nil
	pendingKey = nil
	lastClosed = nil
	Net.toAll("VoteState", { kind = "clear" })
end

return VoteService
