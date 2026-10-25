--!strict
-- Dresses the stands (the waiting room floating over the middle, built by the server) on this client: four striped
-- hot-air balloons tied to its corners that seem to hold it up, a wooden frame around the glass walls with flags
-- along the top, and beams under the floor (what the fighters see when they look up). All drawn only
-- (PartUtil.decor): nothing here collides, casts a shadow (the balloons would throw big ones on the trains) or is
-- seen by raycasts, so the walls still keep everyone in and the camera never bumps into a balloon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))

local Stands = {}

local WOOD = Enum.Material.Wood
local FABRIC = Enum.Material.Fabric
local CYLINDER = Enum.PartType.Cylinder
local STOOD_UP = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder (round about its X) stood upright
local FLAG = CFrame.Angles(math.pi / 4, 0, 0) -- a wedge turned so its long side is on top and its corner hangs down

local function piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	return PartUtil.decor(name, size, cframe, color, material, parent, shape)
end

-- A balloon over the corner (sx, sz), its tether down to the top of that corner's post at `postTop`.
local function balloon(parent: Instance, sx: number, sz: number, colors: { Color3 }, postTop: Vector3)
	local d = Config.Decor
	local r = d.BalloonRadius
	local half = Config.Arena.WaitingRoomSize / 2
	local centre = Vector3.new(sx * (half + 7), postTop.Y + r + 15, sz * (half + 7))
	piece(parent, "Envelope", Vector3.new(r * 2, r * 2, r * 2), CFrame.new(centre), colors[1], FABRIC, Enum.PartType.Ball)
	-- Stripes: bands round the envelope, each as wide as the ball where it sits (a hair wider, to show).
	for _, dy in { -r * 0.5, 0, r * 0.5 } do
		local across = 2 * math.sqrt(r * r - dy * dy) + 0.12
		piece(parent, "Stripe", Vector3.new(if dy == 0 then 1.4 else 1.1, across, across), CFrame.new(centre + Vector3.new(0, dy, 0)) * STOOD_UP, colors[2], FABRIC, CYLINDER)
	end
	piece(parent, "Mouth", Vector3.new(1.6, 3, 3), CFrame.new(centre - Vector3.new(0, r + 0.4, 0)) * STOOD_UP, colors[2], FABRIC, CYLINDER)
	local basket = centre - Vector3.new(0, r + 4.2, 0)
	piece(parent, "Basket", Vector3.new(2.6, 1.8, 2.6), CFrame.new(basket), d.Colors.Wood, Enum.Material.WoodPlanks)
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) } do
		local from = basket + Vector3.new(corner.X * 1.2, 0.9, corner.Z * 1.2)
		local to = centre + Vector3.new(corner.X * 1.6, -r + 0.6, corner.Z * 1.6)
		PartUtil.decorBar("Rope", from, to, 0.12, d.Colors.Rope, FABRIC, parent)
	end
	PartUtil.decorBar("Tether", basket - Vector3.new(0, 0.9, 0), postTop, 0.16, d.Colors.Rope, FABRIC, parent)
end

function Stands.build(): Folder
	local a, d = Config.Arena, Config.Decor
	local old = Workspace:FindFirstChild(Names.StandsFolder)
	if old then
		old:Destroy()
	end
	local folder = PartUtil.folder(Workspace, Names.StandsFolder)
	local y, half, wall = a.WaitingRoomHeight, a.WaitingRoomSize / 2, a.WaitingRoomWall
	local wood = d.Colors.Wood
	local edge = half + 0.5 -- the glass walls' middle
	-- Under the floor: beams both ways (clear of the glass square in the middle), and a board round its edge.
	local window = a.WaitingRoomWindow / 2 + 0.6
	for _, offset in { -half * 0.75, -window, window, half * 0.75 } do
		piece(folder, "Beam", Vector3.new(half * 2, 0.8, 0.8), CFrame.new(0, y - 1.4, offset), wood, WOOD)
		piece(folder, "Beam", Vector3.new(0.8, 0.8, half * 2), CFrame.new(offset, y - 1.4, 0), wood, WOOD)
	end
	for _, side in { -1, 1 } do
		piece(folder, "Fascia", Vector3.new(half * 2 + 2.2, 1.2, 0.6), CFrame.new(0, y - 0.6, side * (half + 1.3)), wood, WOOD)
		piece(folder, "Fascia", Vector3.new(0.6, 1.2, half * 2 + 2.2), CFrame.new(side * (half + 1.3), y - 0.6, 0), wood, WOOD)
	end
	-- A wooden frame round the glass: corner and middle posts, a rail along the top.
	local railY = y + wall + 0.3
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			piece(folder, "Post", Vector3.new(1.2, wall + 0.6, 1.2), CFrame.new(sx * edge, y + (wall + 0.6) / 2, sz * edge), wood, WOOD)
		end
		piece(folder, "Post", Vector3.new(1.2, wall, 0.8), CFrame.new(sx * edge, y + wall / 2, 0), wood, WOOD)
		piece(folder, "Post", Vector3.new(0.8, wall, 1.2), CFrame.new(0, y + wall / 2, sx * edge), wood, WOOD)
		piece(folder, "TopRail", Vector3.new(1.2, 0.6, half * 2 + 2), CFrame.new(sx * edge, railY, 0), wood, WOOD)
		piece(folder, "TopRail", Vector3.new(half * 2 + 2, 0.6, 1.2), CFrame.new(0, railY, sx * edge), wood, WOOD)
	end
	-- Flags along the outside of the top rail, in turn round the colours.
	local flagY = railY - 0.45
	local count = math.floor(half * 2 / 2.4)
	local n = 0
	for _, side in { -1, 1 } do
		for k = 1, count do
			local along = -half + (k - 0.5) * (half * 2 / count)
			for _, turned in { false, true } do
				n += 1
				local color = d.Flags[(n - 1) % #d.Flags + 1]
				local out = side * (edge + 0.7)
				local place = if turned
					then CFrame.new(along, flagY, out) * CFrame.Angles(0, math.pi / 2, 0) * FLAG
					else CFrame.new(out, flagY, along) * FLAG
				PartUtil.decorWedge("Flag", Vector3.new(0.08, 1.3, 1.3), place, color, FABRIC, folder)
			end
		end
	end
	-- The balloons, one per corner, each tied to its corner post's top.
	local corner = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			corner += 1
			balloon(folder, sx, sz, d.Balloons[(corner - 1) % #d.Balloons + 1], Vector3.new(sx * edge, y + wall + 0.6, sz * edge))
		end
	end
	return folder
end

return Stands
