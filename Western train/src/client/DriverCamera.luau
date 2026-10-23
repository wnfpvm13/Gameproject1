--!strict
-- The driver's camera: looks at the player's own locomotive from the front-right, so the face shows, then the player
-- can turn and zoom freely. (The hidden character cannot walk: the server anchors it, and SquashInput takes the S key
-- before the walking controls.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))

local DriverCamera = {}

local VIEW_DIRECTION = Vector3.new(24, 11, -28).Unit -- front-right of the locomotive (its forward is -Z)
local HOLD_BIND = "WesternTrainStartView"

function DriverCamera.follow(locomotive: Model)
	local focus = locomotive:FindFirstChild(Names.CameraFocus)
	if not (focus and focus:IsA("BasePart")) then
		return
	end
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = focus
	-- Min and max zoom both at the start distance, so Roblox's camera takes that distance too and keeps it after the
	-- hold (it would otherwise jump back to its old zoom).
	player.CameraMinZoomDistance = Config.Camera.StartZoom
	player.CameraMaxZoomDistance = Config.Camera.StartZoom
	-- Roblox's camera turns itself to look along the (hidden) character when that character arrives, and on first
	-- join that can come after the locomotive; so the start view is held for a moment, set after the camera's update.
	local holdUntil = os.clock() + Config.Camera.StartHoldSeconds
	RunService:UnbindFromRenderStep(HOLD_BIND) -- a respawn replaces an earlier hold
	RunService:BindToRenderStep(HOLD_BIND, Enum.RenderPriority.Camera.Value + 1, function()
		if not focus.Parent or os.clock() >= holdUntil then
			RunService:UnbindFromRenderStep(HOLD_BIND)
			player.CameraMaxZoomDistance = StarterPlayer.CameraMaxZoomDistance
			player.CameraMinZoomDistance = Config.Camera.MinZoomAfterStart
			return
		end
		local direction = focus.CFrame:VectorToWorldSpace(VIEW_DIRECTION)
		camera.CFrame = CFrame.lookAt(focus.Position + direction * Config.Camera.StartZoom, focus.Position)
	end)
end

return DriverCamera
