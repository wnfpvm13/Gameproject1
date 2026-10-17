--!strict
-- Fixed panel-show camera: while a round runs, everyone looks at the chair row from over the pool,
-- so every face and forbidden word is on one screen. The vertical FOV is widened on narrow screens
-- (tablets 4:3) so all ten chairs still fit horizontally.
local ShowCamera = {}

local DEFAULT_FOV = 70
local MIN_FOV, MAX_FOV = 45, 90
local active = false
local viewportConnection: RBXScriptConnection? = nil

local function point(): BasePart?
	local map = workspace:FindFirstChild("PoolMap")
	return map and map:FindFirstChild("ShowCamera") :: BasePart?
end

local function fovFor(marker: BasePart, camera: Camera): number
	local base = marker:GetAttribute("FieldOfView") or DEFAULT_FOV
	local halfWidth = marker:GetAttribute("HalfWidth")
	local distance = marker:GetAttribute("Distance")
	if not (halfWidth and distance) then
		return base
	end
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local needed = 2 * math.deg(math.atan((halfWidth / distance) / aspect))
	return math.clamp(math.max(base, needed), MIN_FOV, MAX_FOV)
end

function ShowCamera.set(on: boolean)
	local camera = workspace.CurrentCamera
	local marker = point()
	if on and marker then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = marker.CFrame
		camera.FieldOfView = fovFor(marker, camera)
		if not viewportConnection then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if active then
					camera.FieldOfView = fovFor(marker, camera)
				end
			end)
		end
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
