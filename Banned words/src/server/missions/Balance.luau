--!strict
-- The balance game (docs/DESIGN_V3.md §5.2; bundle 6d): "A vs B". The bells of everyone on the ground open
-- BALANCE_BELL_SECONDS; the first BALANCE_TALKERS to ring argue in turn, each on the floor for BALANCE_TALK_SECONDS
-- (chat participants BALANCE_TALK_CHAT_SECONDS). Then everyone on the ground picks in secret within
-- BALANCE_PICK_SECONDS (a pick may change until then). The smaller side flies; a tie or everyone on one side: nobody.
-- Whoever did not pick flies too and missed an answer (the AFK rule).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local BalanceBank = require(script.Parent.Parent:WaitForChild("content"):WaitForChild("BalanceBank"))

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

local Balance = {
	id = "balance",
	title = Config.TEXT.BALANCE_TITLE,
	brief = Config.TEXT.BALANCE_BRIEF, -- (the briefing before it)
	expectedSeconds = Config.BALANCE_BELL_SECONDS + Config.BALANCE_TALKERS * Config.BALANCE_TALK_CHAT_SECONDS
		+ Config.BALANCE_PICK_SECONDS + Config.MINIGAME_RESULT_SECONDS,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.BALANCE_MIN_PLAYERS :: number?,
	needsPresenter = nil :: boolean?,
}

local function ground(ctx: Ctx): { Player }
	local list = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function names(list: { Player }): string
	local out = {}
	for _, player in list do
		table.insert(out, player.DisplayName)
	end
	return table.concat(out, ", ")
end

function Balance.available(final: boolean): boolean
	return not final and #BalanceBank > 0
end

-- Returns false when too few were on the ground to start.
function Balance.run(ctx: Ctx): boolean?
	local players = ground(ctx)
	if #players < Config.BALANCE_MIN_PLAYERS then
		return false
	end
	local question = BalanceBank[ctx.rng:NextInteger(1, #BalanceBank)]
	-- Too few left in the middle (leaves): the game ends with no penalty (§4).
	local function tooFew(): boolean
		local here = 0
		for _, player in players do
			if table.find(ctx.players(), player) then
				here += 1
			end
		end
		return here < Config.BALANCE_MIN_PLAYERS
	end
	local function endEarly(): nil
		ctx.screen(nil)
		ctx.show(Config.TEXT.MINIGAME_TOO_FEW)
		return nil
	end
	ctx.show(Config.TEXT.BALANCE_START)
	ctx.screen({ kind = "balance", stage = "bell", a = question.a, b = question.b,
		endsAt = Match.now() + Config.BALANCE_BELL_SECONDS })
	local talkers = math.min(Config.BALANCE_TALKERS, #players)
	local rung = ctx.bell(players, Config.BALANCE_BELL_SECONDS, false, function(rungNow: { Player }): boolean
		return #rungNow >= talkers -- (enough have rung: on to the talk)
	end)
	for i = 1, math.min(#rung, Config.BALANCE_TALKERS) do
		local talker = rung[i]
		if ctx.cancelled() then
			return nil
		end
		if tooFew() then
			return endEarly()
		end
		if table.find(ctx.players(), talker) and not ctx.flying(talker) then
			local p = Match.participants[talker]
			local seconds = if p and p.chat then Config.BALANCE_TALK_CHAT_SECONDS else Config.BALANCE_TALK_SECONDS
			ctx.screen({ kind = "balance", stage = "talk", a = question.a, b = question.b, ids = { talker.UserId },
				endsAt = Match.now() + seconds })
			ctx.show(string.format(Config.TEXT.BALANCE_TALK, talker.DisplayName))
			ctx.floor(talker)
			ctx.wait(seconds)
			ctx.floor(nil)
		end
	end
	if ctx.cancelled() then
		return nil
	end
	if tooFew() then
		return endEarly()
	end
	local pickers = ground(ctx)
	ctx.show(Config.TEXT.BALANCE_PICK)
	local picks = ctx.ask({ kind = "balance", stage = "pick", a = question.a, b = question.b,
		choices = { question.a, question.b }, changeable = true }, 2, Config.BALANCE_PICK_SECONDS, pickers)
	if ctx.cancelled() then
		return nil
	end
	if tooFew() then
		return endEarly()
	end
	local sideA: { Player }, sideB: { Player }, none: { Player } = {}, {}, {}
	for _, player in pickers do
		if table.find(ctx.players(), player) then
			local pick = picks[player]
			table.insert(if pick == 1 then sideA elseif pick == 2 then sideB else none, player)
		end
	end
	local losers: { Player } = table.clone(none)
	local text
	if #sideA > 0 and #sideB > 0 and #sideA ~= #sideB then
		local smaller: { Player } = if #sideA < #sideB then sideA else sideB
		for _, player in smaller do
			table.insert(losers, player)
		end
		text = string.format(Config.TEXT.BALANCE_COUNT, question.a, #sideA, question.b, #sideB)
	elseif #sideA > 0 and #sideA == #sideB then
		text = Config.TEXT.BALANCE_EVEN
	else
		text = Config.TEXT.BALANCE_SAME
	end
	if #none > 0 then
		text ..= " · " .. string.format(Config.TEXT.BALANCE_NONE, names(none))
	elseif #losers == 0 then
		text ..= " · " .. Config.TEXT.BALANCE_NOBODY
	end
	ctx.screen({ kind = "balanceResult", a = question.a, b = question.b, countA = #sideA, countB = #sideB })
	ctx.show(text)
	local answered = table.clone(sideA)
	for _, player in sideB do
		table.insert(answered, player)
	end
	ctx.answers(answered, none) -- (before the fail: a launched player's miss would not count)
	ctx.fail(losers, "balance")
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return Balance
