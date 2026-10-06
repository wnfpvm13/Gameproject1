--!strict
-- Faithful Blender topology, shared once per client. No sphere/Part prototype fallback.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Packet = require(ReplicatedStorage:WaitForChild("Shared").Assets.HornboarMeshData)
local Data = HttpService:JSONDecode(Packet.Json)
local Mesh = {}
local cache: any = nil
local failure: string? = nil
local building = false
local function vector(p: any): Vector3 return Vector3.new(p[1], p[2], p[3]) end
local function binding(object: Instance): string?
	local value = object:FindFirstChild("Binding")
	return if value and value:IsA("StringValue") then value.Value else nil
end
local function templates(): any
	while building do task.wait() end
	if cache then return cache end
	if failure then error(failure) end
	building = true
	local resources: { any } = {}
	local ok, result = pcall(function()
		local entries = {}
		for _, group in Data.Groups do
			local editable = AssetService:CreateEditableMesh()
			assert(editable, "EditableMesh memory budget exhausted")
			table.insert(resources, editable)
			local vertices, colors = {}, {}
			for index, p in group.Vertices do vertices[index] = editable:AddVertex(vector(p)) end
			for index, c in Data.Palette do colors[index] = editable:AddColor(Color3.new(c[1], c[2], c[3]), 1) end
			for _, face in group.Faces do
				local a, b, c = vector(group.Vertices[face[1]]), vector(group.Vertices[face[2]]), vector(group.Vertices[face[3]])
				local normal = editable:AddNormal((b-a):Cross(c-a).Unit)
				local id = editable:AddTriangle(vertices[face[1]], vertices[face[2]], vertices[face[3]])
				editable:SetFaceNormals(id, { normal, normal, normal })
				editable:SetFaceColors(id, { colors[face[4]], colors[face[4]], colors[face[4]] })
			end
			local part = AssetService:CreateMeshPartAsync(Content.fromObject(editable), { CollisionFidelity = Enum.CollisionFidelity.Box })
			table.insert(resources, part)
			part.Name, part.Size, part.Color, part.Material = "Mesh_"..group.Bone.."_"..group.Binding, vector(group.Size), Color3.new(1,1,1), Enum.Material.SmoothPlastic
			part.CanCollide, part.CanTouch, part.CanQuery, part.Anchored, part.Massless = false, false, false, false, true
			table.insert(entries, { Part = part, Editable = editable, Group = group })
		end
		return entries
	end)
	building = false
	if not ok then
		for _, resource in resources do resource:Destroy() end
		failure = tostring(result); error(failure)
	end
	cache = result
	return cache
end
function Mesh.attach(model: Model): any
	local bones, existing = {}, {}
	for _, object in model:GetDescendants() do
		local tag = binding(object)
		if object:IsA("BasePart") and tag == "Root" then bones.Root = object
		elseif object:IsA("Motor6D") and tag and string.sub(tag,1,6) == "Joint:" then bones[string.sub(tag,7)] = object.Part1
		elseif object:IsA("MeshPart") and tag and (tag == "Visual" or tag == "HornIntact" or tag == "HornBroken") then
			table.insert(existing, { Part = object, Binding = tag })
		end
	end
	-- An owned imported/rigged asset can replace the data path using the same binder contract.
	if #existing > 0 then return existing end
	local entries = templates()
	if not model.Parent then return {} end
	assert(bones.Root, "missing mesh root")
	local folder = Instance.new("Folder"); folder.Name, folder.Parent = "LocalBlenderMesh", model
	local result = {}
	for _, entry in entries do
		local group = entry.Group
		assert(bones[group.Bone], "missing mesh bone "..group.Bone)
		local part = entry.Part:Clone()
		part.CFrame, part.Parent = bones.Root.CFrame*CFrame.new(vector(group.Center)), folder
		local tag = Instance.new("StringValue"); tag.Name, tag.Value, tag.Parent = "Binding", group.Binding, part
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = bones[group.Bone], part, part
		table.insert(result, { Part = part, Binding = group.Binding })
	end
	model:SetAttribute("LocalMeshReady", true)
	return result
end
return Mesh
