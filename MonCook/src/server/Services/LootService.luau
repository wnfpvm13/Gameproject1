--!strict
-- A server outbox: independent personal rolls are sampled once and retained on failure.
local LootService = {}
LootService.__index = LootService
local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}; for key, child in value do result[key] = clone(child) end; return result
end
function LootService.new(options: any): any
	assert(type(options.Roll) == "function", "server RNG required")
	return setmetatable({ Definitions = options.Definitions, Inventory = options.Inventory, Roll = options.Roll,
		Now = options.Now, CanAward = options.CanAward, OnEvent = options.OnEvent, Log = options.Log,
		_jobs = {}, _queued = {}, _ticking = false }, LootService)
end
function LootService._roll(self: any, dropId: string): { any }
	local drop, result = self.Definitions.Drop[dropId], {}
	assert(drop, "invalid server drop definition")
	local function random(): number
		local value = self.Roll()
		assert(type(value) == "number" and value >= 0 and value < 1, "invalid server RNG")
		return value
	end
	for _, entry in drop.Entries do
		if entry.Guaranteed or random() < entry.Chance then
			local quantity = entry.MinQuantity
			if entry.MaxQuantity > entry.MinQuantity then
				quantity += math.floor(random()*(entry.MaxQuantity-entry.MinQuantity+1))
			end
			table.insert(result, { IngredientId = entry.IngredientId, Quantity = quantity })
		end
	end
	return result
end
function LootService.PendingCount(self: any): number
	local count = 0; for _ in self._jobs do count += 1 end; return count
end
function LootService.Enqueue(self: any, event: any): boolean
	assert(type(event) == "table" and (event.Kind == "Dead" or event.Kind == "PartBroken"), "server reward event required")
	assert(type(event.EventId) == "string" and #event.EventId > 0 and #event.EventId <= 200 and type(event.Members) == "table"
		and type(event.At) == "number" and event.At == event.At and math.abs(event.At) < math.huge, "invalid encounter reward")
	local config = self.Definitions.Monster[event.MonsterId]
	assert(config, "invalid reward monster")
	assert((event.Kind == "Dead" and event.DropId == config.DropId)
		or (event.Kind == "PartBroken" and event.PartId == "Horn" and event.DropId == config.Parts.Horn.DropId), "invalid drop source")
	if self._queued[event.EventId] then return true end
	local expires = event.At + self.Definitions.Hunting.Rewards.RetryLifetimeSeconds
	if expires < self.Now() then
		if self.Log then (self.Log :: (string) -> ())("Hunting reward event expired: " .. event.EventId) end
		return true
	end
	local actors, count = {}, 0
	for _, actorId in event.Members do
		assert(type(actorId) == "number" and actorId ~= 0 and actorId % 1 == 0 and math.abs(actorId) < math.huge, "invalid reward member")
		if not actors[actorId] then actors[actorId], count = true, count + 1 end
	end
	if self:PendingCount() + count > self.Definitions.Hunting.Rewards.MaxPending then return false end
	-- Build all rolls before enqueueing; an RNG error leaves the outbox retryable.
	local prepared, orderedActors = {}, {}
	for actorId in actors do table.insert(orderedActors, actorId) end
	table.sort(orderedActors)
	for _, actorId in orderedActors do
		local items = self:_roll(event.DropId)
		if #items > 0 then
			prepared[tostring(actorId) .. ":" .. event.EventId] = { ActorId = actorId, ExpiresAt = expires, RetryAt = self.Now(),
				Request = { ReceiptId = event.EventId, Kind = event.Kind, MonsterId = event.MonsterId, Origin = clone(event.Origin), Items = items } }
		end
	end
	for key, job in prepared do self._jobs[key] = job end
	self._queued[event.EventId] = expires
	return true
end
function LootService._emit(self: any, name: string, actorId: number, receipt: any, item: any?)
	if self.OnEvent then pcall(self.OnEvent, { Name = name, ActorId = actorId, MonsterId = receipt.MonsterId, Item = clone(item) }) end
end
function LootService.Tick(self: any)
	if self._ticking then return end
	self._ticking = true
	local now = self.Now()
	for eventId, expires in self._queued do if expires < now then self._queued[eventId] = nil end end
	for key, job in self._jobs do
		if job.ExpiresAt < now then
			self._jobs[key] = nil
			if self.Log then (self.Log :: (string) -> ())("Personal hunting reward expired for actor " .. tostring(job.ActorId)) end
			continue
		end
		if now < job.RetryAt or (self.CanAward and not (self.CanAward :: (number) -> boolean)(job.ActorId)) then continue end
		local ok, result = pcall(function() return self.Inventory:Grant(job.ActorId, clone(job.Request)) end)
		if ok then
			self._jobs[key] = nil
			if not result.Duplicate then
				local receipt = result.Receipt
				for _, item in receipt.Items do
					if self.Definitions.Ingredient[item.IngredientId].Category ~= "Material" then
						self:_emit("IngredientObtained", job.ActorId, receipt, item)
						if self.Definitions.Ingredient[item.IngredientId].Rarity == "Rare" then self:_emit("RareIngredientObtained", job.ActorId, receipt, item) end
					end
				end
				if receipt.Kind == "Dead" then self:_emit("MonsterKilled", job.ActorId, receipt) end
				if receipt.FirstIngredient then self:_emit("FirstIngredientObtained", job.ActorId, receipt) end
				if receipt.FirstHornboar then self:_emit("FirstHornboarKilled", job.ActorId, receipt) end
			end
		else
			job.RetryAt = self.Now() + self.Definitions.Hunting.Rewards.RetrySeconds
			if self.Log then (self.Log :: (string) -> ())("Personal hunting reward retry: " .. tostring(result)) end
		end
	end
	self._ticking = false
end
return LootService
