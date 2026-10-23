--!strict
-- Reads a train's shared state from its attributes, for the server parts and the client parts alike: its run (the
-- clock CourseService keeps: Names.RunStart/RunFrom/RunSpeed and RunVersion) and whether it has a cowboy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CourseMath = require(shared:WaitForChild("CourseMath"))

local TrainState = {}

-- The train's run (nil before CourseService has set it up) and its version (bumped after every change).
function TrainState.run(train: Model): (CourseMath.Run?, number)
	local start = PartUtil.number(train, Names.RunStart)
	local from = PartUtil.number(train, Names.RunFrom)
	local speed = PartUtil.number(train, Names.RunSpeed)
	local version = PartUtil.number(train, Names.RunVersion) or 0
	if start and from and speed then
		return { start = start, from = from, speed = speed }, version
	end
	return nil, version
end

function TrainState.hasCowboy(train: Model): boolean
	local id = train:GetAttribute(Names.CowboyUserId)
	return typeof(id) == "number" and id ~= 0
end

return TrainState
