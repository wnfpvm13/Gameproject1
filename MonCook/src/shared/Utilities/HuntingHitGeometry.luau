--!strict
-- Exact horizontal sector / upright oriented box contact; broadphase is only a candidate search.
local Math = require(script.Parent.HuntingMath)
type Point = Math.Point
type Flat = { X: number, F: number }
local Geometry = {}
local epsilon = 0.000001
local function clip(polygon: { Flat }, a: number, b: number): { Flat }
	local result = {}
	if #polygon == 0 then return result end
	local previous = polygon[#polygon]
	local previousValue = a*previous.X+b*previous.F
	for _, current in polygon do
		local value = a*current.X+b*current.F
		if (value >= 0) ~= (previousValue >= 0) then
			local t = previousValue/(previousValue-value)
			table.insert(result, { X = previous.X+(current.X-previous.X)*t, F = previous.F+(current.F-previous.F)*t })
		end
		if value >= 0 then table.insert(result, current) end
		previous, previousValue = current, value
	end
	return result
end
function Geometry.contact(origin: Point, facing: Point, center: Point, boxFacing: Point, size: Point,
	reach: number, arc: number, vertical: number): Point?
	if math.abs(origin.Y-center.Y) > vertical+size.Y/2 then return nil end
	local polygon: { Flat } = {}
	for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local p = Math.offset(center, boxFacing, { X = corner[1]*size.X/2, Y = 0, Z = corner[2]*size.Z/2 })
		local dx, dz = p.X-origin.X, p.Z-origin.Z
		table.insert(polygon, { X = -facing.Z*dx+facing.X*dz, F = facing.X*dx+facing.Z*dz })
	end
	local slope = math.tan(math.rad(arc/2))
	polygon = clip(clip(clip(polygon, 0, 1), -1, slope), 1, slope)
	if #polygon == 0 then return nil end
	-- The closest point of a convex polygon is on an edge, or the origin is inside it.
	local best: Flat = { X = 0, F = 0 }
	local centerX, centerZ = origin.X-center.X, origin.Z-center.Z
	local inside = math.abs(-boxFacing.Z*centerX+boxFacing.X*centerZ) <= size.X/2
		and math.abs(boxFacing.X*centerX+boxFacing.Z*centerZ) <= size.Z/2
	local distance = math.huge
	for i, p in polygon do
		local q = polygon[i%#polygon+1]
		local dx, df = q.X-p.X, q.F-p.F
		local denominator = dx*dx+df*df
		local t = if denominator > epsilon then math.clamp(-(p.X*dx+p.F*df)/denominator, 0, 1) else 0
		local candidate = { X = p.X+dx*t, F = p.F+df*t }
		local d = candidate.X^2+candidate.F^2
		if d < distance then best, distance = candidate, d end
	end
	if inside then best, distance = { X = 0, F = 0 }, 0 end
	if distance > reach*reach then return nil end
	return { X = origin.X-facing.Z*best.X+facing.X*best.F,
		Y = math.clamp(origin.Y, center.Y-size.Y/2, center.Y+size.Y/2),
		Z = origin.Z+facing.X*best.X+facing.Z*best.F }
end
function Geometry.prefer(contacts: { any }): { any }
	local groups: { [string]: any } = {}
	local result: { any } = {}
	for _, contact in contacts do
		local current = groups[contact.EncounterId]
		if not current then groups[contact.EncounterId] = contact; table.insert(result, contact)
		elseif contact.Horn and not current.Horn then
			current.Horn, current.Position = true, Math.copy(contact.Position)
		end
	end
	return result
end
function Geometry.aimPoint(origin: Point, facing: Point, monster: any, definition: any, reach: number, arc: number, vertical: number): Point?
	if not Math.point(monster.Position) or not Math.point(monster.Facing)
		or (Math.distance(origin, monster.Position) > epsilon and Math.dot(facing, Math.direction(origin,monster.Position)) < 0) then return nil end
	local best: Point? = nil
	local distance = math.huge
	for _, key in { "BodyHitbox", "HornHitbox" } do
		if key == "HornHitbox" and monster.HornBroken then continue end
		local box = definition[key]
		local hit = Geometry.contact(origin,facing,Math.offset(monster.Position,monster.Facing,box.Offset),monster.Facing,box.Size,reach,arc,vertical)
		if hit and Math.distance(origin,hit) < distance then best, distance = hit, Math.distance(origin,hit) end
	end
	return best
end
function Geometry.debugEnabled(studio: boolean, requested: boolean): boolean return studio and requested end
return table.freeze(Geometry)
