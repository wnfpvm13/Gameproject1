--!strict
-- Each fighter's combat health on the server (HitRules state per character or sandbag model), published as the model's
-- Names.Health attribute for the bars on every screen. Not the Humanoid's Health: that one kills at 0 and refills on
-- its own. Full again at the start of every round (reset).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local HitRules = require(shared:WaitForChild("HitRules"))

local FighterHealth = {}

export type Keeper = {
	reset: (model: Model) -> (), -- full health (a new round)
	-- A hit lands (server time): its kind ("none" while unhittable) and the health left after it.
	hit: (model: Model, now: number) -> (HitRules.Kind, number),
}

function FighterHealth.start(): Keeper
	local rules: HitRules.Rules = {
		max = Config.Health.Max,
		damage = Config.Health.HitDamage,
		window = Config.Hit.ComboWindow,
		launchOn = Config.Hit.LaunchOn,
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
		end,
		hit = function(model: Model, now: number): (HitRules.Kind, number)
			local state = stateOf(model)
			local kind = HitRules.hit(state, rules, now)
			model:SetAttribute(Names.Health, state.health)
			return kind, state.health
		end,
	}
end

return FighterHealth
