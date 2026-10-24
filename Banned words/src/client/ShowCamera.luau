--!strict
-- The fixed round cameras (docs/DESIGN_V3.md §10, owner 2026-10-22):
--   "show"      seated participants watch the chair row from the front, so every other participant (faces and word
--               bubbles) is on screen with the pool behind, including anyone flying off. The FOV makes the row's
--               HalfWidth fit the screen width at the current aspect ratio (the game is landscape only). Rig numbers
--               live on PoolHall.ShowCamera (attributes HalfWidth, MinFov, MaxFov).
--   "presenter" the presenter looks at the row from behind the podium (PoolHall.PresenterCamera, attribute Fov). Their
--               own character stands between that camera and the row, so it is hidden on their screen only (like
--               first person; everyone else still sees them).
-- Everyone else keeps the normal camera.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ShowCamera = {}

export type Mode = "show" | "presenter"

local DEFAULT_FOV = 70

local mode: Mode? = nil
local bound: Camera? = nil -- the camera the change listeners below watch
local connections: { RBXScriptConnection } = {}

local function hall(): Instance?
	return workspace:FindFirstChild("PoolHall")
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
local function fitRow(marker: BasePart, chairs: Instance, camera: Camera): number
	local halfWidth = (marker:GetAttribute("HalfWidth") or 29) :: number
	local minFov = (marker:GetAttribute("MinFov") or 40) :: number
	local maxFov = (marker:GetAttribute("MaxFov") or 70) :: number
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local halfAngle = math.atan(halfWidth / rowDepth(marker, chairs))
	local vertical = 2 * math.deg(math.atan(math.tan(halfAngle) / aspect))
	return math.clamp(vertical, minFov, maxFov)
end

-- The marker and FOV of the current mode, or nil while the map is missing.
local function rig(camera: Camera): (BasePart?, number)
	local map = hall()
	if not map or not mode then
		return nil, DEFAULT_FOV
	end
	if mode == "presenter" then
		local marker = map:FindFirstChild("PresenterCamera") :: BasePart?
		return marker, if marker then (marker:GetAttribute("Fov") or 55) :: number else DEFAULT_FOV
	end
	local marker = map:FindFirstChild("ShowCamera") :: BasePart?
	local chairs = map:FindFirstChild("Chairs")
	if not (marker and chairs) then
		return nil, DEFAULT_FOV
	end
	return marker, fitRow(marker, chairs, camera)
end

local function setHidden(d: Instance, hidden: boolean)
	if d:IsA("BasePart") or d:IsA("Decal") then
		local untyped: any = d
		untyped.LocalTransparencyModifier = if hidden then 1 else 0
	end
end

-- My own character, invisible on my screen (true) or shown again (false). While hidden, parts added later
-- (accessories that load late, tools) are hidden too.
local hiddenAdded: RBXScriptConnection? = nil
local function hideMe(hidden: boolean)
	if hiddenAdded then
		hiddenAdded:Disconnect()
		hiddenAdded = nil
	end
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		setHidden(d, hidden)
	end
	if hidden then
		hiddenAdded = character.DescendantAdded:Connect(function(d)
			setHidden(d, true)
		end)
	end
end

local place: () -> boolean -- defined below (the listeners need it)

-- Watches the current camera: a new aspect ratio refits the FOV, and anything else putting CameraType back (a
-- respawn; in the Studio test 2026-10-22 the MCP execute_luau tool, which restores a camera type it saw change during
-- a call) is undone while a round camera is on. The check runs again when the deferred call fires, so turning the
-- camera off in between wins.
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
		if mode then
			local marker, fov = rig(camera)
			if marker then
				camera.FieldOfView = fov
			end
		end
	end))
	table.insert(connections, camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if mode and camera.CameraType ~= Enum.CameraType.Scriptable then
			task.defer(function()
				if mode then
					place()
				end
			end)
		end
	end))
end

place = function(): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local marker, fov = rig(camera)
	if not marker then
		return false
	end
	bind(camera)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = marker.CFrame
	camera.FieldOfView = fov
	if mode == "presenter" then
		hideMe(true)
	end
	return true
end

-- A replaced CurrentCamera gets the round camera again if it should be on.
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if mode then
		place()
	end
end)

-- `to` = "show" while I'm an alive participant in a round (seated, or flying and coming back), "presenter" while I
-- present one, nil otherwise. Retries once if the map is late.
function ShowCamera.set(to: Mode?)
	if to == mode then
		return
	end
	if mode == "presenter" then
		hideMe(false)
	end
	mode = to
	if to then
		if not place() then
			task.delay(0.5, function()
				if mode == to then
					place()
				end
			end)
		end
	else
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = DEFAULT_FOV
	end
end

-- A blast shakes the round camera for SHAKE_SECONDS (owner 2026-10-24), `strength` studs at first, fading out; it
-- ends back on the rig. Nothing without a round camera (spectators keep their own).
local shaking = 0
function ShowCamera.shake(strength: number, seconds: number)
	local camera = workspace.CurrentCamera
	if not (mode and camera) then
		return
	end
	if not rig(camera) then
		return
	end
	shaking += 1
	local mine = shaking
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / seconds
		local marker = if mode then rig(camera) else nil -- (read every frame: the mode may change meanwhile)
		if mine ~= shaking or not marker or t >= 1 then
			connection:Disconnect()
			if mine == shaking and marker then
				camera.CFrame = marker.CFrame
			end
			return
		end
		local amount = strength * (1 - t)
		camera.CFrame = marker.CFrame * CFrame.new((math.random() * 2 - 1) * amount, (math.random() * 2 - 1) * amount, 0)
	end)
end

-- A new character resets the camera type; put the round camera back if it should be on.
function ShowCamera.reapply()
	if mode then
		place()
	end
end

return ShowCamera
