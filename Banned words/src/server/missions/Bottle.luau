--!strict
-- 물병 세우기 (bundle 8b; owner 2026-10-24: stop a power bar with the bell). One throw per zone of BOTTLE_ZONES; in each
-- a bar runs back and forth (there and back every BOTTLE_PERIOD seconds, from a moment sent ahead so every screen draws
-- it in step) and a green zone sits at a random place, narrower each throw. Everyone rings once per throw: stopped
-- inside the zone (the press made by BOTTLE_THROW_SECONDS after the bar started), their bottle (on a little table in
-- front of their chair) lands standing. After the last throw the fewest standing fly — unless everyone stood the same
-- number (then nobody); who never rang in any throw missed an answer. The bar's place is the server's, at the press
-- less the trip back from the client (PressTiming). Only players still here and on the ground count.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local Config = require(shared:WaitForChild("Config"))
local PressTiming = require(shared:WaitForChild("PressTiming"))
local PowerBar = require(shared:WaitForChild("PowerBar"))
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

local Bottle = {
	id = "bottle",
	title = Config.TEXT.BOTTLE_TITLE,
	brief = string.format(Config.TEXT.BOTTLE_BRIEF, #Config.BOTTLE_ZONES), -- (the briefing before it)
	expectedSeconds = #Config.BOTTLE_ZONES * (Config.BOTTLE_LEAD_SECONDS + Config.BOTTLE_THROW_SECONDS
		+ Config.TIMING_GRACE + Config.BOTTLE_SHOW_SECONDS) + Config.MINIGAME_RESULT_SECONDS,
	expectedFor = nil :: ((players: number) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.BOTTLE_MIN_PLAYERS :: number?,
	maxPlayers = nil :: number?,
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

function Bottle.available(final: boolean): boolean
	return not final
end

-- Who flies from the standing counts: the fewest, unless everyone stood the same number. Pure, for the tests.
function Bottle.losers(players: { Player }, stood: { [Player]: number }): { Player }
	local low, high = math.huge, -math.huge
	for _, player in players do
		local count = stood[player] or 0
		low = math.min(low, count)
		high = math.max(high, count)
	end
	if #players == 0 or low == high then
		return {}
	end
	local out = {}
	for _, player in players do
		if (stood[player] or 0) == low then
			table.insert(out, player)
		end
	end
	return out
end

-- Returns false when too few were on the ground to start.
function Bottle.run(ctx: Ctx): boolean?
	local players = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(players, player)
		end
	end
	if #players < Config.BOTTLE_MIN_PLAYERS then
		return false
	end
	local stood: { [Player]: number } = {}
	local touched: { [Player]: boolean } = {}
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
	local function counts(): { number }
		local list = {}
		for _, player in players do
			table.insert(list, stood[player] or 0)
		end
		return list
	end
	local function tooFew(): boolean
		if #present() < Config.BOTTLE_MIN_PLAYERS then
			ctx.screen(nil)
			ctx.show(Config.TEXT.MINIGAME_TOO_FEW)
			return true
		end
		return false
	end
	ctx.show(Config.TEXT.BOTTLE_START)
	for throw, width in Config.BOTTLE_ZONES do
		local center = ctx.rng:NextNumber(width / 2 + Config.BOTTLE_EDGE, 1 - width / 2 - Config.BOTTLE_EDGE)
		local barStartAt = Match.now() + Config.BOTTLE_LEAD_SECONDS
		ctx.screen({ kind = "bottle", throw = throw, throws = #Config.BOTTLE_ZONES, center = center, width = width,
			barStartAt = barStartAt, period = Config.BOTTLE_PERIOD, ids = ids(players), stood = counts(),
			endsAt = barStartAt + Config.BOTTLE_THROW_SECONDS })
		if not ctx.wait(Config.BOTTLE_LEAD_SECONDS) then
			return nil
		end
		local timing = PressTiming.recorder()
		local _, times = ctx.bell(players, Config.BOTTLE_THROW_SECONDS + Config.TIMING_GRACE, false,
			function(_rung: { Player }, seen: { [Player]: number }): boolean
				timing.note(seen)
				for _, player in present() do
					if not seen[player] then
						return false
					end
				end
				return true
			end)
		if ctx.cancelled() then
			return nil
		end
		local landed = {}
		for _, player in players do
			local at = times[player]
			local standing = false
			if at then
				touched[player] = true
				local t = timing.pressedAt(player, at) - barStartAt
				standing = t <= Config.BOTTLE_THROW_SECONDS
					and math.abs(PowerBar.at(t, Config.BOTTLE_PERIOD) - center) <= width / 2
			end
			if standing then
				stood[player] = (stood[player] or 0) + 1
			end
			table.insert(landed, standing)
		end
		if tooFew() then
			return nil
		end
		ctx.screen({ kind = "bottleThrow", throw = throw, throws = #Config.BOTTLE_ZONES, ids = ids(players),
			landed = landed, stood = counts() })
		if not ctx.wait(Config.BOTTLE_SHOW_SECONDS) then
			return nil
		end
	end
	if tooFew() then -- (someone left while the last throw showed)
		return nil
	end
	local here = present()
	local losers = Bottle.losers(here, stood)
	local pressed, never = {}, {}
	for _, player in here do
		table.insert(if touched[player] then pressed else never, player)
	end
	ctx.screen({ kind = "bottleResult", ids = ids(players), stood = counts(), losers = ids(losers) })
	ctx.show(if #losers > 0 then string.format(Config.TEXT.BOTTLE_RESULT, names(losers)) else Config.TEXT.BOTTLE_TIE)
	ctx.answers(pressed, never) -- (before the fail: a launched player's miss would not count)
	ctx.fail(losers, "bottle")
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return Bottle
