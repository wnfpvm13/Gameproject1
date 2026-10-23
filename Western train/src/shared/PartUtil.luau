--!strict
-- Small instance helpers shared by the server parts and the client parts. Requires nothing.

local PartUtil = {}

-- A part that is only drawn: anchored, no collisions, no touch events, invisible to raycasts.
function PartUtil.ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- A new drawn-only block (see ghost) with smooth surfaces.
function PartUtil.ghostBlock(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	PartUtil.ghost(part)
	part.Parent = parent
	return part
end

-- The FileMesh scale that keeps a mesh in step when its part goes from one size to another.
function PartUtil.meshScale(scale: Vector3, fromSize: Vector3, toSize: Vector3): Vector3
	return scale * (toSize / fromSize)
end

-- The folder of this name under parent, made if it is not there.
function PartUtil.folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

-- The avatar inside a locomotive: its child model with a Humanoid.
function PartUtil.avatarOf(locomotive: Model): Model?
	for _, child in locomotive:GetChildren() do
		if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
			return child
		end
	end
	return nil
end

-- A number attribute, or nil when it is missing or not a number.
function PartUtil.number(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

return PartUtil
