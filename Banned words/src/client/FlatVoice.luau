--!strict
-- Everyone hears everyone at the same volume, wherever they are on the map (owner decision 2026-10-17).
-- Default voice (UseAudioApi) wires each AudioDeviceInput into an AudioEmitter inside the character with a
-- quadratic 7-80 stud rolloff; audibility is computed on the listening client, so flattening the curve here is enough.
local Players = game:GetService("Players")

local FlatVoice = {}

local FLAT_CURVE = { [0] = 1, [2000] = 1 }

local function flatten(emitter: Instance)
	if emitter:IsA("AudioEmitter") then
		-- The curve only counts in Custom mode (the default, but a preset would silently ignore it).
		emitter.DistanceAttenuationMode = Enum.DistanceAttenuationMode.Custom
		emitter:SetDistanceAttenuation(FLAT_CURVE)
	end
end

local function watchCharacter(character: Model)
	for _, child in character:GetChildren() do
		flatten(child)
	end
	character.ChildAdded:Connect(flatten)
end

local function watchPlayer(player: Player)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

function FlatVoice.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return FlatVoice
