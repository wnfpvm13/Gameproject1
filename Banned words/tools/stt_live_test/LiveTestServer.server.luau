-- Live STT test (server): receives one record per item from the client and keeps the session in a DataStore
-- so results can be read back from Studio afterwards (reading needs "Studio access to API services").
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("SttLiveTest")
local resultEvent = shared:WaitForChild("SttResult")
local store = DataStoreService:GetDataStore("SttLiveTest_v1")

local sessions = {}

local function save(session)
	local ok, err = pcall(function()
		store:SetAsync(session.key, session)
	end)
	if not ok then
		warn("[SttLiveTest] save failed:", err)
	end
end

resultEvent.OnServerEvent:Connect(function(player, record)
	if typeof(record) ~= "table" or typeof(record.word) ~= "string" or typeof(record.status) ~= "string" then
		return
	end
	local session = sessions[player]
	if not session then
		session = { key = string.format("u%d_%d", player.UserId, os.time()), userId = player.UserId, records = {} }
		sessions[player] = session
	end
	table.insert(session.records, {
		i = tonumber(record.i),
		word = record.word,
		say = tostring(record.say),
		kind = tostring(record.kind),
		text = string.sub(tostring(record.text), 1, 300),
		status = record.status,
		latency = tonumber(record.latency),
		platform = tostring(record.platform),
	})
	print(string.format("[SttLiveTest] %s #%s %s | %s -> %s", record.status, tostring(record.i), record.word, tostring(record.say), tostring(record.text)))
	save(session)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)
