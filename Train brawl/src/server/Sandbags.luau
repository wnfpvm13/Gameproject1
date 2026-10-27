--!strict
-- Studio practice bots' bodies: default-avatar characters (named Words.bot(N)) that fight in a round and take hits
-- like players. The server owns their physics (SetNetworkOwner(nil)), so it moves them itself with the same rules a
-- player's own client follows (BodyMotion): a short hold, stiff while flying, back on their feet after landing
-- (Config.Knock), and lying down and left behind once below the fall line. Whenever one is free to act in a fight
-- (not flinching from a hit, flying or fallen) its mind decides what it does (think: BotBrain, wired by Main).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local BodyMotion = require(shared:WaitForChild("BodyMotion"))
local Words = require(shared:WaitForChild("Words"))

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

-- stiffSince: launched by a hit at this os.clock(); drifting: below the fall line last frame; flinchUntil: a light hit's
-- stun lasts until this os.clock() (it does nothing meanwhile); acting: its mind ran last frame.
type Bag = { body: CharacterParts.Body, stiffSince: number?, drifting: boolean, flinchUntil: number, acting: boolean }

-- Stops a walk already under way (a MoveTo target lasts until reached or for 8 s, and a step straight in until its
-- mind says otherwise, even after the bag was knocked onto another top, where walking on could take it over an edge).
local function stopWalking(body: CharacterParts.Body)
	body.humanoid:Move(Vector3.zero)
	body.humanoid:MoveTo(body.root.Position)
end

-- fallLine: feet below it have fallen off (ArenaBuilder's layout); think: the bot `model` (its `body`) is free to act at
-- `now` (os.clock()) in a fight.
function Sandbags.start(fallLine: number, think: (model: Model, body: CharacterParts.Body, now: number) -> ()): Service
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
			elseif Workspace:GetAttribute(Names.Phase) == "Fight" and now >= bag.flinchUntil then
				bag.acting = true
				think(model, body, now)
			elseif bag.acting then
				bag.acting = false
				stopWalking(body) -- the fight is over (a hit stopped it already): no walking on off the roof
			end
		end
	end)

	local function spawn(count: number, parent: Instance, equip: (Model) -> ()): { Model }
		local made = {}
		for i = 1, count do
			local ok, model = pcall(function()
				-- The standard body at every fighter's scales (players' are made the same: AvatarRules).
				local description = Instance.new("HumanoidDescription")
				for name, value in Config.Body.Scales do
					(description :: any)[name] = value
				end
				return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
			end)
			if ok and model then
				model.Name = "Sandbag" .. i
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.DisplayName = Words.bot(i)
					humanoid.WalkSpeed = Config.Sandbag.WalkSpeed
				end
				CollectionService:AddTag(model, Names.SandbagTag)
				model.Parent = parent
				local body = CharacterParts.body(model)
				if body then
					-- The weapon first: welding it on changes the assembly, which puts ownership back on automatic.
					equip(model)
					body.root:SetNetworkOwner(nil) -- the server moves and knocks it
					bags[model] = { body = body, stiffSince = nil, drifting = false, flinchUntil = 0, acting = false }
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
			stopWalking(bag.body)
			if kind == "light" then
				-- As a player's client does: the server sends a light hit only after a launch's unhittable moment.
				bag.stiffSince = nil
				bag.flinchUntil = os.clock() + Config.Hit.LightStun
				BodyMotion.stagger(bag.body, velocity, reclaim)
			else
				bag.stiffSince = os.clock()
				BodyMotion.launch(bag.body, velocity, kind, reclaim)
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
