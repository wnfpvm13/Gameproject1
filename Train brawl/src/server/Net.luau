--!strict
-- Creates the remotes under ReplicatedStorage.TrainBrawl.Remotes (one place, so names cannot drift).
-- (The child() helper is taken over from Western train's Net.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))

local Net = {}

export type Remotes = { Swing: RemoteEvent, Hit: RemoteEvent, Feed: RemoteEvent, Blast: RemoteEvent, Block: RemoteEvent, Dodge: RemoteEvent, Swept: RemoteEvent }

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
		Swing = child(folder, "RemoteEvent", Names.SwingRemote) :: RemoteEvent,
		Hit = child(folder, "RemoteEvent", Names.HitRemote) :: RemoteEvent,
		Feed = child(folder, "RemoteEvent", Names.FeedRemote) :: RemoteEvent,
		Blast = child(folder, "RemoteEvent", Names.BlastRemote) :: RemoteEvent,
		Block = child(folder, "RemoteEvent", Names.BlockRemote) :: RemoteEvent,
		Dodge = child(folder, "RemoteEvent", Names.DodgeRemote) :: RemoteEvent,
		Swept = child(folder, "RemoteEvent", Names.SweptRemote) :: RemoteEvent,
	}
end

return Net
