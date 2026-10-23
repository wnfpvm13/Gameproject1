--!strict
-- Squash input from drivers: the sender must own a locomotive, and the state is published as that locomotive's
-- Squashed attribute so every client animates it. Beyond the rate limit nothing is dropped: the latest state waits
-- until the current one-second window ends, so the server always ends up showing what the driver last pressed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))

local SquashService = {}

-- locomotiveOf(player) is supplied by the entry script. Returns a function that stops the service.
-- Attribute writes counted in the current one-second window; `waiting` = the latest state is due when it ends.
type Window = { start: number, count: number, waiting: boolean }

function SquashService.start(remote: RemoteEvent, locomotiveOf: (Player) -> Model?): () -> ()
	local windows: { [Player]: Window } = {}
	local latest: { [Player]: boolean } = {}
	local function windowFor(player: Player, now: number): Window
		local window = windows[player]
		if window and now - window.start < 1 then
			return window
		end
		local fresh = { start = now, count = 0, waiting = false }
		windows[player] = fresh
		return fresh
	end
	local function publish(player: Player)
		local state = latest[player]
		local locomotive = locomotiveOf(player)
		if state ~= nil and locomotive then
			windowFor(player, os.clock()).count += 1
			locomotive:SetAttribute(Names.Squashed, state)
		end
	end
	local received = remote.OnServerEvent:Connect(function(player: Player, isDown: unknown)
		if typeof(isDown) ~= "boolean" then
			return
		end
		latest[player] = isDown
		local now = os.clock()
		local window = windowFor(player, now)
		if window.count < Config.Squash.MaxMessagesPerSecond then
			publish(player)
		elseif not window.waiting then
			window.waiting = true
			task.delay(window.start + 1 - now, publish, player)
		end
	end)
	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		windows[player] = nil
		latest[player] = nil
	end)
	return function()
		received:Disconnect()
		leaving:Disconnect()
	end
end

return SquashService
