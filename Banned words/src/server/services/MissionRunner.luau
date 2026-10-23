--!strict
-- Missions (docs/DESIGN_V3.md §5, §13): lists the missions that may run next (recommended order, also the presenter's
-- menu), picks the next mission that fits the time left and runs one at a time with a
-- ctx (missions cannot require services, so everything they may do comes through the ctx RoundService builds). A
-- mission stops as soon as it is cancelled (the round was decided or is over): its waits wake up and its fails and
-- notices are dropped. Only this service requires the modules under server/missions (tools/tests/check_deps.py
-- checks it). Bundle 2b has one mission, the Studio-only test mission, so the round flow can be tried before the
-- real missions (bundle 4).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local missionFolder = script.Parent.Parent:WaitForChild("missions")
local TestMission = require(missionFolder:WaitForChild("TestMission"))

local MissionRunner = {}

local POLL = 0.2 -- seconds between "cancelled yet?" checks while a mission waits

-- What RoundService gives for one run.
export type Ctx = {
	final: boolean, -- a final question (sudden death) instead of a main-game mission
	players: () -> { Player }, -- the alive participants now
	rng: Random,
	-- Who failed the mission's event `key` (one penalty per event: the same key never costs a player twice);
	-- RoundService turns that into lives and launches.
	fail: (players: { Player }, key: string) -> (),
	show: (text: string) -> (), -- the status line and a toast
	cancelled: () -> boolean, -- the round was decided or another one began: stop
}

-- What a mission gets: the same, with fail/show that do nothing once cancelled, and wait().
export type MissionCtx = {
	final: boolean,
	players: () -> { Player },
	rng: Random,
	fail: (players: { Player }, key: string) -> (),
	show: (text: string) -> (),
	cancelled: () -> boolean,
	-- Waits `seconds`; returns false at once if the mission is cancelled meanwhile (then the mission should return).
	wait: (seconds: number) -> boolean,
}

export type Mission = {
	id: string,
	title: string, -- shown in the presenter's menu
	expectedSeconds: number, -- for the time budget, without the launches afterwards
	maxPerRound: number?, -- nil = no limit (docs/DESIGN_V3.md §5: the quiz; others 2, the roulette 1)
	minPlayers: number?, -- alive participants it needs (nil = any)
	available: (final: boolean) -> boolean,
	run: (ctx: MissionCtx) -> (),
}

-- An entry of the presenter's menu.
export type Option = { id: string, title: string, recommended: boolean }

local MISSIONS: { Mission } = { TestMission }

local played: { [string]: number } = {} -- main-game runs this round, per mission id

local function fits(mission: Mission, secondsLeft: number): boolean
	return mission.expectedSeconds + Config.FLING_RETURN_SECONDS <= secondsLeft
end

-- A new round: nothing played yet.
function MissionRunner.beginRound()
	table.clear(played)
end

-- The main-game missions that may run now, in recommended order (not played yet this round first): available, under
-- their per-round limit, enough players for them, and fitting `secondsLeft` with the launches.
function MissionRunner.candidates(secondsLeft: number, alive: number): { Mission }
	local list = {}
	for _, mission in MISSIONS do
		local count = played[mission.id] or 0
		if mission.available(false) and fits(mission, secondsLeft) and (mission.maxPerRound == nil or count < mission.maxPerRound)
			and alive >= (mission.minPlayers or 0) then
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
	for i, mission in MissionRunner.candidates(secondsLeft, alive) do
		table.insert(options, { id = mission.id, title = mission.title, recommended = i <= Config.PRESENTER_RECOMMENDED })
	end
	return options
end

-- The next main-game mission: `pickedId` if it may still run, else the top recommendation; nil if none fits.
function MissionRunner.choose(secondsLeft: number, alive: number, pickedId: string?): Mission?
	local list = MissionRunner.candidates(secondsLeft, alive)
	for _, mission in list do
		if mission.id == pickedId then
			return mission
		end
	end
	return list[1]
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

local function missionCtx(ctx: Ctx): MissionCtx
	return {
		final = ctx.final,
		players = ctx.players,
		rng = ctx.rng,
		cancelled = ctx.cancelled,
		fail = function(players: { Player }, key: string)
			if not ctx.cancelled() then
				ctx.fail(players, key)
			end
		end,
		show = function(text: string)
			if not ctx.cancelled() then
				ctx.show(text)
			end
		end,
		wait = function(seconds: number): boolean
			local untilAt = os.clock() + seconds
			while os.clock() < untilAt do
				if ctx.cancelled() then
					return false
				end
				task.wait(math.min(POLL, untilAt - os.clock()))
			end
			return not ctx.cancelled()
		end,
	}
end

-- Runs one mission to its end. Returns false if it raised an error (reported; that run is over).
function MissionRunner.run(mission: Mission, ctx: Ctx): boolean
	if not ctx.final then
		played[mission.id] = (played[mission.id] or 0) + 1
	end
	local runCtx = missionCtx(ctx)
	local ok, err = pcall(function(): any
		mission.run(runCtx)
		return nil -- one return value, so the type checker reads pcall's results as (ok, error)
	end)
	if not ok then
		warn("[BannedWords] mission " .. mission.id .. " failed:", err)
	end
	return ok
end

return MissionRunner
