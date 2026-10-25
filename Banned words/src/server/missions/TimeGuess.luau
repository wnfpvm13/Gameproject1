--!strict
-- 숫자 맞추기 (bundle 8b; owner 2026-10-24: not 5 s but a number like 5.63, 5.93, 9.32 between 5 and 10). A target time
-- (TIMEGUESS_MIN-MAX seconds, two decimals) shows for TIMEGUESS_READ_SECONDS, then the clock starts at a moment sent
-- ahead (every screen starts it by its synced clock) and is visible for TIMEGUESS_VISIBLE_SECONDS only; everyone rings
-- once when they think the target has passed. The bells are quiet (only the ringer hears their own ding: another's
-- ding would give the time away). The one farthest from the target, in hundredths of a second as shown, flies (ties:
-- all of them); who never rang flies instead (and missed an answer). Times are the server's, less the trip back from
-- the client (PressTiming). Only players still here and on the ground count.
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

local TimeGuess = {
	id = "timeGuess",
	title = Config.TEXT.TIMEGUESS_TITLE,
	brief = string.format(Config.TEXT.TIMEGUESS_BRIEF, Config.TIMEGUESS_VISIBLE_SECONDS), -- (the briefing before it)
	expectedSeconds = Config.TIMEGUESS_READ_SECONDS + Config.TIMEGUESS_MAX + Config.TIMEGUESS_LATE + Config.TIMING_GRACE
		+ Config.MINIGAME_RESULT_SECONDS,
	expectedFor = nil :: ((players: number) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.TIMEGUESS_MIN_PLAYERS :: number?,
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

-- Seconds in hundredths, as the screens show them.
local function hundredths(seconds: number): number
	return math.floor(seconds * 100 + 0.5) / 100
end

function TimeGuess.available(final: boolean): boolean
	return not final
end

-- The players to lose, from each one's seconds (nil = never rang): who never rang, else the farthest from `target`
-- (ties all). Pure, for the tests.
function TimeGuess.losers(players: { Player }, seconds: { [Player]: number }, target: number): { Player }
	local never = {}
	for _, player in players do
		if seconds[player] == nil then
			table.insert(never, player)
		end
	end
	if #never > 0 then
		return never
	end
	local worst = -1
	for _, player in players do
		worst = math.max(worst, math.abs((seconds[player] :: number) - target))
	end
	local out = {}
	for _, player in players do
		if math.abs((seconds[player] :: number) - target) >= worst - 1e-6 then
			table.insert(out, player)
		end
	end
	return out
end

-- Returns false when too few were on the ground to start.
function TimeGuess.run(ctx: Ctx): boolean?
	local players = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(players, player)
		end
	end
	if #players < Config.TIMEGUESS_MIN_PLAYERS then
		return false
	end
	-- (still here, alive and on the ground)
	local function present(): { Player }
		local list = {}
		for _, player in players do
			if table.find(ctx.players(), player) and not ctx.flying(player) then
				table.insert(list, player)
			end
		end
		return list
	end
	local target = ctx.rng:NextInteger(Config.TIMEGUESS_MIN * 100, Config.TIMEGUESS_MAX * 100) / 100
	local startAt = Match.now() + Config.TIMEGUESS_READ_SECONDS
	ctx.show(string.format(Config.TEXT.TIMEGUESS_START, target))
	ctx.screen({ kind = "timeGuess", target = target, startAt = startAt, visibleFor = Config.TIMEGUESS_VISIBLE_SECONDS,
		ids = ids(players), endsAt = startAt + target + Config.TIMEGUESS_LATE })
	if not ctx.wait(Config.TIMEGUESS_READ_SECONDS) then
		return nil
	end
	local timing = PressTiming.recorder()
	local _, times = ctx.bell(players, target + Config.TIMEGUESS_LATE + Config.TIMING_GRACE, false,
		function(_rung: { Player }, seen: { [Player]: number }): boolean
			timing.note(seen)
			for _, player in present() do
				if not seen[player] then
					return false
				end
			end
			return true
		end, nil, true)
	if ctx.cancelled() then
		return nil
	end
	local here, seconds, pressed, never = present(), {}, {}, {}
	for _, player in here do
		local at = times[player]
		local made = if at then timing.pressedAt(player, at) - startAt else nil
		if made and made <= target + Config.TIMEGUESS_LATE then -- (made after the shown end: as if never)
			seconds[player] = hundredths(made)
			table.insert(pressed, player)
		else
			table.insert(never, player)
		end
	end
	if #here < Config.TIMEGUESS_MIN_PLAYERS then
		ctx.screen(nil)
		ctx.show(Config.TEXT.MINIGAME_TOO_FEW)
		return nil
	end
	local losers = TimeGuess.losers(here, seconds, target)
	local shown = {}
	for _, player in players do
		table.insert(shown, seconds[player] or -1)
	end
	ctx.screen({ kind = "timeGuessResult", target = target, ids = ids(players), seconds = shown, losers = ids(losers) })
	ctx.show(string.format(Config.TEXT.TIMEGUESS_RESULT, target, names(losers)))
	ctx.answers(pressed, never) -- (before the fail: a launched player's miss would not count)
	ctx.fail(losers, "timeGuess")
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return TimeGuess
