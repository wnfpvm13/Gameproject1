-- Lists faces of visible, axis-aligned block parts under workspace.PoolHall that lie in the same plane, face the same
-- way and overlap: two such faces fight over the same pixels and flicker as the camera moves (z-fighting). Found the
-- deck and the pool walls sharing their inner faces along the waterline (owner report 2026-10-27). Read only; run in
-- Studio's Edit datamodel after tools/build_pool_hall.luau. Bottom faces resting on something (Y-) are listed too but
-- are usually hidden.
local EPS = 0.002 -- studs
local ROOT = workspace.PoolHall

local function aligned(cframe: CFrame): boolean
	for _, axis in { cframe.RightVector, cframe.UpVector, cframe.LookVector } do
		-- (only truly axis-aligned parts: the face boxes below are exact only for them; 1e-6 is about 0.08 degrees)
		if math.max(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z)) < 1 - 1e-6 then
			return false
		end
	end
	return true
end

type Face = { plane: number, a0: number, a1: number, b0: number, b1: number, part: BasePart }
local faces: { [string]: { Face } } = {}
for _, p in ROOT:GetDescendants() do
	if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.Transparency < 1 and aligned(p.CFrame) then
		local half = (p.CFrame - p.Position):VectorToWorldSpace(p.Size / 2)
		half = Vector3.new(math.abs(half.X), math.abs(half.Y), math.abs(half.Z))
		local low, high = p.Position - half, p.Position + half
		local spans = { { low.X, high.X }, { low.Y, high.Y }, { low.Z, high.Z } }
		for axis = 1, 3 do
			local other1, other2 = axis % 3 + 1, (axis + 1) % 3 + 1
			for _, side in { 1, 2 } do
				local key = ({ "X", "Y", "Z" })[axis] .. (if side == 2 then "+" else "-")
				faces[key] = faces[key] or {}
				table.insert(faces[key], {
					plane = spans[axis][side],
					a0 = spans[other1][1],
					a1 = spans[other1][2],
					b0 = spans[other2][1],
					b1 = spans[other2][2],
					part = p,
				})
			end
		end
	end
end

local found = {}
for key, list in faces do
	table.sort(list, function(x, y)
		return x.plane < y.plane
	end)
	for i, f in list do
		local j = i + 1
		while j <= #list and list[j].plane - f.plane < EPS do
			local g = list[j]
			local overlapA = math.min(f.a1, g.a1) - math.max(f.a0, g.a0)
			local overlapB = math.min(f.b1, g.b1) - math.max(f.b0, g.b0)
			if overlapA > EPS and overlapB > EPS then
				local name1 = f.part:GetFullName():gsub("^Workspace%.PoolHall%.", "")
				local name2 = g.part:GetFullName():gsub("^Workspace%.PoolHall%.", "")
				table.insert(found, string.format("%s face at %.2f: %s / %s (%.1f x %.1f studs)", key, f.plane, name1, name2, overlapA, overlapB))
			end
			j += 1
		end
	end
	task.wait()
end
table.sort(found)
print(string.format("coplanar overlapping faces: %d", #found))
for _, line in found do
	print(line)
end
return #found
