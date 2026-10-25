--!strict
-- 총잡이 결투 (bundle 8b, owner 2026-10-24). Everyone on the ground is paired at random (an odd one out sits this one
-- out, safe). The bells open at "ready"; "fire!" comes DUEL_READY_MIN-MAX seconds later at random and is sent only at
-- that moment (told ahead, a script could schedule its press). In each pair the first to ring after "fire!" wins and
-- the other flies; ringing before "fire!" is a false start (both: both fly); with a false start the other side is
-- safe whatever they do; who never rings within DUEL_WINDOW of "fire!" flies too (and missed an answer). Reactions
-- are the server's, less the player's whole round trip ("fire!" reached them late and the press came back late;
-- PressTiming), so a slow connection is not a slow hand. Results are given together at the end. A pair whose other
-- player left or is flying is off (no penalty).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local PressTiming = require(shared:WaitForChild("PressTiming"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))

-- MissionRunner.MissionCtx (missions cannot require services, so the shape is repeated here).
type Ctx = {
	final: boolean,
	players: () -> { Player },
	rng: Random,
	fail: (players: { Player }, key: string, subjective: boolean?) -> (),
	show: (text: string) -> (),
	cancelled: () -> boolean,
	stopped: () -> boolean,
	wait: (seconds: number) -> boolean,
	reveal: (seconds: number) -> (),
	flying: (player: Player) -> boolean,
	answers: (answered: { Player }, missed: { Player }) -> (),
	screen: (payload: { [string]: any }?) -> (),
	ask: (payload: { [string]: any }, choices: number, seconds: number, from: { Player }) -> { [Player]: number },
	canFling: (player: Player) -> boolean,
	presenterPick: (options: { { id: string, title: string, recommended: boolean } }, seconds: number, kind: string?) -> string?,
	lever: () -> (),
	talk: (stage: string, topic: string?) -> (),
	presenterReroll: (seconds: number) -> boolean,
	bell: (from: { Player }, seconds: number, firstOnly: boolean,
		enough: (({ Player }, { [Player]: number }, { { player: Player, at: number } }) -> boolean)?, repeatEvery: number?,
		quiet: boolean?)
		-> ({ Player }, { [Player]: number }, { { player: Player, at: number } }),
	screenTo: (player: Player, payload: { [string]: any }?) -> (),
	floor: (player: Player?) -> (),
	presenterVerdict: (answer: string, seconds: number) -> string?,
	score: (player: Player, amount: number) -> (),
	askText: (payload: { [string]: any }, seconds: number, from: { Player }) -> { [Player]: string },
	heads: (words: { [Player]: string }?, known: { [Player]: boolean }?) -> (),
	chat: (handler: ((Player, string) -> ())?) -> (),
}

local Duel = {
	id = "duel",
	title = Config.TEXT.DUEL_TITLE,
	brief = Config.TEXT.DUEL_BRIEF, -- (the briefing before it)
	expectedSeconds = Config.DUEL_READY_MAX + Config.DUEL_WINDOW + Config.TIMING_PING_CAP + Config.TIMING_GRACE
		+ Config.MINIGAME_RESULT_SECONDS,
	expectedFor = nil :: ((players: number) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.DUEL_MIN_PLAYERS :: number?,
	needsPresenter = nil :: boolean?,
}

local function ids(list: { Player }): { number }
	local out = {}
	for _, player in list do
		table.insert(out, player.UserId)
	end
	return out
end

local function names(list: { Player }): string
	local out = {}
	for _, player in list do
		table.insert(out, player.DisplayName)
	end
	return table.concat(out, ", ")
end

function Duel.available(final: boolean): boolean
	return not final
end

-- Who of a pair flies, from each one's reaction in seconds after "fire!" (negative = a false start, nil = never
-- within the window): false starts, else who never rang, else the slower (exactly equal: nobody). Pure, for the tests.
function Duel.loserOf(a: Player, b: Player, reactA: number?, reactB: number?): { Player }
	local falseA = reactA ~= nil and reactA < 0
	local falseB = reactB ~= nil and reactB < 0
	if falseA or falseB then
		local out = {}
		if falseA then
			table.insert(out, a)
		end
		if falseB then
			table.insert(out, b)
		end
		return out
	end
	if reactA == nil or reactB == nil then
		local out = {}
		if reactA == nil then
			table.insert(out, a)
		end
		if reactB == nil then
			table.insert(out, b)
		end
		return out
	end
	if reactA > reactB then
		return { a }
	elseif reactB > reactA then
		return { b }
	end
	return {}
end

-- Returns false when too few were on the ground to start.
function Duel.run(ctx: Ctx): boolean?
	local players = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(players, player)
		end
	end
	if #players < Config.DUEL_MIN_PLAYERS then
		return false
	end
	for i = #players, 2, -1 do -- shuffled, then paired in order
		local j = ctx.rng:NextInteger(1, i)
		players[i], players[j] = players[j], players[i]
	end
	local duels: { { Player } } = {}
	for i = 1, #players - 1, 2 do
		table.insert(duels, { players[i], players[i + 1] })
	end
	local bye = if #players % 2 == 1 then players[#players] else nil
	local shooters = table.clone(players)
	if bye then
		table.remove(shooters, #shooters)
	end
	local function inGame(player: Player): boolean
		return table.find(ctx.players(), player) ~= nil and not ctx.flying(player)
	end
	-- (the screens list everyone in pair order a, b, a, b, ..., the one sitting out last: `hasBye`)
	local everyone = ids(players)
	local readyFor = ctx.rng:NextNumber(Config.DUEL_READY_MIN, Config.DUEL_READY_MAX)
	local fireAt = Match.now() + readyFor
	ctx.show(Config.TEXT.DUEL_READY)
	ctx.screen({ kind = "duel", stage = "ready", ids = everyone, hasBye = bye ~= nil })
	local over = false -- (set on every way out: a "fire!" still waiting must not cover the result or the next game)
	task.delay(readyFor, function()
		if not over and not ctx.cancelled() then
			ctx.screen({ kind = "duel", stage = "fire", ids = everyone, hasBye = bye ~= nil,
				endsAt = Match.now() + Config.DUEL_WINDOW })
		end
	end)
	local timing = PressTiming.recorder()
	-- (open long enough for a reaction just inside the window from the slowest connection: the whole capped round trip,
	-- and a little more for the queues)
	local _, times = ctx.bell(shooters, readyFor + Config.DUEL_WINDOW + Config.TIMING_PING_CAP + Config.TIMING_GRACE, false,
		function(_rung: { Player }, seen: { [Player]: number }): boolean
			timing.note(seen)
			for _, player in shooters do
				if inGame(player) and not seen[player] then
					return false
				end
			end
			return true
		end)
	over = true
	if ctx.cancelled() then
		return nil
	end
	-- Seconds after "fire!" (negative = before it: a false start; past the window = never).
	local function reaction(player: Player): number?
		local at = times[player]
		if not at then
			return nil
		end
		if at < fireAt then
			return math.min(-0.001, at - fireAt) -- (it arrived before "fire!" was even sent)
		end
		local seconds = timing.reactedAt(player, at) - fireAt
		return if seconds > Config.DUEL_WINDOW then nil else seconds
	end
	-- Milliseconds after "fire!" for the screen: at most -1 for a false start, false = never.
	local function ms(react: number?): number | boolean
		if react == nil then
			return false
		end
		local rounded = math.floor(react * 1000 + 0.5)
		return if react < 0 then math.min(-1, rounded) else rounded
	end
	local losers, pressed, never, shown = {}, {}, {}, {}
	local fought = 0
	for _, pair in duels do
		local a, b = pair[1], pair[2]
		local reactA, reactB = reaction(a), reaction(b)
		table.insert(shown, ms(reactA))
		table.insert(shown, ms(reactB))
		if inGame(a) and inGame(b) then -- (one gone: their duel is off, no penalty, no AFK count)
			fought += 1
			for _, player in Duel.loserOf(a, b, reactA, reactB) do
				table.insert(losers, player)
			end
			-- The AFK rule: a ring counts as an answer; never ringing is a miss, unless the other side's false start
			-- already decided the duel.
			local falseStart = (reactA ~= nil and reactA < 0) or (reactB ~= nil and reactB < 0)
			for _, player in pair do
				if times[player] then
					table.insert(pressed, player)
				elseif not falseStart then
					table.insert(never, player)
				end
			end
		end
	end
	if fought == 0 then
		ctx.screen(nil)
		ctx.show(Config.TEXT.MINIGAME_TOO_FEW)
		return nil
	end
	ctx.screen({ kind = "duelResult", ids = everyone, hasBye = bye ~= nil, ms = shown, losers = ids(losers) })
	ctx.show(if #losers > 0 then string.format(Config.TEXT.DUEL_RESULT, names(losers)) else Config.TEXT.DUEL_DRAW)
	ctx.answers(pressed, never) -- (before the fail: a launched player's miss would not count)
	ctx.fail(losers, "duel")
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return Duel
