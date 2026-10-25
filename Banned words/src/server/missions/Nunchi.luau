--!strict
-- Nunchi (docs/DESIGN_V3.md §5.2; bundle 6c): the Korean counting game with the seat bells. The bells of everyone on
-- the ground open; each ring takes the next number (1, 2, 3 ...). Rings within NUNCHI_WINDOW of the first ring of a
-- number clash: they all fly and it ends once that window is over (so three at once all clash). With no clash, once
-- all but one of those still in have rung (and the window after the last ring is over), the one who never rang flies;
-- if they rang in that last moment after all, the last to ring is the last. NUNCHI_IDLE_SECONDS without a ring (or
-- NUNCHI_MAX_SECONDS in all) ends it too: everyone still in who has not rung flies (and missed an answer: the AFK
-- rule). Fewer than NUNCHI_MIN_PLAYERS left in the middle: it ends with no penalty. Ring times are the server's (ping
-- plays a part, known and accepted).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
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
		enough: (({ Player }, { [Player]: number }, { { player: Player, at: number } }) -> boolean)?, repeatEvery: number?)
		-> ({ Player }, { [Player]: number }, { { player: Player, at: number } }),
	screenTo: (player: Player, payload: { [string]: any }?) -> (),
	floor: (player: Player?) -> (),
	presenterVerdict: (answer: string, seconds: number) -> string?,
	score: (player: Player, amount: number) -> (),
	askText: (payload: { [string]: any }, seconds: number, from: { Player }) -> { [Player]: string },
	heads: (words: { [Player]: string }?, known: { [Player]: boolean }?) -> (),
	chat: (handler: ((Player, string) -> ())?) -> (),
}

local Nunchi = {
	id = "nunchi",
	title = Config.TEXT.NUNCHI_TITLE,
	brief = Config.TEXT.NUNCHI_BRIEF, -- (the briefing before it)
	expectedSeconds = Config.NUNCHI_MAX_SECONDS + Config.MINIGAME_RESULT_SECONDS,
	expectedFor = nil :: ((players: number) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.NUNCHI_MIN_PLAYERS :: number?,
	needsPresenter = nil :: boolean?,
}

local function ids(list: { Player }): { number }
	local out = {}
	for _, player in list do
		table.insert(out, player.UserId)
	end
	return out
end

-- The first clash in `rung` (the rings within NUNCHI_WINDOW of the first ring of one number) and that first ring's
-- time, or nil.
function Nunchi.clash(rung: { Player }, times: { [Player]: number }): ({ Player }?, number?)
	local k = 1
	while k < #rung do
		local first = rung[k]
		local group = { first }
		local j = k + 1
		while j <= #rung and times[rung[j]] - times[first] <= Config.NUNCHI_WINDOW do
			table.insert(group, rung[j])
			j += 1
		end
		if #group > 1 then
			return group, times[first]
		end
		k += 1
	end
	return nil, nil
end

local function names(list: { Player }): string
	local out = {}
	for _, player in list do
		table.insert(out, player.DisplayName)
	end
	return table.concat(out, ", ")
end

function Nunchi.available(final: boolean): boolean
	return not final
end

-- Returns false when too few were on the ground to start.
function Nunchi.run(ctx: Ctx): boolean?
	local from = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(from, player)
		end
	end
	if #from < Config.NUNCHI_MIN_PLAYERS then
		return false
	end
	ctx.show(Config.TEXT.NUNCHI_START)
	local startedAt = Match.now()
	ctx.screen({ kind = "nunchi", endsAt = startedAt + Config.NUNCHI_MAX_SECONDS })
	local function present(): { Player } -- who of those who began is still in (not out, not flying)
		local list = {}
		for _, player in from do
			if table.find(ctx.players(), player) and not ctx.flying(player) then
				table.insert(list, player)
			end
		end
		return list
	end
	local function lastAtOf(rung: { Player }, times: { [Player]: number }): number
		return if #rung > 0 then times[rung[#rung]] else startedAt
	end
	local function allButOne(rung: { Player }): boolean
		local here = present()
		local rangHere = 0
		for _, player in here do
			if table.find(rung, player) then
				rangHere += 1
			end
		end
		return rangHere >= #here - 1
	end
	local function settled(rung: { Player }, times: { [Player]: number }): boolean
		local now = Match.now()
		local clash, firstAt = Nunchi.clash(rung, times)
		if clash and firstAt then
			return now - firstAt > Config.NUNCHI_WINDOW -- (the clash window is over: everyone in it is in the clash)
		end
		if #present() < Config.NUNCHI_MIN_PLAYERS then
			return true
		end
		local quiet = now - lastAtOf(rung, times)
		return (allButOne(rung) and quiet > Config.NUNCHI_WINDOW) or quiet >= Config.NUNCHI_IDLE_SECONDS
	end
	local rung, times = ctx.bell(from, Config.NUNCHI_MAX_SECONDS, false, settled)
	if ctx.cancelled() then
		return nil
	end
	local clash = Nunchi.clash(rung, times)
	local here = present()
	if not clash and #here < Config.NUNCHI_MIN_PLAYERS then
		ctx.screen(nil)
		return nil -- (too few left in the middle: no penalty)
	end
	local still = {} -- who is still in and never rang
	for _, player in here do
		if not table.find(rung, player) then
			table.insert(still, player)
		end
	end
	local quiet = Match.now() - lastAtOf(rung, times)
	local timedOut = quiet >= Config.NUNCHI_IDLE_SECONDS or Match.now() - startedAt >= Config.NUNCHI_MAX_SECONDS
	local losers: { Player } = {}
	local text = ""
	local missed: { Player } = {}
	if clash then
		losers, text = clash, string.format(Config.TEXT.NUNCHI_CLASH, names(clash))
	elseif #still == 1 and not timedOut then
		losers, text = still, string.format(Config.TEXT.NUNCHI_LAST, names(still))
	elseif #still == 0 and #rung > 0 then
		local lastOne = rung[#rung] -- (rang in the very last moment: the last to ring is the last)
		losers, text = { lastOne }, string.format(Config.TEXT.NUNCHI_LAST, lastOne.DisplayName)
	else
		losers, text, missed = still, string.format(Config.TEXT.NUNCHI_IDLE, names(still)), still
	end
	local shown = table.clone(rung)
	for _, player in losers do
		if not table.find(shown, player) then
			table.insert(shown, player) -- (after the rings: those who never rang)
		end
	end
	ctx.screen({ kind = "nunchiResult", ids = ids(shown), rang = #rung, losers = ids(losers) })
	if text ~= "" then
		ctx.show(text)
	end
	ctx.answers(rung, missed) -- (before the fail: a launched player's miss would not count)
	ctx.fail(losers, "nunchi") -- (also with nobody: the answers above are counted with it)
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return Nunchi
