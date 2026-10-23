--!strict
-- What the client knows about the round (data + small questions about it, no UI).
local Players = game:GetService("Players")

export type WordsEntry = { words: { string }?, count: number }

local State = {
	round = {
		phase = "Lobby",
		endsAt = 0,
		message = "",
		participants = {},
		alive = {},
		lives = {},
		maxLives = 0,
		total = 0,
	} :: any,
	-- userId string -> visible words (nil words = my own, hidden). Only during the banned-word talk (bundle 6a).
	words = {} :: { [string]: WordsEntry },
	micTested = false,
	-- May I join by chat? The server tells only me: checking / yes / no / voice (a voice account) / error.
	chatAccess = "checking",
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

-- A round is being played (seats taken): Assign, Play or Final.
function State.inRound(): boolean
	local phase = State.round.phase
	return phase == "Assign" or phase == "Play" or phase == "Final"
end

function State.meAlive(): boolean
	return State.isAlive(State.myId())
end

function State.livesOf(userId: number): number
	return State.round.lives[tostring(userId)] or 0
end

-- I present the round being played.
function State.mePresenting(): boolean
	return State.inRound() and State.round.presenter == State.myId()
end

return State
