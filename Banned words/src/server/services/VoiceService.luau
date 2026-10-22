--!strict
-- Voice routing.
-- 1. Flat volume: default voice creates each character's AudioEmitter on the server with a 7-80 stud rolloff;
--    the flat curve set here replicates to every listener (src/client/FlatVoice.luau covers client-made emitters).
-- 2. Players who are out and spectators are silent to the table: during a round their AudioDeviceInput is only
--    audible to each other (docs/DESIGN_V3.md §13; with banned words they know every word).
-- 3. Chat participants are heard by nobody during their round, even if their voice connects meanwhile (§7: speaking
--    would get around the chat judging).
local Players = game:GetService("Players")

local VoiceService = {}

local FLAT_CURVE = { [0] = 1, [2000] = 1 }

local speakers: { [number]: boolean }? = nil -- userIds allowed to talk to the table; nil = no round, everyone open
local silenced: { [number]: boolean } = {} -- userIds nobody hears (chat participants of the round)

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

local function inputOf(player: Player): AudioDeviceInput?
	return player:FindFirstChildOfClass("AudioDeviceInput")
end

local function apply()
	local spectatorIds = {}
	for _, player in Players:GetPlayers() do
		if speakers and not speakers[player.UserId] then
			table.insert(spectatorIds, player.UserId)
		end
	end
	for _, player in Players:GetPlayers() do
		local input = inputOf(player)
		if input then
			if silenced[player.UserId] then
				input.AccessType = Enum.AccessModifierType.Allow
				input:SetUserIdAccessList({}) -- nobody allowed: nobody hears
			elseif speakers == nil or speakers[player.UserId] then
				input.AccessType = Enum.AccessModifierType.Deny
				input:SetUserIdAccessList({}) -- nobody denied: the whole server hears
			else
				input.AccessType = Enum.AccessModifierType.Allow
				input:SetUserIdAccessList(spectatorIds) -- only fellow spectators hear
			end
		end
	end
end

-- Round on: only `userIds` (alive participants) are heard by everyone. nil = round over, everyone open.
function VoiceService.setSpeakers(userIds: { number }?)
	if userIds then
		local set = {}
		for _, id in userIds do
			set[id] = true
		end
		speakers = set
	else
		speakers = nil
	end
	apply()
end

-- The chat participants of the round being played (an empty list when it is over).
function VoiceService.setSilenced(userIds: { number })
	table.clear(silenced)
	for _, id in userIds do
		silenced[id] = true
	end
	apply()
end

function VoiceService.start()
	local function watchPlayer(player: Player)
		if player.Character then
			watchCharacter(player.Character)
		end
		player.CharacterAdded:Connect(watchCharacter)
		player.ChildAdded:Connect(function(child)
			if child:IsA("AudioDeviceInput") then
				apply()
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(function(player)
		watchPlayer(player)
		apply() -- a newcomer is a spectator until the next round
	end)
end

return VoiceService
