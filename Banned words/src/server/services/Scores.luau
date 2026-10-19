--!strict
-- Casual session score (leaderstats "점수") and the assist ("유도") credit. Nothing is saved between sessions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))

local Scores = {}

local speechLog: { { player: Player, at: number } } = {}
local roundAssists: { [Player]: number } = {}

local function setupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local score = Instance.new("IntValue")
	score.Name = "점수"
	score.Parent = stats
	stats.Parent = player
end

function Scores.start()
	for _, player in Players:GetPlayers() do
		setupLeaderstats(player)
	end
	Players.PlayerAdded:Connect(setupLeaderstats)
	Players.PlayerRemoving:Connect(function(player)
		roundAssists[player] = nil
	end)
end

function Scores.add(player: Player, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("점수") :: IntValue?
	if value then
		value.Value += amount
	end
end

-- Called for every judged transcript, so the assist goes to whoever was talking right before a launch.
function Scores.noteSpeech(player: Player)
	table.insert(speechLog, { player = player, at = os.clock() })
	if #speechLog > 64 then
		table.remove(speechLog, 1)
	end
end

-- The most recent other alive participant who spoke within the assist window gets +1.
function Scores.creditAssist(victim: Player): Player?
	local now = os.clock()
	for i = #speechLog, 1, -1 do
		local entry = speechLog[i]
		if now - entry.at > Config.ASSIST_WINDOW then
			break
		end
		if entry.player ~= victim and Match.isAlive(entry.player) then
			roundAssists[entry.player] = (roundAssists[entry.player] or 0) + Config.SCORE_ASSIST
			Scores.add(entry.player, Config.SCORE_ASSIST)
			return entry.player
		end
	end
	return nil
end

function Scores.bestAssist(): (Player?, number)
	local best, bestScore = nil, 0
	for player, score in roundAssists do
		if score > bestScore then
			best, bestScore = player, score
		end
	end
	return best, bestScore
end

function Scores.resetRound()
	table.clear(speechLog)
	table.clear(roundAssists)
end

return Scores
