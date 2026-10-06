--!strict
-- Art references are resolved by stable Binding tags, never by visual paths.
local Binder = {}
local function binding(object: Instance): string?
	local value = object:FindFirstChild("Binding")
	return if value and value:IsA("StringValue") then value.Value else nil
end
function Binder.scan(model: Model): any
	local result: any = { Model = model, Root = nil, HornIntact = {}, HornBroken = {}, Joints = {} }
	for _, object in model:GetDescendants() do
		local tag = binding(object)
		if object:IsA("BasePart") then
			if tag == "Root" then result.Root = object
			elseif tag == "HornIntact" then table.insert(result.HornIntact, object)
			elseif tag == "HornBroken" then table.insert(result.HornBroken, object) end
		elseif object:IsA("Motor6D") and tag and string.sub(tag, 1, 6) == "Joint:" then
			result.Joints[string.sub(tag, 7)] = object
		end
	end
	assert(result.Root, "asset missing Root binding: " .. model.Name)
	return result
end
function Binder.horn(asset: any, broken: boolean)
	for _, part in asset.HornIntact do part.Transparency = if broken then 1 else 0 end
	for _, part in asset.HornBroken do part.Transparency = if broken then 0 else 1 end
	if asset.HornHitbox then asset.HornHitbox.CanQuery = not broken end
end
function Binder.monster(template: Model, config: any, encounterId: string): any
	local model = template:Clone()
	model.Name = encounterId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local asset = Binder.scan(model)
	asset.Root.Anchored = true
	local gameplay: Instance = model
	for _, object in model:GetDescendants() do if binding(object) == "GameplayContainer" then gameplay = object; break end end
	for _, id in { "Body", "Horn" } do
		local definition = config[id .. "Hitbox"]
		local part = Instance.new("Part")
		part.Name = "HIT_Hornboar_" .. id
		part.Size = Vector3.new(definition.Size.X, definition.Size.Y, definition.Size.Z)
		part.CFrame = asset.Root.CFrame * CFrame.new(definition.Offset.X, definition.Offset.Y, definition.Offset.Z)
		part.Transparency, part.CanCollide, part.CanTouch, part.Massless = 1, false, false, true
		part:SetAttribute("EncounterId", encounterId)
		part:SetAttribute("HitboxPart", id)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = asset.Root, part, part
		part.Parent = gameplay
		asset[id .. "Hitbox"] = part
	end
	model:SetAttribute("EncounterId", encounterId)
	Binder.horn(asset, false)
	return asset
end
function Binder.weapon(template: Model, hand: BasePart, character: Model, grip: CFrame): Model
	local model = template:Clone()
	model.Name = "MonCookEquippedWeapon"
	local asset = Binder.scan(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, false, true end
	end
	model:PivotTo(hand.CFrame * grip)
	model.Parent = character
	local motor = Instance.new("Motor6D")
	motor.Name, motor.Part0, motor.Part1 = "CleaverGrip", hand, asset.Root
	motor.C0, motor.Parent = grip, hand
	return model
end
return Binder
