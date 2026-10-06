--!strict
local Math = require(script.Parent.HuntingMath)
local Contracts = {}
local fields: { [string]: boolean } = { Sequence = true, AttackType = true, Facing = true, TargetHint = true }
local actions: { [string]: boolean } = { Basic = true, Heavy = true, Dodge = true }
function Contracts.intent(payload: any, maximum: number): (boolean, string?)
	if type(payload) ~= "table" then return false, "Payload" end
	local count = 0
	for key in payload do
		if type(key) ~= "string" or not fields[key] then return false, "Fields" end
		count += 1
	end
	if count > 4 then return false, "Fields" end
	if not Math.finite(payload.Sequence) or payload.Sequence < 1 or payload.Sequence > maximum
		or payload.Sequence % 1 ~= 0 then return false, "Sequence" end
	if type(payload.AttackType) ~= "string" or not actions[payload.AttackType] then return false, "Action" end
	if payload.Facing ~= nil then
		if not Math.point(payload.Facing) then return false, "Facing" end
		for key in payload.Facing do if key ~= "X" and key ~= "Y" and key ~= "Z" then return false, "Facing" end end
		if math.abs(payload.Facing.X) > 1 or math.abs(payload.Facing.Y) > 1 or math.abs(payload.Facing.Z) > 1 then return false, "Facing" end
	end
	if payload.TargetHint ~= nil and (type(payload.TargetHint) ~= "string" or #payload.TargetHint == 0
		or #payload.TargetHint > 128) then return false, "TargetHint" end
	return true, nil
end
function Contracts.weapon(profile: any, weapons: any): (string?, any)
	if type(profile) ~= "table" or type(profile.Equipment) ~= "table" then return nil, nil end
	local equipment = profile.Equipment
	local equipped = equipment.EquippedWeaponId
	-- Preserve the Foundation starter default. Other IDs must refer to owned instances.
	if equipped == "StarterCleaver" and weapons.StarterCleaver then return "StarterCleaver", weapons.StarterCleaver end
	if type(equipment.Weapons) ~= "table" then return nil, nil end
	for key, owned in equipment.Weapons do
		if type(owned) == "table" and owned.InstanceId == equipped and (key == equipped or type(key) == "number")
			and type(owned.WeaponConfigId) == "string" and weapons[owned.WeaponConfigId] then
			return owned.WeaponConfigId, weapons[owned.WeaponConfigId]
		end
	end
	return nil, nil
end
function Contracts.bucket(ingredient: any): string
	return if ingredient.Category == "Material" then "Materials" else "Ingredients"
end
return table.freeze(Contracts)
