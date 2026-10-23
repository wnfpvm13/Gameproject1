--!strict
-- Jump input from drivers: the sender must own a locomotive, and the jump's start (server time) is published as that
-- locomotive's Names.JumpAt attribute, so every client plays the same arc. The start is when the driver pressed (their
-- client's server time, sent along), allowed up to Config.Run.PassTolerance back for the network delay, so the arc
-- others see lines up with the driver's (and with the gold bags). A jump that would start before the last one has
-- landed is ignored, with Config.Jump.LandSlack for clock differences. The driver's client never jumps while flat, so a
-- jump also lets go of a Squashed that SquashService is still holding back under its message limit (otherwise the
-- others would see the train jump flat, and the server's squash history would show it flat in the air).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local JumpService = {}

-- Starts a jump on `locomotive` from server time `pressedAt` (nil: now; a time too far back, or ahead, is moved to the
-- nearest allowed one) unless that is before the last jump has landed. Returns whether it jumped. (The stand-in driver
-- jumps through this too.)
function JumpService.jump(locomotive: Model, pressedAt: number?): boolean
	local now = Workspace:GetServerTimeNow()
	local at = if pressedAt and pressedAt == pressedAt then math.clamp(pressedAt, now - Config.Run.PassTolerance, now) else now
	local j = Config.Jump
	local last = PartUtil.number(locomotive, Names.JumpAt)
	if last and at < last + j.Seconds - j.LandSlack then
		return false
	end
	if locomotive:GetAttribute(Names.Squashed) == true then
		locomotive:SetAttribute(Names.Squashed, false)
	end
	locomotive:SetAttribute(Names.JumpAt, at)
	return true
end

-- locomotiveOf(player) is supplied by the entry script. Returns a function that stops the service.
function JumpService.start(remote: RemoteEvent, locomotiveOf: (Player) -> Model?): () -> ()
	local received = remote.OnServerEvent:Connect(function(player: Player, pressedAt: unknown)
		local locomotive = locomotiveOf(player)
		if locomotive then
			JumpService.jump(locomotive, if typeof(pressedAt) == "number" then pressedAt else nil)
		end
	end)
	return function()
		received:Disconnect()
	end
end

return JumpService
