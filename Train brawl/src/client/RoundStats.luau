--!strict
-- The player's own numbers this round, counted on this client from the server's words (persona fix 5): hits landed on
-- others (not taken on a block), home runs dealt (the feed), hits taken since its last fall - not those it blocked -
-- (for the knock-off line: RoundHud), when its fight began and when it went out for good. Starts over at each count-down. The knock-offs are
-- the server's (Names.KOs on the character).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local RoundStats = {}
RoundStats.__index = RoundStats

-- What the result card shows: knock-offs, home runs, hits landed, seconds on the trains (0 when it watched), and the
-- titles it earned (Words.Titles keys: the most home runs, the most knock-offs - from the feed, ties share - and still
-- aboard at the end).
export type Summary = { kos: number, homers: number, landed: number, seconds: number, played: boolean, titles: { string } }

type Fields = {
	landed: number,
	homers: number,
	taken: number, -- since the last fall
	began: number?, -- server time the player's fight began (nil: not in this round)
	outAt: number?, -- server time it went out for good
	endedAt: number?, -- server time the fight ended
	phase: string?,
	-- Everyone's home runs and knock-offs this round, by name, from the feed.
	homersBy: { [string]: number },
	kosBy: { [string]: number },
}
export type Stats = typeof(setmetatable({} :: Fields, RoundStats))

function RoundStats.new(): Stats
	local fields: Fields = { landed = 0, homers = 0, taken = 0, began = nil, outAt = nil, endedAt = nil, phase = nil, homersBy = {}, kosBy = {} }
	return setmetatable(fields, RoundStats)
end

-- A hit from the server: `mine` the player struck it, `me` the player took it; `guard` "blocked" or "broken" when it
-- met a block.
function RoundStats.hit(self: Stats, mine: boolean, me: boolean, guard: string?)
	if mine and guard == nil then
		self.landed += 1
	end
	if me and guard ~= "blocked" then
		self.taken += 1 -- (a hit taken on the block does not count; one that broke it does)
	end
end

-- A line of the feed: who got the knock-off (nil: nobody), `byMe` the player did, `meOut` the player was knocked off
-- (`out`: for good), how. Returns the hits the player took before that fall when it was the player's (then counted
-- afresh).
function RoundStats.feed(self: Stats, by: string?, byMe: boolean, meOut: boolean, how: string, out: boolean): number?
	if byMe and how == "homerun" then
		self.homers += 1
	end
	if by then
		self.kosBy[by] = (self.kosBy[by] or 0) + 1
		if how == "homerun" then
			self.homersBy[by] = (self.homersBy[by] or 0) + 1
		end
	end
	if not meOut then
		return nil
	end
	local taken = self.taken
	self.taken = 0
	if out then
		self.outAt = Workspace:GetServerTimeNow()
	end
	return taken
end

-- Every frame: the round's phase, and whether the player is in it (on the trains or on its way back).
function RoundStats.update(self: Stats, phase: string, inRound: boolean)
	local before = self.phase
	self.phase = phase
	local counting, fighting = phase == "Countdown", phase == "Fight"
	local wasCounting, wasFighting = before == "Countdown", before == "Fight"
	if counting and not wasCounting then
		self.landed, self.homers, self.taken, self.began, self.outAt, self.endedAt = 0, 0, 0, nil, nil, nil
		table.clear(self.homersBy)
		table.clear(self.kosBy)
	elseif fighting and not wasFighting and inRound then
		self.began = Workspace:GetServerTimeNow()
	elseif wasFighting and not fighting then
		self.endedAt = Workspace:GetServerTimeNow()
	end
end

-- Whether `name` has the most in `counts` (at least one; ties share it).
local function most(counts: { [string]: number }, name: string): boolean
	local mine = counts[name] or 0
	if mine <= 0 then
		return false
	end
	for _, count in counts do
		if count > mine then
			return false
		end
	end
	return true
end

-- The player's round so far (for the result card), from its character's knock-offs; `name`: its name as the feed says.
function RoundStats.summary(self: Stats, own: Model?, name: string): Summary
	local began = self.began
	local ended = self.outAt or self.endedAt or Workspace:GetServerTimeNow()
	local titles = {}
	if most(self.homersBy, name) then
		table.insert(titles, "homers")
	end
	if most(self.kosBy, name) then
		table.insert(titles, "kos")
	end
	if began and not self.outAt and self.endedAt then
		table.insert(titles, "survived")
	end
	return {
		titles = titles,
		kos = if own then PartUtil.number(own, Names.KOs) or 0 else 0,
		homers = self.homers,
		landed = self.landed,
		seconds = if began then math.max(0, ended - began) else 0,
		played = began ~= nil,
	}
end

return RoundStats
