--!strict
-- Constructed only by the Studio + explicit Testing flag gate in HuntingRuntime.
local Debug = {}
Debug.__index = Debug
local function vector(p: any): Vector3 return Vector3.new(p.X, p.Y, p.Z) end
function Debug.new(parent: Instance, style: any): any
	local folder = Instance.new("Folder"); folder.Name, folder.Parent = "CombatHitboxQA", parent
	return setmetatable({ Folder = folder, Actors = {}, Style = style }, Debug)
end
function Debug.Render(self: any, ctx: any, action: any, at: number)
	local entry = self.Actors[ctx.ActorId]
	if not action or action.AttackType == "Dodge" or at > action.EndAt then
		if entry then entry:Destroy(); self.Actors[ctx.ActorId] = nil end
		return
	end
	if not entry then
		entry = Instance.new("Folder"); entry.Name, entry.Parent = tostring(ctx.ActorId), self.Folder
		self.Actors[ctx.ActorId] = entry
		for index = 1, self.Style.DebugSegments+2 do
			local part = Instance.new("Part")
			part.Name, part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = tostring(index), true, false, false, false
			part.Material, part.Parent = Enum.Material.Neon, entry
		end
	end
	local root, facing = ctx.Root.Position, vector(action.Facing)
	local origin = root-Vector3.new(0, 2.5, 0)
	local frame = CFrame.lookAt(origin, origin+facing)
	local values = if action.AttackType == "Heavy" then self.Style.DebugHeavyColor else self.Style.DebugBasicColor
	local inWindow = at >= action.WindowStartAt and at <= action.WindowEndAt
	local function line(index: number, a: Vector3, b: Vector3)
		local part = entry:FindFirstChild(tostring(index)) :: Part
		part.Size, part.CFrame = Vector3.new(0.10, 0.07, (b-a).Magnitude), CFrame.lookAt((a+b)/2, b)
		part.Color, part.Transparency = Color3.new(values[1], values[2], values[3]), if inWindow then 0.10 else 0.75
	end
	local previous = origin
	for index = 0, self.Style.DebugSegments do
		local angle = math.rad(-action.ArcDegrees/2+action.ArcDegrees*index/self.Style.DebugSegments)
		local point = frame:PointToWorldSpace(Vector3.new(math.sin(angle)*action.Reach, 0, -math.cos(angle)*action.Reach))
		if index == 0 then line(1, origin, point) else line(index+1, previous, point) end
		previous = point
	end
	line(self.Style.DebugSegments+2, previous, origin)
end
function Debug.Remove(self: any, actorId: number)
	local entry = self.Actors[actorId]; if entry then entry:Destroy(); self.Actors[actorId] = nil end
end
return Debug
