--!strict
-- Dresses every car but the locomotives on this client (LocomotiveDecor does those), from the same layout the server
-- built the cars from (ArenaLayout): two trucks of wheels under each car and couplers at its ends, and by kind:
-- boxcars a sliding door, posts and braces, a ladder, the line's lettering and a walkway on the roof; the coal tender
-- coal and a rim on top; flatcars stakes along the deck and battens and ropes on the crates; the caboose windows (its
-- lookout's too) and red marker lamps. The planks between the trains get iron straps. All of it drawn only
-- (PartUtil.decor): nothing here collides, casts a shadow or is seen by raycasts, so where anyone can stand stays
-- the server's. What lies on a top is mostly a few hundredths high, under the feet; the coal (up to about 0.4), the
-- tender's rim (0.35) and the flatcar's stakes along its edges (1) stand higher and are walked through.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))

local CarDecor = {}

local BLACK = Color3.new(0, 0, 0)

local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local BLOCK = Enum.PartType.Block
local CYLINDER = Enum.PartType.Cylinder

-- Where the car's `share` of its length is along the track.
local function along(place: ArenaLayout.CarPlace, share: number): number
	return place.front + place.length * share
end

local function piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	return PartUtil.decor(name, size, cframe, color, material or METAL, parent, shape or BLOCK)
end

-- Lettering on a car's side: painted outward on a see-through plate in front of the posts and braces (still under
-- the roof's overhang).
local function lettering(parent: Instance, x: number, side: number, y: number, z: number, size: Vector2, text: string)
	local a = Config.Arena
	local at = CFrame.new(x + side * (a.RoofWidth / 2 - a.BodyInset + 0.21), y, z)
	PartUtil.letterPlate(parent, Vector3.new(0.04, size.Y, size.X), at, if side == 1 then Enum.NormalId.Right else Enum.NormalId.Left, text, Config.Decor.Colors.Trim)
end

-- Two trucks of wheels under the car, its side sills and a coupler at each end.
local function runningGear(parent: Instance, x: number, place: ArenaLayout.CarPlace)
	local a, colors = Config.Arena, Config.Decor.Colors
	local halfWidth = a.RoofWidth / 2 - a.BodyInset
	local wheel = Config.Decor.TruckWheelRadius
	local trucks: { number } = if place.length <= 12 then { 0.25, 0.75 } else { 0.2, 0.8 }
	for _, share in trucks do
		local z = along(place, share)
		piece(parent, "Bolster", Vector3.new(a.Gauge * 2 + 0.6, 0.5, 0.8), CFrame.new(x, a.BodyBottom - 0.25, z), colors.Iron)
		for _, side in { -1, 1 } do
			piece(parent, "TruckFrame", Vector3.new(0.35, 0.7, 3.6), CFrame.new(x + side * (a.Gauge + 0.45), wheel + 0.1, z), colors.Iron)
			for _, dz in { -1.15, 1.15 } do
				piece(parent, "Wheel", Vector3.new(0.4, wheel * 2, wheel * 2), CFrame.new(x + side * a.Gauge, wheel, z + dz), a.Colors.Wheel, METAL, CYLINDER)
			end
		end
	end
	for _, side in { -1, 1 } do
		piece(parent, "Sill", Vector3.new(0.16, 0.4, place.length), CFrame.new(x + side * (halfWidth + 0.08), a.BodyBottom + 0.2, place.middle), colors.Iron)
	end
	piece(parent, "Coupler", Vector3.new(0.7, 0.45, 0.5), CFrame.new(x, a.BodyBottom + 0.4, place.front - 0.12), colors.Iron)
	piece(parent, "Coupler", Vector3.new(0.7, 0.45, 0.5), CFrame.new(x, a.BodyBottom + 0.4, place.back + 0.12), colors.Iron)
end

-- A ladder up one side of a car, its rails `z` and `z + 1.2` along the track.
local function ladder(parent: Instance, x: number, side: number, z: number, top: number)
	local a, colors = Config.Arena, Config.Decor.Colors
	local ladderX = x + side * (a.RoofWidth / 2 - a.BodyInset + 0.22)
	local bottom = a.BodyBottom + 0.2
	for _, railZ in { z, z + 1.2 } do
		piece(parent, "LadderRail", Vector3.new(0.12, top - 0.3 - bottom, 0.12), CFrame.new(ladderX, (bottom + top - 0.3) / 2, railZ), colors.Iron)
	end
	local y = bottom + 0.6
	while y < top - 0.6 do
		piece(parent, "LadderRung", Vector3.new(0.1, 0.1, 1.3), CFrame.new(ladderX, y, z + 0.6), colors.Iron)
		y += 1.1
	end
end

local function boxcar(parent: Instance, x: number, place: ArenaLayout.CarPlace, number: number)
	local a, colors = Config.Arena, Config.Decor.Colors
	local halfWidth = a.RoofWidth / 2 - a.BodyInset
	local top = place.roof
	local bodyTop = top - 0.3
	local height = bodyTop - a.BodyBottom
	local door = a.Colors.Boxcar:Lerp(BLACK, 0.22)
	local frontPanel, backPanel = place.middle - 2.75, place.middle + 2.75
	for _, side in { -1, 1 } do
		local face = x + side * halfWidth
		-- The sliding door on its rails (the rails run over the back panel, where it slides open to), and its handle.
		local doorBottom, doorTop = a.BodyBottom + 0.5, bodyTop - 0.7
		piece(parent, "Door", Vector3.new(0.12, doorTop - doorBottom, 5.2), CFrame.new(face + side * 0.06, (doorBottom + doorTop) / 2, place.middle), door, WOOD)
		for _, railY in { doorTop + 0.15, doorBottom - 0.1 } do
			piece(parent, "DoorRail", Vector3.new(0.14, 0.22, 11), CFrame.new(face + side * 0.13, railY, place.middle + 2.5), colors.Iron)
		end
		piece(parent, "Handle", Vector3.new(0.1, 1.4, 0.18), CFrame.new(face + side * 0.17, (doorBottom + doorTop) / 2, place.middle + 2.2), colors.Iron)
		-- Posts at the ends and beside the door, a brace across each panel.
		for _, z in { place.front + 0.15, frontPanel, backPanel, place.back - 0.15 } do
			piece(parent, "Post", Vector3.new(0.1, height, 0.3), CFrame.new(face + side * 0.05, a.BodyBottom + height / 2, z), door, WOOD)
		end
		local low, high = a.BodyBottom + 0.3, bodyTop - 0.3
		PartUtil.decorBar("Brace", Vector3.new(face + side * 0.08, low, place.front + 0.3), Vector3.new(face + side * 0.08, high, frontPanel - 0.15), 0.22, door, WOOD, parent)
		PartUtil.decorBar("Brace", Vector3.new(face + side * 0.08, low, place.back - 0.3), Vector3.new(face + side * 0.08, high, backPanel + 0.15), 0.22, door, WOOD, parent)
		ladder(parent, x, side, place.back - 1.65, top)
		lettering(parent, x, side, bodyTop - 1.5, (place.front + frontPanel) / 2 + 0.3, Vector2.new(6, 1.5), Config.Decor.Lettering)
		lettering(parent, x, side, bodyTop - 1.4, (backPanel + place.back) / 2 - 0.6, Vector2.new(3.6, 1.1), "No. " .. number)
	end
	-- On the roof: seams across it and a walkway along the middle (a few hundredths high: under the feet).
	local seam = 2.5
	local z = place.front + seam
	while z < place.back - 0.5 do
		piece(parent, "RoofSeam", Vector3.new(a.RoofWidth - 0.2, 0.05, 0.18), CFrame.new(x, top + 0.025, z), a.Colors.Roof:Lerp(BLACK, 0.3))
		z += seam
	end
	piece(parent, "Walkway", Vector3.new(1.6, 0.06, place.length - 0.6), CFrame.new(x, top + 0.03, place.middle), colors.Wood, WOOD)
end

local function tender(parent: Instance, x: number, place: ArenaLayout.CarPlace, number: number)
	local a, colors = Config.Arena, Config.Decor.Colors
	local halfWidth = a.RoofWidth / 2 - a.BodyInset
	local top = place.roof
	-- Coal: flat lumps lying on the top (sticking up a few tenths), and a low rim around it.
	for k = 1, 9 do
		local lx = x + (((k * 37) % 7) / 6 - 0.5) * 6.5
		local lz = place.front + 1.2 + ((k * 53) % 9) / 8 * (place.length - 4)
		piece(parent, "Coal", Vector3.new(1.7, 0.5, 1.4), CFrame.new(lx, top - 0.05, lz) * CFrame.Angles(0.12 * (k % 3 - 1), k * 1.3, 0.1), a.Colors.Coal, Enum.Material.Slate)
	end
	for _, side in { -1, 1 } do
		piece(parent, "Rim", Vector3.new(0.25, 0.35, place.length), CFrame.new(x + side * (a.RoofWidth / 2 - 0.125), top + 0.175, place.middle), a.Colors.Tender)
		piece(parent, "Lining", Vector3.new(0.06, 0.14, place.length - 0.6), CFrame.new(x + side * (halfWidth + 0.03), top - 1.3, place.middle), colors.Trim)
		lettering(parent, x, side, (a.BodyBottom + top) / 2 - 0.4, place.middle, Vector2.new(4.4, 1.3), "No. " .. number)
	end
	for _, z in { place.front + 0.125, place.back - 0.125 } do
		piece(parent, "Rim", Vector3.new(a.RoofWidth, 0.35, 0.25), CFrame.new(x, top + 0.175, z), a.Colors.Tender)
	end
	piece(parent, "WaterHatch", Vector3.new(0.25, 1.8, 1.8), CFrame.new(x, top + 0.12, place.back - 1.5) * CFrame.Angles(0, 0, math.pi / 2), colors.Iron, METAL, CYLINDER)
end

local function flatcar(parent: Instance, x: number, place: ArenaLayout.CarPlace, kind: ArenaLayout.Kind)
	local a, colors = Config.Arena, Config.Decor.Colors
	local top = place.roof
	for _, side in { -1, 1 } do
		piece(parent, "DeckEdge", Vector3.new(0.3, 0.06, place.length), CFrame.new(x + side * (a.RoofWidth / 2 - 0.15), top + 0.03, place.middle), colors.Wood, WOOD)
		local z = place.front + 1.5
		while z < place.back - 1 do
			piece(parent, "Stake", Vector3.new(0.3, 1.1, 0.3), CFrame.new(x + side * (a.RoofWidth / 2 - 0.2), top + 0.45, z), colors.Wood, WOOD)
			z += 3
		end
	end
	-- Each crate: a cross of battens on its two sides facing across the track and a rope strap over it.
	local crates: { ArenaLayout.Box } = kind.crates or {}
	for _, crate in crates do
		local z = along(place, crate.along)
		local fore, aft = z - crate.length / 2 + 0.3, z + crate.length / 2 - 0.3
		local low, high = top + 0.3, top + crate.height - 0.3
		for _, side in { -1, 1 } do
			local faceX = x + side * (crate.width / 2 + 0.08)
			PartUtil.decorBar("Batten", Vector3.new(faceX, low, fore), Vector3.new(faceX, high, aft), 0.2, colors.Wood, WOOD, parent)
			PartUtil.decorBar("Batten", Vector3.new(faceX, low, aft), Vector3.new(faceX, high, fore), 0.2, colors.Wood, WOOD, parent)
			piece(parent, "Strap", Vector3.new(0.05, crate.height, 0.25), CFrame.new(x + side * (crate.width / 2 + 0.03), top + crate.height / 2, z), colors.Rope, Enum.Material.Fabric)
		end
		piece(parent, "Strap", Vector3.new(crate.width + 0.1, 0.05, 0.25), CFrame.new(x, top + crate.height + 0.025, z), colors.Rope, Enum.Material.Fabric)
	end
end

local function caboose(parent: Instance, x: number, place: ArenaLayout.CarPlace, kind: ArenaLayout.Kind)
	local a, colors = Config.Arena, Config.Decor.Colors
	local halfWidth = a.RoofWidth / 2 - a.BodyInset
	local top = place.roof
	for _, side in { -1, 1 } do
		local face = x + side * halfWidth
		for _, share in { 0.16, 0.38, 0.72 } do
			local z = along(place, share)
			piece(parent, "WindowFrame", Vector3.new(0.08, 2.1, 1.8), CFrame.new(face + side * 0.04, top - 2.9, z), colors.Trim, WOOD)
			piece(parent, "Window", Vector3.new(0.1, 1.7, 1.4), CFrame.new(face + side * 0.06, top - 2.9, z), colors.Window, Enum.Material.Glass)
		end
		ladder(parent, x, side, place.front + 0.45, top)
		lettering(parent, x, side, a.BodyBottom + 1.5, place.middle, Vector2.new(7, 1.2), Config.Decor.Lettering)
		-- Red marker lamps at the back corners.
		piece(parent, "MarkerLamp", Vector3.new(0.5, 0.7, 0.35), CFrame.new(x + side * 4.1, top - 1.6, place.back + 0.17), colors.Marker, Enum.Material.Neon)
	end
	local cupola = kind.cupola
	if cupola then
		local from, to = along(place, cupola.from), along(place, cupola.to)
		local cupolaTop = top + cupola.height
		local middle, length = (from + to) / 2, to - from
		for _, side in { -1, 1 } do
			for _, share in { 0.3, 0.7 } do
				local z = from + length * share
				piece(parent, "WindowFrame", Vector3.new(0.06, 1.4, 1.7), CFrame.new(x + side * (cupola.width / 2 + 0.03), top + 1.6, z), colors.Trim, WOOD)
				piece(parent, "Window", Vector3.new(0.08, 1.1, 1.4), CFrame.new(x + side * (cupola.width / 2 + 0.05), top + 1.6, z), colors.Window, Enum.Material.Glass)
			end
		end
		for _, z in { from - 0.04, to + 0.04 } do
			piece(parent, "Window", Vector3.new(1.8, 1.1, 0.08), CFrame.new(x, top + 1.6, z), colors.Window, Enum.Material.Glass)
		end
		-- An overhanging cap whose top is the lookout's own (nothing sticks up from where people stand).
		piece(parent, "CupolaCap", Vector3.new(cupola.width + 0.6, 0.25, length + 0.6), CFrame.new(x, cupolaTop - 0.125, middle), a.Colors.Roof)
	end
end

-- Iron straps across each plank: at both ends and in the middle.
local function plankStraps(parent: Instance, plank: ArenaLayout.Plank)
	local a = Config.Arena
	local y = plank.top + a.PlankThickness + 0.025
	for _, dx in { -plank.length / 2 + 0.6, 0, plank.length / 2 - 0.6 } do
		piece(parent, "Strap", Vector3.new(0.3, 0.05, a.PlankWidth + 0.1), CFrame.new(plank.x + dx, y, plank.z), Config.Decor.Colors.Iron)
	end
end

-- layout: the arena (ArenaLayout.layout). Returns the folder it all went in.
function CarDecor.build(layout: ArenaLayout.Layout): Folder
	local old = Workspace:FindFirstChild(Names.CarDecorFolder)
	if old then
		old:Destroy()
	end
	local folder = PartUtil.folder(Workspace, Names.CarDecorFolder)
	for i, train in layout.trains do
		for k, place in train.cars do
			local kind = Config.Arena.CarKinds[place.kind]
			if kind.boiler then
				continue -- LocomotiveDecor's
			end
			local number = 100 * i + k
			runningGear(folder, train.x, place)
			if place.kind == "Tender" then
				tender(folder, train.x, place, number)
			elseif place.kind == "Flatcar" then
				flatcar(folder, train.x, place, kind)
			elseif place.kind == "Caboose" then
				caboose(folder, train.x, place, kind)
			else
				boxcar(folder, train.x, place, number)
			end
		end
	end
	for _, plank in layout.planks do
		plankStraps(folder, plank)
	end
	return folder
end

return CarDecor
