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

-- A drawn-only piece of dressing (see ghost) at `cframe`, casting no shadow (the many small pieces would only cost
-- shadow-map time). shape: Block when nil, Cylinder (round about its own X) or Ball.
function PartUtil.decor(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = false
	PartUtil.ghost(part)
	part.Parent = parent
	return part
end

-- A drawn-only wedge (see decor): its slope runs from its top back edge (+Z) down to its bottom front edge (-Z).
function PartUtil.decorWedge(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.CastShadow = false
	PartUtil.ghost(part)
	part.Parent = parent
	return part
end

-- A drawn-only bar from `a` to `b`, `thickness` square (ropes, braces, rods). Not for straight up or down.
function PartUtil.decorBar(name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material, parent: Instance): Part
	return PartUtil.decor(name, Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material, parent)
end

-- A see-through plate at `cframe` with `text` painted on its `face` (lettering on a car's side): see decor and letter.
function PartUtil.letterPlate(parent: Instance, size: Vector3, cframe: CFrame, face: Enum.NormalId, text: string, color: Color3): Part
	local plate = PartUtil.decor("Lettering", size, cframe, color, Enum.Material.SmoothPlastic, parent)
	plate.Transparency = 1
	PartUtil.letter(plate, face, text, color)
	return plate
end

-- Paints `text` on one face of `part` (lettering on a car's side), as large as the face allows.
function PartUtil.letter(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Lettering"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Antique
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = part
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
