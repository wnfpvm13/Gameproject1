--!strict
-- Draws bat swings on every client, for every character, by turning the right shoulder (no uploaded animation): the
-- arm lifts out to the side cocked back, sweeps round across the front to the left (the bat level at shoulder
-- height, pointing straight ahead as the hit lands), and comes down, over Config.Bat.SwingSeconds. The turns are
-- for R15's RightShoulder, whose joint frame lines up with the torso (the place uses R15 avatars). A swing starts at the
-- character's Names.SwingAt (server time, set by BatService), or at once for the player's own swing (play()). The
-- joint is written in RunService.Stepped, after the Animator has written it for the frame (a value written in
-- RenderStepped is overwritten before it is drawn - learned in Western train's CowboyPose).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("TrainBrawl")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local CharacterParts = require(shared:WaitForChild("CharacterParts"))

local SwingPose = {}

-- Swings being drawn: the shoulder and the server time the swing started.
local swinging: { [Model]: { joint: CharacterParts.Joint, at: number } } = {}

-- The shoulder's turn `u` (0..1) through a swing: `lift` raises the arm out to the right (about the joint's forward
-- axis), then `turn` swings it round the torso's up axis (negative = toward the back, positive = across the front).
-- Wind-up to u 0.22, strike to 0.52 (the bat's tip crosses straight ahead near Config.Bat.HitAt / SwingSeconds =
-- 0.375), then down.
local function pose(u: number): CFrame
	local lift, turn
	if u < 0.22 then
		local k = u / 0.22
		lift, turn = k, -40 * k
	elseif u < 0.52 then
		local k = (u - 0.22) / 0.3
		lift, turn = 1, -40 + 170 * k
	else
		local k = (u - 0.52) / 0.48
		lift, turn = 1 - k, 130 * (1 - k)
	end
	return CFrame.Angles(0, math.rad(turn), 0) * CFrame.Angles(0, 0, math.rad(90) * lift)
end

RunService.Stepped:Connect(function()
	local now = Workspace:GetServerTimeNow()
	local seconds = Config.Bat.SwingSeconds
	for model, swing in swinging do
		local u = (now - swing.at) / seconds
		if u >= 1 or not swing.joint:IsDescendantOf(Workspace) then
			swinging[model] = nil
			if swing.joint:IsDescendantOf(Workspace) then
				(swing.joint :: any).Transform = CFrame.identity -- put straight once
			end
		elseif u >= 0 then
			-- Both joint kinds have Transform; the type checker cannot write through the union.
			(swing.joint :: any).Transform = pose(u)
		end
	end
end)

-- Starts drawing a swing of `model` that began at server time `at`.
function SwingPose.play(model: Model, at: number)
	local joint = CharacterParts.shoulder(model)
	if joint then
		swinging[model] = { joint = joint, at = at }
	end
end

-- Follows a character's Names.SwingAt (every swing the server takes). `skip(at)` returns true for a swing this client
-- already drew (the player's own, started at once). Returns the connection.
function SwingPose.follow(model: Model, skip: (number) -> boolean): RBXScriptConnection
	return model:GetAttributeChangedSignal(Names.SwingAt):Connect(function()
		local at = model:GetAttribute(Names.SwingAt)
		if typeof(at) == "number" and not skip(at) then
			SwingPose.play(model, at)
		end
	end)
end

return SwingPose
