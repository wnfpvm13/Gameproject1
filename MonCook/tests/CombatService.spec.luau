--!strict
local Service = require(script.Parent.Parent.src.server.Services.CombatService)
local Registry = require(script.Parent.Parent.src.shared.Config.Registry)
local Math = require(script.Parent.Parent.src.shared.Utilities.HuntingMath)
local Contracts = require(script.Parent.Parent.src.shared.Utilities.HuntingContracts)
local Defaults = require(script.Parent.Parent.src.shared.Utilities.PlayerDataDefaults)
return function(): number
	local count = 0
	local function check(_name: string, test: () -> ()) test(); count += 1 end
	local function fixture(): (any, any, any, any, any)
		local clock, hits, actions = { Now = 0, Id = 0 }, {}, {}
		local context = { ActorId = 1, Position = { X = 0, Y = 0, Z = 0 }, Facing = { X = 0, Y = 0, Z = -1 },
			Alive = true, Eligible = true, Location = "World", Profile = Defaults.new() }
		local target = { State = "Idle", Position = { X = 0, Y = 0, Z = -5 } }
		local contact = { EncounterId = "boar", Position = target.Position, ValidHitbox = true, Horn = true }
		local service = Service.new({ Definitions = Registry.Definitions, Geometry = Math, Contracts = Contracts,
			Now = function() return clock.Now end, NewId = function() clock.Id += 1; return "session-" .. tostring(clock.Id) end,
			GetContext = function() return context end, GetTarget = function(id: string) return if id == "boar" then target else nil end,
			ResolveContacts = function() return { contact } end,
			ApplyHit = function(id: string, actor: number, hit: any) table.insert(hits, { Id = id, Actor = actor, Hit = hit }) end,
			MoveDodge = function(_actor: number, direction: any, distance: number) context.Position = Math.advance(context.Position, direction, distance) end,
			OnAction = function(action: any) table.insert(actions, action) end })
		return service, clock, context, hits, { Target = target, Contact = contact, Actions = actions }
	end
	local function request(s: any, seq: number, kind: string?): any return s:Request(1, { Sequence = seq, AttackType = kind or "Basic" }) end
	check("three-hit progression and wrap", function()
		local s, clock = fixture()
		for seq = 1, 4 do
			local response = request(s, seq); assert(response.Ok and response.Action.ComboIndex == (seq-1)%3+1)
			clock.Now = response.Action.EndAt + 0.01
		end
	end)
	check("late input resets combo", function()
		local s, clock = fixture(); assert(request(s, 1).Action.ComboIndex == 1)
		clock.Now = 2; assert(request(s, 2).Action.ComboIndex == 1)
	end)
	check("heavy resets combo", function()
		local s, clock = fixture(); clock.Now = request(s, 1).Action.EndAt + 0.01
		clock.Now = request(s, 2, "Heavy").Action.EndAt + 0.01
		assert(request(s, 3).Action.ComboIndex == 1)
	end)
	check("active attack locks further input", function()
		local s, clock = fixture(); request(s, 1); clock.Now = 0.1
		assert(request(s, 2).Error == "Busy")
	end)
	check("burst limiter consumes rejected sequence", function()
		local s, clock = fixture(); request(s, 1); clock.Now = 0.01
		assert(request(s, 2).Error == "Rate"); clock.Now = 1
		assert(request(s, 2).Error == "Duplicate")
	end)
	check("accepted packet replay cannot damage twice", function()
		local s, clock, _, hits = fixture(); request(s, 1); clock.Now = 0.15; s:Tick()
		assert(request(s, 1).Error == "Duplicate"); s:Tick(); assert(#hits == 1)
	end)
	check("explicit attack window excludes windup and recovery", function()
		local s, clock, _, hits = fixture(); request(s, 1); clock.Now = 0.1; s:Tick(); assert(#hits == 0)
		clock.Now = 0.35; s:Tick(); assert(#hits == 0)
	end)
	check("contact once throughout window", function()
		local s, clock, _, hits = fixture(); request(s, 1)
		for _, time in { 0.13, 0.18, 0.25, 0.27 } do clock.Now = time; s:Tick() end
		assert(#hits == 1 and hits[1].Hit.Damage == 12 and hits[1].Hit.PartPower == 8)
	end)
	check("heavy is slower with stronger part power", function()
		local s, clock, _, hits = fixture(); local response = request(s, 1, "Heavy")
		assert(response.Action.WindowStartAt > Registry.Definitions.Weapon.StarterCleaver.Basic[1].Windup)
		clock.Now = 0.45; s:Tick(); assert(#hits == 1 and hits[1].Hit.Damage == 20 and hits[1].Hit.PartPower == 55)
	end)
	check("server rejects out-of-range target at hit time", function()
		local s, clock, _, hits, objects = fixture(); request(s, 1)
		objects.Contact.Position.Z = -100; clock.Now = 0.15; s:Tick(); assert(#hits == 0)
	end)
	check("behind and vertical targets rejected", function()
		local s, clock, _, hits, objects = fixture(); request(s, 1)
		objects.Contact.Position.Z = 5; clock.Now = 0.15; s:Tick(); assert(#hits == 0)
		objects.Contact.Position.Z, objects.Contact.Position.Y = -5, 20; s:Tick(); assert(#hits == 0)
	end)
	check("invalid hitbox and dead target rejected", function()
		local s, clock, _, hits, objects = fixture(); request(s, 1); clock.Now = 0.15
		objects.Contact.ValidHitbox = false; s:Tick(); assert(#hits == 0)
		objects.Contact.ValidHitbox = true; objects.Target.State = "Dead"; s:Tick(); assert(#hits == 0)
	end)
	check("client damage and roll fields rejected", function()
		local s = fixture()
		assert(not s:Request(1, { Sequence = 1, AttackType = "Heavy", Damage = 9999 }).Ok)
		assert(not s:Request(1, { Sequence = 2, AttackType = "DropRoll" }).Ok)
	end)
	check("alive world and ready profile required", function()
		local s, clock, ctx = fixture(); ctx.Alive = false; assert(request(s, 1).Error == "Unavailable")
		ctx.Alive, ctx.Location = true, "Expedition"; clock.Now = 1; assert(request(s, 2).Error == "Unavailable")
		ctx.Location, ctx.Eligible = "World", false; clock.Now = 2; assert(request(s, 3).Error == "Unavailable")
	end)
	check("equipment ownership validation", function()
		local s, _, ctx = fixture(); ctx.Profile.Equipment.EquippedWeaponId = "HunterCleaver"
		assert(request(s, 1).Error == "Weapon")
	end)
	check("death or travel during window cancels attack", function()
		local s, clock, ctx, hits = fixture(); request(s, 1); ctx.Location = "Restaurant"; clock.Now = 0.15; s:Tick()
		assert(#hits == 0 and s:State(1).Action == nil)
	end)
	check("equipment change during attack cancels", function()
		local s, clock, ctx, hits = fixture(); request(s, 1); ctx.Profile.Equipment.EquippedWeaponId = "other"; clock.Now = 0.15; s:Tick()
		assert(#hits == 0 and s:State(1).Action == nil)
	end)
	check("excessive facing correction denied", function()
		local s = fixture(); local result = s:Request(1, { Sequence = 1, AttackType = "Basic", Facing = { X = 0, Y = 0, Z = 1 } })
		assert(result.Ok and result.Action.Facing.Z == -1)
	end)
	check("limited mobile assist and invalid hint harmless", function()
		local s, clock, _, _, objects = fixture(); objects.Target.Position.X = 1
		local r = s:Request(1, { Sequence = 1, AttackType = "Basic", TargetHint = "boar" }); assert(r.Ok and r.Action.Facing.X > 0)
		clock.Now = 1; assert(s:Request(1, { Sequence = 2, AttackType = "Basic", TargetHint = "missing" }).Ok)
	end)
	check("dodge is movement with cooldown, no attack damage", function()
		local s, clock, ctx, hits = fixture(); local response = request(s, 1, "Dodge"); assert(response.Ok)
		clock.Now = 0.1; s:Tick(); assert(ctx.Position.Z < 0 and #hits == 0)
		clock.Now = 0.3; assert(request(s, 2, "Dodge").Error == "DodgeCooldown")
		clock.Now = 1.5; assert(request(s, 3, "Dodge").Ok)
		assert(Registry.Definitions.Combat.Rules.DodgeProtectionSeconds == 0)
	end)
	check("dodge permits deliberate sideways avoidance", function()
		local s, clock, ctx = fixture()
		assert(s:Request(1, { Sequence = 1, AttackType = "Dodge", Facing = { X = 1, Y = 0, Z = 0 } }).Ok)
		clock.Now = 0.1; s:Tick(); assert(ctx.Position.X > 0 and ctx.Position.Z == 0)
	end)
	check("dodge finishes its configured distance at the final tick", function()
		local s, clock, ctx = fixture(); request(s, 1, "Dodge")
		for _, time in { 0.05, 0.10, 0.15, 0.20, 0.25 } do clock.Now = time; s:Tick() end
		assert(math.abs(ctx.Position.Z + Registry.Definitions.Combat.Rules.DodgeDistance) < 0.00001)
		assert(s:State(1).Action == nil)
	end)
	check("action snapshots isolated and forget cancels", function()
		local s, clock, _, hits = fixture(); local response = request(s, 1); response.Action.Damage = 9999
		assert(s:State(1).Action.Damage == 12); s:Forget(1); clock.Now = 0.15; s:Tick(); assert(#hits == 0)
	end)
	check("presentation failure cannot enable duplicate attack", function()
		local s, clock, _, hits = fixture(); s.OnAction = function() error("UI unavailable") end
		assert(request(s, 1).Ok); clock.Now = 0.15; s:Tick(); assert(#hits == 1 and request(s, 1).Error == "Duplicate")
	end)
	return count
end
