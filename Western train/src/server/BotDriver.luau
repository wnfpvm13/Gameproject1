--!strict
-- The stand-in driver for a cowboy without a partner (Studio testing, Names.SoloCowboy): it squashes its train a
-- little before each low bridge and lets go a little after, by setting the train's Squashed attribute as a real
-- driver's input would (CourseService then judges the bridges itself, as for a quiet driver).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CourseMath = require(shared:WaitForChild("CourseMath"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local BotDriver = {}

export type Bot = { drive: (train: Model) -> (), stop: (train: Model) -> (), shutdown: () -> () }

-- Whether the stand-in wants the train flat at this run distance: from LeadStuds before the front meets a bridge
-- until TrailStuds after the back has left it (the bridge just behind counts too).
local function wantsFlat(train: Model, distance: number): boolean
	local b, bot = Config.Bridge, Config.Bot
	local front = PartUtil.number(train, Names.SpanFront) or 0
	local back = PartUtil.number(train, Names.SpanBack) or 0
	local index = CourseMath.nextBridge(distance, b.FirstAt, b.Gaps, b.Depth, back)
	for i = math.max(1, index - 1), index do
		local enter, exit = CourseMath.under(CourseMath.bridgeAt(i, b.FirstAt, b.Gaps), b.Depth, front, back)
		if distance >= enter - bot.LeadStuds and distance <= exit + bot.TrailStuds then
			return true
		end
	end
	return false
end

function BotDriver.start(): Bot
	local driven: { [Model]: boolean } = {}
	local ticking = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for train in driven do
			local start = PartUtil.number(train, Names.RunStart)
			local from = PartUtil.number(train, Names.RunFrom)
			local speed = PartUtil.number(train, Names.RunSpeed)
			if start and from and speed then
				local flat = speed > 0 and wantsFlat(train, CourseMath.distance({ start = start, from = from, speed = speed }, now))
				if (train:GetAttribute(Names.Squashed) == true) ~= flat then
					train:SetAttribute(Names.Squashed, flat)
				end
			end
		end
	end)
	return {
		drive = function(train: Model)
			driven[train] = true
		end,
		stop = function(train: Model)
			driven[train] = nil
		end,
		shutdown = function()
			ticking:Disconnect()
			table.clear(driven)
		end,
	}
end

return BotDriver
