--!strict
local Field = {}
local function color(value: any): Color3 return Color3.new(value[1], value[2], value[3]) end
function Field.build(workspace: Workspace, assets: Instance, config: any): Instance
	local field = workspace:FindFirstChild(config.FolderName)
	if not field then field = Instance.new("Folder"); field.Name = config.FolderName; field.Parent = workspace end
	local props = Instance.new("Folder")
	props.Name, props.Parent = "EnvironmentV1", field
	for index, placement in config.Props do
		local template = assets:FindFirstChild(placement.AssetId)
		assert(template and template:IsA("Model"), "missing field asset: " .. placement.AssetId)
		local model = (template :: Model):Clone()
		model.Name = placement.AssetId .. "_" .. tostring(index)
		for _, object in model:GetDescendants() do
			if object:IsA("BasePart") then
				object.Anchored = true
				local solid = object.Name == "Trunk" or object.Name == "Rock" or object.Name == "Post" or object.Name == "Stump"
				object.CanCollide, object.CanQuery, object.CanTouch = solid, solid, false
			end
		end
		model:PivotTo(CFrame.new(placement.X, config.GroundHeight, placement.Z)*CFrame.Angles(0, math.rad(placement.Yaw), 0))
		model.Parent = props
		if string.find(placement.AssetId, "Sign", 1, true) then
			local board = model:FindFirstChild("Signboard", true)
			if board and board:IsA("BasePart") then
				local gui = Instance.new("SurfaceGui")
				gui.Name, gui.Face, gui.CanvasSize, gui.Parent = "GreenwoodSign", Enum.NormalId.Front, Vector2.new(480, 160), board
				local text = Instance.new("TextLabel")
				text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
				text.Font, text.TextSize, text.TextColor3 = Enum.Font.GothamBold, 30, Color3.fromRGB(76, 48, 26)
				text.Text, text.Parent = "GREENWOOD\nHornboar 사냥터 →", gui
			end
		end
	end
	local lighting = game:GetService("Lighting")
	lighting.ClockTime, lighting.Brightness = config.Lighting.ClockTime, config.Lighting.Brightness
	lighting.Ambient, lighting.OutdoorAmbient = color(config.Lighting.Ambient), color(config.Lighting.OutdoorAmbient)
	return field
end
return Field
