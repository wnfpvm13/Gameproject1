--!strict
-- Blocking, drawn on this client (decision 11's hold-to-block, persona fix 4): every fighter holding a block
-- (Names.Blocking, from the server's Guarding) shows a pale gold shield in front of it, a flattened lens of the
-- ForceField material at chest height that turns with it. A hit taken on the block flashes the shield and throws a few
-- sparks off it (hit); a guard broken by a string's third bursts the shield into shards that fly off and fade, with
-- "막기 깨짐!" over the head for a moment; a hit that went through a block says why there (through(): "옆!", "뒤!",
-- "못 막는 공격!"), and a hit the player struck back right after blocking says "반격!" with a ding (counter()). Drawn
-- only: no collisions or raycasts.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))
local SoundBank = require(shared:WaitForChild("SoundBank"))

local BlockShow = {}

local SHIELD = Color3.fromRGB(255, 214, 110)
local SHIELD_SIZE = Vector3.new(4.6, 5, 4.6)
local SHIELD_FLAT = 0.2 -- the lens is this thin, along the facing
local SHIELD_AT = CFrame.new(0, 0.4, -1.7) -- in front of the root, at the chest
local RESTING = 0.25 -- the shield's transparency while held (fainter read as a thin ring in Studio)
local FLASH_SECONDS = 0.18
local SHARDS = 7
local SHARD_SECONDS = 0.45
local BROKEN_SECONDS = 0.8

-- A shield on a fighter: its part and when it last flashed (os.clock).
type Shield = { body: CharacterParts.Body, part: BasePart, flashAt: number }

local folder: Folder? = nil
local shields: { [Model]: Shield } = {}

local function holder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local made = PartUtil.folder(Workspace, "TrainBrawlShields")
	folder = made
	return made
end

local function makeShield(body: CharacterParts.Body): Shield
	local part = PartUtil.decor("Shield", SHIELD_SIZE, body.root.CFrame * SHIELD_AT, SHIELD, Enum.Material.ForceField, nil, Enum.PartType.Ball)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1, SHIELD_FLAT)
	mesh.Parent = part
	part.Transparency = RESTING
	part.Parent = holder()
	return { body = body, part = part, flashAt = -math.huge }
end

-- A few gold sparks off a point, gone in a moment.
local function sparks(at: CFrame, count: number)
	local spot = PartUtil.decor("BlockSparks", Vector3.new(0.2, 0.2, 0.2), at, SHIELD, Enum.Material.SmoothPlastic)
	spot.Transparency = 1
	spot.Parent = holder()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 244, 200), SHIELD)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.15, 0.3)
	emitter.Speed = NumberRange.new(14, 24)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Rate = 0
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Parent = spot
	emitter:Emit(count)
	Debris:AddItem(spot, 0.5)
end

-- The shield bursting: shards of it fly out from where it was and fade.
local function shatter(at: CFrame)
	for i = 1, SHARDS do
		local angle = (i / SHARDS) * math.pi * 2
		local out = (at.RightVector * math.cos(angle) + at.UpVector * math.sin(angle)) + at.LookVector * 0.6
		local shard = PartUtil.decor("Shard", Vector3.new(0.9, 0.9, 0.12), at * CFrame.Angles(0, 0, angle), SHIELD, Enum.Material.Neon)
		shard.Transparency = 0.2
		shard.Parent = holder()
		local goal = { CFrame = shard.CFrame + out.Unit * 3 + Vector3.new(0, -1, 0), Transparency = 1 }
		TweenService:Create(shard, TweenInfo.new(SHARD_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
		Debris:AddItem(shard, SHARD_SECONDS + 0.05)
	end
	sparks(at, 18)
end

-- `text` in `color` over a fighter's head for a moment ("막기 깨짐!", or why a hit went through the block).
local function note(model: Model, text: string, color: Color3)
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TrainBrawlGuardBroken"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(160, 34)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	local label = UiStyle.label(billboard, "Note", UDim2.fromScale(1, 1), 26, color)
	label.Text = text
	billboard.Parent = head
	UiStyle.pop(label, 1.5)
	Debris:AddItem(billboard, BROKEN_SECONDS)
end

-- A hit met `victim`'s block: "blocked" (softened: the shield flashes and sparks) or "broken" (the guard broke).
function BlockShow.hit(victim: Model, guard: string)
	local body = CharacterParts.body(victim)
	if not body then
		return
	end
	local at = body.root.CFrame * SHIELD_AT
	if guard == "broken" then
		local shield = shields[victim]
		if shield then
			shield.part:Destroy()
			shields[victim] = nil
		end
		shatter(at)
		note(victim, Words.GuardBroken, UiStyle.Red)
	else
		local shield = shields[victim]
		if shield then
			shield.flashAt = os.clock()
		end
		sparks(at, 10)
	end
end

-- A hit went through `victim`'s block (BlockRules.through: "side", "back" or "weapon"): says why over its head
-- (2026-10-31: a tester could not tell a late block from one hit from the side).
function BlockShow.through(victim: Model, why: string)
	local text = Words.BlockThrough[why]
	if text then
		note(victim, text, UiStyle.Gold)
	end
end

-- The player hit `victim` back right after blocking (Config.Block.CounterSeconds): "반격!" over it, and a ding.
function BlockShow.counter(victim: Model)
	note(victim, Words.Counter, UiStyle.Gold)
	local head = victim:FindFirstChild("Head")
	SoundBank.play("CountBell", if head and head:IsA("BasePart") then head else nil, 1.4)
end

-- Every frame, for the fighters in the round.
function BlockShow.update(models: { Model })
	local clock = os.clock()
	local seen: { [Model]: boolean } = {}
	for _, model in models do
		if model:GetAttribute(Names.Blocking) == true then
			local body = CharacterParts.body(model)
			if body then
				seen[model] = true
				local old = shields[model]
				local current = if old and old.body.root == body.root and old.part.Parent then old else makeShield(body)
				if old and current ~= old then
					old.part:Destroy()
				end
				shields[model] = current
				current.part.CFrame = body.root.CFrame * SHIELD_AT
				local flash = (clock - current.flashAt) / FLASH_SECONDS
				current.part.Transparency = if flash < 1 then RESTING * flash else RESTING
			end
		end
	end
	for model, shield in shields do
		if not seen[model] then
			shield.part:Destroy()
			shields[model] = nil
		end
	end
end

return BlockShow
