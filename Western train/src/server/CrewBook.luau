--!strict
-- Who is on which train. Each slot (one track) has a driver - a player, or the stand-in driver when a lone cowboy
-- asked for one (Studio testing) - and at most one cowboy on its roof. Players pair up in the order they join: the
-- first drives, the next rides that train's roof, the third drives the next train, and so on. Pure bookkeeping on
-- any player keys (no Roblox API), so the luau CLI tests run it. Requires nothing.

local CrewBook = {}
CrewBook.__index = CrewBook

export type Role = "driver" | "cowboy"
-- driver is nil while the stand-in drives (bot = true).
export type Crew = { driver: any?, cowboy: any?, bot: boolean }
-- What a leaving player changed: the train goes, the cowboy now drives, or the train stays without a cowboy.
export type Change = "freed" | "promoted" | "nocowboy"

type Fields = { crews: { [number]: Crew }, size: number }
export type Book = typeof(setmetatable({} :: Fields, CrewBook))

function CrewBook.new(size: number): Book
	local fields: Fields = { crews = {}, size = size }
	return setmetatable(fields, CrewBook)
end

-- Where a new player goes. soloCowboy: a player who finds no train to ride rides one with the stand-in driver
-- instead of driving. Returns the slot, the role, and whether the player took over from a stand-in driver (that
-- train is rebuilt from the new driver's avatar); nil when every slot is taken.
function CrewBook.join(self: Book, player: any, soloCowboy: boolean): (number?, Role?, boolean)
	local already, role = CrewBook.find(self, player)
	if already then
		return already, role :: Role?, false -- joining twice changes nothing
	end
	for slot = 1, self.size do
		local crew = self.crews[slot]
		if crew and crew.bot and crew.cowboy ~= nil then
			crew.driver = player
			crew.bot = false
			return slot, "driver", true
		end
	end
	for slot = 1, self.size do
		local crew = self.crews[slot]
		if crew and not crew.bot and crew.driver ~= nil and crew.cowboy == nil then
			crew.cowboy = player
			return slot, "cowboy", false
		end
	end
	for slot = 1, self.size do
		if not self.crews[slot] then
			if soloCowboy then
				self.crews[slot] = { driver = nil, cowboy = player, bot = true }
				return slot, "cowboy", false
			end
			self.crews[slot] = { driver = player, cowboy = nil, bot = false }
			return slot, "driver", false
		end
	end
	return nil, nil, false
end

-- A player leaves. Returns the slot, what changed, and the cowboy who now drives (for "promoted"); nil when the
-- player had no slot.
function CrewBook.leave(self: Book, player: any): (number?, Change?, any?)
	for slot, crew in self.crews do
		if crew.driver == player then
			local cowboy = crew.cowboy
			if cowboy ~= nil then
				crew.driver = cowboy
				crew.cowboy = nil
				return slot, "promoted", cowboy
			end
			self.crews[slot] = nil
			return slot, "freed", nil
		elseif crew.cowboy == player then
			crew.cowboy = nil
			if crew.bot then
				self.crews[slot] = nil -- the stand-in only drives for a cowboy
				return slot, "freed", nil
			end
			return slot, "nocowboy", nil
		end
	end
	return nil, nil, nil
end

-- The player's slot and role, or nil.
function CrewBook.find(self: Book, player: any): (number?, Role?)
	for slot, crew in self.crews do
		if crew.driver == player then
			return slot, "driver"
		elseif crew.cowboy == player then
			return slot, "cowboy"
		end
	end
	return nil, nil
end

function CrewBook.crew(self: Book, slot: number): Crew?
	return self.crews[slot]
end

return CrewBook
