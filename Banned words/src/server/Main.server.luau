-- 금칙어 게임 Korean server entry point: creates the remotes, then runs rounds forever.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("BannedWords")
local remotes = shared:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "RoundState", "Words", "Transcript", "Eliminated", "Suspect" } do
	if not remotes:FindFirstChild(name) then
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = remotes
	end
end
remotes.Parent = shared

require(script.Parent:WaitForChild("VoiceService")).start()
require(script.Parent:WaitForChild("RoundService")).start(remotes)
