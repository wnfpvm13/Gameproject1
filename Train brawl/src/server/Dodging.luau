--!strict
-- Dodge rolls on the server (decision 22, owner 2026-10-31). A player's client rolls its own character at once and
-- tells the server which way (Names.DodgeRemote, a flat Vector3); the server takes the roll when the fighter may fight
-- (hooks.canDodge: on the trains in a running fight), is not stunned by a hit (hooks.stunned), stands on something and
-- its last roll started Config.Dodge.Cooldown ago (DodgeRules.ready, Slack early at most: the network). A roll taken
-- makes the fighter unhittable for Config.Dodge.Immune (hooks.immune) and is published as the model's Names.DodgeDir
-- and Names.DodgeAt for every screen to draw (DodgeShow). A practice bot rolls through dodge() - judged the same with no
-- slack, and moved here (BodyMotion.roll: the server runs its body). rolling() says whether a fighter is mid-roll: it
-- may not attack or block then (WeaponService, Guarding, through Main).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local BodyMotion = require(shared:WaitForChild("BodyMotion"))
local DodgeRules = require(shared:WaitForChild("DodgeRules"))

local Dodging = {}

export type Hooks = {
	canDodge: (model: Model) -> boolean, -- on the trains in a running fight
	stunned: (model: Model) -> boolean, -- flinching or flying from a hit (WeaponService)
	immune: (model: Model, now: number, seconds: number) -> (), -- unhittable for a while (FighterHealth)
}
export type Service = {
	rolling: (model: Model) -> boolean,
	-- A practice bot's roll along the flat `direction`; whether it was taken.
	dodge: (model: Model, direction: Vector3) -> boolean,
	stop: () -> (),
}

function Dodging.start(remote: RemoteEvent, hooks: Hooks): Service
	local d = Config.Dodge
	-- When each fighter's last roll started (server time).
	local last: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

	-- Takes a roll by `model` along the flat unit `direction` now, if it may; `slack`: how early it may come.
	local function take(model: Model, direction: Vector3, slack: number): boolean
		local body = CharacterParts.body(model)
		local now = Workspace:GetServerTimeNow()
		if not (body and body.humanoid.Health > 0 and hooks.canDodge(model)) or hooks.stunned(model) then
			return false
		end
		if not DodgeRules.ready(last[model], now, d.Cooldown, slack) or not BodyMotion.grounded(body) then
			return false
		end
		last[model] = now
		hooks.immune(model, now, d.Immune)
		model:SetAttribute(Names.DodgeDir, direction)
		model:SetAttribute(Names.DodgeAt, now)
		return true
	end

	-- The flat unit way to roll: `wanted` when it is a usable flat vector, else straight back from where it faces.
	local function way(model: Model, wanted: unknown): Vector3
		local look = model:GetPivot().LookVector
		local mx, mz = 0, 0
		if typeof(wanted) == "Vector3" then
			local flat = Vector3.new(wanted.X, 0, wanted.Z)
			local length = flat.Magnitude
			if length > 1e-3 and length < math.huge then -- (also false for NaN)
				mx, mz = flat.X / length, flat.Z / length
			end
		end
		local x, z = DodgeRules.direction(mx, mz, look.X, look.Z)
		return Vector3.new(x, 0, z)
	end

	local received = remote.OnServerEvent:Connect(function(player: Player, wanted: unknown)
		local model = player.Character
		if model then
			take(model, way(model, wanted), d.Slack)
		end
	end)

	return {
		rolling = function(model: Model): boolean
			local at = model:GetAttribute(Names.DodgeAt)
			return DodgeRules.rolling(if typeof(at) == "number" then at else nil, Workspace:GetServerTimeNow(), d.Seconds)
		end,
		dodge = function(model: Model, direction: Vector3): boolean
			local flat = way(model, direction)
			if not take(model, flat, 0) then
				return false
			end
			local body = CharacterParts.body(model)
			if body then
				BodyMotion.roll(body, flat)
			end
			return true
		end,
		stop = function()
			received:Disconnect()
		end,
	}
end

return Dodging
