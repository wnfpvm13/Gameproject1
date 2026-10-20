--!strict
-- What the client knows about the round (data + small questions about it, no UI).
local Players = game:GetService("Players")

export type WordsEntry = { words: { string }?, count: number }

local State = {
	round = { phase = "Lobby", endsAt = 0, message = "", participants = {}, alive = {}, total = 0 } :: any,
	words = {} :: { [string]: WordsEntry }, -- userId string -> visible words (nil words = my own, hidden)
	theme = nil :: any, -- { theme }
	micTested = false,
}

function State.myId(): number
	return Players.LocalPlayer.UserId
end

function State.isParticipant(userId: number): boolean
	return table.find(State.round.participants, userId) ~= nil
end

function State.isAlive(userId: number): boolean
	return table.find(State.round.alive, userId) ~= nil
end

function State.inRound(): boolean
	return State.round.phase == "Assign" or State.round.phase == "Talk"
end

function State.meAlive(): boolean
	return State.isAlive(State.myId())
end

function State.myWordCount(): number
	local entry = State.words[tostring(State.myId())]
	return if entry then entry.count else 0
end

return State
