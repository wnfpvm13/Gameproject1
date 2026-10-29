--!strict
-- Hats and other accessories popping off as a fighter is worn down (decision 11's "체력 50·25에서 장신구 튕김 (모양만,
-- 다음 판 복구)", brought forward by the persona playtest 2026-10-29: "everyone looks the same, nothing cute"). When a
-- fighter's health (Names.Health) drops to Config.Pop.At[1] or under, one of its accessories - the hat first, then the
-- hair, then any other - flies off with a pop, spinning up and away from the camera, and fades; at At[2] another goes. Only for show and
-- only on this client: the real one is just hidden (its parts made see-through here) and all of them come back when the
-- next round counts down. Practice bots wear a cowboy hat for it (Sandbags).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local SoundBank = require(shared:WaitForChild("SoundBank"))

local AccessoryPop = {}
AccessoryPop.__index = AccessoryPop

-- Which accessory goes first: a hat, then hair, then the rest.
local ORDER: { [Enum.AccessoryType]: number } = {
	[Enum.AccessoryType.Hat] = 1,
	[Enum.AccessoryType.Hair] = 2,
}

-- A part hidden here: what its transparency was.
type Hidden = { part: BasePart, was: number }
-- A copy flying off: its model (its parts as they sat, moved as one by its pivot, the handle), where it started, its
-- spin and velocity, and when it started (os.clock).
type Flying = { model: Model, parts: { BasePart }, start: CFrame, velocity: Vector3, spin: Vector3, startedAt: number }
type Fields = { seen: { [Model]: number }, hidden: { Hidden }, flying: { Flying }, folder: Folder, phase: string? }
export type Pop = typeof(setmetatable({} :: Fields, AccessoryPop))

function AccessoryPop.new(): Pop
	local fields: Fields = { seen = {}, hidden = {}, flying = {}, folder = PartUtil.folder(Workspace, "TrainBrawlPoppedHats"), phase = nil }
	return setmetatable(fields, AccessoryPop)
end

-- The accessory of `model` to pop next (still showing), or nil.
local function nextAccessory(model: Model, hiddenParts: { [BasePart]: boolean }): Accessory?
	local best: Accessory? = nil
	local bestRank = math.huge
	for _, child in model:GetChildren() do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and not hiddenParts[handle] then
				local rank = ORDER[child.AccessoryType] or 3
				if rank < bestRank then
					best, bestRank = child, rank
				end
			end
		end
	end
	return best
end

local function pop(self: Pop, model: Model)
	local hiddenParts: { [BasePart]: boolean } = {}
	for _, h in self.hidden do
		hiddenParts[h.part] = true
	end
	local accessory = nextAccessory(model, hiddenParts)
	if not accessory then
		return
	end
	local p = Config.Pop
	local parts: { BasePart } = {}
	local handle = accessory:FindFirstChild("Handle") :: BasePart
	local flyer = Instance.new("Model")
	flyer.Name = "PoppedAccessory"
	for _, item in accessory:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(self.hidden, { part = item, was = item.Transparency })
			local copy = item:Clone()
			for _, inside in copy:GetChildren() do
				-- Only its look goes along (a mesh, a texture), not its welds or attachments.
				if not (inside:IsA("DataModelMesh") or inside:IsA("Decal") or inside:IsA("SurfaceAppearance")) then
					inside:Destroy()
				end
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CastShadow = false
			copy.Parent = flyer
			if item == handle then
				flyer.PrimaryPart = copy
			end
			table.insert(parts, copy)
			item.Transparency = 1
		end
	end
	flyer.Parent = self.folder
	-- Out away from the camera (one flying at it hid the view in Studio), a little to either side.
	local away = handle.Position - Workspace.CurrentCamera.CFrame.Position
	local flat = Vector3.new(away.X, 0, away.Z)
	local out = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local across = Vector3.new(-out.Z, 0, out.X) * (math.random() * 2 - 1) * 0.6
	local spread = (out + across).Unit * p.Side
	table.insert(self.flying, {
		model = flyer,
		parts = parts,
		start = handle.CFrame,
		velocity = Vector3.new(0, p.Up, 0) + spread,
		spin = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * p.Spin,
		startedAt = os.clock(),
	})
	SoundBank.play("StarPop", handle, 1.25 + math.random() * 0.15)
end

-- Every frame, for the fighters in the round (on their way back too); phase: the round's.
function AccessoryPop.update(self: Pop, models: { Model }, phase: string)
	local p = Config.Pop
	if phase == "Countdown" and self.phase ~= "Countdown" then
		-- A new round: every accessory back.
		for _, h in self.hidden do
			if h.part.Parent then
				h.part.Transparency = h.was
			end
		end
		table.clear(self.hidden)
		table.clear(self.seen)
	end
	self.phase = phase
	for _, model in models do
		local health = PartUtil.number(model, Names.Health)
		if health then
			local before = self.seen[model]
			self.seen[model] = health
			if before and health < before then
				for _, at in p.At do
					if before > at and health <= at then
						pop(self, model)
					end
				end
			end
		end
	end
	-- The copies fly up, spin and fade.
	local clock = os.clock()
	for index = #self.flying, 1, -1 do
		local f = self.flying[index]
		local t = clock - f.startedAt
		if t >= p.Seconds then
			f.model:Destroy()
			table.remove(self.flying, index)
		else
			local at = f.start.Position + f.velocity * t + Vector3.new(0, -0.5 * Workspace.Gravity * p.Gravity * t * t, 0)
			local turn = CFrame.Angles(f.spin.X * t, f.spin.Y * t, f.spin.Z * t)
			local frame = CFrame.new(at) * (f.start - f.start.Position) * turn
			local fade = math.clamp((t - p.Seconds * 0.6) / (p.Seconds * 0.4), 0, 1)
			f.model:PivotTo(frame)
			for _, part in f.parts do
				part.LocalTransparencyModifier = fade
			end
		end
	end
end

return AccessoryPop
