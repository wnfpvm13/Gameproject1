--!strict
-- The mail bags on the trackside cranes, judged on the server. Each train keeps the next bag to pick up and the bags
-- picked up as attributes (Names.MailNext, Names.MailTaken). The cowboy's client reports a pickup; the server takes it
-- when it is the next bag and the bag is near the train: from Config.Mail.PickupSlack before the train's front until
-- the moment the bag would count as missed. A bag still not picked up Config.Run.ReportTimeout after it has gone past
-- the train's back is missed: `onMissed` (wired by Main to CourseService) sends the run back to before the bridge
-- in front of that crane. A train without a cowboy has no bags: its next bag just moves on past the cranes it passes
-- (they are not counted as picked up).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CourseMath = require(shared:WaitForChild("CourseMath"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local TrainState = require(shared:WaitForChild("TrainState"))

local MailService = {}

export type Service = { track: (train: Model) -> (), untrack: (train: Model) -> (), stop: () -> () }

type State = {
	next: number,
	taken: number,
	missedVersion: number?, -- the run version when a bag was missed: no judging until the run changes
}

local function craneAt(i: number): number
	local b = Config.Bridge
	return (CourseMath.mailAt(i, b.FirstAt, b.Gaps))
end

-- onMissed(train, index): bag `index` was missed; the run should go back to before that crane's section.
function MailService.start(remote: RemoteEvent, onMissed: (Model, number) -> ()): Service
	local states: { [Model]: State } = {}

	local function publish(train: Model, state: State)
		train:SetAttribute(Names.MailNext, state.next)
		train:SetAttribute(Names.MailTaken, state.taken)
	end

	local received = remote.OnServerEvent:Connect(function(player: Player, index: unknown)
		if typeof(index) ~= "number" then
			return
		end
		for train, state in states do
			if train:GetAttribute(Names.CowboyUserId) == player.UserId and index == state.next then
				local run = TrainState.run(train)
				if run and run.speed > 0 then
					local distance = CourseMath.distance(run, Workspace:GetServerTimeNow())
					local front = PartUtil.number(train, Names.SpanFront) or 0
					local back = PartUtil.number(train, Names.SpanBack) or 0
					-- The bag's place along the train is distance - crane: taken from just before the front until the bag
					-- would be judged missed (a late report still counts while it can).
					local along = distance - craneAt(index)
					local lastChance = back + Config.Run.ReportTimeout * run.speed
					if along >= front - Config.Mail.PickupSlack and along <= lastChance then
						state.next += 1
						state.taken += 1
						publish(train, state)
					end
				end
				return
			end
		end
	end)

	local ticking = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for train, state in states do
			local run, version = TrainState.run(train)
			if run and run.speed > 0 and state.missedVersion ~= version then
				state.missedVersion = nil
				local back = PartUtil.number(train, Names.SpanBack) or 0
				local pastAt = CourseMath.timeAt(run, craneAt(state.next) + back) -- the bag reaches the train's back
				if not TrainState.hasCowboy(train) then
					if now >= pastAt then
						state.next += 1 -- nobody to pick it up: the train just goes by
						publish(train, state)
					end
				elseif now >= pastAt + Config.Run.ReportTimeout then
					state.missedVersion = version
					onMissed(train, state.next)
				end
			end
		end
	end)

	return {
		track = function(train: Model)
			local state: State = { next = 1, taken = 0, missedVersion = nil }
			states[train] = state
			publish(train, state)
		end,
		untrack = function(train: Model)
			states[train] = nil
		end,
		stop = function()
			received:Disconnect()
			ticking:Disconnect()
			table.clear(states)
		end,
	}
end

return MailService
