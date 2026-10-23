--!strict
-- A cowboy's bridge splat, for everyone to see: the cowboy's client reports it with when it happened (its server-time
-- estimate) and the server publishes that time as the train's Names.SplatAt attribute (allowed up to
-- Config.Run.PassTolerance back for the network delay; one per Config.Cowboy.SplatSeconds, less that allowance, since
-- a late report is moved forward), so every client draws the paper gag at the same moment and the driver hears of it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local SplatService = {}

-- trainOf(player) is supplied by the entry script: the train the player rides as its cowboy. Returns a function that
-- stops the service.
function SplatService.start(remote: RemoteEvent, trainOf: (Player) -> Model?): () -> ()
	local received = remote.OnServerEvent:Connect(function(player: Player, happenedAt: unknown)
		local train = trainOf(player)
		if not train then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local at = if typeof(happenedAt) == "number" and happenedAt == happenedAt
			then math.clamp(happenedAt, now - Config.Run.PassTolerance, now)
			else now
		local last = PartUtil.number(train, Names.SplatAt)
		if not last or at >= last + Config.Cowboy.SplatSeconds - Config.Run.PassTolerance then
			train:SetAttribute(Names.SplatAt, at)
		end
	end)
	return function()
		received:Disconnect()
	end
end

return SplatService
