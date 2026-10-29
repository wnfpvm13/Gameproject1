--!strict
-- Each fighter's combat health on the server (HitRules state per character or sandbag model), published as the model's
-- Names.Health attribute for the bars on every screen. Not the Humanoid's Health: that one kills at 0 and refills on
-- its own. Full again at the start of every round and on the way back after a fall (reset). A fighter just back on
-- the trains is unhittable for a moment unless it attacks (guard, unguard), published as Names.GuardUntil for the
-- shimmer every screen draws on it (ComebackShow).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local HitRules = require(shared:WaitForChild("HitRules"))

local FighterHealth = {}

export type Keeper = {
	reset: (model: Model) -> (), -- full health (a new round, or coming back after a fall)
	guard: (model: Model, now: number, seconds: number) -> (), -- unhittable for `seconds` (just back on the trains)
	unguard: (model: Model, now: number) -> (), -- the guard ends at once (it attacked)
	-- A hit of `damage` by `by` lands (server time; launch: the attacker's hit launches): its kind ("none" while
	-- unhittable), the health left after it, and whether a crowd launched it (HitRules' guard).
	hit: (model: Model, now: number, damage: number, launch: boolean, by: Model?) -> (HitRules.Kind, number, boolean),
}

function FighterHealth.start(): Keeper
	local rules: HitRules.Rules = {
		max = Config.Health.Max,
		window = Config.Hit.GangWindow,
		gang = Config.Hit.GangHits,
		immune = Config.Hit.LaunchImmune,
	}
	local states: { [Model]: HitRules.State } = setmetatable({}, { __mode = "k" }) :: any

	local function stateOf(model: Model): HitRules.State
		local state = states[model]
		if not state then
			state = HitRules.new(rules.max)
			states[model] = state
		end
		return state
	end

	return {
		reset = function(model: Model)
			states[model] = HitRules.new(rules.max)
			model:SetAttribute(Names.Health, rules.max)
			model:SetAttribute(Names.GuardUntil, nil)
		end,
		guard = function(model: Model, now: number, seconds: number)
			local state = stateOf(model)
			state.immuneUntil = math.max(state.immuneUntil, now + seconds)
			model:SetAttribute(Names.GuardUntil, now + seconds)
		end,
		unguard = function(model: Model, now: number)
			local guardUntil = model:GetAttribute(Names.GuardUntil)
			if typeof(guardUntil) == "number" and guardUntil > now then
				-- Nothing else makes it unhittable while guarded: it cannot be hit (or launched) meanwhile.
				stateOf(model).immuneUntil = now
				model:SetAttribute(Names.GuardUntil, nil)
			end
		end,
		hit = function(model: Model, now: number, damage: number, launch: boolean, by: Model?): (HitRules.Kind, number, boolean)
			local state = stateOf(model)
			local kind, ganged = HitRules.hit(state, rules, now, damage, launch, by)
			model:SetAttribute(Names.Health, state.health)
			return kind, state.health, ganged
		end,
	}
end

return FighterHealth
