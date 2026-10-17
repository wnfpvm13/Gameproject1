--!strict
-- Fixed panel-show camera: while a round runs, everyone looks at the chair row from over the pool,
-- so every face and forbidden word is on one screen.
local ShowCamera = {}

local DEFAULT_FOV = 70
local active = false

local function point(): BasePart?
	local map = workspace:FindFirstChild("PoolMap")
	return map and map:FindFirstChild("ShowCamera") :: BasePart?
end

function ShowCamera.set(on: boolean)
	local camera = workspace.CurrentCamera
	local marker = point()
	if on and marker then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = marker.CFrame
		camera.FieldOfView = marker:GetAttribute("FieldOfView") or DEFAULT_FOV
	elseif active then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = DEFAULT_FOV
	end
	active = on and marker ~= nil
end

function ShowCamera.reapply()
	if active then
		ShowCamera.set(true)
	end
end

return ShowCamera
