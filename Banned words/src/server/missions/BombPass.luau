--!strict
-- The bomb (docs/DESIGN_V3.md §5.2; bundle 6c, owner 2026-10-23; a pass button instead of a question, owner
-- 2026-10-25). Everyone on the ground stands in a ring drawn at the start (shown on screen; missions do not know the
-- seats). Whoever gets the bomb holds it a random BOMB_HOLD_MIN-MAX seconds with the button off, then "넘기기" lights
-- up and a press hands it to the next in the ring (skipping anyone who left or flies). It goes off after a hidden time
-- between BOMB_MIN_SECONDS and BOMB_MAX_SECONDS (no timer on screen: the time sent with the button is always
-- BOMB_MAX_SECONDS ahead, so it gives nothing away); only a press the server got before that counts; whoever holds it
-- then flies. A holder who leaves or flies hands it on at once. Who had the button lit for BOMB_IDLE_SECONDS and never
-- pressed missed an answer (the AFK rule).
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

local BombPass = {
	id = "bomb",
	title = Config.TEXT.BOMB_TITLE,
	brief = Config.TEXT.BOMB_BRIEF, -- (the briefing before it)
	expectedSeconds = Config.BOMB_MAX_SECONDS + Config.MINIGAME_RESULT_SECONDS,
	maxPerRound = Config.GAME_PER_ROUND :: number?,
	minPlayers = Config.BOMB_MIN_PLAYERS :: number?,
	needsPresenter = nil :: boolean?,
}

local function ids(list: { Player }): { number }
	local out = {}
	for _, player in list do
		table.insert(out, player.UserId)
	end
	return out
end

function BombPass.available(final: boolean): boolean
	return not final
end

-- Returns false when too few were on the ground to start.
function BombPass.run(ctx: Ctx): boolean?
	local ring = {}
	for _, player in ctx.players() do
		if not ctx.flying(player) then
			table.insert(ring, player)
		end
	end
	if #ring < Config.BOMB_MIN_PLAYERS then
		return false
	end
	for i = #ring, 2, -1 do
		local j = ctx.rng:NextInteger(1, i)
		ring[i], ring[j] = ring[j], ring[i]
	end
	local function holding(index: number): boolean
		local player = ring[index]
		return table.find(ctx.players(), player) ~= nil and not ctx.flying(player)
	end
	-- The next one in the ring from `index` (itself first when `including`) who can hold it; nil if nobody can.
	local function nextFrom(index: number, including: boolean): number?
		for step = if including then 0 else 1, #ring do
			local candidate = (index - 1 + step) % #ring + 1
			if holding(candidate) then
				return candidate
			end
		end
		return nil
	end
	ctx.show(Config.TEXT.BOMB_START)
	local deadline = os.clock() + ctx.rng:NextNumber(Config.BOMB_MIN_SECONDS, Config.BOMB_MAX_SECONDS)
	local holder: number? = 1
	local held: { [Player]: boolean } = {}
	local answered: { [Player]: boolean } = {}
	while os.clock() < deadline do
		holder = nextFrom(holder or 1, true)
		if not holder then
			return nil -- (nobody left to hold it)
		end
		local player = ring[holder]
		ctx.show(string.format(Config.TEXT.BOMB_HOLDER, player.DisplayName))
		local shown = { kind = "bomb", ids = ids(ring), holder = holder, choices = { Config.TEXT.BOMB_PASS },
			shownEndsAt = Match.now() + Config.BOMB_MAX_SECONDS }
		ctx.screen(shown) -- (the button is off while the bomb is fresh)
		local lockEnds = math.min(deadline, os.clock() + ctx.rng:NextNumber(Config.BOMB_HOLD_MIN, Config.BOMB_HOLD_MAX))
		while os.clock() < lockEnds and not ctx.cancelled() and holding(holder) do
			ctx.wait(math.min(0.1, lockEnds - os.clock()))
		end
		if ctx.cancelled() then
			return nil
		end
		if holding(holder) and os.clock() < deadline then
			-- (presses are taken until the bomb goes off at the latest)
			local opened = os.clock()
			local answers = ctx.ask(shown, 1, deadline - opened, { player })
			if ctx.cancelled() then
				return nil
			end
			if answers[player] then
				answered[player] = true
				held[player] = true
				holder = nextFrom(holder, false) or holder
			elseif os.clock() - opened >= Config.BOMB_IDLE_SECONDS - 0.05 and holding(holder) then
				held[player] = true -- (the button lit long enough and no press: it counts; cut short by a flight it does not)
			end
		end
	end
	holder = if holder then nextFrom(holder, true) else nil
	if not holder then
		return nil
	end
	local loser = ring[holder]
	local yes, no = {}, {}
	for player in held do
		table.insert(if answered[player] then yes else no, player)
	end
	ctx.screen({ kind = "bombResult", ids = ids(ring), holder = holder })
	ctx.show(string.format(Config.TEXT.BOMB_BOOM, loser.DisplayName))
	ctx.answers(yes, no) -- (before the fail: a launched player's miss would not count)
	ctx.fail({ loser }, "boom")
	ctx.reveal(Config.MINIGAME_RESULT_SECONDS)
	return nil
end

return BombPass
