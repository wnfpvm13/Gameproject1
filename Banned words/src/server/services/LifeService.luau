--!strict
-- Lives (docs/DESIGN_V3.md §4). Everyone starts a round with LIVES; a failed player loses one (RoundService launches
-- them) and at zero is out. The rules:
--   - one penalty per event: the same event never costs the same player twice;
--   - none while flying: a launched player takes no new penalty until back on the chair;
--   - simultaneous fails are taken together, and a fail that would leave nobody alive sends exactly those players to
--     a final among themselves instead (they stay in with no lives left);
--   - subjective launches (the presenter or a vote decides) in public servers: SUBJECTIVE_FLINGS per player per round,
--     and never the last life (bundles 3-4 use this);
--   - AFK_MISSES answer missions missed in a row make a player a spectator (out); a miss while flying does not count.
-- Lives live in Match.participants; this module only changes them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))

local LifeService = {}

export type Kind = "objective" | "subjective"
export type Outcome = { player: Player, livesLeft: number, out: boolean }

local busy: (Player) -> boolean = function(_player: Player): boolean
	return false -- until start() gets the real check
end
local penalized: { [string]: { [Player]: boolean } } = {} -- event id -> players it already cost a life
local subjectiveUsed: { [Player]: number } = {}

-- isBusy(player): true while the player cannot take a penalty (flying; RoundService passes SeatService.isFlying).
function LifeService.start(isBusy: (Player) -> boolean)
	busy = isBusy
	Players.PlayerRemoving:Connect(function(player)
		subjectiveUsed[player] = nil
		for _, set in penalized do
			set[player] = nil
		end
	end)
end

-- A fresh round: lives come from Match.participants (RoundService sets them), the per-round counters start over.
function LifeService.beginRound()
	table.clear(penalized)
	table.clear(subjectiveUsed)
end

-- Whether `player` can be failed now by an event of this kind (alive, not flying; subjective limits in public).
function LifeService.canFail(player: Player, kind: Kind): boolean
	local p = Match.participants[player]
	if not (p and p.alive) or busy(player) then
		return false
	end
	if kind == "subjective" and Match.serverKind == "public" then
		return (subjectiveUsed[player] or 0) < Config.SUBJECTIVE_FLINGS and p.lives > 1
	end
	return true
end

-- Fails `players` for event `eventId`. Returns who lost a life (and who is now out), and whether the fail sent the
-- players hit to a final among themselves (it would have left nobody alive). The event is used up for everyone
-- listed, also for those it could not hit (flying, limits): the same event coming again later never costs them.
function LifeService.fail(players: { Player }, eventId: string, kind: Kind): ({ Outcome }, boolean)
	local seen = penalized[eventId] or {}
	penalized[eventId] = seen
	local hit: { Player } = {}
	for _, player in players do
		if not seen[player] then
			seen[player] = true
			if LifeService.canFail(player, kind) then
				table.insert(hit, player)
			end
		end
	end
	-- Would this leave nobody alive? Then nobody goes out: the players hit play the final.
	local survivors = 0
	for player, p in Match.participants do
		if p.alive and not (table.find(hit, player) and p.lives <= 1) then
			survivors += 1
		end
	end
	local toFinal = #hit > 0 and survivors == 0
	local outcomes: { Outcome } = {}
	for _, player in hit do
		local p = Match.participants[player]
		p.lives = math.max(0, p.lives - 1)
		if kind == "subjective" then
			subjectiveUsed[player] = (subjectiveUsed[player] or 0) + 1
		end
		local out = p.lives == 0 and not toFinal
		if out then
			p.alive = false
		end
		table.insert(outcomes, { player = player, livesLeft = p.lives, out = out })
	end
	return outcomes, toFinal
end

-- Puts players out at once (a wrong final answer, leaving, the AFK rule, a Studio test). Already-out players are
-- skipped. Returns the outcomes.
function LifeService.eliminate(players: { Player }): { Outcome }
	local outcomes: { Outcome } = {}
	for _, player in players do
		local p = Match.participants[player]
		if p and p.alive then
			p.alive = false
			p.lives = 0
			table.insert(outcomes, { player = player, livesLeft = 0, out = true })
		end
	end
	return outcomes
end

-- An answer mission closed: `answered` resets the player's run of misses; AFK_MISSES misses in a row put them out.
-- A mission missed while flying does not count (docs/DESIGN_V3.md §4). Returns true if this miss made the player out.
function LifeService.noteAnswer(player: Player, answered: boolean): boolean
	local p = Match.participants[player]
	if not (p and p.alive) then
		return false
	end
	if answered then
		p.afkMisses = 0
		return false
	end
	if busy(player) then
		return false
	end
	p.afkMisses += 1
	if p.afkMisses >= Config.AFK_MISSES then
		LifeService.eliminate({ player })
		return true
	end
	return false
end

return LifeService
