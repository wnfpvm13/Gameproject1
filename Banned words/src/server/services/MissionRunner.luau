--!strict
-- Missions (docs/DESIGN_V3.md §5, §13): lists the missions that may run next (recommended order, also the presenter's
-- menu), picks the next one that fits the time left (the presenter's pick, else at random: missions played less this
-- round are likelier and the one just played is skipped when another fits) and runs one at a time with a
-- ctx (missions cannot require services, so everything they may do comes through the ctx RoundService builds). A
-- mission stops as soon as it is cancelled (the round was decided or is over): its waits wake up and its fails and
-- notices are dropped. Only this service requires the modules under server/missions (tools/tests/check_deps.py
-- checks it). It alone listens to the answer remote ("MissionAnswer") and hands answers to the running mission's
-- question (docs/DESIGN_V3.md §13: Net.listen cannot disconnect, so missions never listen themselves). What a mission
-- shows on everyone's screen goes out as "Mission" and is sent again on Sync.
-- Bundle 4: the quiz (also the final), the roulette, "say what you like" (4b, bells since 6b); bundle 6a: the
-- banned-word talk (only while speech judging is on); bundle 6b: the bell quiz (only with a presenter); and the
-- Studio-only test mission.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local missionFolder = script.Parent.Parent:WaitForChild("missions")
local Quiz = require(missionFolder:WaitForChild("Quiz"))
local Roulette = require(missionFolder:WaitForChild("Roulette"))
local OneWord = require(missionFolder:WaitForChild("OneWord"))
local BannedTalk = require(missionFolder:WaitForChild("BannedTalk"))
local TestMission = require(missionFolder:WaitForChild("TestMission"))

local MissionRunner = {}

local POLL = 0.2 -- seconds between "cancelled yet?" checks while a mission waits

-- What RoundService gives for one run.
export type Ctx = {
	final: boolean, -- a final question (sudden death) instead of a main-game mission
	players: () -> { Player }, -- the alive participants now
	rng: Random,
	-- Who failed the mission's event `key` (one penalty per event: the same key never costs a player twice);
	-- RoundService turns that into lives and launches. `subjective`: the presenter or a vote decided (limits apply).
	fail: (players: { Player }, key: string, subjective: boolean?) -> (),
	show: (text: string) -> (), -- the status line and a toast
	cancelled: () -> boolean, -- the round was decided or another one began: stop
	stopped: () -> boolean, -- another round began (or the round broke): not even a result may stay on screen
	flying: (player: Player) -> boolean, -- launched and not back yet (cannot answer, takes no penalty)
	-- An answer mission closed: who answered and who did not (the AFK rule, docs/DESIGN_V3.md §4).
	answers: (answered: { Player }, missed: { Player }) -> (),
	canFling: (player: Player) -> boolean, -- a subjective launch may hit them now (public limits, not flying)
	-- The presenter picks one of `options` within `seconds` (nil: none in time, no presenter, or the round is over).
	presenterPick: (options: { Option }, seconds: number) -> string?,
	-- The banned-word talk's stage (docs/DESIGN_V3.md §6): "prep" (words drawn avoiding `topic`, shown, chat rules on)
	-- or "talk" (judged from now on). RoundService runs the settle stage after the mission, whatever happened.
	talk: (stage: string, topic: string?) -> (),
	-- The presenter's re-draw window: waits `seconds` or until they press "start now"; false if cancelled meanwhile.
	presenterReroll: (seconds: number) -> boolean,
	-- The seat bells of `from` open for `seconds` (bundle 6b): who rang, first to last (`firstOnly`: closes at the first).
	bell: (from: { Player }, seconds: number, firstOnly: boolean) -> { Player },
	-- The floor (§5.1): only `player` (and the presenter) heard by everyone, alive players receive only their chat;
	-- nil ends it. RoundService ends it after every mission too.
	floor: (player: Player?) -> (),
	-- The presenter judges an answer (the bell quiz): "right", "wrong", or nil (none in time, no presenter, over).
	presenterVerdict: (answer: string, seconds: number) -> string?,
	score: (player: Player, amount: number) -> (), -- session points (a right bell-quiz answer)
}

-- What a mission gets: the same, with fail/show that do nothing once cancelled, and wait().
export type MissionCtx = {
	final: boolean,
	players: () -> { Player },
	rng: Random,
	fail: (players: { Player }, key: string, subjective: boolean?) -> (),
	show: (text: string) -> (),
	cancelled: () -> boolean,
	stopped: () -> boolean,
	-- Waits `seconds`; returns false at once if the mission is cancelled meanwhile (then the mission should return).
	wait: (seconds: number) -> boolean,
	-- Keeps a result already given on screen for `seconds`, also when that result decided the round (only a new round
	-- cuts it short).
	reveal: (seconds: number) -> (),
	flying: (player: Player) -> boolean,
	answers: (answered: { Player }, missed: { Player }) -> (),
	-- Everyone's mission screen (a table with `kind`; nil clears it). Cleared when the mission ends.
	screen: (payload: { [string]: any }?) -> (),
	-- Shows `payload` (with `endsAt` and the question number `id` added) and collects one answer (a choice
	-- 1..`choices`, sent with that number) from each of `from` for `seconds`, or until all of them still alive answered
	-- or the mission is cancelled. Returns the answers.
	ask: (payload: { [string]: any }, choices: number, seconds: number, from: { Player }) -> { [Player]: number },
	canFling: (player: Player) -> boolean,
	presenterPick: (options: { Option }, seconds: number) -> string?,
	lever: () -> (), -- everyone sees the podium lever pulled (the presenter's launch)
	talk: (stage: string, topic: string?) -> (),
	presenterReroll: (seconds: number) -> boolean,
	bell: (from: { Player }, seconds: number, firstOnly: boolean) -> { Player },
	floor: (player: Player?) -> (),
	presenterVerdict: (answer: string, seconds: number) -> string?,
	score: (player: Player, amount: number) -> (),
}

export type Mission = {
	id: string,
	title: string, -- shown in the presenter's menu
	expectedSeconds: number, -- for the time budget, without the launches afterwards
	maxPerRound: number?, -- nil = no limit (docs/DESIGN_V3.md §5: the quiz; others 2, the roulette 1)
	minPlayers: number?, -- alive participants it needs (nil = any)
	needsPresenter: boolean?, -- offered only while someone presents (the one-word mission)
	available: (final: boolean) -> boolean,
	run: (ctx: MissionCtx) -> boolean?, -- false: it had nothing to play (a quiz with no clean question left)
}

-- An entry of a presenter's menu.
export type Option = { id: string, title: string, recommended: boolean }

local MISSIONS: { Mission } = { Quiz, Quiz.bell, Roulette, OneWord, BannedTalk, TestMission }

local played: { [string]: number } = {} -- main-game runs this round, per mission id
local screenNow: { [string]: any }? = nil -- what the running mission shows (sent again on Sync)
-- The open question: its number, who may answer, how many choices, until when (server time), the answers so far.
type Question = { id: number, from: { [Player]: boolean }, choices: number, endsAt: number, answers: { [Player]: number } }
local question: Question? = nil
local questions = 0 -- question numbers so far (an answer sent for an older question never counts for a newer one)

local function fits(mission: Mission, secondsLeft: number): boolean
	return mission.expectedSeconds + Config.FLING_RETURN_SECONDS <= secondsLeft
end

-- A new round: nothing played yet.
function MissionRunner.beginRound()
	table.clear(played)
end

-- The main-game missions that may run now, in recommended order (not played yet this round first): available, under
-- their per-round limit, enough players for them, a presenter if they need one, and fitting `secondsLeft` with the
-- launches.
function MissionRunner.candidates(secondsLeft: number, alive: number, presenter: boolean): { Mission }
	local list = {}
	for _, mission in MISSIONS do
		local count = played[mission.id] or 0
		if mission.available(false) and fits(mission, secondsLeft) and (mission.maxPerRound == nil or count < mission.maxPerRound)
			and alive >= (mission.minPlayers or 0) and (presenter or not mission.needsPresenter) then
			table.insert(list, mission)
		end
	end
	local position: { [Mission]: number } = {}
	for i, mission in list do
		position[mission] = i
	end
	table.sort(list, function(a, b)
		local pa, pb = played[a.id] or 0, played[b.id] or 0
		if pa ~= pb then
			return pa < pb
		end
		return position[a] < position[b]
	end)
	return list
end

-- The presenter's menu for the same choice.
function MissionRunner.options(secondsLeft: number, alive: number): { Option }
	local options = {}
	for i, mission in MissionRunner.candidates(secondsLeft, alive, true) do
		table.insert(options, { id = mission.id, title = mission.title, recommended = i <= Config.PRESENTER_RECOMMENDED })
	end
	return options
end

-- The next main-game mission: `pickedId` if it may still run, else one at random (docs/DESIGN_V3.md §5.1): weight
-- 1 / (1 + runs this round), and not `lastId` (the one just played) while another one fits. nil if none fits.
-- `presenter`: someone presents now.
function MissionRunner.choose(secondsLeft: number, alive: number, presenter: boolean, pickedId: string?, rng: Random,
	lastId: string?): Mission?
	local list = MissionRunner.candidates(secondsLeft, alive, presenter)
	for _, mission in list do
		if mission.id == pickedId then
			return mission
		end
	end
	if #list > 1 and lastId then
		for i, mission in list do
			if mission.id == lastId then
				table.remove(list, i)
				break
			end
		end
	end
	local total = 0
	for _, mission in list do
		total += 1 / (1 + (played[mission.id] or 0))
	end
	local roll = rng:NextNumber() * total
	for _, mission in list do
		roll -= 1 / (1 + (played[mission.id] or 0))
		if roll <= 0 then
			return mission
		end
	end
	return list[#list]
end

-- A mission that can ask final questions, or nil (then the survivors share the win).
function MissionRunner.finalMission(): Mission?
	for _, mission in MISSIONS do
		if mission.available(true) then
			return mission
		end
	end
	return nil
end

local function setScreen(payload: { [string]: any }?)
	screenNow = payload
	Net.toAll("Mission", payload or { kind = "none" })
end

local function waitOrCancel(ctx: Ctx, seconds: number, done: (() -> boolean)?, stop: (() -> boolean)?): boolean
	local untilAt = os.clock() + seconds
	local stopNow = stop or ctx.cancelled
	while os.clock() < untilAt do
		if stopNow() then
			return false
		end
		if done and done() then
			return true
		end
		task.wait(math.min(POLL, untilAt - os.clock()))
	end
	return not stopNow()
end

local function missionCtx(ctx: Ctx): MissionCtx
	return {
		final = ctx.final,
		players = ctx.players,
		rng = ctx.rng,
		cancelled = ctx.cancelled,
		stopped = ctx.stopped,
		flying = ctx.flying,
		answers = function(answered: { Player }, missed: { Player })
			if not ctx.cancelled() then
				ctx.answers(answered, missed)
			end
		end,
		screen = function(payload: { [string]: any }?)
			if not ctx.cancelled() then
				setScreen(payload)
			end
		end,
		ask = function(payload: { [string]: any }, choices: number, seconds: number, from: { Player }): { [Player]: number }
			questions += 1
			local open: Question = { id = questions, from = {}, choices = choices, endsAt = Match.now() + seconds, answers = {} }
			for _, player in from do
				open.from[player] = true
			end
			question = open
			local shown = table.clone(payload)
			shown.endsAt = open.endsAt
			shown.id = open.id
			if not ctx.cancelled() then
				setScreen(shown)
			end
			waitOrCancel(ctx, seconds, function()
				local alive = ctx.players()
				for player in open.from do
					if not open.answers[player] and table.find(alive, player) then
						return false -- (someone who left or went out meanwhile is not waited for)
					end
				end
				return true
			end)
			if question == open then
				question = nil
			end
			return open.answers
		end,
		fail = function(players: { Player }, key: string, subjective: boolean?)
			if not ctx.cancelled() then
				ctx.fail(players, key, subjective)
			end
		end,
		canFling = ctx.canFling,
		presenterPick = function(options: { Option }, seconds: number): string?
			if ctx.cancelled() then
				return nil
			end
			return ctx.presenterPick(options, seconds)
		end,
		lever = function()
			if not ctx.cancelled() then
				Net.toAll("Lever", {})
			end
		end,
		talk = function(stage: string, topic: string?)
			if not ctx.cancelled() then
				ctx.talk(stage, topic)
			end
		end,
		presenterReroll = function(seconds: number): boolean
			if ctx.cancelled() then
				return false
			end
			return ctx.presenterReroll(seconds)
		end,
		bell = function(from: { Player }, seconds: number, firstOnly: boolean): { Player }
			if ctx.cancelled() then
				return {}
			end
			return ctx.bell(from, seconds, firstOnly)
		end,
		floor = ctx.floor, -- (also after a cancel: the floor must always be given back)
		presenterVerdict = function(answer: string, seconds: number): string?
			if ctx.cancelled() then
				return nil
			end
			return ctx.presenterVerdict(answer, seconds)
		end,
		score = function(player: Player, amount: number)
			if not ctx.cancelled() then
				ctx.score(player, amount)
			end
		end,
		show = function(text: string)
			if not ctx.cancelled() then
				ctx.show(text)
			end
		end,
		wait = function(seconds: number): boolean
			return waitOrCancel(ctx, seconds, nil)
		end,
		reveal = function(seconds: number)
			waitOrCancel(ctx, seconds, nil, ctx.stopped)
		end,
	}
end

-- Runs one mission to its end. Returns false if it raised an error (reported; that run is over), and whether it
-- played (false when it had nothing to play).
function MissionRunner.run(mission: Mission, ctx: Ctx): (boolean, boolean)
	if not ctx.final then
		played[mission.id] = (played[mission.id] or 0) + 1
	end
	local runCtx = missionCtx(ctx)
	local didPlay = true
	local ok, err = pcall(function(): any
		didPlay = mission.run(runCtx) ~= false
		return nil -- one return value, so the type checker reads pcall's results as (ok, error)
	end)
	if not ok then
		warn("[BannedWords] mission " .. mission.id .. " failed:", err)
	end
	question = nil
	if screenNow then
		setScreen(nil)
	end
	return ok, didPlay
end

-- Answers to the open question: its number, a whole number in 1..choices, from someone asked, before the end; the
-- first one counts.
function MissionRunner.start()
	Net.listen("MissionAnswer", function(player, id, choice)
		local open = question
		if not open or id ~= open.id or not open.from[player] or open.answers[player] or typeof(choice) ~= "number" then
			return
		end
		if Match.now() > open.endsAt then
			return
		end
		if choice % 1 == 0 and choice >= 1 and choice <= open.choices then
			open.answers[player] = choice
		end
	end)
end

-- The texts on the mission screen now (a question and its choices, a topic): a new banned word must not appear in
-- them (docs/DESIGN_V3.md §6).
function MissionRunner.screenTexts(): { string }
	local texts = {}
	local shown = screenNow
	if shown then
		for _, key in { "question", "topic" } do
			if typeof(shown[key]) == "string" then
				table.insert(texts, shown[key])
			end
		end
		if typeof(shown.choices) == "table" then
			for _, choice in shown.choices do
				table.insert(texts, tostring(choice))
			end
		end
		if typeof(shown.ids) == "table" then -- names on the wheel, the performers, the vote (shown by name)
			for _, userId in shown.ids do
				local player = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
				if player then
					table.insert(texts, player.DisplayName)
				end
			end
		end
	end
	return texts
end

-- A player asked for the whole state again: the mission screen too.
function MissionRunner.sendScreen(player: Player)
	if screenNow then
		Net.to(player, "Mission", screenNow)
	end
end

return MissionRunner
