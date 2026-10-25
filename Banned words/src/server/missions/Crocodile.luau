--!strict
-- Crocodile teeth (docs/DESIGN_V3.md §5.2; bundle 6c, owner 2026-10-23). Everyone on the ground takes turns in an
-- order drawn at the start; on their turn a player presses one of CROC_TEETH teeth on screen within
-- CROC_TURN_SECONDS. One tooth, hidden on the server, bites: whoever presses it flies, and so does a player whose time
-- runs out (an answer the AFK rule counts). A tooth pressed once stays down (a press on it is ignored and the turn
-- goes on), so at most CROC_TEETH - 1 safe presses can happen: it always ends with someone. A player who left or flies
-- when their turn comes, or during it, is skipped (no tooth goes down); a cap of CROC_TEETH turns' time keeps the
-- whole game within its time budget (past it, nobody flies).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))

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

local Crocodile = {
	id = "croc",
	title = Config.TEXT.CROC_TITLE,
	brief = Config.TEXT.CROC_BRIEF, -- (the briefing before it)
	-- The longest run (capped in `run`): CROC_TEETH turns at the last moment, then the result.
	expectedSeconds = Config.CROC_TEETH * Config.CROC_TURN_SECONDS + Config.MINIGAME_RESULT_SECONDS,
	expectedFor = nil :: ((players: number) -> number)?,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.CROC_MIN_PLAYERS :: number?,
	needsPresenter = nil :: boolean?,
}

local function ids(list: { Player }): { number }
	local out = {}
	for _, player in list do
		table.insert(out, player.UserId)
	end
	return out
end

-- Everyone on the ground, in a random order.
local function drawOrder(ctx: Ctx): { Player }
	local order = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(order, player)
		end
	end
	for i = #order, 2, -1 do
		local j = ctx.rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	return order
end

function Crocodile.available(final: boolean): boolean
	return not final
end

-- Returns false when too few were on the ground to start.
function Crocodile.run(ctx: Ctx): boolean?
	local order = drawOrder(ctx)
	if #order < Config.CROC_MIN_PLAYERS then
		return false
	end
	ctx.show(Config.TEXT.CROC_START)
	local bad = ctx.rng:NextInteger(1, Config.CROC_TEETH)
	local down: { boolean } = table.create(Config.CROC_TEETH, false)
	local answered: { Player } = {}
	local loser: Player? = nil
	local late = false
	local index = 0
	local skipped = 0
	local capAt = os.clock() + Config.CROC_TEETH * Config.CROC_TURN_SECONDS
	while not loser do
		if os.clock() >= capAt then
			return nil -- (turns kept being skipped: the time budget is up, nobody flies)
		end
		index = index % #order + 1
		local player = order[index]
		if not table.find(ctx.players(), player) or ctx.flying(player) then
			skipped += 1
			if skipped >= #order then
				return nil -- (nobody left to take a turn)
			end
			continue
		end
		skipped = 0
		ctx.show(string.format(Config.TEXT.CROC_TURN, player.DisplayName))
		-- A press on a tooth already down is ignored: the turn goes on for the time left.
		local turnEnds = math.min(os.clock() + Config.CROC_TURN_SECONDS, capAt)
		local tooth: number? = nil
		repeat
			local answers = ctx.ask({ kind = "croc", ids = ids(order), current = index, down = table.clone(down) },
				Config.CROC_TEETH, math.max(0, turnEnds - os.clock()), { player })
			if ctx.cancelled() then
				return nil
			end
			local pressed = answers[player]
			if pressed and not down[pressed] then
				tooth = pressed
			end
		until tooth or not answers[player] or os.clock() >= turnEnds
		if not table.find(ctx.players(), player) or ctx.flying(player) then
			continue -- (left or flew during the turn: skipped, nothing goes down)
		end
		if tooth == nil then
			if os.clock() >= capAt then
				return nil -- (the time budget ran out during this turn: nobody flies)
			end
			loser, late = player, true
			continue
		end
		if not table.find(answered, player) then
			table.insert(answered, player)
		end
		down[tooth] = true
		if tooth == bad then
			loser = player
		end
	end
	local who = loser :: Player
	ctx.screen({ kind = "crocResult", ids = ids(order), down = down, bad = bad, loser = table.find(order, who), late = late })
	ctx.show(string.format(if late then Config.TEXT.CROC_LATE else Config.TEXT.CROC_BITE, who.DisplayName))
	ctx.answers(answered, if late then { who } else {}) -- (before the fail: a launched player's miss would not count)
	ctx.fail({ who }, "bite")
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return Crocodile
