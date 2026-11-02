--!strict
-- Weapon crates on the server (Config.Drops). While a fight runs, crates float down under parachutes onto spots on the
-- trains' wide tops (roofs and decks, never under a lookout or a crate, never a car coming off: hooks.away; a crate on
-- a car that comes off goes with it). Each is for someone (WeaponRules.crateFor): one with bare fists, and lands on its
-- train, the nearest of a few random tries at least Config.Drops.NearGap from it (WeaponRules.nearSpot) - except in a
-- stand-off (no hit for QuietSeconds: hooks.quietSince), when it lands the farthest from everyone, as bait (persona
-- fix 6). Each holds a weapon picked by weight
-- (WeaponRules.pick) and showing its name. Its shadow on the top shows where one will land while it falls (drawn by every
-- client: GroundMarks). Coal tenders get none (a crate half sunk in coal, its shadow lost on it). A fighter with
-- bare fists who walks into a landed crate takes its weapon (hooks.give; practice bots go for one on their top: landed()).
-- How many crates the map holds follows the fighters left (WeaponRules.cratesFor); a crate nobody takes blinks and goes
-- away. Nothing here collides or is seen by
-- raycasts. The crates carry their state as attributes (Names.CrateWeapon, CrateLanded, CrateTakenBy) for the clients'
-- sounds (DropShow).
-- Once a fight, the golden crate takes the place of a regular drop (decision 25, Config.Drops.Golden): told Notice
-- seconds ahead on Workspace (Names.GoldenAt, GoldenSpot: the middle train's biggest top, WeaponRules.goldenTop), gold,
-- lit, with a "쾅" weapon in turn (WeaponRules.goldenNext), not counted against the crates the map holds. Anyone may
-- take it, a weapon in hand or not, by staying by it Hold seconds while not stunned or rolling (hooks.busy); who took
-- what goes on Workspace (Names.GoldenTaken) for every screen (GoldenShow).
local Players = game:GetService("Players")
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
	canTake: (model: Model) -> boolean, -- a fighter holding bare fists
	give: (model: Model, weapon: string) -> (), -- hands the weapon over
	away: (train: number, car: number) -> boolean, -- that car is coming off or gone (Uncoupling)
	quietSince: () -> number, -- server time a hit last landed in the fight (RoundService)
	busy: (model: Model) -> boolean, -- stunned by a hit or rolling (no taking the golden crate then)
}
-- landed: where the landed crates nobody has taken yet lie (on their tops); golden: where the landed golden crate lies
-- (nil: none).
export type Drops = { clear: () -> (), landed: () -> { Vector3 }, golden: () -> Vector3?, stop: () -> () }

-- train, car: the car it lands on. golden: the golden crate; holding: since when (server time) each fighter has stood by
-- it to take it.
type Crate = {
	model: Model,
	box: Part,
	weapon: string,
	landAt: number,
	marker: Part?,
	chute: { BasePart },
	train: number,
	car: number,
	golden: boolean,
	holding: { [Model]: number },
}

local CRATE = 2.6 -- the box's size
local MARGIN = 2.5 -- a landing spot keeps this far in from a top's edges

local TAKE_HEIGHT = 3 -- a fighter's middle within this much over or under the box takes it (not from the car below)

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	return PartUtil.decor(name, size, CFrame.identity, color, material, nil, shape) -- parented by the caller
end

local TRIES = 12 -- random spots tried for a crate (the best of them is taken)

-- A landing spot on a wide top that nothing higher stands over and whose car is not coming off: of a few random ones,
-- for the fighter `near` (when one) the nearest at least NearGap from it on its train (WeaponRules.nearSpot), else the
-- farthest from every fighter at `others` (ArenaLayout.clearest: bait); nil when none is found. Also its surface.
local function spot(surfaces: { ArenaLayout.Surface }, away: (number, number) -> boolean, others: { { x: number, z: number } }, near: { x: number, z: number }?): (Vector3?, ArenaLayout.Surface?)
	local wide = {}
	for _, surface in surfaces do
		if surface.width >= Config.Arena.RoofWidth - 1e-6 and surface.length > MARGIN * 2 and surface.kind ~= "Tender" and not away(surface.train, surface.car) then
			table.insert(wide, surface)
		end
	end
	if near then
		-- Only its own train's tops (the train whose line it stands nearest), when that train has any left.
		local line, lineDistance = nil, math.huge
		for _, surface in wide do
			local distance = math.abs(surface.x - near.x)
			if distance < lineDistance then
				line, lineDistance = surface.train, distance
			end
		end
		local own = {}
		for _, surface in wide do
			if surface.train == line then
				table.insert(own, surface)
			end
		end
		if #own > 0 then
			wide = own
		end
	end
	if #wide == 0 then
		return nil, nil
	end
	local tries: { ArenaLayout.Spot } = {}
	local onTop: { [ArenaLayout.Spot]: ArenaLayout.Surface } = {}
	for _ = 1, TRIES do
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
			local try = { x = x, y = surface.top, z = z, train = surface.train, car = surface.car }
			table.insert(tries, try)
			onTop[try] = surface
		end
	end
	local best: ArenaLayout.Spot? = nil
	if near then
		local points = {}
		for _, try in tries do
			table.insert(points, { x = try.x, z = try.z })
		end
		local index = WeaponRules.nearSpot(points, near.x, near.z, Config.Drops.NearGap)
		best = if index then tries[index] else nil
	else
		best = ArenaLayout.clearest(tries, others)
	end
	if not best then
		return nil, nil
	end
	return Vector3.new(best.x, best.y, best.z), onTop[best]
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
		if crate.golden then
			Workspace:SetAttribute(Names.GoldenAt, nil)
			Workspace:SetAttribute(Names.GoldenSpot, nil)
		end
	end

	local function clear()
		for _, crate in table.clone(crates) do
			remove(crate)
		end
	end

	-- A crate of `weapon` falling onto `at` on top `train`/`car` (golden: the golden crate).
	local function make(now: number, at: Vector3, train: number, car: number, weapon: string, golden: boolean)
		local gold = d.Golden.Color
		local model = Instance.new("Model")
		model.Name = "Crate"
		model:SetAttribute(Names.CrateWeapon, weapon)
		model:SetAttribute(Names.CrateLanded, false)
		model:SetAttribute(Names.CrateGolden, if golden then true else nil)
		local box = if golden
			then part("Box", Vector3.new(CRATE, CRATE, CRATE), gold, Enum.Material.Metal)
			else part("Box", Vector3.new(CRATE, CRATE, CRATE), Config.Arena.Colors.Crate, Enum.Material.WoodPlanks)
		if golden then
			box.Reflectance = 0.25
			local glow = Instance.new("PointLight")
			glow.Color = gold
			glow.Range = 14
			glow.Brightness = 2
			glow.Parent = box
		end
		local landed = CFrame.new(at + Vector3.new(0, CRATE / 2, 0))
		box.CFrame = landed + Vector3.new(0, d.FallHeight, 0)
		box.Parent = model
		model.PrimaryPart = box
		-- The parachute: a flattened dome canopy with a pale vent on top and four cords, welded to the box (they follow it
		-- down and go when it lands). A plain ball read as a balloon.
		local chute: { BasePart } = {}
		local canopy = part("Canopy", Vector3.new(7, 7, 7), if golden then gold else Color3.fromRGB(232, 84, 60), Enum.Material.Fabric, Enum.PartType.Ball)
		local dome = Instance.new("SpecialMesh")
		dome.MeshType = Enum.MeshType.Sphere
		dome.Scale = Vector3.new(1, 0.42, 1)
		dome.Parent = canopy
		canopy.CFrame = box.CFrame + Vector3.new(0, 6.5, 0)
		table.insert(chute, canopy)
		local vent = part("Vent", Vector3.new(3, 3, 3), Color3.fromRGB(240, 226, 196), Enum.Material.Fabric, Enum.PartType.Ball)
		local cap = Instance.new("SpecialMesh")
		cap.MeshType = Enum.MeshType.Sphere
		cap.Scale = Vector3.new(1, 0.3, 1)
		cap.Parent = vent
		vent.CFrame = canopy.CFrame + Vector3.new(0, 1.1, 0) -- only its top shows, a pale patch on the canopy's crown
		table.insert(chute, vent)
		for _, corner in { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) } do
			local a = box.Position + Vector3.new(corner.X * 1.2, CRATE / 2, corner.Z * 1.2)
			local b = canopy.Position + Vector3.new(corner.X * 2.3, -0.4, corner.Z * 2.3) -- just inside the canopy's underside
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
		label.Text = (if golden then Words.GoldenTag else "") .. (Words.Weapons[weapon] or weapon)
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
		table.insert(crates, {
			model = model,
			box = box,
			weapon = weapon,
			landAt = now + d.FallSeconds,
			marker = marker,
			chute = chute,
			train = train,
			car = car,
			golden = golden,
			holding = {},
		})
	end

	local function drop(now: number, fighters: { Model })
		local seen: { WeaponRules.Seen } = {}
		local others = {}
		for _, model in fighters do
			local p = model:GetPivot().Position
			table.insert(seen, { x = p.X, z = p.Z, fists = hooks.canTake(model) })
			table.insert(others, { x = p.X, z = p.Z })
		end
		local index = WeaponRules.crateFor(seen, now - hooks.quietSince(), d.QuietSeconds, math.random)
		local near = if index then others[index] else nil
		local at, surface = spot(surfaces, hooks.away, others, near)
		local weapon = WeaponRules.pick(Config.Weapons, math.random())
		if not (at and surface and weapon) then
			return
		end
		make(now, at, surface.train, surface.car, weapon, false)
	end

	-- The golden crate: this fight's spot (chosen when told), the weapons still to come in turn, the last one given.
	local trains = 0
	for _, surface in surfaces do
		trains = math.max(trains, surface.train)
	end
	local goldenAt = math.huge -- server time it drops this fight
	local goldenTop: ArenaLayout.Surface? = nil
	local goldenDone = false
	local goldenBag: { string } = {}
	local lastGolden: string? = nil

	local function shownName(model: Model): string
		local player = Players:GetPlayerFromCharacter(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		return if player then player.DisplayName elseif humanoid then humanoid.DisplayName else model.Name
	end

	local function unsetGolden()
		Workspace:SetAttribute(Names.GoldenAt, nil)
		Workspace:SetAttribute(Names.GoldenSpot, nil)
	end

	local function step(now: number)
		local fighting = Workspace:GetAttribute(Names.Phase) == "Fight"
		if not fighting then
			if #crates > 0 then
				clear()
			end
			if fightStarted then
				unsetGolden()
				Workspace:SetAttribute(Names.GoldenTaken, nil)
			end
			fightStarted, nextDrop = nil, math.huge
			return
		end
		if not fightStarted then
			fightStarted = now
			nextDrop = now + d.FirstAfter
			goldenAt = now + WeaponRules.goldenTime(d.FirstAfter, d.Every, d.Golden.At)
			goldenTop, goldenDone = nil, false
			Workspace:SetAttribute(Names.GoldenTaken, nil)
		end
		-- The golden crate is told of ahead, where it will land.
		if not goldenDone and not goldenTop and now >= goldenAt - d.Golden.Notice then
			goldenTop = WeaponRules.goldenTop(surfaces, (trains + 1) // 2, Config.Arena.RoofWidth, hooks.away)
			if goldenTop then
				Workspace:SetAttribute(Names.GoldenSpot, Vector3.new(goldenTop.x, goldenTop.top, goldenTop.z))
				Workspace:SetAttribute(Names.GoldenAt, goldenAt)
			else
				goldenDone = true -- nowhere to put it this fight
			end
		end
		local fighters = hooks.fighters()
		if now >= nextDrop then
			local top = goldenTop
			if top and not goldenDone and nextDrop >= goldenAt - 0.05 then
				-- This drop is the golden one (not counted against the map's crates).
				goldenDone = true
				local weapon = WeaponRules.goldenNext(goldenBag, d.Golden.Weapons, lastGolden, math.random)
				lastGolden = weapon
				make(now, Vector3.new(top.x, top.top, top.z), top.train, top.car, weapon, true)
			elseif #crates < WeaponRules.cratesFor(#fighters, d.MaxOnMap, d.FightersPerCrate) then
				drop(now, fighters)
			end
			nextDrop = now + d.Every
		end
		for _, crate in table.clone(crates) do
			if hooks.away(crate.train, crate.car) then
				remove(crate) -- its car is coming off: it goes with it
				continue
			end
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
					local by = false
					if body then
						local offset = body.root.Position - crate.box.Position
						by = Vector3.new(offset.X, 0, offset.Z).Magnitude <= d.PickupReach and math.abs(offset.Y) <= TAKE_HEIGHT
					end
					local takes = false
					if crate.golden then
						-- Anyone, after standing by it a moment unhurt.
						if by and not hooks.busy(model) then
							local since = crate.holding[model] or now
							crate.holding[model] = since
							takes = now - since >= d.Golden.Hold
						else
							crate.holding[model] = nil
						end
					else
						takes = by and hooks.canTake(model)
					end
					if takes then
						hooks.give(model, crate.weapon)
						if crate.golden then
							Workspace:SetAttribute(Names.GoldenTaken, shownName(model) .. "|" .. crate.weapon)
							unsetGolden()
						end
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

	task.spawn(function()
		while running do
			step(Workspace:GetServerTimeNow())
			task.wait(0.1)
		end
		clear()
	end)

	return {
		clear = clear,
		landed = function(): { Vector3 }
			local list = {}
			local now = Workspace:GetServerTimeNow()
			for _, crate in crates do
				if now >= crate.landAt then
					table.insert(list, crate.box.Position)
				end
			end
			return list
		end,
		golden = function(): Vector3?
			local now = Workspace:GetServerTimeNow()
			for _, crate in crates do
				if crate.golden and now >= crate.landAt then
					return crate.box.Position
				end
			end
			return nil
		end,
		stop = function()
			running = false
		end,
	}
end

return WeaponDrops
