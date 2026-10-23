--!strict
-- Remote events: the only place that creates them. Every server module talks to clients through these helpers.
--
-- Server -> client                         Client -> server
--   RoundState  round snapshot (Match)       Ready       mic test passed + voice connected
--   LifeLost    who lost a life / is out:    Sync        "send me the current state"
--               { reason, players = {        Reaction    spectator emoji
--               { userId, name, lives, out }  DevFling    Studio only: (mode) lose a life / "out" / "show"
--               }, final = they all fell at   ChatJoin    (on) join rounds by text chat instead of voice
--               once and play the final }
--   ChatAccess  to one player only: may I join by chat? { state = checking / yes / no / voice / error }
--   PresenterMenu to the presenter: { options = { {id, title, recommended} } | nil (closed), endsAt }
--   Sound       a presenter sound button: { index } (Config.PRESENTER_SOUNDS)
--   (client -> server: Volunteer (on), PresenterPick (mission id), PresenterSound (index))
--   Notice      short toast text
--   Reaction    emoji shown above a player
--   Fling       a flying chair fired: { userId, seatIndex, flightTime, landAt }
--   Splash      that player hit the water: { userId, position }
-- Kept for the speech judging and the banned words (JudgeService / WordService, not wired in V3 until phase 2 /
-- bundle 5): Words, WordWarn, Settle (server -> client), Transcript, VoicePing, Settled (client -> server).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local NAMES = {
	"RoundState", "LifeLost", "ChatAccess", "Notice", "Reaction", "Fling", "Splash", "Ready", "Sync", "DevFling", "ChatJoin",
	"Volunteer", "PresenterMenu", "PresenterPick", "PresenterSound", "Sound",
	"Words", "WordWarn", "Settle", "Transcript", "VoicePing", "Settled",
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
