--!strict
-- The show camera (docs/DESIGN_V3.md §10, owner 2026-10-22): seated participants watch the chair row from the front,
-- so every other participant (faces and word bubbles) is on screen with the pool behind, including anyone flying off.
-- The FOV makes the row's HalfWidth fit the screen width at the current aspect ratio (the game is landscape only).
-- Rig numbers live on PoolHall.ShowCamera (attributes HalfWidth, MinFov, MaxFov). Everyone else keeps the normal camera.
local ShowCamera = {}

local DEFAULT_FOV = 70

local active = false
local bound: Camera? = nil -- the camera the change listeners below watch
local connections: { RBXScriptConnection } = {}

local function rig(): (BasePart?, Instance?)
	local hall = workspace:FindFirstChild("PoolHall")
	if not hall then
		return nil, nil
	end
	return hall:FindFirstChild("ShowCamera") :: BasePart?, hall:FindFirstChild("Chairs")
end

-- Distance from the camera to the chair row along the view direction (the row's centre = the seats' average).
local function rowDepth(marker: BasePart, chairs: Instance): number
	local sum, count = Vector3.zero, 0
	for _, chair in chairs:GetChildren() do
		local seat = chair:FindFirstChild("Seat") :: BasePart?
		if seat then
			sum += seat.Position
			count += 1
		end
	end
	if count == 0 then
		return 40
	end
	return math.max((sum / count - marker.Position):Dot(marker.CFrame.LookVector), 1)
end

-- Vertical FOV that shows HalfWidth studs to each side of the row centre at the current aspect ratio.
local function fovFor(marker: BasePart, chairs: Instance, camera: Camera): number
	local halfWidth = (marker:GetAttribute("HalfWidth") or 29) :: number
	local minFov = (marker:GetAttribute("MinFov") or 40) :: number
	local maxFov = (marker:GetAttribute("MaxFov") or 70) :: number
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local halfAngle = math.atan(halfWidth / rowDepth(marker, chairs))
	local vertical = 2 * math.deg(math.atan(math.tan(halfAngle) / aspect))
	return math.clamp(vertical, minFov, maxFov)
end

local place: () -> boolean -- defined below (the listeners need it)

-- Watches the current camera: a new aspect ratio refits the FOV, and anything else putting CameraType back (a
-- respawn; in the Studio test 2026-10-22 the MCP execute_luau tool, which restores a camera type it saw change during
-- a call) is undone while the show camera is on. The check runs again when the deferred call fires, so turning the
-- show camera off in between wins.
local function bind(camera: Camera)
	if bound == camera then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	bound = camera
	table.insert(connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local marker, chairs = rig()
		if active and marker and chairs then
			camera.FieldOfView = fovFor(marker, chairs, camera)
		end
	end))
	table.insert(connections, camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if active and camera.CameraType ~= Enum.CameraType.Scriptable then
			task.defer(function()
				if active then
					place()
				end
			end)
		end
	end))
end

place = function(): boolean
	local camera = workspace.CurrentCamera
	local marker, chairs = rig()
	if not (camera and marker and chairs) then
		return false
	end
	bind(camera)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = marker.CFrame
	camera.FieldOfView = fovFor(marker, chairs, camera)
	return true
end

-- A replaced CurrentCamera gets the show camera again if it should be on.
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if active then
		place()
	end
end)

-- on = I'm an alive participant in a round (seated, or flying and coming back). Retries once if the map is late.
function ShowCamera.set(on: boolean)
	if on then
		if not active then
			active = true
			if not place() then
				task.delay(0.5, function()
					if active then
						place()
					end
				end)
			end
		end
	elseif active then
		active = false
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = DEFAULT_FOV
	end
end

-- A new character resets the camera type; put the show camera back if it should be on.
function ShowCamera.reapply()
	if active then
		place()
	end
end

return ShowCamera
