--!strict
-- The way back onto the trains for a fighter who fell with a ticket left (decision 11; the round keeps the tickets and
-- sends the fighter here: send). The fall (or the home-run flight) plays on for `after` seconds; then the fighter goes up
-- to the stands, the gondola the balloons hold (hooks.stands), and waits there Config.Comeback.WaitSeconds. Then it is put
-- DropHeight over the clearest spawn spot (farthest from every fighter on the trains: ArenaLayout.clearest) and comes
-- down under a parachute at DropSpeed: a LinearVelocity on its root that its owner's physics runs (a player's client or
-- this server for a bot), with no walking or jumping meanwhile, and its shadow on the roof where it will land
-- (Names.LandingMark, drawn by GroundMarks). Once its feet are on the spot's top (or a moment after they should be), the
-- pull goes and back() is called. Every screen reads the way back from the fighter's Names.ReturnPhase ("Up": falling,
-- then in the stands; "Down": under the parachute, drawn by ComebackShow) and Names.ReturnAt (when the drop starts).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local PartUtil = require(shared:WaitForChild("PartUtil"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local ArenaLayout = require(shared:WaitForChild("ArenaLayout"))

local Comebacks = {}

export type Hooks = {
	fighters: () -> { Model }, -- the fighters on the trains (not those on their way back)
	stands: () -> CFrame, -- a spot of its own in the stands
	isPlayer: (model: Model) -> boolean, -- a player's character (held still under the parachute; a bot is not walked)
}
export type Service = {
	-- Sends `model` back: up to the stands after `after` seconds, down by parachute after the wait, back() once landed.
	-- Returns a function that calls the way back off (the model stays wherever it is; back() is never called).
	send: (model: Model, after: number, back: () -> ()) -> () -> (),
	stop: () -> (),
}

-- A drop under way: the spot's top it lands on, when it should be down by (server time), the pull (and the attachment
-- made for it, when the root had none) and the shadow.
type Drop = { body: CharacterParts.Body, top: number, landBy: number, pull: LinearVelocity, made: Attachment?, mark: BasePart, back: () -> () }

-- The root stands this high over the top under the feet (as the round places fighters on their spawn spots).
local STAND_HEIGHT = 3.5

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function clearAttributes(model: Model)
	model:SetAttribute(Names.ReturnPhase, nil)
	model:SetAttribute(Names.ReturnAt, nil)
end

-- spots: the arena's spawn spots (the safe places to land on); folder: where the landing shadows go.
function Comebacks.start(spots: { ArenaLayout.Spot }, folder: Instance, hooks: Hooks): Service
	local c = Config.Comeback
	local drops: { [Model]: Drop } = {}

	-- The pull and the shadow go; a player walks and jumps again.
	local function release(model: Model, drop: Drop)
		drops[model] = nil
		drop.pull:Destroy()
		if drop.made then
			drop.made:Destroy()
		end
		drop.mark:Destroy()
		if hooks.isPlayer(model) and drop.body.humanoid.Parent then
			drop.body.humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
			drop.body.humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
		end
	end

	-- Over the clearest spot, a parachute pull on the root and the shadow where it lands.
	local function drop(model: Model, back: () -> ())
		local body = CharacterParts.body(model)
		if not body then
			clearAttributes(model)
			back() -- nothing to bring down (the round puts out a fighter that died)
			return
		end
		local others = {}
		for _, other in hooks.fighters() do
			if other ~= model then
				local at = other:GetPivot().Position
				table.insert(others, { x = at.X, z = at.Z })
			end
		end
		local shuffled = table.clone(spots)
		for i = #shuffled, 2, -1 do
			local j = math.random(i)
			shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
		end
		local spot = ArenaLayout.clearest(shuffled, others)
		if not spot then
			clearAttributes(model)
			back()
			return
		end
		local at = Vector3.new(spot.x, spot.y + STAND_HEIGHT + c.DropHeight, spot.z)
		-- Facing across the track, toward the middle (as at the round's start).
		local toward = if spot.x > 0 then Vector3.new(-1, 0, 0) elseif spot.x < 0 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, -1)
		model:PivotTo(CFrame.lookAt(at, at + toward))
		body.root.AssemblyLinearVelocity = Vector3.zero
		body.root.AssemblyAngularVelocity = Vector3.zero
		if hooks.isPlayer(model) then
			body.humanoid.WalkSpeed = 0
			body.humanoid.JumpHeight = 0
		end
		local found = body.root:FindFirstChild("RootAttachment")
		local made: Attachment? = nil
		if not (found and found:IsA("Attachment")) then
			local extra = Instance.new("Attachment")
			extra.Name = "ComebackAttachment"
			extra.Parent = body.root
			made = extra
		end
		local pull = Instance.new("LinearVelocity")
		pull.Name = "Parachute"
		pull.Attachment0 = if made then made else found :: Attachment
		pull.RelativeTo = Enum.ActuatorRelativeTo.World
		pull.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		pull.VectorVelocity = Vector3.new(0, -c.DropSpeed, 0)
		pull.MaxForce = body.root.AssemblyMass * Workspace.Gravity * c.PullWeights
		pull.Parent = body.root
		local seconds = c.DropHeight / c.DropSpeed
		-- Where it lands: an invisible flat part every client draws a shadow on (GroundMarks, as for a crate).
		local mark = PartUtil.decor(Names.LandingMark, Vector3.new(4.5, 0.05, 4.5), CFrame.new(spot.x, spot.y + 0.05, spot.z), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		mark.Transparency = 1
		mark:SetAttribute(Names.MarkEndsAt, now() + seconds)
		mark:SetAttribute(Names.MarkSeconds, seconds)
		mark.Parent = folder
		model:SetAttribute(Names.ReturnPhase, "Down")
		model:SetAttribute(Names.ReturnAt, nil)
		drops[model] = { body = body, top = spot.y, landBy = now() + seconds + c.LandSlack, pull = pull, made = made, mark = mark, back = back }
	end

	local ticking = RunService.Heartbeat:Connect(function()
		local t = now()
		for model, d in table.clone(drops) do
			if not model.Parent or not d.body.root.Parent then
				release(model, d)
				continue
			end
			if CharacterParts.feetY(d.body) <= d.top + c.LandedWithin or t >= d.landBy then
				release(model, d)
				clearAttributes(model)
				d.back()
			end
		end
	end)

	return {
		send = function(model: Model, after: number, back: () -> ()): () -> ()
			local live = true
			local dropAt = now() + after + c.WaitSeconds
			model:SetAttribute(Names.ReturnPhase, "Up")
			model:SetAttribute(Names.ReturnAt, dropAt)
			task.delay(after, function()
				if live and model.Parent then
					local body = CharacterParts.body(model)
					model:PivotTo(hooks.stands())
					if body then
						body.root.AssemblyLinearVelocity = Vector3.zero
					end
				end
			end)
			task.delay(after + c.WaitSeconds, function()
				if live and model.Parent then
					drop(model, back)
				end
			end)
			return function()
				live = false
				local d = drops[model]
				if d then
					release(model, d)
				end
				if model.Parent then
					clearAttributes(model)
				end
			end
		end,
		stop = function()
			ticking:Disconnect()
			for model, d in table.clone(drops) do
				release(model, d)
			end
		end,
	}
end

return Comebacks
