--!strict
-- Where the gold bags are and when a train's driver should jump for them, from Config (shared by the client that draws
-- the cranes and jump markers, the cowboy's pickup, the stand-in driver and the server's gold MailService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CourseMath = require(shared:WaitForChild("CourseMath"))

local GoldTrack = {}

-- Gold bag k's run distance and the side its crane stands on.
function GoldTrack.at(k: number): (number, number)
	local b, g = Config.Bridge, Config.GoldMail
	return CourseMath.goldAt(k, b.FirstAt, b.Gaps, g.At, g.Every)
end

-- The run distance at which the train should start its jump for gold bag k: a cowboy in the middle of the car roofs
-- (Names.CarRoofFront to Names.SpanBack) who jumps at the top of the arc is then at the top of their own jump as the
-- bag passes over (Config.GoldMail.RiseSeconds).
function GoldTrack.jumpFrom(train: Model, k: number): number
	local roofFront = PartUtil.number(train, Names.CarRoofFront) or 0
	local back = PartUtil.number(train, Names.SpanBack) or 0
	local leadStuds = (Config.Jump.Seconds / 2 + Config.GoldMail.RiseSeconds) * Config.Run.Speed
	return CourseMath.jumpFrom((GoldTrack.at(k)), (roofFront + back) / 2, leadStuds)
end

return GoldTrack
