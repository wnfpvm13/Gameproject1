--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.HuntingAnimationConfig)
local Ownership = require(ReplicatedStorage.Shared.Utilities.CombatTrackOwnership)
local Tracks = {}
local JOINT = { LowerTorso = "RootJoint", UpperTorso = "Waist", Head = "Neck",
	RightUpperArm = "RightShoulder", RightLowerArm = "RightElbow", RightHand = "RightWrist",
	LeftUpperArm = "LeftShoulder", LeftLowerArm = "LeftElbow", LeftHand = "LeftWrist",
	RightUpperLeg = "RightHip", RightLowerLeg = "RightKnee", RightFoot = "RightAnkle",
	LeftUpperLeg = "LeftHip", LeftLowerLeg = "LeftKnee", LeftFoot = "LeftAnkle" }
local function key(action: any): string
	return if action.AttackType == "Basic" then "Basic"..tostring(action.ComboIndex or 1) else action.AttackType
end
local function load(character: Model, entry: any, name: string): AnimationTrack?
	if entry.TrackCache[name] ~= nil then return entry.TrackCache[name] or nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then return nil end
	local id = Config.Player[name]
	if id == "" and RunService:IsStudio() and Config.StudioClipPreview then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local animations = assets and assets:FindFirstChild("Animations")
		local folder = animations and animations:FindFirstChild("PlayerCombat")
		local source = folder and folder:FindFirstChild(name)
		if source and source:IsA("KeyframeSequence") then
			local clip = source:Clone()
			-- The source is in canonical avatar axes. Retarget to this actual R15's C0 axes.
			for _, pose in clip:GetDescendants() do
				if pose:IsA("Pose") then
					local joint = entry.Joints[JOINT[pose.Name]]
					if joint then local axes = joint.C0.Rotation; pose.CFrame = axes:Inverse()*pose.CFrame*axes end
				end
			end
			local ok, previewId = pcall(function() return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(clip) end)
			clip:Destroy()
			if ok then id = previewId end
		end
	end
	if id == "" then entry.TrackCache[name] = false; return nil end
	local animation = Instance.new("Animation"); animation.AnimationId = id
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	animation:Destroy()
	if not ok then
		entry.TrackCache[name] = false
		warn("[MonCook Animation] Cannot load "..name..": "..tostring(track))
		return nil
	end
	track.Priority, track.Looped = Enum.AnimationPriority.Action, false
	entry.TrackCache[name] = track
	return track
end
function Tracks.stop(entry: any)
	if entry.ActiveTrack then entry.ActiveTrack:Stop(Config.TrackFadeSeconds); entry.ActiveTrack = nil end
	entry.ActiveStamp = nil
end
function Tracks.update(character: Model, entry: any, action: any, at: number): boolean
	entry.TrackCache = entry.TrackCache or {}
	if not action or at >= action.EndAt then Tracks.stop(entry); return false end
	local name = key(action)
	if not Ownership.createsTrack(character == Players.LocalPlayer.Character, Config.Player[name]) then
		-- The owner's published track already replicates through the server Animator.
		-- Observers inspect it; they never load, seek, stop, or own that track.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, replicated in animator:GetPlayingAnimationTracks() do
				if replicated.IsPlaying and replicated.Animation.AnimationId == Config.Player[name]
					and replicated.Priority == Enum.AnimationPriority.Action then return true end
			end
		end
		return false
	end
	local track = load(character, entry, name)
	if not track then Tracks.stop(entry); return false end
	local stamp = action.AttackId or (name..":"..tostring(action.StartedAt))
	if entry.ActiveStamp ~= stamp then
		-- Approval of the same predicted stroke corrects its phase without restarting it.
		local continuation = entry.ActiveTrack == track and entry.ActivePredicted and not action.Predicted
		if not continuation then Tracks.stop(entry); track:Play(Config.TrackFadeSeconds) end
		entry.ActiveTrack, entry.ActiveStamp, entry.ActivePredicted = track, stamp, action.Predicted == true
	end
	if track.Length <= 0 then return false end
	local speed = track.Length/(action.EndAt-action.StartedAt)
	track:AdjustSpeed(speed)
	local position = math.clamp((at-action.StartedAt)*speed, 0, math.max(0,track.Length-0.001))
	if math.abs(track.TimePosition-position) > 0.06 then track.TimePosition = position end
	return track.IsPlaying
end
function Tracks.destroy(entry: any)
	Tracks.stop(entry)
	for _, track in entry.TrackCache or {} do if track then track:Destroy() end end
end
return Tracks
