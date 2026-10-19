--!strict
-- Seated players look across the ring from just behind and above their own chair, so every other chair
-- (faces + word bubbles) is on screen. The FOV widens on narrow screens so the side chairs still fit.
-- Rig numbers live as attributes on LoungeMap.CameraRig (Back, Up, LookY, HalfAngle) for easy tuning.
-- Ghosts and spectators keep the normal camera and walk around.
local Players = game:GetService("Players")

local RingCamera = {}

local DEFAULT_FOV = 70
local MIN_FOV, MAX_FOV = 40, 90

local active = false
local viewportConnection: RBXScriptConnection? = nil

local function rig(): (BasePart?, BasePart?)
	local map = workspace:FindFirstChild("LoungeMap")
	if not map then
		return nil, nil
	end
	return map:FindFirstChild("Center") :: BasePart?, map:FindFirstChild("CameraRig") :: BasePart?
end

local function mySeat(): Seat?
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return if seat and seat:IsA("Seat") then seat else nil
end

-- Vertical FOV that shows `halfAngle` degrees to each side at the current aspect ratio.
local function fovFor(halfAngle: number, camera: Camera): number
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local vertical = 2 * math.deg(math.atan(math.tan(math.rad(halfAngle)) / aspect))
	return math.clamp(vertical, MIN_FOV, MAX_FOV)
end

local function place(): boolean
	local camera = workspace.CurrentCamera
	local center, cameraRig = rig()
	local seat = mySeat()
	if not (center and cameraRig and seat) then
		return false
	end
	local back = (cameraRig:GetAttribute("Back") or 9) :: number
	local up = (cameraRig:GetAttribute("Up") or 11) :: number
	local lookY = (cameraRig:GetAttribute("LookY") or 6) :: number
	local halfAngle = (cameraRig:GetAttribute("HalfAngle") or 42) :: number
	local outward = seat.Position - center.Position
	outward = Vector3.new(outward.X, 0, outward.Z)
	outward = if outward.Magnitude > 0.1 then outward.Unit else Vector3.new(0, 0, 1)
	local position = Vector3.new(seat.Position.X, center.Position.Y, seat.Position.Z) + outward * back + Vector3.new(0, up, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(position, center.Position + Vector3.new(0, lookY, 0))
	camera.FieldOfView = fovFor(halfAngle, camera)
	if not viewportConnection then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if active then
				camera.FieldOfView = fovFor(halfAngle, camera)
			end
		end)
	end
	return true
end

-- on = I'm an alive participant in a round. Retries until I'm actually seated.
function RingCamera.set(on: boolean)
	local camera = workspace.CurrentCamera
	if on then
		active = true
		if not place() then
			task.delay(0.3, function()
				if active then
					place()
				end
			end)
		end
	elseif active then
		active = false
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = DEFAULT_FOV
	end
end

function RingCamera.reapply()
	if active then
		place()
	end
end

return RingCamera
