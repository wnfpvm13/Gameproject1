--!strict
-- Remote events: the only place that creates them. Every server module talks to clients through these helpers.
--
-- Server -> client                         Client -> server
--   RoundState  round snapshot (Match)       Transcript  (text, segment start in server time)
--   Words       visible words per player     VoicePing   mic hears speech (activity only)
--   WordWarn    a new word is coming         Ready       mic test passed + voice connected
--   Eliminated  someone was launched / left  Sync        "send me the current state"
--   Host        theme, topic card, event     Reaction    ghost/spectator emoji
--   Notice      short toast text
--   Reaction    emoji shown above a player
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local NAMES = {
	"RoundState", "Words", "WordWarn", "Eliminated", "Host", "Notice", "Reaction",
	"Transcript", "VoicePing", "Ready", "Sync",
}

local folder: Folder

function Net.init()
	local shared = ReplicatedStorage:WaitForChild("BannedWords")
	local existing = shared:FindFirstChild("Remotes")
	folder = if existing then existing :: Folder else Instance.new("Folder")
	folder.Name = "Remotes"
	for _, child in folder:GetChildren() do
		if not table.find(NAMES, child.Name) then
			child:Destroy() -- remotes from an older install
		end
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
	folder.Parent = shared
end

function Net.event(name: string): RemoteEvent
	local event = folder:FindFirstChild(name)
	assert(event and event:IsA("RemoteEvent"), "unknown remote " .. name)
	return event
end

function Net.toAll(name: string, payload: any)
	Net.event(name):FireAllClients(payload)
end

function Net.to(player: Player, name: string, payload: any)
	Net.event(name):FireClient(player, payload)
end

function Net.notice(text: string)
	Net.toAll("Notice", { text = text })
end

function Net.listen(name: string, handler: (Player, ...any) -> ())
	Net.event(name).OnServerEvent:Connect(handler)
end

return Net
