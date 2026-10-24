--!strict
-- Swings, judged on the server. A player's client swings at once and tells the server (with where it aimed); the
-- server takes the swing when the player is fighting, alive, not stunned by a hit (from Config.Knock.SwingGrace until
-- the hit's stun ends: a swing arriving sooner was pressed before the player saw the hit) and the bat is ready
-- (Config.Bat.Cooldown, less a little slack), marks the character's SwingAt so every client draws it, and
-- Config.Bat.HitAt later hits every other fighter in the cone in front (SwingTargets, reach widened by ReachSlack for
-- the network delay; aimed where the swinger's client said it aimed when pressed, as the character is the client's
-- to turn anyway). Each hit asks the health keeper what it was (HitRules: light, launch or smash) and pushes by
-- health (HitRules.force); it is sent to every client
-- (Names.HitRemote: the victim, the velocity, the swinger and the kind): the victim's own client moves its character,
-- everyone shows the hit; a sandbag is moved here (the server owns it). A smash ends its fighter's round.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local BatMath = require(shared:WaitForChild("BatMath"))
local HitRules = require(shared:WaitForChild("HitRules"))
local SwingTargets = require(shared:WaitForChild("SwingTargets"))

local BatService = {}

export type Hooks = {
	canSwing: (model: Model) -> boolean, -- the model is a fighter in a running fight
	fighters: () -> { Model }, -- the models that can be hit
	hit: (victim: Model, now: number) -> (HitRules.Kind, number), -- the health keeper: this hit's kind, health left
	knockHere: (model: Model, velocity: Vector3, kind: HitRules.Kind) -> boolean, -- moves a server-owned model (a sandbag)
	onHit: (victim: Model, swinger: Model) -> (), -- for the knock-off credit
	onSmash: (victim: Model) -> (), -- health emptied: out of the round
}

function BatService.start(swingRemote: RemoteEvent, hitRemote: RemoteEvent, hooks: Hooks): () -> ()
	local b = Config.Bat
	local lastSwing: { [Player]: number } = {}
	-- Per fighter: when the last hit landed and when its stun ends (server time).
	local hitAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	local stunUntil: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

	local function strike(swinger: Model, facing: Vector3)
		local body = CharacterParts.body(swinger)
		if not (body and hooks.canSwing(swinger)) then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local from = body.root.Position
		for _, victim in SwingTargets.find(body, hooks.fighters(), b.Reach + b.ReachSlack, facing) do
			local kind, health = hooks.hit(victim.model, now)
			if kind ~= "none" then
				local push, lift = HitRules.force(kind, health, Config.Health.Max, Config.Hit)
				local at = victim.root.Position
				local vx, vy, vz = BatMath.knock(from.X, from.Z, facing.X, facing.Z, at.X, at.Z, push, lift)
				local velocity = Vector3.new(vx, vy, vz)
				hitAt[victim.model] = now
				stunUntil[victim.model] = now + (if kind == "light" then Config.Hit.LightStun else Config.Knock.MinSeconds)
				hooks.knockHere(victim.model, velocity, kind)
				hitRemote:FireAllClients(victim.model, velocity, swinger, kind)
				hooks.onHit(victim.model, swinger)
				if kind == "smash" then
					hooks.onSmash(victim.model)
				end
			end
		end
	end

	local received = swingRemote.OnServerEvent:Connect(function(player: Player, aim: unknown)
		local model = player.Character
		local body = CharacterParts.body(model)
		if not (model and body and body.humanoid.Health > 0 and hooks.canSwing(model)) then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local since = hitAt[model]
		local stunned = stunUntil[model]
		if since and stunned and now - since >= Config.Knock.SwingGrace and now < stunned then
			return -- still stunned by a hit (the client does not swing then either)
		end
		local last = lastSwing[player]
		if last and now - last < b.Cooldown - b.CooldownSlack then
			return
		end
		lastSwing[player] = now
		-- Where the swinger aimed when pressed (along the ground); the facing this server sees if that is unusable.
		local seen = body.root.CFrame.LookVector
		local facing = Vector3.new(seen.X, 0, seen.Z)
		if typeof(aim) == "Vector3" then
			local flat = Vector3.new(aim.X, 0, aim.Z)
			local length = flat.Magnitude
			if length > 1e-3 and length < math.huge then -- also false for NaN
				facing = flat / length
			end
		end
		model:SetAttribute(Names.SwingAt, now)
		task.delay(b.HitAt, strike, model, facing)
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
