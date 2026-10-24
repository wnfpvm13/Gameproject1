--!strict
-- Swings, judged on the server. A player's client swings at once and tells the server; the server takes the swing
-- when the player is fighting, alive, not flying from a hit (from Config.Knock.SwingGrace to MinSeconds after it:
-- a swing arriving sooner was pressed before the player saw the hit) and the bat is ready
-- (Config.Bat.Cooldown, less a little slack), marks the character's SwingAt so every client draws it, and
-- Config.Bat.HitAt later hits every other fighter in the cone in front (SwingTargets, reach widened by ReachSlack for
-- the network delay), once each. A hit is sent to every client (Names.HitRemote: the victim, the knock and the
-- swinger): the victim's own client knocks its character, everyone shows the hit; a sandbag is knocked here (the
-- server owns it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local BatMath = require(shared:WaitForChild("BatMath"))
local SwingTargets = require(shared:WaitForChild("SwingTargets"))

local BatService = {}

export type Hooks = {
	canSwing: (model: Model) -> boolean, -- the model is a fighter in a running fight
	fighters: () -> { Model }, -- the models that can be hit
	knockHere: (model: Model, velocity: Vector3) -> boolean, -- knocks a server-owned model (a sandbag); false otherwise
	onHit: (victim: Model, swinger: Model) -> (), -- for the knock-off credit
}

function BatService.start(swingRemote: RemoteEvent, hitRemote: RemoteEvent, hooks: Hooks): () -> ()
	local b = Config.Bat
	local lastSwing: { [Player]: number } = {}
	local knockedAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any -- last hit, server time

	local function strike(swinger: Model)
		local body = CharacterParts.body(swinger)
		if not (body and hooks.canSwing(swinger)) then
			return
		end
		local from = body.root.Position
		local facing = body.root.CFrame.LookVector
		for _, victim in SwingTargets.find(body, hooks.fighters(), b.Reach + b.ReachSlack) do
			local at = victim.root.Position
			local vx, vy, vz = BatMath.knock(from.X, from.Z, facing.X, facing.Z, at.X, at.Z, b.Push, b.Lift)
			local velocity = Vector3.new(vx, vy, vz)
			knockedAt[victim.model] = Workspace:GetServerTimeNow()
			hooks.knockHere(victim.model, velocity)
			hitRemote:FireAllClients(victim.model, velocity, swinger)
			hooks.onHit(victim.model, swinger)
		end
	end

	local received = swingRemote.OnServerEvent:Connect(function(player: Player)
		local model = player.Character
		local body = CharacterParts.body(model)
		if not (model and body and body.humanoid.Health > 0 and hooks.canSwing(model)) then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local hitAt = knockedAt[model]
		local k = Config.Knock
		if hitAt and now - hitAt >= k.SwingGrace and now - hitAt < k.MinSeconds then
			return -- still flying from a hit (the client does not swing then either)
		end
		local last = lastSwing[player]
		if last and now - last < b.Cooldown - b.CooldownSlack then
			return
		end
		lastSwing[player] = now
		model:SetAttribute(Names.SwingAt, now)
		task.delay(b.HitAt, strike, model)
	end)
	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		lastSwing[player] = nil
	end)
	return function()
		received:Disconnect()
		leaving:Disconnect()
	end
end

return BatService
