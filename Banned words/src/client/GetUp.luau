--!strict
-- After a launch the server ends the ragdoll (PlatformStand off) and hands my character back to me. Only the owning
-- client may change its humanoid's state (docs/DESIGN_V3.md §10 step 5), so this stands my character back up unless
-- the server has put it back on a chair. The ownership may arrive with or after PlatformStand, so it retries
-- (GETUP_TRIES times, GETUP_RETRY_SECONDS apart) until the humanoid has left the lying states.
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BannedWords"):WaitForChild("Config"))

local GetUp = {}

local LYING: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
}

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local attempt = 0 -- a newer PlatformStand change cancels an older retry chain
	humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
		if humanoid.PlatformStand then
			return
		end
		attempt += 1
		local mine = attempt
		task.spawn(function()
			for _ = 1, Config.GETUP_TRIES do
				task.wait(Config.GETUP_RETRY_SECONDS)
				local still = attempt == mine and humanoid.Parent ~= nil and humanoid.Health > 0
				if not still or humanoid.PlatformStand or humanoid.Sit or humanoid.SeatPart ~= nil then
					return
				end
				if not LYING[humanoid:GetState()] then
					return -- up already
				end
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end)
end

function GetUp.start()
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(watch, player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

return GetUp
