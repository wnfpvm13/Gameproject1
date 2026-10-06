--!strict
-- Roblox boundary only. Foundation's authenticated actor/profile/location APIs are injected.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared.Config.Registry)
local Math = require(Shared.Utilities.HuntingMath)
local HitGeometry = require(Shared.Utilities.HuntingHitGeometry)
local Contracts = require(Shared.Utilities.HuntingContracts)
local NetworkDefinition = require(Shared.Remotes.Definitions).Hunting
local FieldConfig = require(Shared.Config.GreenwoodConfig)
local Style = require(Shared.Config.HuntingUIStyle)
local CombatStyle = require(Shared.Config.CombatPresentationConfig)
local Services = script.Parent.Parent.Services
local MonsterService = require(Services.MonsterService)
local CombatService = require(Services.CombatService)
local InventoryService = require(Services.InventoryService)
local LootService = require(Services.LootService)
local Binder = require(script.Parent.HuntingAssetBinder)
local Field = require(script.Parent.GreenwoodField)
local Runtime = {}
local function point(v: Vector3): any return { X = v.X, Y = v.Y, Z = v.Z } end
local function vector(p: any): Vector3 return Vector3.new(p.X, p.Y, p.Z) end
local function color(c: any): Color3 return Color3.new(c[1], c[2], c[3]) end
local function now(): number return Workspace:GetServerTimeNow() end
local function newId(): string return HttpService:GenerateGUID(false) end
function Runtime.start(options: any): any
	if options.IsRestaurant then return nil end
	local definitions, rules = Registry.Definitions, Registry.Definitions.Combat.Rules
	local showHitboxes = HitGeometry.debugEnabled(RunService:IsStudio(), definitions.Testing.ShowCombatHitboxes)
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local monsterAssets, weaponAssets = assets:WaitForChild("Monsters"), assets:WaitForChild("Weapons")
	for _, definition in definitions.Monster do assert(monsterAssets:FindFirstChild(definition.AssetId), "missing monster V1 asset") end
	Field.build(Workspace, assets:WaitForChild("Environment"), FieldConfig)
	local modelsFolder = Instance.new("Folder")
	modelsFolder.Name, modelsFolder.Parent = "MonCookMonsters", Workspace
	local debugView = if showHitboxes then require(script.Parent.CombatDebugView).new(modelsFolder, CombatStyle) else nil
	local network = Instance.new("Folder")
	network.Name = NetworkDefinition.Folder
	local intent, stateRemote, changed = Instance.new("RemoteEvent"), Instance.new("RemoteFunction"), Instance.new("RemoteEvent")
	intent.Name, stateRemote.Name, changed.Name = NetworkDefinition.Intent, NetworkDefinition.State, NetworkDefinition.Changed
	intent.Parent, stateRemote.Parent, changed.Parent = network, network, network
	local analytics = Instance.new("BindableEvent")
	analytics.Name, analytics.Parent = "HuntingAnalytics", script.Parent.Parent
	local function observe(event: any) analytics:Fire(event) end
	local models: { [string]: any } = {}
	local lastStateRequest: { [Player]: number } = {}
	local dodges: { [number]: any } = {}
	local departing: { [number]: Player } = {}
	local closing = false
	local function log(message: string) warn("[MonCook Hunting] " .. message) end
	local function profile(actorId: number): any
		if not options.Data:HasProfile(actorId) then return nil end
		local ok, data = pcall(function() return options.Data:Get(actorId) end)
		return if ok then data else nil
	end
	local function context(actorId: number): any
		local player = options.Lookup(actorId)
		local character = if player then player.Character else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local data = profile(actorId)
		if not player or not root or not root:IsA("BasePart") or not humanoid or not data then return nil end
		if departing[actorId] and departing[actorId] ~= player then departing[actorId] = nil end
		return { ActorId = actorId, Player = player, Character = character, Root = root, Humanoid = humanoid,
			Position = point(root.Position), Facing = point(root.CFrame.LookVector), Profile = data,
			Alive = humanoid.Health > 0, Location = options.Location(actorId),
			Eligible = not closing and not departing[actorId] and not options.IsTraveling(actorId) }
	end
	local function contexts(): { any }
		local result = {}
		for _, player in Players:GetPlayers() do
			local actorId = options.ActorId(player)
			if actorId then local value = context(actorId); if value then table.insert(result, value) end end
		end
		return result
	end
	local function obstacleParams(): RaycastParams
		local excluded: { Instance } = { modelsFolder }
		for _, player in Players:GetPlayers() do if player.Character then table.insert(excluded, player.Character) end end
		local params = RaycastParams.new()
		params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, excluded
		params.RespectCanCollide = true
		return params
	end
	local function lineClear(from: Vector3, to: Vector3): boolean
		return Workspace:Raycast(from, to-from, obstacleParams()) == nil
	end
	local inventory: any
	local combat: any
	local monsters: any
	local function playerState(actorId: number): any
		local data = profile(actorId)
		if not data then return { Ready = false } end
		local ctx = context(actorId)
		local weaponId = Contracts.weapon(data, definitions.Weapon)
		local combatState = combat:State(actorId)
		return { Ready = true, Location = options.Location(actorId), Traveling = options.IsTraveling(actorId),
			Inventory = inventory:Snapshot(actorId), WeaponId = weaponId,
			Health = if ctx then ctx.Humanoid.Health else 0, MaxHealth = if ctx then ctx.Humanoid.MaxHealth else 100,
			DodgeReadyAt = combatState.DodgeReadyAt, Action = combatState.Action }
	end
	local function sendState(actorId: number)
		local player = options.Lookup(actorId)
		if not player or player.Parent ~= Players then return end
		local ok, snapshot = pcall(playerState, actorId)
		if ok then changed:FireClient(player, { Kind = "State", State = snapshot }) end
	end
	inventory = InventoryService.new({ Data = options.Data, Definitions = definitions, Geometry = Math, Contracts = Contracts, Now = now, Log = log,
		OnGranted = function(actorId: number, receipt: any, origin: any)
			local player = options.Lookup(actorId)
			if not player or player.Parent ~= Players then return end
			changed:FireClient(player, { Kind = "Loot", Receipt = receipt, Origin = origin })
			sendState(actorId)
		end })
	local random = Random.new()
	local loot = LootService.new({ Definitions = definitions, Inventory = inventory, Now = now,
		Roll = function() return random:NextNumber() end, Log = log,
		CanAward = function(actorId: number) return (options.Lookup(actorId) ~= nil or departing[actorId] ~= nil) and options.Data:HasProfile(actorId) end,
		OnEvent = observe })
	local function header(asset: any)
		local gui = Instance.new("BillboardGui")
		gui.Name, gui.Adornee, gui.Size = "HornboarHealth", asset.Root, UDim2.fromOffset(170, 57)
		gui.StudsOffsetWorldSpace, gui.MaxDistance, gui.AlwaysOnTop = Vector3.new(0, 6.2, 0), 75, false
		gui.Parent = asset.Model
		local background = Instance.new("Frame")
		background.Size, background.BackgroundColor3, background.BackgroundTransparency = UDim2.fromScale(1, 1), color(Style.Background), 0.22
		background.Parent = gui
		local corner = Instance.new("UICorner"); corner.CornerRadius, corner.Parent = UDim.new(0, 8), background
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency, text.Font, text.TextSize = UDim2.new(1, -8, 1, -14), 1, Enum.Font.GothamBold, 13
		text.Position, text.TextColor3, text.Parent = UDim2.fromOffset(4, 2), color(Style.Text), background
		local bar = Instance.new("Frame")
		bar.Position, bar.Size, bar.BackgroundColor3, bar.BorderSizePixel = UDim2.new(0, 4, 1, -9), UDim2.new(1, -8, 0, 5), color(Style.Health), 0
		bar.Parent = background
		asset.Header, asset.HealthBar = text, bar
	end
	local function telegraph(asset: any, monster: any, definition: any)
		if asset.Telegraph then asset.Telegraph:Destroy(); asset.Telegraph = nil end
		if monster.State ~= "Windup" then return end
		local attack = definition.Attacks[monster.AttackType]
		local mark = Instance.new("Part")
		mark.Name, mark.Anchored, mark.CanCollide, mark.CanTouch, mark.CanQuery = "AttackTelegraph", true, false, false, false
		mark.Material, mark.Color, mark.Transparency = Enum.Material.Neon, color(FieldConfig.Telegraph.Color), FieldConfig.Telegraph.Transparency
		local length = if attack.Speed then attack.Speed*attack.Duration+attack.ContactForwardOffset+attack.Radius else attack.Range
		mark.Size = Vector3.new(attack.Radius*2, FieldConfig.Telegraph.Thickness, length)
		local origin, facing = vector(monster.Position)+Vector3.new(0, 0.06, 0), vector(monster.Facing)
		mark.CFrame, mark.Parent = CFrame.lookAt(origin, origin+facing)*CFrame.new(0, 0, -length/2), modelsFolder
		asset.Telegraph = mark
	end
	monsters = MonsterService.new({ Definitions = definitions, Geometry = Math, Now = now, NewId = newId, Log = log,
		Move = function(id: string, from: any, to: any): any
			local definition = definitions.Monster[monsters:Get(id).MonsterId]
			local start, finish = vector(from)+vector(definition.BodyHitbox.Offset), vector(to)+vector(definition.BodyHitbox.Offset)
			local delta = finish-start
			if delta.Magnitude > 0 then
				local hit = Workspace:Blockcast(CFrame.new(start), vector(definition.BodyHitbox.Size), delta, obstacleParams())
				if hit then return Math.copy(from) end
			end
			return to
		end,
		OnEvent = function(event: any)
			if event.Kind == "Damaged" then
				changed:FireAllClients({ Kind = "Hit", EncounterId = event.EncounterId, ActorId = event.ActorId,
					Origin = event.Origin, Part = event.Part, Heavy = event.Heavy, Reaction = event.Reaction, At = event.At })
			elseif event.Kind == "AttackHit" then
				local ctx = context(event.ActorId)
				if ctx and ctx.Alive and ctx.Location == "World" and ctx.Eligible
					and lineClear(vector(event.Origin)+Vector3.new(0, 3, 0), ctx.Root.Position) then ctx.Humanoid:TakeDamage(event.Damage) end
			elseif event.Kind == "PartBroken" then
				local asset = models[event.EncounterId]
				if asset then Binder.horn(asset, true) end
				changed:FireAllClients({ Kind = "PartBroken", EncounterId = event.EncounterId, Origin = event.Origin })
				observe({ Name = "PartBroken", EncounterId = event.EncounterId, MonsterId = event.MonsterId })
			elseif event.Kind == "MonsterEncounterStarted" then observe({ Name = event.Kind, ActorId = event.ActorId, MonsterId = event.MonsterId }) end
		end })
	local function contacts(ctx: any, action: any): { any }
		local included: { Instance } = {}
		for _, asset in models do
			if asset.Model:GetAttribute("State") ~= "Dead" then
				table.insert(included, asset.BodyHitbox)
				if asset.HornHitbox.CanQuery then table.insert(included, asset.HornHitbox) end
			end
		end
		local overlap = OverlapParams.new()
		overlap.FilterType, overlap.FilterDescendantsInstances = Enum.RaycastFilterType.Include, included
		local position, facing = vector(ctx.Position), vector(action.Facing)
		local frame = CFrame.lookAt(position, position+facing)*CFrame.new(0, 0, -action.Reach/2)
		local size = Vector3.new(2*action.Reach*math.sin(math.rad(action.ArcDegrees/2)), rules.VerticalTolerance*2, action.Reach)
		local result = {}
		for _, part in Workspace:GetPartBoundsInBox(frame, size, overlap) do
			local id = part:GetAttribute("EncounterId")
			local asset = if type(id) == "string" then models[id] else nil
			if not asset or (part ~= asset.BodyHitbox and part ~= asset.HornHitbox) then continue end
			local horn = part == asset.HornHitbox and asset.HornHitbox.CanQuery
			local contact = HitGeometry.contact(ctx.Position, action.Facing, point(part.Position), point(part.CFrame.LookVector),
				point(part.Size), action.Reach, action.ArcDegrees, rules.VerticalTolerance)
			if contact and lineClear(position, vector(contact)) then
				table.insert(result, { EncounterId = id, Position = contact, ValidHitbox = true, Horn = horn })
			end
		end
		return HitGeometry.prefer(result)
	end
	combat = CombatService.new({ Definitions = definitions, Geometry = Math, HitGeometry = HitGeometry, Contracts = Contracts, Now = now, NewId = newId,
		GetContext = context, GetTarget = function(id: string) return monsters:Get(id) end, ResolveContacts = contacts,
		ApplyHit = function(id: string, actorId: number, hit: any) monsters:ApplyHit(id, actorId, hit) end,
		Log = log, MoveDodge = function(actorId: number, facing: any, distance: number)
			local ctx = context(actorId)
			if not ctx or not ctx.Alive or ctx.Location ~= "World" or not ctx.Eligible then return end
			if not dodges[actorId] then
				dodges[actorId] = { Root = ctx.Root, Humanoid = ctx.Humanoid, Player = ctx.Player, AutoRotate = ctx.Humanoid.AutoRotate }
				pcall(function() ctx.Root:SetNetworkOwner(nil) end)
				ctx.Humanoid.AutoRotate = false
			end
			local delta = vector(facing)*distance
			if delta.Magnitude == 0 then return end
			local params = obstacleParams()
			local hit = Workspace:Blockcast(ctx.Root.CFrame, vector(rules.DodgeCollisionSize), delta, params)
			if hit then delta = delta.Unit*math.max(0, hit.Distance-rules.DodgeObstacleMargin) end
			local destination = ctx.Root.Position+delta
			if not Workspace:Raycast(destination+Vector3.new(0, rules.DodgeGroundProbeUp, 0), Vector3.new(0, -rules.DodgeGroundProbeDown, 0), params) then return end
			ctx.Root.CFrame += delta
			ctx.Root.AssemblyLinearVelocity = Vector3.new(0, ctx.Root.AssemblyLinearVelocity.Y, 0)
		end,
		OnAction = function(action: any)
			local ctx = context(action.ActorId)
			if not ctx then return end
			if action.AttackType ~= "Dodge" then ctx.Root.CFrame = CFrame.lookAt(ctx.Root.Position, ctx.Root.Position+vector(action.Facing)) end
			ctx.Character:SetAttribute("HuntingActorId", action.ActorId)
			ctx.Character:SetAttribute("HuntingAttack", action.AttackType)
			ctx.Character:SetAttribute("HuntingCombo", action.ComboIndex or 0)
			ctx.Character:SetAttribute("HuntingAttackStart", action.StartedAt)
			ctx.Character:SetAttribute("HuntingAttackEnd", action.EndAt)
			ctx.Character:SetAttribute("HuntingHitStart", action.WindowStartAt)
			ctx.Character:SetAttribute("HuntingHitEnd", action.WindowEndAt)
			observe({ Name = if action.AttackType == "Heavy" then "HeavyAttackUsed" elseif action.AttackType == "Dodge" then "DodgeUsed" else "AttackUsed",
				ActorId = action.ActorId, WeaponId = action.WeaponId, ComboIndex = action.ComboIndex })
		end })
	local function attachWeapon(ctx: any)
		if ctx.Character:FindFirstChild("MonCookEquippedWeapon") then return end
		local weaponId, definition = Contracts.weapon(ctx.Profile, definitions.Weapon)
		if not weaponId then return end
		local hand = ctx.Character:FindFirstChild("RightHand") or ctx.Character:FindFirstChild("Right Arm")
		local template = weaponAssets:FindFirstChild(definition.AssetId)
		if not hand or not hand:IsA("BasePart") or not template or not template:IsA("Model") then return end
		local grip = FieldConfig.WeaponGrip
		Binder.weapon(template, hand, ctx.Character, CFrame.new(grip.X, grip.Y, grip.Z)*CFrame.Angles(math.rad(grip.PitchDegrees), 0, 0))
	end
	local function syncModels()
		local present = {}
		for _, monster in monsters:List() do
			local id, definition = monster.EncounterId, definitions.Monster[monster.MonsterId]
			present[id] = true
			local asset = models[id]
			if not asset then
				asset = Binder.monster(monsterAssets:FindFirstChild(definition.AssetId) :: Model, definition, id)
				asset.Model:SetAttribute("MonsterId", monster.MonsterId)
				asset.Model.Parent = modelsFolder
				if showHitboxes then
					asset.BodyHitbox.Transparency, asset.BodyHitbox.Color = 0.72, Color3.fromRGB(60, 190, 255)
					asset.HornHitbox.Transparency, asset.HornHitbox.Color = 0.55, Color3.fromRGB(210, 90, 255)
				end
				header(asset); models[id] = asset
			end
			local position, facing = vector(monster.Position), vector(monster.Facing)
			asset.Root.CFrame = CFrame.lookAt(position, position+facing)
			for _, key in { "State", "BodyHP", "HornHP", "HornBroken", "StateStartedAt", "StateUntil", "AttackType", "LastHitAt", "LastHitKind", "LastHitHeavy" } do
				asset.Model:SetAttribute(key, monster[key])
			end
			Binder.horn(asset, monster.HornBroken)
			if showHitboxes and monster.HornBroken then asset.HornHitbox.Transparency = 1 end
			if asset.State ~= monster.State then telegraph(asset, monster, definition); asset.State = monster.State end
			local warning = if monster.State == "Windup" then (if monster.AttackType == "Charge" then "! 돌진 준비" else "! 머리치기 준비")
				elseif monster.State == "Dead" then "처치" else "Hornboar"
			asset.Header.Text = warning .. "  " .. tostring(math.ceil(monster.BodyHP)) .. "/" .. tostring(definition.MaxHealth)
				.. "\n" .. (if monster.HornBroken then "✓ 뿔 파괴" else "◇ 뿔 " .. tostring(math.ceil(monster.HornHP)) .. "/" .. tostring(definition.HornHealth))
			asset.HealthBar.Size = UDim2.new(monster.BodyHP/definition.MaxHealth, -8*monster.BodyHP/definition.MaxHealth, 0, 5)
		end
		for id, asset in models do
			if not present[id] then
				if asset.Telegraph then asset.Telegraph:Destroy() end
				asset.Model:Destroy(); models[id] = nil
			end
		end
	end
	intent.OnServerEvent:Connect(function(player: Player, payload: any)
		if closing then return end
		local actorId = options.ActorId(player)
		if not actorId then return end
		local ok, response = pcall(function() return combat:Request(actorId, payload) end)
		local sequence = if type(payload) == "table" and Math.finite(payload.Sequence) then payload.Sequence else 0
		changed:FireClient(player, { Kind = "ActionResult", Sequence = sequence,
			Result = if ok then response else { Ok = false, Error = "Unavailable" } })
	end)
	stateRemote.OnServerInvoke = function(player: Player): any
		local at = now()
		if lastStateRequest[player] and at-lastStateRequest[player] < rules.StateRequestInterval then return { Ready = false } end
		lastStateRequest[player] = at
		local actorId = options.ActorId(player)
		if not actorId then return { Ready = false } end
		local ok, snapshot = pcall(playerState, actorId)
		return if ok then snapshot else { Ready = false }
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local actorId = options.ActorId(player)
		if actorId then combat:Forget(actorId) end
		lastStateRequest[player] = nil
	end)
	local elapsed, pushedAt, lootRunning = 0, 0, false
	RunService.Heartbeat:Connect(function(delta: number)
		if closing then return end
		elapsed += delta
		if elapsed < rules.TickSeconds then return end
		local step = elapsed; elapsed = 0
		local ok, reason = pcall(function()
			for actorId in departing do if not options.Data:HasProfile(actorId) and not options.Lookup(actorId) then departing[actorId] = nil end end
			local actors = contexts()
			combat:Tick(); monsters:Tick(actors, step); syncModels()
			for _, event in monsters:PendingRewards() do if loot:Enqueue(event) then monsters:AckReward(event.EventId) end end
			for _, ctx in actors do
				attachWeapon(ctx)
				if debugView then debugView:Render(ctx, combat:State(ctx.ActorId).Action, now()) end
			end
			for actorId, dodge in dodges do
				local action = combat:State(actorId).Action
				if not action or action.AttackType ~= "Dodge" then
					if dodge.Root.Parent then pcall(function() dodge.Root:SetNetworkOwner(dodge.Player) end) end
					if dodge.Humanoid.Parent then dodge.Humanoid.AutoRotate = dodge.AutoRotate end
					dodges[actorId] = nil
				end
			end
			if now()-pushedAt >= rules.StatePushInterval then
				pushedAt = now()
				for _, player in Players:GetPlayers() do local id = options.ActorId(player); if id then sendState(id) end end
			end
		end)
		if not ok then log("World tick: " .. tostring(reason)) end
		if not lootRunning and loot:PendingCount() > 0 then
			lootRunning = true
			task.spawn(function()
				local success, message = pcall(function() loot:Tick() end)
				lootRunning = false
				if not success then log("Loot worker: " .. tostring(message)) end
			end)
		end
	end)
	network.Parent = ReplicatedStorage
	local function flush(actorId: number?)
		if actorId then
			departing[actorId] = options.Lookup(actorId)
			combat:Forget(actorId)
			if debugView then debugView:Remove(actorId) end
		else closing = true end
		for _, event in monsters:PendingRewards() do if loot:Enqueue(event) then monsters:AckReward(event.EventId) end end
		local deadline = now()+definitions.Hunting.Rewards.DepartureFlushSeconds
		while loot:PendingCount(actorId) > 0 and now() < deadline do
			loot:Tick()
			if loot:PendingCount(actorId) > 0 then task.wait(0.05) end
		end
		if loot:PendingCount(actorId) > 0 then log("Uncommitted hunting rewards remain after departure flush") end
	end
	print("[MonCook Hunting] Shared Greenwood runtime ready; server-authoritative Hornboar and personal inventory")
	return { Combat = combat, Monsters = monsters, Inventory = inventory, Loot = loot, Analytics = analytics,
		FlushActor = function(actorId: number) flush(actorId) end, Close = function() flush(nil) end }
end
return Runtime
