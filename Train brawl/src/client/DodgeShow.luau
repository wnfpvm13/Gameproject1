--!strict
-- Follows every fighter's dodge rolls on this screen (decision 22): a roll the server published (Names.DodgeAt with its
-- Names.DodgeDir) is handed to `draw` once - the tucked turn, the swoosh and the dust, wired in init (SwingPose.roll,
-- SoundBank, LaunchShow.dust) - unless skip() says it was drawn already (the player's own roll, drawn when pressed). A
-- roll already over when first seen (joining late) is not drawn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))

local DodgeShow = {}
DodgeShow.__index = DodgeShow

-- draw: draws a roll by a model that started at server time `at` along the flat `direction`.
type Draw = (model: Model, at: number, direction: Vector3) -> ()
-- seen: the roll (its DodgeAt) last handled on each fighter.
type Fields = { draw: Draw, seen: { [Model]: number } }
export type Show = typeof(setmetatable({} :: Fields, DodgeShow))

function DodgeShow.new(draw: Draw): Show
	local fields: Fields = { draw = draw, seen = setmetatable({}, { __mode = "k" }) :: any }
	return setmetatable(fields, DodgeShow)
end

-- Every frame, for the fighters in the round. skip(model, at): that roll was drawn already.
function DodgeShow.update(self: Show, models: { Model }, skip: (model: Model, at: number) -> boolean)
	local now = Workspace:GetServerTimeNow()
	for _, model in models do
		local at = model:GetAttribute(Names.DodgeAt)
		if typeof(at) == "number" and self.seen[model] ~= at then
			self.seen[model] = at
			if now - at < Config.Dodge.Seconds and not skip(model, at) then
				local dir = model:GetAttribute(Names.DodgeDir)
				self.draw(model, at, if typeof(dir) == "Vector3" then dir else -model:GetPivot().LookVector)
			end
		end
	end
end

return DodgeShow
