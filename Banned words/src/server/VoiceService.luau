--!strict
-- Flat voice volume on the server side: default voice creates each character's AudioEmitter on the server,
-- so the flat curve set here replicates to every listener (src/client/FlatVoice.luau covers client-made emitters).
local Players = game:GetService("Players")

local VoiceService = {}

local FLAT_CURVE = { [0] = 1, [2000] = 1 }

local function flatten(child: Instance)
	if child:IsA("AudioEmitter") then
		child:SetDistanceAttenuation(FLAT_CURVE)
	end
end

local function watchCharacter(character: Model)
	for _, child in character:GetChildren() do
		flatten(child)
	end
	character.ChildAdded:Connect(flatten)
end

function VoiceService.start()
	local function watchPlayer(player: Player)
		if player.Character then
			watchCharacter(player.Character)
		end
		player.CharacterAdded:Connect(watchCharacter)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return VoiceService
