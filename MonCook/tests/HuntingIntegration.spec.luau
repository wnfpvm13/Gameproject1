--!strict
-- Real pure services together. Roblox physics, input events and Studio are separate QA.
local Combat = require(script.Parent.Parent.src.server.Services.CombatService)
local Monsters = require(script.Parent.Parent.src.server.Services.MonsterService)
local Inventory = require(script.Parent.Parent.src.server.Services.InventoryService)
local Loot = require(script.Parent.Parent.src.server.Services.LootService)
local Data = require(script.Parent.Parent.src.server.Services.DataService)
local Store = require(script.Parent.Support.InMemoryStore)
local Registry = require(script.Parent.Parent.src.shared.Config.Registry)
local Math = require(script.Parent.Parent.src.shared.Utilities.HuntingMath)
local HitGeometry = require(script.Parent.Parent.src.shared.Utilities.HuntingHitGeometry)
local Contracts = require(script.Parent.Parent.src.shared.Utilities.HuntingContracts)
local Defaults = require(script.Parent.Parent.src.shared.Utilities.PlayerDataDefaults)
local Migration = require(script.Parent.Parent.src.shared.Utilities.PlayerDataMigration)
local function clone(v: any): any
	if type(v) ~= "table" then return v end
	local r = {}; for k, x in v do r[k] = clone(x) end; return r
end
return function(): number
	local count = 0
	local function check(_name: string, test: () -> ()) test(); count += 1 end
	local function fixture(): any
		local config, clock, store = clone(Registry.Definitions), { Now = 100, Id = 0 }, Store.new()
		config.Spawn.GreenwoodOutskirts.MaxAlive = 1
		local data = Data.new({ Store = store, OwnerId = "hunting", Now = function() return clock.Now end, LockSeconds = 180, NewData = Defaults.new, Migrate = Migration.migrate })
		local actors, seq = {}, {}
		for id = 1, 3 do
			data:Load(id); actors[id] = { ActorId = id, Position = { X = 100, Y = 3, Z = 100 },
				Facing = { X = 0, Y = 0, Z = -1 }, Alive = true, Eligible = true, Location = "World" }; seq[id] = 0
		end
		local function newId(): string clock.Id += 1; return "id-" .. tostring(clock.Id) end
		local monster = Monsters.new({ Definitions = config, Geometry = Math, NewId = newId, Now = function() return clock.Now end })
		monster:Tick({}, 0.05)
		local inventory = Inventory.new({ Data = data, Definitions = config, Geometry = Math, Contracts = Contracts, Now = function() return clock.Now end })
		local rolls = { Count = 0 }
		local loot = Loot.new({ Definitions = config, Inventory = inventory, Now = function() return clock.Now end,
			Roll = function() rolls.Count += 1; return 0.99 end, CanAward = function(id: number) return data:HasProfile(id) end })
		local blocked = { Value = false }
		local combat = Combat.new({ Definitions = config, Geometry = Math, Contracts = Contracts, Now = function() return clock.Now end, NewId = newId,
			GetContext = function(id: number): any local c = clone(actors[id]); c.Profile = data:Get(id); return c end,
			GetTarget = function(id: string): any return monster:Get(id) end,
			ResolveContacts = function(ctx: any, action: any): any
				local result = {}; if blocked.Value then return result end
				for _, m in monster:List() do
					local definition = config.Monster[m.MonsterId]
					local body, horn = Math.offset(m.Position, m.Facing, definition.BodyHitbox.Offset), Math.offset(m.Position, m.Facing, definition.HornHitbox.Offset)
					local hitHorn = if m.HornBroken then nil else HitGeometry.contact(ctx.Position, action.Facing, horn, m.Facing,
						definition.HornHitbox.Size, action.Reach, action.ArcDegrees, config.Combat.Rules.VerticalTolerance)
					local hitBody = HitGeometry.contact(ctx.Position, action.Facing, body, m.Facing,
						definition.BodyHitbox.Size, action.Reach, action.ArcDegrees, config.Combat.Rules.VerticalTolerance)
					if hitHorn or hitBody then table.insert(result, { EncounterId = m.EncounterId, Position = hitHorn or hitBody, Horn = hitHorn ~= nil, ValidHitbox = true }) end
				end
				return result
			end,
			ApplyHit = function(id: string, actor: number, hit: any) monster:ApplyHit(id, actor, hit) end,
			MoveDodge = function(id: number, facing: any, distance: number) actors[id].Position = Math.advance(actors[id].Position, facing, distance) end })
		local f: any = { Config = config, Clock = clock, Store = store, Data = data, Monster = monster, Inventory = inventory,
			Combat = combat, Loot = loot, Actors = actors, Sequences = seq, Rolls = rolls, Blocked = blocked }
		function f:Drain()
			for _, e in monster:PendingRewards() do if loot:Enqueue(e) then monster:AckReward(e.EventId) end end
			loot:Tick()
		end
		function f:Attack(actorId: number, kind: string, part: string?): any
			local m = monster:Get("id-1")
			local localOffset = if part == "Horn" then { X = 0, Y = 3, Z = -9 } else { X = 7, Y = 3, Z = 0 }
			actors[actorId].Position = Math.offset(m.Position, m.Facing, localOffset)
			actors[actorId].Facing = Math.direction(actors[actorId].Position, m.Position)
			seq[actorId] += 1
			local response = combat:Request(actorId, { Sequence = seq[actorId], AttackType = kind, Facing = actors[actorId].Facing })
			assert(response.Ok, tostring(response.Error))
			while clock.Now < response.Action.EndAt+0.1 do clock.Now += 0.05; combat:Tick(); self:Drain() end
			return response
		end
		function f:Kill(actorId: number)
			for _ = 1, 20 do if monster:Get("id-1").State == "Dead" then return end; self:Attack(actorId, "Basic") end
			error("Hornboar did not die")
		end
		return f
	end
	check("solo horn break then kill then persisted inventory", function()
		local f = fixture(); f:Attack(1, "Heavy", "Horn"); f:Attack(1, "Heavy", "Horn")
		assert(f.Monster:Get("id-1").HornBroken and f.Monster:Get("id-1").BodyHP > 0 and f.Data:Get(1).Inventory.Materials.HornCore == 1)
		f:Kill(1); local p = f.Data:Get(1)
		assert(p.Inventory.Ingredients.HornboarMeat == 2 and p.Inventory.Materials.HornCore == 1 and p.Currencies.Gold == 0)
		f.Data:Release(1); f.Data:Load(1); assert(f.Inventory:Snapshot(1).Materials[1].Quantity == 1)
	end)
	check("two contributors, final hit owner and AFK bystander", function()
		local f = fixture(); f:Attack(1, "Basic"); f:Attack(2, "Heavy", "Horn"); f:Attack(2, "Heavy", "Horn"); f:Kill(2)
		for _, id in { 1, 2 } do
			local p = f.Data:Get(id); assert(p.Inventory.Ingredients.HornboarMeat == 2 and p.Inventory.Materials.HornCore == 1 and p.Currencies.Gold == 0)
		end
		assert(next(f.Data:Get(3).Inventory.Ingredients) == nil and next(f.Data:Get(3).Inventory.Materials) == nil)
	end)
	check("normal kill without horn grants food only", function()
		local f = fixture(); f:Kill(1); assert(f.Data:Get(1).Inventory.Ingredients.HornboarMeat == 2 and next(f.Data:Get(1).Inventory.Materials) == nil)
	end)
	check("replayed attack and dead hits cannot duplicate rewards", function()
		local f = fixture(); local first = f:Attack(1, "Heavy", "Horn")
		assert(not f.Combat:Request(1, { Sequence = f.Sequences[1], AttackType = "Heavy" }).Ok)
		f:Attack(1, "Heavy", "Horn"); f:Kill(1); local old = f.Data:Get(1)
		f.Clock.Now += 1; f.Combat:Request(1, { Sequence = f.Sequences[1]+1, AttackType = "Heavy" }); f.Clock.Now += 0.45; f.Combat:Tick(); f:Drain()
		assert(f.Data:Get(1).Inventory.Materials.HornCore == old.Inventory.Materials.HornCore and f.Data:Get(1).Inventory.Ingredients.HornboarMeat == old.Inventory.Ingredients.HornboarMeat)
		assert(first.Action.Damage == 20)
	end)
	check("persist failure keeps personal roll for later commit", function()
		local f = fixture(); f:Attack(1, "Heavy", "Horn"); f.Store.FailNext = true
		f:Attack(1, "Heavy", "Horn")
		-- Attack helper advances through the retry; no quantity duplication.
		f.Clock.Now += 1.1; f:Drain(); assert(f.Data:Get(1).Inventory.Materials.HornCore == 1)
		f:Kill(1); assert(f.Rolls.Count == 3 and f.Data:Get(1).Inventory.Ingredients.HornboarMeat == 2)
	end)
	check("late contributor is excluded from earlier part reward", function()
		local f = fixture(); f:Attack(1, "Heavy", "Horn"); f:Attack(1, "Heavy", "Horn"); f:Attack(2, "Basic"); f:Kill(2)
		assert(f.Data:Get(2).Inventory.Materials.HornCore == nil and f.Data:Get(2).Inventory.Ingredients.HornboarMeat == 2)
	end)
	check("blocked contacts cannot damage or earn loot", function()
		local f = fixture(); f.Blocked.Value = true; f:Attack(1, "Heavy", "Horn")
		assert(f.Monster:Get("id-1").BodyHP == 140 and #f.Monster:Eligible("id-1") == 0 and f.Loot:PendingCount() == 0)
	end)
	check("respawn has fresh identity health and contribution", function()
		local f = fixture(); f:Kill(1); local deathAt = f.Monster:Get("id-1").DeathAt
		f.Clock.Now = deathAt+7.1; f.Monster:Tick({}, 0.05)
		local spawned = f.Monster:List()[1]
		assert(spawned.EncounterId ~= "id-1" and spawned.BodyHP == 140 and spawned.HornHP == 80 and #f.Monster:Eligible(spawned.EncounterId) == 0)
	end)
	return count
end
