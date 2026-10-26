--!strict
-- A lit fuse's fizz: small hot sparks spitting out of a dynamite stick's fuse and falling, on the stick in a hand
-- (WeaponGear) and the one thrown (Dynamite). Particles instead of Roblox's old Sparkles effect (its yellow stars read
-- as a 2008 placeholder). Shared because both server parts make it.

local FuseSparks = {}

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

-- Adds the fizz to `parent` (a part or an attachment) and returns it.
function FuseSparks.add(parent: Instance): ParticleEmitter
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "FuseSparks"
	sparks.Texture = FIRE_TEXTURE
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 236, 160), Color3.fromRGB(255, 120, 40))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.04) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) })
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Rate = 45
	sparks.Speed = NumberRange.new(3, 7)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -25, 0)
	sparks.Drag = 2
	sparks.Parent = parent
	return sparks
end

return FuseSparks
