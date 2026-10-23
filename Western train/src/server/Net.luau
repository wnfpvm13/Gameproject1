--!strict
-- Creates the remotes under ReplicatedStorage.WesternTrain.Remotes (one place, so names cannot drift).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Names = require(shared:WaitForChild("Names"))

local Net = {}

export type Remotes = { Squash: RemoteEvent, Bridge: RemoteEvent, Mail: RemoteEvent, Jump: RemoteEvent, Gold: RemoteEvent }

local function child(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	while existing and existing.ClassName ~= className do
		existing:Destroy() -- a stray instance with our name would make clients wait on the wrong one
		existing = parent:FindFirstChild(name)
	end
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = parent
	return made
end

function Net.create(): Remotes
	local folder = child(shared, "Folder", Names.RemotesFolder)
	return {
		Squash = child(folder, "RemoteEvent", Names.SquashRemote) :: RemoteEvent,
		Bridge = child(folder, "RemoteEvent", Names.BridgeRemote) :: RemoteEvent,
		Mail = child(folder, "RemoteEvent", Names.MailRemote) :: RemoteEvent,
		Jump = child(folder, "RemoteEvent", Names.JumpRemote) :: RemoteEvent,
		Gold = child(folder, "RemoteEvent", Names.GoldRemote) :: RemoteEvent,
	}
end

return Net
