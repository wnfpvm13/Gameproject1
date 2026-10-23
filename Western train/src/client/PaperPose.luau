--!strict
-- Draws a cowboy as thin as a sheet of paper (the bridge splat gag): every visible part of the character is made thin
-- along its own front-to-back axis by a factor (PaperPath.thickness), an accessory's FileMesh through its scale, and
-- put back to exactly its own size at 1. Drawn on every client for every cowboy; local only (the server never sees
-- these sizes). The root part is left alone (it is invisible, and the Humanoid stands on it); the thinned parts do not
-- collide meanwhile, so the gag never pushes the character around. Call set() for each cowboy every frame, then
-- flush() once: a character nobody drew this frame (its train went, or it is nobody's cowboy any more) is put back.
local PaperPose = {}

type Saved = { size: Vector3, collides: boolean, mesh: SpecialMesh?, scale: Vector3 }

-- The characters drawn thin now, with each part's own size, collision (and FileMesh scale) to go back to.
local saved: { [Model]: { [BasePart]: Saved } } = {}
local drawn: { [Model]: boolean } = {} -- the characters set() this frame

local function restore(parts: { [BasePart]: Saved })
	for part, own in parts do
		part.Size = own.size
		part.CanCollide = own.collides
		if own.mesh then
			own.mesh.Scale = own.scale
		end
	end
end

-- Remembers the character's parts not remembered yet (an accessory may arrive while the cowboy is thin).
local function remember(character: Model, parts: { [BasePart]: Saved })
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and not parts[item] then
			local mesh = item:FindFirstChildOfClass("SpecialMesh")
			local fileMesh = if mesh and mesh.MeshType == Enum.MeshType.FileMesh then mesh else nil
			parts[item] = { size = item.Size, collides = item.CanCollide, mesh = fileMesh, scale = if fileMesh then fileMesh.Scale else Vector3.one }
		end
	end
end

-- factor: the thickness as a share of the cowboy's own (1 = as they are).
function PaperPose.set(character: Model?, factor: number)
	if not character then
		return
	end
	drawn[character] = true
	local parts = saved[character]
	if factor == 1 then
		if parts then
			restore(parts)
			saved[character] = nil
		end
		return
	end
	if not parts then
		parts = {}
		saved[character] = parts
	end
	remember(character, parts)
	for part, own in parts do
		part.Size = Vector3.new(own.size.X, own.size.Y, own.size.Z * factor)
		part.CanCollide = false
		if own.mesh then
			own.mesh.Scale = Vector3.new(own.scale.X, own.scale.Y, own.scale.Z * factor)
		end
	end
end

-- After this frame's set() calls: puts back every character that was not drawn this frame.
function PaperPose.flush()
	for character, parts in saved do
		if not drawn[character] then
			restore(parts)
			saved[character] = nil
		end
	end
	table.clear(drawn)
end

return PaperPose
