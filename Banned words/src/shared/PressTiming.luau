--!strict
-- When a bell press really happened (bundle 8b timing games). The player's round trip (Player:GetNetworkPing, official:
-- round trip, in seconds) is read as soon as their press is seen — not later, when it may have changed — and capped
-- at Config.TIMING_PING_CAP:
--   - a start sent ahead in server time (숫자 맞추기, 물병 세우기: every screen starts by its synced clock) is late at
--     the server only by the trip back: half the round trip (`pressedAt`);
--   - a signal sent at its moment (총잡이 결투's "fire!": not told ahead, so nobody can schedule a press) reaches the
--     player late too: the whole round trip (`reactedAt`).
-- What it cannot see: the remote's queueing and a frame or two of drawing; and a modified client can still press by
-- script. Those are the limits of any timing game here (docs/DESIGN_V3.md §5.2).
local Config = require(script.Parent:WaitForChild("Config"))

local PressTiming = {}

local function roundTrip(player: Player): number
	local ok, ping = pcall(function(): number
		return player:GetNetworkPing()
	end)
	if not (ok and type(ping) == "number") then
		return 0
	end
	return math.clamp(ping, 0, Config.TIMING_PING_CAP)
end

export type Recorder = {
	note: (times: { [Player]: number }) -> (), -- call while the bells are open (each poll): new presses get their trip
	pressedAt: (player: Player, arrivedAt: number) -> number,
	reactedAt: (player: Player, arrivedAt: number) -> number,
}

function PressTiming.recorder(): Recorder
	local trips: { [Player]: number } = {}
	local function trip(player: Player): number
		local value = trips[player]
		if value == nil then
			value = roundTrip(player)
			trips[player] = value
		end
		return value
	end
	return {
		note = function(times: { [Player]: number })
			for player in times do
				trip(player)
			end
		end,
		pressedAt = function(player: Player, arrivedAt: number): number
			return arrivedAt - trip(player) / 2
		end,
		reactedAt = function(player: Player, arrivedAt: number): number
			return arrivedAt - trip(player)
		end,
	}
end

return PressTiming
