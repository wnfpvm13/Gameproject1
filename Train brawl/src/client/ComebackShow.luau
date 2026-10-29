--!strict
-- The way back after a fall, drawn on this client from each fighter's attributes (the server's Comebacks and
-- FighterHealth): while a fighter comes down (Names.ReturnPhase "Down") a parachute opens over it, a flattened dome
-- with a pale vent and four cords to its shoulders, in blue (the crates' are red), following its root each frame; once
-- it has landed the parachute sinks and fades. While it is unhittable after landing (Names.GuardUntil) it shimmers
-- (a pulsing pale Highlight), so everyone sees why hits do not land and when they will. Drawn only: no collisions or
-- raycasts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local ComebackShow = {}

local CANOPY = Color3.fromRGB(88, 178, 230)
local VENT = Color3.fromRGB(240, 226, 196)
local CORD = Color3.fromRGB(230, 220, 200)
local CANOPY_SIZE = 7.5
local CANOPY_UP = 8.2 -- the canopy's middle over the root (its rim well clear of the head, the cords showing)
local FOLD_SECONDS = 0.35 -- after landing the parachute sinks and fades this long
local GUARD_FILL = Color3.fromRGB(255, 244, 214)
local GUARD_EDGE = Color3.fromRGB(255, 214, 96)
local GUARD_PULSE = 10 -- radians per second

-- A parachute on a fighter: its pieces (canopy, vent, cords) and, once landed, when it started folding (os.clock).
type Chute = { body: CharacterParts.Body, canopy: BasePart, vent: BasePart, cords: { Part }, foldedAt: number? }

local folder: Folder? = nil
local chutes: { [Model]: Chute } = {}
local glows: { [Model]: Highlight } = {}

local CORNERS = { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) }

local function holder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local made = PartUtil.folder(Workspace, "TrainBrawlParachutes")
	folder = made
	return made
end

local function dome(name: string, size: number, flat: number, color: Color3): BasePart
	-- Smooth: in fabric the canopy's shaded underside read as a dark disc (Studio).
	local part = PartUtil.decor(name, Vector3.new(size, size, size), CFrame.identity, color, Enum.Material.SmoothPlastic, nil, Enum.PartType.Ball)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, flat, 1)
	mesh.Parent = part
	part.Parent = holder()
	return part
end

local function open(body: CharacterParts.Body): Chute
	local cords = {}
	for _ = 1, #CORNERS do
		local cord = PartUtil.decor("Cord", Vector3.new(0.08, 0.08, 1), CFrame.identity, CORD, Enum.Material.Fabric)
		cord.Parent = holder()
		table.insert(cords, cord)
	end
	return { body = body, canopy = dome("Canopy", CANOPY_SIZE, 0.42, CANOPY), vent = dome("Vent", 3, 0.3, VENT), cords = cords, foldedAt = nil }
end

local function remove(chute: Chute)
	chute.canopy:Destroy()
	chute.vent:Destroy()
	for _, cord in chute.cords do
		cord:Destroy()
	end
end

-- Puts the parachute over its fighter (turned with it), `sink` lower and `fade` transparent.
local function place(chute: Chute, sink: number, fade: number)
	local root = chute.body.root.CFrame
	local look = Vector3.new(root.LookVector.X, 0, root.LookVector.Z)
	local facing = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(root.Position, root.Position + facing)
	local canopy = base * CFrame.new(0, CANOPY_UP - sink, 0)
	chute.canopy.CFrame = canopy
	chute.vent.CFrame = canopy * CFrame.new(0, 1.15, 0) -- only its top shows, a pale patch on the crown
	chute.canopy.Transparency = fade
	chute.vent.Transparency = fade
	for i, corner in CORNERS do
		local a = (base * CFrame.new(corner.X * 0.75, 1.1, corner.Z * 0.35)).Position -- the shoulders
		local b = (canopy * CFrame.new(corner.X * 2.6, -0.5, corner.Z * 2.6)).Position -- just inside the rim
		local cord = chute.cords[i]
		cord.Size = Vector3.new(0.08, 0.08, (b - a).Magnitude)
		cord.CFrame = CFrame.lookAt((a + b) / 2, b)
		cord.Transparency = fade
	end
end

-- Every frame, for the fighters in the round (those on their way back too).
function ComebackShow.update(models: { Model })
	local clock = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local seen: { [Model]: boolean } = {}
	for _, model in models do
		seen[model] = true
		local down = model:GetAttribute(Names.ReturnPhase) == "Down"
		local chute = chutes[model]
		if down then
			local body = CharacterParts.body(model)
			if body and (not chute or chute.foldedAt or chute.body.root ~= body.root) then
				if chute then
					remove(chute)
				end
				chutes[model] = open(body)
			end
		elseif chute and not chute.foldedAt then
			chute.foldedAt = clock
		end
		local guardUntil = PartUtil.number(model, Names.GuardUntil)
		local guarded = guardUntil ~= nil and serverNow < guardUntil
		local glow = glows[model]
		if guarded then
			if not glow then
				local made = Instance.new("Highlight")
				made.Name = "TrainBrawlGuard"
				made.FillColor = GUARD_FILL
				made.OutlineColor = GUARD_EDGE
				made.DepthMode = Enum.HighlightDepthMode.Occluded
				made.Adornee = model
				made.Parent = model
				glows[model] = made
			end
			local pulse = (math.sin(clock * GUARD_PULSE) + 1) / 2
			local shown = glows[model]
			shown.FillTransparency = 0.45 + 0.3 * pulse
			shown.OutlineTransparency = 0.1 + 0.4 * pulse
		elseif glow then
			glow:Destroy()
			glows[model] = nil
		end
	end
	for model, chute in chutes do
		local folded = chute.foldedAt
		local gone = not seen[model] or not chute.body.root.Parent
		local share = if folded then (clock - folded) / FOLD_SECONDS else 0
		if gone or share >= 1 then
			remove(chute)
			chutes[model] = nil
		else
			place(chute, share * 2, share)
		end
	end
	for model, glow in glows do
		if not seen[model] then
			glow:Destroy()
			glows[model] = nil
		end
	end
end

return ComebackShow
