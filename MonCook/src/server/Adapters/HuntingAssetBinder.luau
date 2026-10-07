--!strict
-- Imported Studio assets prefer explicit Binding tags, with stable name fallbacks
-- for the user-imported Hornboar MeshPart + Motor6D rig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RigMap = require(ReplicatedStorage:WaitForChild("Shared").Utilities.ImportedHornboarRig)
local Policy = require(ReplicatedStorage:WaitForChild("Shared").Utilities.HuntingAssetPolicy)

local Binder = {}
local function binding(object: Instance): string?
	local value = object:FindFirstChild("Binding")
	return if value and value:IsA("StringValue") then value.Value else nil
end
local function semanticPart(object: BasePart): string?
	return binding(object) or RigMap.partBinding(object.Name)
end
local function semanticJoint(object: Motor6D): string?
	local tag = binding(object)
	if tag and string.sub(tag, 1, 6) == "Joint:" then return string.sub(tag, 7) end
	return RigMap.jointSemantic(object.Name, if object.Parent then object.Parent.Name else nil)
end

function Binder.resolve(folder: Instance, config: any): Model
	local preferred = config.PreferredAssetId and folder:FindFirstChild(config.PreferredAssetId)
	if preferred and preferred:IsA("Model") then
		local summary: any = { MarkedReady = preferred:GetAttribute("HornboarV2Ready") == true,
			Root = false, Meshes = 0, HornIntact = false, HornBroken = false, Bones = {} }
		for _, object in preferred:GetDescendants() do
			if object:IsA("BasePart") then
				local semantic = semanticPart(object)
				if semantic == "Root" then summary.Root = true end
				if object:IsA("MeshPart") then summary.Meshes += 1 end
				if semantic == "HornIntact" then summary.HornIntact = true end
				if semantic == "HornBroken" then summary.HornBroken = true end
			elseif object:IsA("Bone") then
				local semantic = RigMap.boneSemantic(object.Name)
				if semantic then summary.Bones[semantic] = true end
			end
		end
		local ready, reason = Policy.ready(summary)
		if ready then return preferred end
		warn("[MonCook Art] V2 unavailable: "..tostring(reason).."; using retained V1")
	end
	local fallback = folder:FindFirstChild(config.AssetId)
	assert(fallback and fallback:IsA("Model"), "missing imported monster template: "..config.AssetId)
	return fallback :: Model
end

function Binder.scan(model: Model): any
	local result: any = { Model = model, Root = nil, HornIntact = {}, HornBroken = {}, Joints = {} }
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			local tag = semanticPart(object)
			if tag == "Root" then result.Root = object
			elseif tag == "HornIntact" then table.insert(result.HornIntact, object)
			elseif tag == "HornBroken" then table.insert(result.HornBroken, object) end
		elseif object:IsA("Motor6D") then
			local name = semanticJoint(object)
			if name then result.Joints[name] = object end
		end
	end
	if not result.Root and model.PrimaryPart then result.Root = model.PrimaryPart end
	assert(result.Root, "asset missing Root/RootPart: " .. model.Name)
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
	-- Imported visuals are presentation only. Gameplay uses the explicit server hitboxes below.
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			object.Anchored = object == asset.Root
			object.CanCollide, object.CanQuery, object.CanTouch, object.Massless = false, false, false, true
		end
	end
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
	model:SetAttribute("ImportedRuntimeAsset", true)
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
