--!strict
-- The back cars coming off during a fight (persona fix 6; B's "칸 떨어져 나가기", brought forward against stand-offs).
-- Config.Uncouple.FirstAfter seconds into the fight, then every Every, the last car of a random train still longer than
-- KeepCars cars is marked with Names.CarLeavingAt (when it lets go, Warning seconds on: every client warns of it,
-- UncoupleShow). Then the server moves the car's model and the planks resting on it (ArenaLayout.planksOn) along
-- Uncouple.motion each frame - easing back, then dropping away behind - and gives their parts that motion's velocity,
-- so whoever stands on it is carried along as on a moving floor (and falls off with it: FallWatch). Once past the drop
-- it is put far below and marked Names.CarGone. Everything is put back when the fight is over. away() says which cars
-- are leaving or gone (no crate lands there, nobody comes back down there).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local Uncouple = require(shared:WaitForChild("Uncouple"))

local Uncoupling = {}

export type Service = {
	away: (train: number, car: number) -> boolean, -- leaving or gone this fight
	stop: () -> (),
}

-- A car on its way off: its model and the planks on it with where each was, and when it lets go (server time).
type Moving = { model: Model, home: CFrame, planks: { { part: BasePart, home: CFrame } }, letGo: number }

local OUT_OF_SIGHT = Vector3.new(0, -400, 0)

-- Gives every part of `parts` the velocity (they are anchored: whoever stands on one is carried along).
local function carry(parts: { BasePart }, velocity: Vector3)
	for _, part in parts do
		part.AssemblyLinearVelocity = velocity
	end
end

local function partsOf(model: Model): { BasePart }
	local list = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(list, item)
		end
	end
	return list
end

-- folder: the arena's (ArenaBuilder: the train models, the planks); layout: where everything is.
function Uncoupling.start(folder: Instance, layout: ArenaLayout.Layout): Service
	local u = Config.Uncouple
	local away: { [string]: boolean } = {}
	local moving: { Moving } = {}
	-- Every car moved this fight, with its planks, to put back.
	local moved: { Moving } = {}
	local nextAt: number? = nil

	local function key(train: number, car: number): string
		return train .. ":" .. car
	end

	local function carModel(train: number, car: number): Model?
		local trainModel = folder:FindFirstChild(Names.TrainModel .. train)
		local found = trainModel and trainModel:FindFirstChild(Names.CarModel .. car)
		return if found and found:IsA("Model") then found else nil
	end

	local function plankPart(number: number): BasePart?
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute(Names.PlankNumber) == number then
				return child
			end
		end
		return nil
	end

	-- Moves a car and its planks to where they are `t` seconds after letting go.
	local function place(m: Moving, t: number)
		local back, down, vBack, vDown = Uncouple.motion(t, u)
		local shift = Vector3.new(0, -down, back)
		local velocity = Vector3.new(0, -vDown, vBack)
		m.model:PivotTo(m.home + shift)
		carry(partsOf(m.model), velocity)
		for _, plank in m.planks do
			plank.part.CFrame = plank.home + shift
			plank.part.AssemblyLinearVelocity = velocity
		end
	end

	-- Puts every car moved this fight back where it was.
	local function restore()
		for _, m in moved do
			m.model:PivotTo(m.home)
			carry(partsOf(m.model), Vector3.zero)
			m.model:SetAttribute(Names.CarLeavingAt, nil)
			m.model:SetAttribute(Names.CarGone, nil)
			for _, plank in m.planks do
				plank.part.CFrame = plank.home
				plank.part.AssemblyLinearVelocity = Vector3.zero
			end
		end
		table.clear(moved)
		table.clear(moving)
		table.clear(away)
	end

	-- The next car to go: the last car still on of a random train still longer than it keeps.
	local function warn(now: number)
		local left = {}
		for i, train in layout.trains do
			local count = 0
			for k in train.cars do
				if not away[key(i, k)] then
					count = k
				end
			end
			left[i] = count
		end
		local train = Uncouple.pick(left, u.KeepCars, math.random)
		if not train then
			return
		end
		local car = left[train]
		local model = carModel(train, car)
		if not model then
			return
		end
		away[key(train, car)] = true
		local planks = {}
		for _, number in ArenaLayout.planksOn(layout, train, car) do
			local part = plankPart(number)
			if part then
				table.insert(planks, { part = part, home = part.CFrame })
			end
		end
		local m: Moving = { model = model, home = model:GetPivot(), planks = planks, letGo = now + u.Warning }
		model:SetAttribute(Names.CarLeavingAt, m.letGo)
		table.insert(moving, m)
		table.insert(moved, m)
	end

	local ticking = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		if Workspace:GetAttribute(Names.Phase) ~= "Fight" then
			if #moved > 0 then
				restore()
			end
			nextAt = nil
			return
		end
		if not nextAt then
			local endsAt = PartUtil.number(Workspace, Names.PhaseEndsAt) or now
			nextAt = endsAt - Config.Round.MaxSeconds + u.FirstAfter
		end
		if now >= (nextAt :: number) then
			nextAt = (nextAt :: number) + u.Every
			warn(now)
		end
		for _, m in table.clone(moving) do
			local t = now - m.letGo
			if t > 0 then
				if Uncouple.over(t, u) then
					m.model:PivotTo(m.home + OUT_OF_SIGHT)
					carry(partsOf(m.model), Vector3.zero)
					for _, plank in m.planks do
						plank.part.CFrame = plank.home + OUT_OF_SIGHT
						plank.part.AssemblyLinearVelocity = Vector3.zero
					end
					m.model:SetAttribute(Names.CarGone, true)
					table.remove(moving, table.find(moving, m) :: number)
				else
					place(m, t)
				end
			end
		end
	end)

	return {
		away = function(train: number, car: number): boolean
			return away[key(train, car)] == true
		end,
		stop = function()
			ticking:Disconnect()
			restore()
		end,
	}
end

return Uncoupling
