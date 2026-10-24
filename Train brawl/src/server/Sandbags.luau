--!strict
-- Studio practice partners: sandbag characters (default avatars named "샌드백 N") that wander the roofs during a fight
-- and take hits
-- like players. The server owns their physics (SetNetworkOwner(nil)), so it moves them itself with the same rules a
-- player's own client follows (BodyMotion): a short hold, stiff while flying, back on their feet after landing
-- (Config.Knock), and lying down and left behind once below the fall line.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local BodyMotion = require(shared:WaitForChild("BodyMotion"))

local Sandbags = {}

export type Service = {
	-- Makes `count` sandbags under `parent` and returns their models (equip(model) is called on each).
	spawn: (count: number, parent: Instance, equip: (Model) -> ()) -> { Model },
	-- A hit of this kind on a sandbag: a light one flinches it, a launch or smash sends it flying (stiff until it
	-- lands). Returns false for a model that is not one.
	knock: (model: Model, velocity: Vector3, kind: string) -> boolean,
	-- Removes every sandbag.
	clear: () -> (),
	stop: () -> (),
}

-- stiffSince: launched by a hit at this os.clock(); drifting: below the fall line last frame.
type Bag = { body: CharacterParts.Body, stiffSince: number?, drifting: boolean, nextWander: number }

-- A spot to walk to on the roof of the train the bag is on, near where it stands.
local function wanderSpot(body: CharacterParts.Body): Vector3
	local a = Config.Arena
	local here = body.root.Position
	local best, bestX = 1, math.huge
	for i = 1, a.Trains do
		local x = ArenaLayout.trainX(i, a.Trains, a.RoofWidth, a.Gap)
		if math.abs(x - here.X) < math.abs(bestX - here.X) then
			best, bestX = i, x
		end
	end
	local places = ArenaLayout.carPlaces(a.Cars, a.CarGap)
	local front, back = places[1].front + 2, places[#places].back - 2
	local halfWidth = a.RoofWidth / 2 - 1.5
	local x = ArenaLayout.trainX(best, a.Trains, a.RoofWidth, a.Gap) + (math.random() * 2 - 1) * halfWidth
	local z = math.clamp(here.Z + (math.random() * 2 - 1) * 8, front, back)
	return Vector3.new(x, here.Y, z)
end

-- fallLine: feet below it have fallen off (ArenaBuilder).
function Sandbags.start(fallLine: number): Service
	local bags: { [Model]: Bag } = {}
	local ticking = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for model, bag in bags do
			if not model.Parent then
				bags[model] = nil
				continue
			end
			local body = bag.body
			if CharacterParts.feetY(body) < fallLine then
				bag.drifting = true
				BodyMotion.drift(body)
				continue
			end
			local since = bag.stiffSince
			if bag.drifting then
				-- Back above the line: put on a roof by the round after it was made under it (not yet placed).
				bag.drifting = false
				if not since then
					BodyMotion.getUp(body)
				end
			end
			if since then
				if BodyMotion.landed(body, now - since) then
					bag.stiffSince = nil
					BodyMotion.getUp(body)
				end
			elseif Workspace:GetAttribute(Names.Phase) == "Fight" and now >= bag.nextWander then
				bag.nextWander = now + Config.Sandbag.WanderSeconds * (0.6 + math.random() * 0.8)
				body.humanoid:MoveTo(wanderSpot(body))
			end
		end
	end)

	local function spawn(count: number, parent: Instance, equip: (Model) -> ()): { Model }
		local made = {}
		for i = 1, count do
			local ok, model = pcall(function()
				return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
			end)
			if ok and model then
				model.Name = "Sandbag" .. i
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.DisplayName = "샌드백 " .. i
					humanoid.WalkSpeed = Config.Sandbag.WalkSpeed
				end
				CollectionService:AddTag(model, Names.SandbagTag)
				model.Parent = parent
				local body = CharacterParts.body(model)
				if body then
					-- The bat first: welding it on changes the assembly, which puts ownership back on automatic.
					equip(model)
					body.root:SetNetworkOwner(nil) -- the server moves and knocks it
					bags[model] = { body = body, stiffSince = nil, drifting = false, nextWander = 0 }
					table.insert(made, model)
				else
					model:Destroy()
				end
			else
				warn("[TrainBrawl] could not make a sandbag: " .. tostring(model))
			end
		end
		return made
	end

	return {
		spawn = spawn,
		knock = function(model: Model, velocity: Vector3, kind: string): boolean
			local bag = bags[model]
			if not bag then
				return false
			end
			local function reclaim(root: BasePart)
				root:SetNetworkOwner(nil) -- the server keeps moving it
			end
			if kind == "light" then
				-- As a player's client does: the server sends a light hit only after a launch's unhittable moment.
				bag.stiffSince = nil
				BodyMotion.stagger(bag.body, velocity, reclaim)
			else
				bag.stiffSince = os.clock()
				BodyMotion.launch(bag.body, velocity, reclaim)
			end
			return true
		end,
		clear = function()
			for model in bags do
				model:Destroy()
			end
			table.clear(bags)
		end,
		stop = function()
			ticking:Disconnect()
		end,
	}
end

return Sandbags
