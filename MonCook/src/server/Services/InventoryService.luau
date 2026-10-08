--!strict
-- Server-only API; no remote exposes Grant. Stacks and receipt commit together.
local InventoryService = {}
InventoryService.__index = InventoryService
local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}; for key, child in value do result[key] = clone(child) end; return result
end
function InventoryService.new(options: any): any
	return setmetatable({ Data = options.Data, Definitions = options.Definitions, Contracts = options.Contracts,
		Math = options.Geometry, Now = options.Now, OnGranted = options.OnGranted, Log = options.Log }, InventoryService)
end
function InventoryService._items(self: any, items: any): { any }
	assert(type(items) == "table" and #items > 0, "reward items required")
	local totals, result, seen = {}, {}, 0
	for index, item in items do
		assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #items, "dense reward array required")
		seen += 1
		assert(type(item) == "table" and type(item.IngredientId) == "string" and self.Definitions.Ingredient[item.IngredientId], "invalid ingredient")
		assert(self.Math.finite(item.Quantity) and item.Quantity > 0 and item.Quantity % 1 == 0
			and item.Quantity <= self.Definitions.Hunting.Rewards.MaxStack, "invalid item quantity")
		totals[item.IngredientId] = (totals[item.IngredientId] or 0) + item.Quantity
	end
	assert(seen == #items, "dense reward array required")
	for id, quantity in totals do
		assert(quantity <= self.Definitions.Hunting.Rewards.MaxStack, "reward overflow")
		table.insert(result, { IngredientId = id, Quantity = quantity })
	end
	table.sort(result, function(a: any, b: any) return a.IngredientId < b.IngredientId end)
	return result
end
local function sameItems(a: any, b: any): boolean
	if #a ~= #b then return false end
	for index, item in a do if item.IngredientId ~= b[index].IngredientId or item.Quantity ~= b[index].Quantity then return false end end
	return true
end
function InventoryService.Grant(self: any, actorId: number, request: any): any
	assert(type(request) == "table" and type(request.ReceiptId) == "string" and #request.ReceiptId > 0
		and #request.ReceiptId <= 200, "invalid hunting receipt")
	assert((request.Kind == "Dead" or request.Kind == "PartBroken") and self.Definitions.Monster[request.MonsterId], "invalid reward source")
	local items, now = self:_items(request.Items), self.Now()
	local profile = self.Data:Get(actorId)
	local existing = if profile.HuntingReceipts then profile.HuntingReceipts[request.ReceiptId] else nil
	if existing then
		assert(existing.Kind == request.Kind and existing.MonsterId == request.MonsterId and sameItems(existing.Items, items), "receipt content mismatch")
		return { Duplicate = true, Receipt = clone(existing) }
	end
	local committed = self.Data:Update(actorId, function(draft: any)
		if draft.HuntingReceipts == nil then draft.HuntingReceipts = {} end
		assert(type(draft.HuntingReceipts) == "table", "invalid hunting receipt collection")
		assert(draft.HuntingReceipts[request.ReceiptId] == nil, "receipt already exists")
		for key, receipt in draft.HuntingReceipts do
			assert(type(receipt) == "table" and self.Math.finite(receipt.GrantedAt), "invalid stored hunting receipt")
			if now - receipt.GrantedAt > self.Definitions.Hunting.Rewards.ReceiptRetentionSeconds then draft.HuntingReceipts[key] = nil end
		end
		local firstIngredient, firstHornboar = false, false
		for _, item in items do
			local definition = self.Definitions.Ingredient[item.IngredientId]
			local bucket = self.Contracts.bucket(definition)
			local current = draft.Inventory[bucket][item.IngredientId] or 0
			assert(self.Math.finite(current) and current >= 0 and current % 1 == 0, "invalid existing item stack")
			assert(current + item.Quantity <= self.Definitions.Hunting.Rewards.MaxStack, "item stack overflow")
			draft.Inventory[bucket][item.IngredientId] = current + item.Quantity
			if bucket == "Ingredients" and not draft.AnalyticsFlags.FirstIngredientObtained then firstIngredient = true end
		end
		if request.Kind == "Dead" and request.MonsterId == "Hornboar" and not draft.AnalyticsFlags.FirstHornboarKilled then firstHornboar = true end
		if firstIngredient then draft.AnalyticsFlags.FirstIngredientObtained = true end
		if firstHornboar then draft.AnalyticsFlags.FirstHornboarKilled = true end
		draft.HuntingReceipts[request.ReceiptId] = { GrantedAt = now, Items = clone(items), Kind = request.Kind,
			MonsterId = request.MonsterId, FirstIngredient = firstIngredient, FirstHornboar = firstHornboar }
	end)
	local receipt = committed.HuntingReceipts[request.ReceiptId]
	if self.OnGranted then
		local ok, reason = pcall(self.OnGranted, actorId, clone(receipt), clone(request.Origin))
		if not ok and self.Log then (self.Log :: (string) -> ())("Inventory presentation: " .. tostring(reason)) end
	end
	return { Duplicate = false, Receipt = clone(receipt) }
end
function InventoryService.Snapshot(self: any, actorId: number): any
	local profile, result = self.Data:Get(actorId), { Ingredients = {}, Materials = {} }
	for _, bucket in { "Ingredients", "Materials" } do
		for id, quantity in profile.Inventory[bucket] do
			if type(id) ~= "string" or not self.Math.finite(quantity) or quantity <= 0 then continue end
			local definition = self.Definitions.Ingredient[id]
			table.insert(result[bucket], { IngredientId = id, Quantity = quantity,
				DisplayName = if definition then definition.DisplayName else id,
				Category = if definition then definition.Category else "Unknown",
				AssetId = if definition then definition.AssetId else nil,
				Rarity = if definition then definition.Rarity or "Common" else "Common" })
		end
		table.sort(result[bucket], function(a: any, b: any) return a.IngredientId < b.IngredientId end)
	end
	return result
end
return InventoryService
