--!strict
-- The fixed round cameras (docs/DESIGN_V3.md §10, owner 2026-10-22):
--   "show"      seated participants watch the chair row from the front, so every other participant (faces and word
--               bubbles) is on screen with the pool behind, including anyone flying off. The FOV makes the row's
--               HalfWidth fit the screen width at the current aspect ratio (the game is landscape only). Rig numbers
--               live on PoolHall.ShowCamera (attributes HalfWidth, MinFov, MaxFov). A round of few players (they sit in
--               the middle chairs) is framed closer (review 2026-10-25: two players were tiny among eight empty chairs):
--               the seated chairs plus Config.SHOW_MARGIN studs, at least Config.SHOW_MIN_HALF_WIDTH, and the view
--               tilts so the tops of the head tags (Config.SHOW_KEEP_HEIGHT over the seats) stay at the same height on
--               screen as in the wide view: on a phone the status board above and the card below leave a narrow band,
--               and 스무고개's words must stay in it (Studio check 2026-10-26: keeping the seats' height instead pushed
--               the words under the status board).
--   "presenter" the presenter looks at the row from behind the podium (PoolHall.PresenterCamera, attribute Fov). Their
--               own character stands between that camera and the row, so it is hidden on their screen only (like
--               first person; everyone else still sees them).
-- Everyone else keeps the normal camera.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Config"))

local ShowCamera = {}

export type Mode = "show" | "presenter"

local DEFAULT_FOV = 70

local mode: Mode? = nil
local seatedCount = 0 -- participants this round (they sit in the middle chairs); 0 = frame the whole row
local wideUntil = 0 -- os.clock() until which the whole row is framed (someone flies: review 2026-10-26, the close frame
-- cut flights to the side and landings outside the pool)
local bound: Camera? = nil -- the camera the change listeners below watch
local connections: { RBXScriptConnection } = {}

local function hall(): Instance?
	return workspace:FindFirstChild("PoolHall")
end

local function seats(chairs: Instance): { BasePart }
	local list = {}
	for _, chair in chairs:GetChildren() do
		local seat = chair:FindFirstChild("Seat")
		if seat and seat:IsA("BasePart") then
			table.insert(list, seat)
		end
	end
	return list
end

-- Distance from the camera to the chair row along the view direction (the row's centre = the seats' average), and the
-- seats' average height.
local function rowDepth(marker: BasePart, chairs: Instance): (number, number)
	local sum, count = Vector3.zero, 0
	for _, seat in seats(chairs) do
		sum += seat.Position
		count += 1
	end
	if count == 0 then
		return 40, marker.Position.Y - 8
	end
	local centre = sum / count
	return math.max((centre - marker.Position):Dot(marker.CFrame.LookVector), 1), centre.Y
end

-- Vertical FOV that shows `halfWidth` studs to each side of the row centre at the current aspect ratio.
local function fovFor(halfWidth: number, depth: number, camera: Camera): number
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local halfAngle = math.atan(halfWidth / depth)
	return 2 * math.deg(math.atan(math.tan(halfAngle) / aspect))
end

-- How far the seated chairs reach from the camera's centre line: the `seatedCount` chairs nearest the middle.
local function seatedReach(marker: BasePart, chairs: Instance): number
	local offsets = {}
	for _, seat in seats(chairs) do
		table.insert(offsets, math.abs((seat.Position - marker.Position):Dot(marker.CFrame.RightVector)))
	end
	table.sort(offsets)
	return offsets[math.clamp(seatedCount, 1, math.max(#offsets, 1))] or 0
end

-- The show camera: where it looks from and its FOV. The whole row, or closer for few players (tilted so the head tags
-- keep their height on screen).
local function fitRow(marker: BasePart, chairs: Instance, camera: Camera): (CFrame, number)
	local rowHalf = (marker:GetAttribute("HalfWidth") or 29) :: number
	local maxFov = (marker:GetAttribute("MaxFov") or 70) :: number
	local depth, seatY = rowDepth(marker, chairs)
	local wide = math.clamp(fovFor(rowHalf, depth, camera), (marker:GetAttribute("MinFov") or 40) :: number, maxFov)
	if seatedCount <= 0 or os.clock() < wideUntil then
		return marker.CFrame, wide
	end
	local halfWidth = math.clamp(seatedReach(marker, chairs) + Config.SHOW_MARGIN, Config.SHOW_MIN_HALF_WIDTH, rowHalf)
	if halfWidth >= rowHalf then
		return marker.CFrame, wide -- (many players: exactly the wide view, also on a narrow phone)
	end
	local close = math.min(math.max(fovFor(halfWidth, depth, camera), Config.SHOW_MIN_FOV), wide)
	if close >= wide - 0.5 then
		return marker.CFrame, wide
	end
	-- (the head tags' tops sit at the same fraction of the screen height as in the wide view)
	local keepY = seatY + Config.SHOW_KEEP_HEIGHT
	local centreY = (marker.Position + marker.CFrame.LookVector * depth).Y
	local wideHalf = depth * math.tan(math.rad(wide / 2))
	local closeHalf = depth * math.tan(math.rad(close / 2))
	local fromTop = (centreY + wideHalf - keepY) / (2 * wideHalf)
	local closeCentreY = keepY + (fromTop - 0.5) * 2 * closeHalf
	local tilt = math.atan((centreY - closeCentreY) / depth)
	return marker.CFrame * CFrame.Angles(-tilt, 0, 0), close
end

-- Where the current mode's camera looks from and its FOV, or nil while the map is missing.
local function rig(camera: Camera): (CFrame?, number)
	local map = hall()
	if not map or not mode then
		return nil, DEFAULT_FOV
	end
	if mode == "presenter" then
		local marker = map:FindFirstChild("PresenterCamera") :: BasePart?
		return if marker then marker.CFrame else nil, if marker then (marker:GetAttribute("Fov") or 55) :: number else DEFAULT_FOV
	end
	local marker = map:FindFirstChild("ShowCamera") :: BasePart?
	local chairs = map:FindFirstChild("Chairs")
	if not (marker and chairs) then
		return nil, DEFAULT_FOV
	end
	return fitRow(marker, chairs, camera)
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
			local at, fov = rig(camera)
			if at then
				camera.CFrame = at
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
	local at, fov = rig(camera)
	if not at then
		return false
	end
	bind(camera)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = at
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
-- present one, nil otherwise; `seated`: how many play this round (the show camera frames their chairs). Retries once
-- if the map is late.
function ShowCamera.set(to: Mode?, seated: number?)
	local count = if to == "show" then seated or 0 else 0
	if to == mode and count == seatedCount then
		return
	end
	seatedCount = count
	if to == mode then
		place() -- (the same mode, another frame)
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
		local at = if mode then rig(camera) else nil -- (read every frame: the mode may change meanwhile)
		if mine ~= shaking or not at or t >= 1 then
			connection:Disconnect()
			if mine == shaking and at then
				camera.CFrame = at
			end
			return
		end
		local amount = strength * (1 - t)
		camera.CFrame = at * CFrame.new((math.random() * 2 - 1) * amount, (math.random() * 2 - 1) * amount, 0)
	end)
end

-- Someone flies: the whole row for `seconds` (the blast hides the cut), then the close frame comes back smoothly.
local widenings = 0
function ShowCamera.widen(seconds: number)
	wideUntil = math.max(wideUntil, os.clock() + seconds)
	widenings += 1
	local mine = widenings
	if mode == "show" then
		place()
	end
	task.delay(seconds + 0.05, function()
		local camera = workspace.CurrentCamera
		if mine ~= widenings or mode ~= "show" or not camera or os.clock() < wideUntil then
			return
		end
		local at, fov = rig(camera)
		if at then
			TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ CFrame = at, FieldOfView = fov }):Play()
		end
	end)
end

-- A new character resets the camera type; put the round camera back if it should be on.
function ShowCamera.reapply()
	if mode then
		place()
	end
end

return ShowCamera
