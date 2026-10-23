--!strict
-- Small part helpers shared by the server parts and the client animator. Requires nothing.

local PartUtil = {}

-- A part that is only drawn: anchored, no collisions, no touch events, invisible to raycasts.
function PartUtil.ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- The FileMesh scale that keeps a mesh in step when its part goes from one size to another.
function PartUtil.meshScale(scale: Vector3, fromSize: Vector3, toSize: Vector3): Vector3
	return scale * (toSize / fromSize)
end

return PartUtil
