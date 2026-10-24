--!strict
-- 물병 세우기's bottles (bundle 8b, owner 2026-10-24): while the game runs every player in it gets a little round
-- table in front of their chair (toward the show camera, beside their knees; the gaps between chairs hold the bells)
-- with a water bottle on it, and each throw flips the bottle: it jumps, turns over twice and lands standing or on its
-- side (a player who joins mid-game gets them at the next screen). Everything is drawn on this client only (the server says who stood); nothing collides or can be touched.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Bottles = {}

local TABLE_HEIGHT = 1.5 -- studs above the floor to the table top
local TABLE_RADIUS = 0.75
local BOTTLE_SIZE = Vector3.new(0.6, 1.5, 0.6)
local IN_FRONT = 2.6 -- studs in front of the seat (toward the camera)
local TO_THE_LEFT = 0.9 -- and a little to the seated player's left (their right hand is on the bell)
local JUMP = 2.2 -- studs the bottle rises while it flips
local FLIP_SECONDS = 0.8
local TURNS = 2 -- whole turns in the air

local folder: Folder? = nil
local bottles: { [number]: { part: BasePart, rest: CFrame } } = {} -- userId -> its bottle and resting place

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

-- The floor height under `point` (the carpet), or `fallback`.
local function floorAt(point: Vector3, fallback: number, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(point + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
	return if hit then hit.Position.Y else fallback
end

-- A table and a standing bottle for each of `userIds` who sits on a chair now.
function Bottles.setup(userIds: { number })
	Bottles.clear()
	local f = Instance.new("Folder")
	f.Name = "BW_Bottles"
	f.Parent = workspace
	folder = f
	local ignore: { Instance } = { f }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _, userId in userIds do
		local player = Players:GetPlayerByUserId(userId)
		local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if seat then
			local chair = seat.Parent
			if chair then
				table.insert(ignore, chair)
			end
			-- (the seat faces the camera: its -Z; its -X is the seated player's left)
			local spot = seat.CFrame * CFrame.new(-TO_THE_LEFT, 0, -IN_FRONT)
			local floor = floorAt(spot.Position, seat.Position.Y - 2, ignore)
			local top = floor + TABLE_HEIGHT
			local flat = CFrame.new(spot.Position.X, 0, spot.Position.Z)
			part("Leg", Vector3.new(TABLE_HEIGHT, 0.25, 0.25), flat * CFrame.new(0, floor + TABLE_HEIGHT / 2, 0)
				* CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 224, 230), Enum.Material.Metal, Enum.PartType.Cylinder)
			part("Top", Vector3.new(0.15, TABLE_RADIUS * 2, TABLE_RADIUS * 2), flat * CFrame.new(0, top, 0)
				* CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			local rest = flat * CFrame.new(0, top + 0.075 + BOTTLE_SIZE.Y / 2, 0)
			local bottle = part("Bottle", BOTTLE_SIZE, rest, Color3.fromRGB(120, 200, 255), Enum.Material.Glass)
			bottle.Transparency = 0.1 -- (see-through glass vanished against the white deck in the Studio check)
			local cap = part("Cap", Vector3.new(0.3, 0.18, 0.3), rest * CFrame.new(0, BOTTLE_SIZE.Y / 2 + 0.09, 0),
				Color3.fromRGB(40, 110, 220), Enum.Material.SmoothPlastic)
			local weld = Instance.new("WeldConstraint") -- (the cap follows the bottle's CFrame changes)
			weld.Part0 = bottle
			weld.Part1 = cap
			weld.Parent = bottle
			cap.Anchored = false
			bottles[userId] = { part = bottle, rest = rest }
		end
	end
end

-- A throw: `userId`'s bottle jumps, turns over TURNS times and lands standing (`standing`) or on its side. Drawn frame
-- by frame (a tween takes the shortest way round and would not turn twice).
function Bottles.flip(userId: number, standing: boolean)
	local entry = bottles[userId]
	if not entry then
		return
	end
	local bottle, rest = entry.part, entry.rest
	local fallen = rest * CFrame.new(0, -BOTTLE_SIZE.Y / 2 + BOTTLE_SIZE.X / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - started) / FLIP_SECONDS)
		if bottles[userId] ~= entry then
			connection:Disconnect() -- (cleared meanwhile)
			return
		end
		if t >= 1 then
			connection:Disconnect()
			bottle.CFrame = if standing then rest else fallen
			return
		end
		local height = 4 * JUMP * t * (1 - t) -- (up and down again)
		local turn = TURNS * 2 * math.pi * t
		bottle.CFrame = rest * CFrame.new(0, height, 0) * CFrame.Angles(turn, 0, 0)
	end)
end

-- Back to standing for the next throw.
function Bottles.reset()
	for _, entry in bottles do
		entry.part.CFrame = entry.rest
	end
end

function Bottles.clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(bottles)
end

return Bottles
