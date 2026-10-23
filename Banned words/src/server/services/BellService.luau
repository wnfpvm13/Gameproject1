--!strict
-- The seat bells (docs/DESIGN_V3.md §5.1; bundle 6b, owner 2026-10-23): every chair has a bell next to it. A mission
-- opens the bells of some players for a while (`collect`); each of them may ring once, and the rings are kept in the
-- order they reached the server (that order decides who was first: ping plays a small part, known and accepted). A
-- ring needs the player alive, on the ground, in the main game, and BELL_COOLDOWN after their last ring. Everyone hears
-- the ding and sees that bell light up ("BellRang"); clients show their bell button while it is open to them
-- ("BellOpen"). Every window has its own number and a ring must name it (a late ring never counts for a later window);
-- a window that wants only the first ring closes the moment it comes. A repeating window (bundle 6d, red light) takes
-- every press at least `repeatEvery` apart from each player and keeps them all (with no ding: too many). Outside an
-- open window rings do nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))
local Match = require(script.Parent.Parent:WaitForChild("Match"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local BellService = {}

local POLL = 0.05 -- seconds between "done yet?" checks while the bells are open

export type Press = { player: Player, at: number }
type Window = { id: number, from: { [Player]: boolean }, rung: { Player }, times: { [Player]: number }, endsAt: number,
	firstOnly: boolean, repeatEvery: number?, presses: { Press }, lastPress: { [Player]: number } }

local window: Window? = nil
local windows = 0
local lastRing: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any -- (players who left drop out)
local unavailable: (Player) -> boolean = function(_player)
	return false
end

local function ids(set: { [Player]: boolean }): { number }
	local out = {}
	for player in set do
		table.insert(out, player.UserId)
	end
	return out
end

local function tell(player: Player?)
	local open = window
	local payload = if open
		then { open = true, id = open.id, ids = ids(open.from), endsAt = open.endsAt, repeating = open.repeatEvery ~= nil }
		else { open = false }
	if player then
		Net.to(player, "BellOpen", payload)
	else
		Net.toAll("BellOpen", payload)
	end
end

-- isBusy(player): another service owns the player now (flying), so their bell does not count.
function BellService.start(isBusy: (Player) -> boolean)
	unavailable = isBusy
	Net.listen("Bell", function(player, windowId)
		local open = window
		if not open or windowId ~= open.id or not open.from[player] then
			return
		end
		local every = open.repeatEvery
		if not every and table.find(open.rung, player) then
			return
		end
		if Match.now() > open.endsAt then
			return -- (past its end: the window is only waiting to be closed)
		end
		if Match.phase ~= "Play" or not Match.isAlive(player) or unavailable(player) then
			return
		end
		local now = os.clock()
		if every then
			if now - (open.lastPress[player] or -math.huge) < every then
				return
			end
			open.lastPress[player] = now
			table.insert(open.presses, { player = player, at = Match.now() })
			if not table.find(open.rung, player) then
				table.insert(open.rung, player)
				open.times[player] = Match.now()
			end
			return
		end
		if now - (lastRing[player] or -math.huge) < Config.BELL_COOLDOWN then
			return
		end
		lastRing[player] = now
		table.insert(open.rung, player)
		open.times[player] = Match.now()
		Net.toAll("BellRang", { userId = player.UserId })
		if open.firstOnly then
			window = nil -- (closed at once: nobody else rings in the moment before collect looks again)
			tell(nil)
		end
	end)
end

-- Opens the bells of `from` for `seconds` and waits. Returns who rang, first to last, when each first ring arrived
-- (Match.now()) and, for a repeating window (`repeatEvery`), every press. `firstOnly`: closes at the first ring. Ends
-- early when `enough(rung, times, presses)` says so (a game that knows its outcome; it is asked every poll, so a game
-- may also follow the presses live) or `stop()` (the mission was cancelled).
function BellService.collect(from: { Player }, seconds: number, firstOnly: boolean, stop: () -> boolean,
	enough: (({ Player }, { [Player]: number }, { Press }) -> boolean)?, repeatEvery: number?)
	: ({ Player }, { [Player]: number }, { Press })
	windows += 1
	local open: Window = { id = windows, from = {}, rung = {}, times = {}, endsAt = Match.now() + seconds,
		firstOnly = firstOnly, repeatEvery = repeatEvery, presses = {}, lastPress = {} }
	for _, player in from do
		open.from[player] = true
	end
	window = open
	tell(nil)
	local untilAt = os.clock() + seconds
	while os.clock() < untilAt and not stop() and window == open and not (enough and enough(open.rung, open.times, open.presses)) do
		task.wait(math.min(POLL, math.max(0, untilAt - os.clock())))
	end
	if window == open then
		window = nil
		tell(nil)
	end
	return open.rung, open.times, open.presses
end

-- A mission ended (or the round): the bells close.
function BellService.close()
	if window then
		window = nil
		tell(nil)
	end
end

-- A player asked for the whole state again.
function BellService.send(player: Player)
	if window then
		tell(player)
	end
end

return BellService
