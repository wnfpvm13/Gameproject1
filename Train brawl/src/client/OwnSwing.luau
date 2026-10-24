--!strict
-- The player's own swing on this client. When the control is pressed and a swing may start (fighting, still in the
-- round, not stunned by a hit, the bat ready), it is drawn and heard at once and its hits are shown at once (the
-- same cone the server uses, without the network slack: SwingTargets), and the server is told with where the
-- character aims (it turns with the camera under the mouse lock); the server judges it for real (BatService). The drawing and the hit effects come in as hooks (SwingPose, HitFeedback via init).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))
local SwingTargets = require(shared:WaitForChild("SwingTargets"))

local OwnSwing = {}
OwnSwing.__index = OwnSwing

-- A swing the server reports this close to the player's own last one is that one (already drawn).
local SAME_SWING_SECONDS = 0.5

export type Hooks = {
	fighters: () -> { Model }, -- the characters still in the round
	stunned: () -> boolean, -- the player's character is flinching or flying from a hit
	draw: (model: Model, at: number) -> (), -- draw and sound a swing that started at server time `at`
	predict: (victim: Model) -> (), -- show a hit the swing is about to land
}

type Fields = { remote: RemoteEvent, hooks: Hooks, last: number }
export type Swing = typeof(setmetatable({} :: Fields, OwnSwing))

function OwnSwing.new(remote: RemoteEvent, hooks: Hooks): Swing
	local fields: Fields = { remote = remote, hooks = hooks, last = -math.huge }
	return setmetatable(fields, OwnSwing)
end

-- The control was pressed; `model` is the player's character (nil = none).
function OwnSwing.press(self: Swing, model: Model?)
	local body = CharacterParts.body(model)
	local now = Workspace:GetServerTimeNow()
	if not body or body.model:GetAttribute(Names.Alive) ~= true or Workspace:GetAttribute(Names.Phase) ~= "Fight" then
		return
	end
	if self.hooks.stunned() or now - self.last < Config.Bat.Cooldown then
		return
	end
	self.last = now
	self.hooks.draw(body.model, now)
	-- The server judges along this aim (taken now), so the hits shown at once use it too.
	local aim = body.root.CFrame.LookVector
	self.remote:FireServer(aim)
	task.delay(Config.Bat.HitAt, function()
		local me = CharacterParts.body(body.model)
		-- Hit while swinging: the server judges from where the knock took the player, so show no hits of its own.
		if me and not self.hooks.stunned() then
			for _, victim in SwingTargets.find(me, self.hooks.fighters(), Config.Bat.Reach, aim) do
				self.hooks.predict(victim.model)
			end
		end
	end)
end

-- Whether a swing of the player's character that the server says started at `at` is the one drawn when pressed.
function OwnSwing.drawn(self: Swing, at: number): boolean
	return math.abs(at - self.last) < SAME_SWING_SECONDS
end

return OwnSwing
