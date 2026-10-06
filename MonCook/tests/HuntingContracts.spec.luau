--!strict
local Registry = require(script.Parent.Parent.src.shared.Config.Registry)
local Contracts = require(script.Parent.Parent.src.shared.Utilities.HuntingContracts)
local Math = require(script.Parent.Parent.src.shared.Utilities.HuntingMath)
local Defaults = require(script.Parent.Parent.src.shared.Utilities.PlayerDataDefaults)
local function copy(v: any): any
	if type(v) ~= "table" then return v end
	local r = {}; for k, item in v do r[k] = copy(item) end; return r
end
return function(): number
	local count = 0
	local function check(test: () -> ()) test(); count += 1 end
	local origin, front = { X = 0, Y = 0, Z = 0 }, { X = 0, Y = 0, Z = -1 }
	check(function()
		assert(Contracts.intent({ Sequence = 1, AttackType = "Heavy", Facing = front, TargetHint = "encounter" }, 100))
		for _, action in { "Basic", "Dodge" } do assert(Contracts.intent({ Sequence = 2, AttackType = action }, 100)) end
	end)
	check(function()
		for _, field in { "Damage", "HitMonster", "HornBroken", "UserId", "DropRoll", "Items" } do
			local p: any = { Sequence = 1, AttackType = "Basic" }; p[field] = 9999
			assert(not Contracts.intent(p, 100))
		end
	end)
	check(function()
		for _, n in { 0, -1, 1.5, math.huge, 0/0, 101 } do assert(not Contracts.intent({ Sequence = n, AttackType = "Basic" }, 100)) end
		assert(not Contracts.intent({ Sequence = 1, AttackType = "Roll" }, 100))
		assert(not Contracts.intent("Basic", 100))
	end)
	check(function()
		assert(not Contracts.intent({ Sequence = 1, AttackType = "Basic", Facing = { X = 99, Y = 0, Z = 0 } }, 100))
		assert(not Contracts.intent({ Sequence = 1, AttackType = "Basic", TargetHint = {} }, 100))
		assert(not Contracts.intent({ Sequence = 1, AttackType = "Basic", Facing = { X = 0/0, Y = 0, Z = 0 } }, 100))
	end)
	check(function()
		assert(Contracts.weapon(Defaults.new(), Registry.Definitions.Weapon) == "StarterCleaver")
		local p: any = Defaults.new(); p.Equipment.EquippedWeaponId = "MadeUp"
		assert(Contracts.weapon(p, Registry.Definitions.Weapon) == nil)
	end)
	check(function()
		local p: any = Defaults.new(); p.Equipment.EquippedWeaponId = "owned-1"
		p.Equipment.Weapons["owned-1"] = { InstanceId = "owned-1", WeaponConfigId = "StarterCleaver" }
		assert(Contracts.weapon(p, Registry.Definitions.Weapon) == "StarterCleaver")
		p.Equipment.Weapons["owned-1"].InstanceId = "different"
		assert(Contracts.weapon(p, Registry.Definitions.Weapon) == nil)
	end)
	check(function()
		assert(Math.correctFacing(front, { X = 0, Y = 0, Z = 1 }, 55).Z == -1)
		assert(Math.correctFacing(front, { X = 0.4, Y = 0, Z = -0.9 }, 55).X > 0)
		assert(Math.correctFacing(front, origin, 55).Z == -1)
	end)
	check(function()
		assert(Math.inArc(origin, front, { X = 0, Y = 2, Z = -5 }, 8, 100, 6))
		assert(not Math.inArc(origin, front, { X = 0, Y = 0, Z = 5 }, 8, 100, 6))
		assert(not Math.inArc(origin, front, { X = 0, Y = 9, Z = -5 }, 8, 100, 6))
		assert(not Math.inArc(origin, front, { X = 0, Y = 0, Z = -20 }, 8, 100, 6))
	end)
	check(function()
		assert(Math.segmentDistance({ X = 2, Y = 0, Z = -5 }, origin, { X = 0, Y = 0, Z = -10 }) == 2)
		assert(Math.offset(origin, front, { X = 2, Y = 3, Z = -4 }).Z == -4)
	end)
	check(function()
		for id, item in Registry.Definitions.Ingredient do
			assert(Contracts.bucket(item) == (if id == "HornCore" then "Materials" else "Ingredients"))
		end
		assert(Registry.Definitions.Economy.Rules.MonsterGoldDrops == false)
	end)
	check(function()
		local config = copy(Registry.Definitions); config.Drop.Hornboar.Entries[1].Chance = 0.5
		assert(not pcall(Registry.validate, config))
		config = copy(Registry.Definitions); config.Weapon.StarterCleaver.Heavy.PartPower = 1
		assert(not pcall(Registry.validate, config))
	end)
	check(function()
		local config = copy(Registry.Definitions); config.Spawn.GreenwoodOutskirts.RegionId = "GreenwoodDeepRuins"
		assert(not pcall(Registry.validate, config))
		config = copy(Registry.Definitions); config.Hunting.Rewards.ReceiptRetentionSeconds = 1
		assert(not pcall(Registry.validate, config))
	end)
	return count
end
