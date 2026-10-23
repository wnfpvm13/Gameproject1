--!strict
-- A short puff of steam out of both sides of a locomotive's chimney cap ("푸쉭") when it folds flat or springs back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))

local SteamPuff = {}
SteamPuff.__index = SteamPuff

type Side = { attachment: Attachment, emitter: ParticleEmitter, turn: CFrame }
type Fields = { cap: BasePart, sides: { Side } }
export type Puff = typeof(setmetatable({} :: Fields, SteamPuff))

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local function emitter(parent: Attachment): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE_TEXTURE
	e.Enabled = false
	e.EmissionDirection = Enum.NormalId.Top
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(9, 15)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Drag = 5
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(245, 245, 245))
	e.Parent = parent
	return e
end

-- nil when the locomotive has no chimney cap.
function SteamPuff.new(locomotive: Model): Puff?
	local cap = locomotive:FindFirstChild(Names.ChimneyCap, true)
	if not (cap and cap:IsA("BasePart")) then
		return nil
	end
	-- The cap is an upright cylinder: its own Y axis points sideways, so attachments on +Y and -Y (the second one
	-- turned half round) puff out of the left and right sides.
	local sides = {}
	for _, angle in { 0, math.pi } do
		local attachment = Instance.new("Attachment")
		attachment.Name = "SteamPuff"
		attachment.Parent = cap
		table.insert(sides, { attachment = attachment, emitter = emitter(attachment), turn = CFrame.Angles(angle, 0, 0) })
	end
	return setmetatable({ cap = cap, sides = sides } :: Fields, SteamPuff)
end

-- Puffs from the cap's edge at its current size (the animator keeps resizing the cap). A cylinder is drawn with the
-- smaller of its Y and Z sizes as the diameter.
function SteamPuff.burst(self: Puff)
	local radius = math.min(self.cap.Size.Y, self.cap.Size.Z) / 2
	for _, side in self.sides do
		side.attachment.CFrame = side.turn * CFrame.new(0, radius, 0)
		side.emitter:Emit(Config.Squash.SteamPuffCount)
	end
end

function SteamPuff.destroy(self: Puff)
	for _, side in self.sides do
		side.attachment:Destroy()
	end
	table.clear(self.sides)
end

return SteamPuff
