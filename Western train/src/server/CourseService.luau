--!strict
-- Each train's run toward the low bridges, judged on the server. The run's clock lives on the locomotive as
-- attributes (Names.RunStart/RunFrom/RunSpeed), so every client draws the same moving world from the shared server
-- time. The driver's client judges each bridge at once from the real squash shape and reports it: a hit is taken as
-- it is; a pass is checked, once the bridge has gone by, against the squash states the server received
-- (Config.Run.PassTolerance and ReleaseGrace allow for the network delay and the body's rise); a bridge nobody
-- reports is judged the same way once it is well past. A hit holds the run for the crash gag, then the run goes again
-- from a little before that bridge. A missed mail bag (MailService, through Main) holds the run the same way and
-- sends it back to before the bridge in front of that crane, so the whole section (bridge and crane) comes again.
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
	-- A new train: its run starts after Config.Run.StartDelay. driver = the player whose reports count (nil for the
	-- stand-in driver: its bridges are judged by the server alone).
	begin: (locomotive: Model, driver: Player?) -> (),
	finish: (locomotive: Model) -> (),
	-- Mail bag `index` was missed (MailService): the run stops for Config.Mail.MissSeconds, then goes again from the
	-- restart point of bridge `index` (crane i stands after bridge i), so that section comes again (Names.MissedMail
	-- is set meanwhile).
	missMail: (locomotive: Model, index: number) -> (),
	stop: () -> (),
}

type State = {
	locomotive: Model,
	driver: Player?,
	run: CourseMath.Run,
	front: number, -- the locomotive's ends in its own Z (Names.SpanFront/SpanBack)
	back: number,
	next: number, -- the bridge waiting to be judged
	reported: boolean, -- the driver said "passed" for it: judged soon after it has gone by
	history: { CourseMath.Change },
	crashed: boolean,
	generation: number, -- bumped by every hold (crash or missed bag), so an old restart timer does nothing
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
	local states: { [Model]: State } = {}
	local function stateOf(player: Player): State?
		for _, state in states do
			if state.driver == player then
				return state
			end
		end
		return nil
	end

	local function bridgeAt(i: number): number
		return CourseMath.bridgeAt(i, bridges.FirstAt, bridges.Gaps)
	end
	local function window(state: State, i: number): (number, number)
		return CourseMath.under(bridgeAt(i), bridges.Depth, state.front, state.back)
	end

	-- Holds the run at `distance` for `seconds`, then runs again from `restartFrom` (the next bridge to judge is then
	-- the first one ahead of it); `after` runs just before the restart is published.
	local function hold(state: State, distance: number, seconds: number, restartFrom: number, after: () -> ())
		state.crashed = true
		state.generation += 1
		local generation = state.generation
		state.run = { start = now(), from = distance, speed = 0 }
		publish(state)
		task.delay(seconds, function()
			if states[state.locomotive] ~= state or state.generation ~= generation then
				return
			end
			state.crashed = false
			state.next = CourseMath.nextBridge(restartFrom, bridges.FirstAt, bridges.Gaps, bridges.Depth, state.back)
			state.reported = false
			state.run = { start = now() + run.ResumeDelay, from = restartFrom, speed = run.Speed }
			after()
			publish(state)
		end)
	end

	local function crash(state: State, index: number, distance: number)
		hold(state, distance, run.CrashSeconds, bridgeAt(index) - run.RestartLead, function()
			state.locomotive:SetAttribute(Names.CrashIndex, 0)
		end)
		count(state.locomotive, Names.Crashes)
		state.locomotive:SetAttribute(Names.CrashIndex, index)
	end

	-- A pass stands when the server saw the locomotive flat for the whole time the bridge was over it, allowing for
	-- the delay before a press reached the server and for a release in the last moment (the body is still low then);
	-- otherwise the front hit the bridge.
	local function judge(state: State, index: number)
		local enter, exit = window(state, index)
		local from = CourseMath.timeAt(state.run, enter) + run.PassTolerance
		local to = CourseMath.timeAt(state.run, exit) - run.ReleaseGrace
		state.reported = false
		if CourseMath.squashedThroughout(state.history, from, to) then
			state.next = index + 1
			count(state.locomotive, Names.Passed)
		else
			crash(state, index, enter)
		end
	end

	local received = remote.OnServerEvent:Connect(function(player: Player, index: unknown, hit: unknown, distance: unknown)
		local state = stateOf(player)
		if not state or state.crashed or typeof(index) ~= "number" or typeof(hit) ~= "boolean" or index ~= state.next then
			return
		end
		local enter, exit = window(state, index)
		if hit then
			-- Not before the front can have reached the bridge (small clock differences allowed).
			if now() >= CourseMath.timeAt(state.run, enter) - run.PassTolerance then
				local at = if typeof(distance) == "number" and distance == distance then distance else enter
				crash(state, index, math.clamp(at, enter, exit))
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
		for _, state in states do
			if not state.crashed and state.run.speed > 0 then
				local _, exit = window(state, state.next)
				local passedAt = CourseMath.timeAt(state.run, exit)
				if t >= passedAt + (if state.reported then run.PassTolerance else run.ReportTimeout) then
					judge(state, state.next)
				end
			end
		end
	end)

	local function finish(locomotive: Model)
		local state = states[locomotive]
		states[locomotive] = nil
		if state then
			state.watch:Disconnect()
		end
	end

	local function begin(locomotive: Model, driver: Player?)
		finish(locomotive)
		local history = { { time = now(), squashed = locomotive:GetAttribute(Names.Squashed) == true } }
		local state: State = {
			locomotive = locomotive,
			driver = driver,
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
		states[locomotive] = state
		locomotive:SetAttribute(Names.CrashIndex, 0)
		locomotive:SetAttribute(Names.MissedMail, 0)
		locomotive:SetAttribute(Names.Passed, 0)
		locomotive:SetAttribute(Names.Crashes, 0)
		publish(state)
	end

	local function missMail(locomotive: Model, index: number)
		local state = states[locomotive]
		if not state or state.crashed then
			return
		end
		-- The same restart point as a crash into the bridge in front of the crane: clear of that bridge (and of the
		-- bridge before it), with the bridge and then the crane coming again.
		hold(state, CourseMath.distance(state.run, now()), Config.Mail.MissSeconds, bridgeAt(index) - run.RestartLead, function()
			locomotive:SetAttribute(Names.MissedMail, 0)
		end)
		locomotive:SetAttribute(Names.MissedMail, index)
	end

	return {
		begin = begin,
		finish = finish,
		missMail = missMail,
		stop = function()
			received:Disconnect()
			ticking:Disconnect()
			for locomotive in states do
				finish(locomotive)
			end
		end,
	}
end

return CourseService
