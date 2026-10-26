--!strict
-- Weapon crates on the server (Config.Drops). While a fight runs, crates float down under parachutes onto random spots
-- on the trains' wide tops (roofs and decks, never under a lookout or a crate), each holding a weapon picked by weight
-- (WeaponRules.pick) and showing its name. A ring on the top marks where one will land while it falls. A player with
-- bare fists who walks into a landed crate takes its weapon (hooks.give). How many crates the map holds follows the
-- fighters left (WeaponRules.cratesFor); a crate nobody takes blinks and goes away. Nothing here collides or is seen by
-- raycasts. The crates carry their state as attributes (Names.CrateWeapon, CrateLanded, CrateTakenBy) for the clients'
-- sounds (DropShow).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local WeaponRules = require(shared:WaitForChild("WeaponRules"))
local UiStyle = require(shared:WaitForChild("UiStyle"))
local Words = require(shared:WaitForChild("Words"))

local WeaponDrops = {}

export type Hooks = {
	fighters: () -> { Model }, -- the fighters still in the round
	canTake: (model: Model) -> boolean, -- a player's character holding bare fists
	give: (model: Model, weapon: string) -> (), -- hands the weapon over
}
export type Drops = { clear: () -> (), stop: () -> () }

type Crate = { model: Model, box: Part, weapon: string, landAt: number, marker: Part?, chute: { BasePart } }

local CRATE = 2.6 -- the box's size
local MARGIN = 2.5 -- a landing spot keeps this far in from a top's edges

local TAKE_HEIGHT = 3 -- a fighter's middle within this much over or under the box takes it (not from the car below)

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	return PartUtil.decor(name, size, CFrame.identity, color, material, nil, shape) -- parented by the caller
end

-- A random landing spot on a wide top that nothing higher stands over; nil when none is found in a few tries.
local function spot(surfaces: { ArenaLayout.Surface }): Vector3?
	local wide = {}
	for _, surface in surfaces do
		if surface.width >= Config.Arena.RoofWidth - 1e-6 and surface.length > MARGIN * 2 then
			table.insert(wide, surface)
		end
	end
	if #wide == 0 then
		return nil
	end
	for _ = 1, 12 do
		local surface = wide[math.random(#wide)]
		local x = surface.x + (math.random() * 2 - 1) * (surface.width / 2 - MARGIN)
		local z = surface.z + (math.random() * 2 - 1) * (surface.length / 2 - MARGIN)
		local covered = false
		for _, other in surfaces do
			if other.top > surface.top + 1e-6 and math.abs(x - other.x) < other.width / 2 + CRATE / 2 and math.abs(z - other.z) < other.length / 2 + CRATE / 2 then
				covered = true
			end
		end
		if not covered then
			return Vector3.new(x, surface.top, z)
		end
	end
	return nil
end

-- surfaces: the arena's tops (ArenaLayout); folder: where the crates go.
function WeaponDrops.start(surfaces: { ArenaLayout.Surface }, folder: Instance, hooks: Hooks): Drops
	local d = Config.Drops
	local crates: { Crate } = {}
	local running = true
	local fightStarted: number? = nil
	local nextDrop = math.huge

	local function remove(crate: Crate)
		local index = table.find(crates, crate)
		if index then
			table.remove(crates, index)
		end
		crate.model:Destroy()
		if crate.marker then
			crate.marker:Destroy()
		end
	end

	local function clear()
		for _, crate in table.clone(crates) do
			remove(crate)
		end
	end

	local function drop(now: number)
		local at = spot(surfaces)
		local weapon = WeaponRules.pick(Config.Weapons, math.random())
		if not (at and weapon) then
			return
		end
		local model = Instance.new("Model")
		model.Name = "Crate"
		model:SetAttribute(Names.CrateWeapon, weapon)
		model:SetAttribute(Names.CrateLanded, false)
		local box = part("Box", Vector3.new(CRATE, CRATE, CRATE), Config.Arena.Colors.Crate, Enum.Material.WoodPlanks)
		local landed = CFrame.new(at + Vector3.new(0, CRATE / 2, 0))
		box.CFrame = landed + Vector3.new(0, d.FallHeight, 0)
		box.Parent = model
		model.PrimaryPart = box
		-- The parachute: a flattened dome canopy with a pale vent on top and four cords, welded to the box (they follow it
		-- down and go when it lands). A plain ball read as a balloon.
		local chute: { BasePart } = {}
		local canopy = part("Canopy", Vector3.new(7, 7, 7), Color3.fromRGB(232, 84, 60), Enum.Material.Fabric, Enum.PartType.Ball)
		local dome = Instance.new("SpecialMesh")
		dome.MeshType = Enum.MeshType.Sphere
		dome.Scale = Vector3.new(1, 0.42, 1)
		dome.Parent = canopy
		canopy.CFrame = box.CFrame + Vector3.new(0, 6.5, 0)
		table.insert(chute, canopy)
		local vent = part("Vent", Vector3.new(3, 3, 3), Color3.fromRGB(240, 226, 196), Enum.Material.Fabric, Enum.PartType.Ball)
		local cap = Instance.new("SpecialMesh")
		cap.MeshType = Enum.MeshType.Sphere
		cap.Scale = Vector3.new(1, 0.45, 1)
		cap.Parent = vent
		vent.CFrame = canopy.CFrame + Vector3.new(0, 1.2, 0) -- its top shows above the canopy's
		table.insert(chute, vent)
		for _, corner in { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) } do
			local a = box.Position + Vector3.new(corner.X * 1.2, CRATE / 2, corner.Z * 1.2)
			local b = canopy.Position + Vector3.new(corner.X * 2.4, -0.9, corner.Z * 2.4) -- the canopy's rim
			local cord = part("Cord", Vector3.new(0.1, 0.1, (b - a).Magnitude), Color3.fromRGB(230, 220, 200), Enum.Material.Fabric)
			cord.CFrame = CFrame.lookAt((a + b) / 2, b)
			table.insert(chute, cord)
		end
		for _, piece in chute do
			piece.Anchored = false
			piece.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = box
			weld.Part1 = piece
			weld.Parent = piece
			piece.Parent = model
		end
		-- What is inside, over the box.
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(140, 36)
		tag.StudsOffset = Vector3.new(0, CRATE, 0)
		tag.AlwaysOnTop = true
		tag.MaxDistance = 120
		local label = UiStyle.label(tag, "Weapon", UDim2.fromScale(1, 1), 28, UiStyle.Gold)
		label.Text = Words.Weapons[weapon] or weapon
		tag.Parent = box
		-- Where it will land: an invisible flat part every client draws the crate's shadow on (GroundMarks).
		local marker = part(Names.LandingMark, Vector3.new(4.5, 0.05, 4.5), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		marker.Transparency = 1
		marker.CFrame = CFrame.new(at + Vector3.new(0, 0.05, 0))
		marker:SetAttribute(Names.MarkEndsAt, Workspace:GetServerTimeNow() + d.FallSeconds)
		marker:SetAttribute(Names.MarkSeconds, d.FallSeconds)
		marker.Parent = folder
		model.Parent = folder
		TweenService:Create(box, TweenInfo.new(d.FallSeconds, Enum.EasingStyle.Linear), { CFrame = landed }):Play()
		table.insert(crates, { model = model, box = box, weapon = weapon, landAt = now + d.FallSeconds, marker = marker, chute = chute })
	end

	local function step(now: number)
		local fighting = Workspace:GetAttribute(Names.Phase) == "Fight"
		if not fighting then
			if #crates > 0 then
				clear()
			end
			fightStarted, nextDrop = nil, math.huge
			return
		end
		if not fightStarted then
			fightStarted = now
			nextDrop = now + d.FirstAfter
		end
		local fighters = hooks.fighters()
		if now >= nextDrop then
			if #crates < WeaponRules.cratesFor(#fighters, d.MaxOnMap) then
				drop(now)
			end
			nextDrop = now + d.Every
		end
		for _, crate in table.clone(crates) do
			if now >= crate.landAt then
				if crate.marker then
					-- Landed: the parachute and the mark go.
					crate.marker:Destroy()
					crate.marker = nil
					for _, piece in crate.chute do
						piece:Destroy()
					end
					table.clear(crate.chute)
					crate.model:SetAttribute(Names.CrateLanded, true)
				end
				local age = now - crate.landAt
				if age >= d.LifeSeconds then
					remove(crate)
					continue
				end
				-- Blinks for its last seconds.
				crate.box.Transparency = if age > d.LifeSeconds - 3 and math.floor(age * 4) % 2 == 0 then 0.7 else 0
				for _, model in fighters do
					local body = CharacterParts.body(model)
					if body and hooks.canTake(model) then
						local offset = body.root.Position - crate.box.Position
						if Vector3.new(offset.X, 0, offset.Z).Magnitude <= d.PickupReach and math.abs(offset.Y) <= TAKE_HEIGHT then
							hooks.give(model, crate.weapon)
							crate.model:SetAttribute(Names.CrateTakenBy, model.Name)
							local index = table.find(crates, crate)
							if index then
								table.remove(crates, index)
							end
							-- A moment for the clients to hear whose it became before it goes.
							crate.box.Transparency = 1
							task.delay(0.2, function()
								crate.model:Destroy()
							end)
							break
						end
					end
				end
			end
		end
	end

	task.spawn(function()
		while running do
			step(Workspace:GetServerTimeNow())
			task.wait(0.1)
		end
		clear()
	end)

	return {
		clear = clear,
		stop = function()
			running = false
		end,
	}
end

return WeaponDrops
