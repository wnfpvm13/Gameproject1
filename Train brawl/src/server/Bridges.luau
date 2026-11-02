--!strict
-- Low bridges over the trains during a fight (decision 24; the rules are BridgeRules', the numbers Config.Bridge's).
-- Config.Bridge.FirstAfter seconds into the fight, then every Every while the fight has Warning and PassSeconds left, a
-- pass is put on Workspace as Names.BridgeAt: the server time its beam reaches the front of the trains, Warning seconds
-- on. Every client draws the bridge running in
-- with the scenery, warns and marks the low tops (BridgeShow). While the beam goes over, every fighter still in the
-- round and not on its way back (Names.ReturnPhase) that is under the beam and too tall for it - standing on a roof,
-- on a lookout or a chimney, mid-jump or flying from a hit; ducked (hooks.ducking: holding its block) it is Duck
-- tall - is caught: hooks.swept (a blow from the beam), once a pass. The pass ends once the beam is past the back of
-- the trains, and when the fight ends.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))
local BridgeRules = require(shared:WaitForChild("BridgeRules"))

local Bridges = {}

export type Hooks = {
	fighters: () -> { Model }, -- the fighters still in the round
	ducking: (model: Model) -> boolean, -- it holds its block now (Guarding): ducked under the beam
	swept: (model: Model) -> (), -- the beam caught it: a blow, thrown back along the train
}
export type Service = {
	passing: () -> BridgeRules.Pass?, -- the pass coming or going over now (nil: none)
	stop: () -> (),
}

-- The front and back of the trains along the track (Z).
function Bridges.ends(layout: ArenaLayout.Layout): (number, number)
	local front, back = math.huge, -math.huge
	for _, train in layout.trains do
		front = math.min(front, train.cars[1].front)
		back = math.max(back, train.cars[#train.cars].back)
	end
	return front, back
end

function Bridges.start(layout: ArenaLayout.Layout, hooks: Hooks): Service
	local b = Config.Bridge
	local frontZ, backZ = Bridges.ends(layout)
	local nextAt: number? = nil
	local pass: BridgeRules.Pass? = nil
	local caught: { [Model]: boolean } = {} -- swept this pass

	local function finish()
		pass = nil
		table.clear(caught)
		Workspace:SetAttribute(Names.BridgeAt, nil)
	end

	local ticking = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		if Workspace:GetAttribute(Names.Phase) ~= "Fight" then
			if pass then
				finish()
			end
			nextAt = nil
			return
		end
		if not nextAt then
			local endsAt = PartUtil.number(Workspace, Names.PhaseEndsAt) or now
			nextAt = endsAt - Config.Round.MaxSeconds + b.FirstAfter
		end
		local endsAt = PartUtil.number(Workspace, Names.PhaseEndsAt) or math.huge
		if not pass and now >= (nextAt :: number) and endsAt - now >= b.Warning + b.PassSeconds then
			nextAt = (nextAt :: number) + b.Every
			local coming: BridgeRules.Pass = { arriveAt = now + b.Warning, frontZ = frontZ, speed = Config.Run.Speed }
			pass = coming
			Workspace:SetAttribute(Names.BridgeAt, coming.arriveAt)
		end
		local current = pass
		if not current then
			return
		end
		local beamZ = BridgeRules.beamZ(current, now)
		for _, model in hooks.fighters() do
			local body = if caught[model] then nil else CharacterParts.body(model)
			if body and body.humanoid.Health > 0 and model:GetAttribute(Names.ReturnPhase) == nil then
				local at = body.root.Position
				local tall = if hooks.ducking(model) then b.Duck else b.Stature
				if BridgeRules.under(beamZ, at.Z, b.Depth, b.Slack) and BridgeRules.tooTall(CharacterParts.feetY(body), tall, b.Clearance) then
					caught[model] = true
					hooks.swept(model)
				end
			end
		end
		if BridgeRules.over(current, now, backZ, b.Depth) then
			finish()
		end
	end)

	return {
		passing = function(): BridgeRules.Pass?
			return pass
		end,
		stop = function()
			ticking:Disconnect()
			finish()
		end,
	}
end

return Bridges
