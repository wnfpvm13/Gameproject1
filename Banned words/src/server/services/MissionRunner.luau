--!strict
-- Missions (docs/DESIGN_V3.md §5, §13): picks the next mission that fits the time left and runs one at a time with a
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
	expectedSeconds: number, -- for the time budget, without the launches afterwards
	available: (final: boolean) -> boolean,
	run: (ctx: MissionCtx) -> (),
}

local MISSIONS: { Mission } = { TestMission }

-- The next main-game mission that still fits, launches included, in `secondsLeft`; nil if none does.
function MissionRunner.choose(secondsLeft: number): Mission?
	for _, mission in MISSIONS do
		if mission.available(false) and mission.expectedSeconds + Config.FLING_RETURN_SECONDS <= secondsLeft then
			return mission
		end
	end
	return nil
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
