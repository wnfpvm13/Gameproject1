--!strict
-- Watches the fighters' feet on the server: whoever drops below the fall line (Config.Fall.Margin under the lowest
-- roof) has missed the train. The fighters come from the round, which drops a fighter once it is out, so each one is
-- reported once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local FallWatch = {}

-- fighters() lists the models still in the round; onFall(model) is called for each that falls. Returns a stop
-- function.
function FallWatch.start(fallLine: number, fighters: () -> { Model }, onFall: (Model) -> ()): () -> ()
	local ticking = RunService.Heartbeat:Connect(function()
		for _, model in fighters() do
			local body = CharacterParts.body(model)
			if body and CharacterParts.feetY(body) < fallLine then
				onFall(model)
			end
		end
	end)
	return function()
		ticking:Disconnect()
	end
end

return FallWatch
