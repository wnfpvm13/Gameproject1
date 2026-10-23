--!strict
-- Red light, green light (무궁화 꽃이 피었습니다; docs/DESIGN_V3.md §5.2; bundle 6d). REDLIGHT_SECONDS of lights drawn
-- at the start (green REDLIGHT_GREEN_MIN-MAX seconds, red REDLIGHT_RED_MIN-MAX, green first), shown on everyone's
-- screen as they change. Every bell press on green moves a player one step (the bells count at most
-- REDLIGHT_MAX_PRESS a second, so a macro or a fast phone gains nothing beyond that); a press on red after
-- REDLIGHT_GRACE (the light may reach a client late) puts the player out of this game: they fly. Reaching REDLIGHT_GOAL
-- steps is safe (later presses do not matter). At the end everyone still short of the goal flies; who never pressed
-- missed an answer (the AFK rule). Press times are the server's.
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
}

local RedLight = {
	id = "redLight",
	title = Config.TEXT.REDLIGHT_TITLE,
	expectedSeconds = Config.REDLIGHT_SECONDS + Config.MINIGAME_RESULT_SECONDS,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.REDLIGHT_MIN_PLAYERS :: number?,
	needsPresenter = nil :: boolean?,
}

type Phase = { light: string, from: number, to: number }

-- The lights from `startAt` (Match.now()) for REDLIGHT_SECONDS, green first.
function RedLight.lights(startAt: number, rng: Random): { Phase }
	local phases: { Phase } = {}
	local t = startAt
	local green = true
	while t < startAt + Config.REDLIGHT_SECONDS do
		local length = if green then rng:NextNumber(Config.REDLIGHT_GREEN_MIN, Config.REDLIGHT_GREEN_MAX)
			else rng:NextNumber(Config.REDLIGHT_RED_MIN, Config.REDLIGHT_RED_MAX)
		table.insert(phases, { light = if green then "green" else "red", from = t, to = t + length })
		t += length
		green = not green
	end
	return phases
end

-- The light at `at` and when it began.
local function lightAt(phases: { Phase }, at: number): (string, number)
	for _, phase in phases do
		if at < phase.to then
			return phase.light, phase.from
		end
	end
	local last = phases[#phases]
	return last.light, last.from
end

-- A press on red this long after the light changed is caught: REDLIGHT_GRACE, plus the player's round trip (the light
-- reaches their screen late and the press comes back late), up to REDLIGHT_PING_CAP.
local function graceOf(player: Player): number
	local ok, ping = pcall(function(): number
		return player:GetNetworkPing()
	end)
	local extra = if ok and type(ping) == "number" then math.clamp(ping, 0, Config.REDLIGHT_PING_CAP) else 0
	return Config.REDLIGHT_GRACE + extra
end

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

function RedLight.available(final: boolean): boolean
	return not final
end

-- Returns false when too few were on the ground to start.
function RedLight.run(ctx: Ctx): boolean?
	local players = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(players, player)
		end
	end
	if #players < Config.REDLIGHT_MIN_PLAYERS then
		return false
	end
	ctx.show(Config.TEXT.REDLIGHT_START)
	local startAt = Match.now()
	local endsAt = startAt + Config.REDLIGHT_SECONDS
	local phases = RedLight.lights(startAt, ctx.rng)
	local steps: { [Player]: number } = {}
	local caught: { [Player]: boolean } = {}
	local touched: { [Player]: boolean } = {} -- pressed at all (an answer for the AFK rule)
	local seen = 0
	local shownLight, shownAt = "", -math.huge
	local function progress(): { number }
		local list = {}
		for _, player in players do
			table.insert(list, math.min(steps[player] or 0, Config.REDLIGHT_GOAL))
		end
		return list
	end
	-- Too few left in the middle (leaves): the game ends with no penalty (§4).
	local function tooFew(): boolean
		local here = 0
		for _, player in players do
			if table.find(ctx.players(), player) then
				here += 1
			end
		end
		return here < Config.REDLIGHT_MIN_PLAYERS
	end
	local function caughtIds(): { number }
		local list = {}
		for _, player in players do
			if caught[player] then
				table.insert(list, player.UserId)
			end
		end
		return list
	end
	-- Asked every poll while the bells are open: count the new presses, update the screen, end when nobody is left
	-- to move (everyone at the goal or caught).
	local function follow(_rung: { Player }, _times: { [Player]: number }, presses: { { player: Player, at: number } }): boolean
		for i = seen + 1, #presses do
			seen = i
			local press = presses[i]
			local player = press.player
			touched[player] = true
			if not caught[player] and (steps[player] or 0) < Config.REDLIGHT_GOAL then
				local light, since = lightAt(phases, press.at)
				if light == "green" then
					steps[player] = (steps[player] or 0) + 1
				elseif press.at - since > graceOf(player) then
					caught[player] = true
				end
			end
		end
		local now = Match.now()
		local light = lightAt(phases, now)
		if light ~= shownLight or now - shownAt >= Config.REDLIGHT_UPDATE then
			shownLight, shownAt = light, now
			ctx.screen({ kind = "redLight", light = light, goal = Config.REDLIGHT_GOAL, ids = ids(players),
				steps = progress(), caught = caughtIds(), endsAt = endsAt })
		end
		if tooFew() then
			return true
		end
		for _, player in players do
			if not caught[player] and (steps[player] or 0) < Config.REDLIGHT_GOAL and table.find(ctx.players(), player) then
				return false
			end
		end
		return true
	end
	local rung, times, presses = ctx.bell(players, Config.REDLIGHT_SECONDS, false, follow, 1 / Config.REDLIGHT_MAX_PRESS)
	if ctx.cancelled() then
		return nil
	end
	follow(rung, times, presses) -- (the presses after the last check count too)
	if tooFew() then
		ctx.screen(nil)
		ctx.show(Config.TEXT.MINIGAME_TOO_FEW)
		return nil
	end
	local caughtList, short, pressed, never = {}, {}, {}, {}
	for _, player in players do
		if table.find(ctx.players(), player) then
			if caught[player] then
				table.insert(caughtList, player)
			elseif (steps[player] or 0) < Config.REDLIGHT_GOAL then
				table.insert(short, player)
			end
			table.insert(if touched[player] then pressed else never, player)
		end
	end
	local losers = table.clone(caughtList)
	for _, player in short do
		table.insert(losers, player)
	end
	ctx.screen({ kind = "redLightResult", goal = Config.REDLIGHT_GOAL, ids = ids(players), steps = progress(),
		caught = caughtIds() })
	local lines = {}
	if #caughtList > 0 then
		table.insert(lines, string.format(Config.TEXT.REDLIGHT_CAUGHT, names(caughtList)))
	end
	if #short > 0 then
		table.insert(lines, string.format(Config.TEXT.REDLIGHT_SHORT, names(short)))
	end
	ctx.show(if #lines > 0 then table.concat(lines, " · ") else Config.TEXT.REDLIGHT_ALL_SAFE)
	ctx.answers(pressed, never) -- (before the fail: a launched player's miss would not count)
	ctx.fail(losers, "redLight")
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return RedLight
