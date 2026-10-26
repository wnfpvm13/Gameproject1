--!strict
-- The roulette (docs/DESIGN_V3.md §5; bundle 4a, owner 2026-10-23: a 2D wheel on the screen): the server picks one
-- alive player at random and everyone's screen spins to that name (a coin for two players). The one picked fails.
-- Once a round; players flying when it starts are not on the wheel.
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

local Roulette = {
	id = "roulette",
	title = Config.TEXT.ROULETTE_TITLE,
	brief = Config.TEXT.ROULETTE_BRIEF, -- (the briefing before it)
	expectedSeconds = Config.ROULETTE_SPIN_SECONDS + Config.ROULETTE_REVEAL_SECONDS,
	expectedFor = nil :: ((players: number) -> number)?,
	maxPerRound = Config.ROULETTE_PER_ROUND :: number?,
	minPlayers = Config.ROULETTE_MIN_PLAYERS :: number?,
	needsPresenter = nil :: boolean?,
}

function Roulette.available(final: boolean): boolean
	return not final
end

-- Returns false when too few were on the ground to start (it does not count as a game, like the others).
function Roulette.run(ctx: Ctx): boolean?
	local wheel = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(wheel, player)
		end
	end
	if #wheel < Config.ROULETTE_MIN_PLAYERS then
		return false
	end
	local index = ctx.rng:NextInteger(1, #wheel)
	local ids = {}
	for _, player in wheel do
		table.insert(ids, player.UserId)
	end
	ctx.show(Config.TEXT.ROULETTE_START)
	ctx.screen({ kind = "roulette", ids = ids, pick = index, startsAt = Match.now(),
		spinSeconds = Config.ROULETTE_SPIN_SECONDS })
	if not ctx.wait(Config.ROULETTE_SPIN_SECONDS) then
		return nil
	end
	local picked = wheel[index]
	ctx.show(string.format(Config.TEXT.ROULETTE_HIT, picked.DisplayName))
	ctx.fail({ picked }, "spin")
	ctx.reveal(Config.ROULETTE_REVEAL_SECONDS) -- the wheel stays on the name, also when this decided the round
	return nil
end

return Roulette
