--!strict
-- Each driver's run toward the low bridges, judged on the server. The run's clock lives on the locomotive as
-- attributes (Names.RunStart/RunFrom/RunSpeed), so every client draws the same moving world from the shared server
-- time. The driver's client judges each bridge at once from the real squash shape and reports it: a hit is taken as
-- it is; a pass is checked, once the bridge has gone by, against the squash states the server received
-- (Config.Run.PassTolerance and ReleaseGrace allow for the network delay and the body's rise); a bridge nobody
-- reports is judged the same way once it is well past. A hit holds the run for the crash gag, then the run goes again
-- from a little before that bridge.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CourseMath = require(shared:WaitForChild("CourseMath"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local CourseService = {}

export type Service = {
	begin: (player: Player, locomotive: Model) -> (), -- a new locomotive: its run starts after Config.Run.StartDelay
	finish: (player: Player) -> (),
	stop: () -> (),
}

type State = {
	locomotive: Model,
	run: CourseMath.Run,
	front: number, -- the locomotive's ends in its own Z (Names.SpanFront/SpanBack)
	back: number,
	next: number, -- the bridge waiting to be judged
	reported: boolean, -- the driver said "passed" for it: judged soon after it has gone by
	history: { CourseMath.Change },
	crashed: boolean,
	generation: number, -- bumped by every crash, so an old restart timer does nothing
	watch: RBXScriptConnection,
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function count(locomotive: Model, name: string)
	locomotive:SetAttribute(name, (PartUtil.number(locomotive, name) or 0) + 1)
end

-- The three run values, then the version last: a client reads all three when the version changes.
local function publish(state: State)
	local locomotive = state.locomotive
	locomotive:SetAttribute(Names.RunStart, state.run.start)
	locomotive:SetAttribute(Names.RunFrom, state.run.from)
	locomotive:SetAttribute(Names.RunSpeed, state.run.speed)
	count(locomotive, Names.RunVersion)
end

function CourseService.start(remote: RemoteEvent): Service
	local run, bridges = Config.Run, Config.Bridge
	local states: { [Player]: State } = {}

	local function bridgeAt(i: number): number
		return CourseMath.bridgeAt(i, bridges.FirstAt, bridges.Gaps)
	end
	local function window(state: State, i: number): (number, number)
		return CourseMath.under(bridgeAt(i), bridges.Depth, state.front, state.back)
	end

	local function crash(player: Player, state: State, index: number, distance: number)
		state.crashed = true
		state.generation += 1
		local generation = state.generation
		state.run = { start = now(), from = distance, speed = 0 }
		publish(state)
		count(state.locomotive, Names.Crashes)
		state.locomotive:SetAttribute(Names.CrashIndex, index)
		task.delay(run.CrashSeconds, function()
			if states[player] ~= state or state.generation ~= generation then
				return
			end
			state.crashed = false
			state.next = index -- the same bridge again
			state.reported = false
			state.run = { start = now() + run.ResumeDelay, from = bridgeAt(index) - run.RestartLead, speed = run.Speed }
			state.locomotive:SetAttribute(Names.CrashIndex, 0)
			publish(state)
		end)
	end

	-- A pass stands when the server saw the locomotive flat for the whole time the bridge was over it, allowing for
	-- the delay before a press reached the server and for a release in the last moment (the body is still low then);
	-- otherwise the front hit the bridge.
	local function judge(player: Player, state: State, index: number)
		local enter, exit = window(state, index)
		local from = CourseMath.timeAt(state.run, enter) + run.PassTolerance
		local to = CourseMath.timeAt(state.run, exit) - run.ReleaseGrace
		state.reported = false
		if CourseMath.squashedThroughout(state.history, from, to) then
			state.next = index + 1
			count(state.locomotive, Names.Passed)
		else
			crash(player, state, index, enter)
		end
	end

	local received = remote.OnServerEvent:Connect(function(player: Player, index: unknown, hit: unknown, distance: unknown)
		local state = states[player]
		if not state or state.crashed or typeof(index) ~= "number" or typeof(hit) ~= "boolean" or index ~= state.next then
			return
		end
		local enter, exit = window(state, index)
		if hit then
			-- Not before the front can have reached the bridge (small clock differences allowed).
			if now() >= CourseMath.timeAt(state.run, enter) - run.PassTolerance then
				local at = if typeof(distance) == "number" and distance == distance then distance else enter
				crash(player, state, index, math.clamp(at, enter, exit))
			end
		else
			state.reported = true -- judged by the ticker below once the bridge has gone by and the history is in
		end
	end)

	-- Bridges are judged once they have gone by and the squash states sent until then have had time to arrive
	-- (PassTolerance) when the driver said "passed"; later (ReportTimeout) when they said nothing (a slow or quiet
	-- client).
	local ticking = RunService.Heartbeat:Connect(function()
		local t = now()
		for player, state in states do
			if not state.crashed and state.run.speed > 0 then
				local _, exit = window(state, state.next)
				local passedAt = CourseMath.timeAt(state.run, exit)
				if t >= passedAt + (if state.reported then run.PassTolerance else run.ReportTimeout) then
					judge(player, state, state.next)
				end
			end
		end
	end)

	local function finish(player: Player)
		local state = states[player]
		states[player] = nil
		if state then
			state.watch:Disconnect()
		end
	end

	local function begin(player: Player, locomotive: Model)
		finish(player)
		local history = { { time = now(), squashed = locomotive:GetAttribute(Names.Squashed) == true } }
		local state: State = {
			locomotive = locomotive,
			run = { start = now() + run.StartDelay, from = 0, speed = run.Speed },
			front = PartUtil.number(locomotive, Names.SpanFront) or 0,
			back = PartUtil.number(locomotive, Names.SpanBack) or 0,
			next = 1,
			reported = false,
			history = history,
			crashed = false,
			generation = 0,
			watch = locomotive:GetAttributeChangedSignal(Names.Squashed):Connect(function()
				table.insert(history, { time = now(), squashed = locomotive:GetAttribute(Names.Squashed) == true })
				-- Keep the last state before the kept span: it is the state at the span's start.
				while #history > 1 and history[2].time < now() - run.HistorySeconds do
					table.remove(history, 1)
				end
			end),
		}
		states[player] = state
		locomotive:SetAttribute(Names.CrashIndex, 0)
		locomotive:SetAttribute(Names.Passed, 0)
		locomotive:SetAttribute(Names.Crashes, 0)
		publish(state)
	end

	return {
		begin = begin,
		finish = finish,
		stop = function()
			received:Disconnect()
			ticking:Disconnect()
			for player in states do
				finish(player)
			end
		end,
	}
end

return CourseService
