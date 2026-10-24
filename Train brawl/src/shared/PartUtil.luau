--!strict
-- Small instance helpers shared by the server parts and the client parts. Requires nothing.
-- (ghost, ghostBlock and folder are taken over from Western train's PartUtil.)

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

-- A new anchored block players stand on or bump into (it collides and raycasts see it).
function PartUtil.solidBlock(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local part = PartUtil.ghostBlock(name, size, color, material, parent)
	part.CanCollide = true
	part.CanQuery = true
	return part
end

-- The child folder with this name (made when missing).
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

-- A number attribute, or nil.
function PartUtil.number(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

return PartUtil
