--!strict
-- Western train client entry point (squash prototype): only wiring. Every locomotive gets an animator, a steam
-- puff, its run (RunTracker) and the moving world drawn around it (CourseView bridges, TrackScroll scenery). The
-- player's own locomotive follows the squash key at once (and tells the server), shows in the face window and has
-- its bridges judged here (reported to the server); other locomotives follow their Squashed attribute. A crash on
-- any locomotive (its CrashIndex attribute, or our own judgement first) plays the stamp, stars and a jolt.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local LocomotiveAnimator = require(script:WaitForChild("LocomotiveAnimator"))
local SquashInput = require(script:WaitForChild("SquashInput"))
local SteamPuff = require(script:WaitForChild("SteamPuff"))
local DriverCamera = require(script:WaitForChild("DriverCamera"))
local FaceCam = require(script:WaitForChild("FaceCam"))
local RunTracker = require(script:WaitForChild("RunTracker"))
local CourseView = require(script:WaitForChild("CourseView"))
local TrackScroll = require(script:WaitForChild("TrackScroll"))
local RunFeedback = require(script:WaitForChild("RunFeedback"))

local player = Players.LocalPlayer
local remotes = shared:WaitForChild(Names.RemotesFolder)
local squashRemote = remotes:WaitForChild(Names.SquashRemote) :: RemoteEvent
local bridgeRemote = remotes:WaitForChild(Names.BridgeRemote) :: RemoteEvent
local faceCam = FaceCam.new(player:WaitForChild("PlayerGui"))

local CRASH_WORD = Color3.fromRGB(255, 120, 70)
local PASS_WORD = Color3.fromRGB(255, 230, 120)

type Tracked = {
	animator: LocomotiveAnimator.Animator,
	puff: SteamPuff.Puff?,
	squashed: boolean,
	run: RunTracker.Tracker,
	course: CourseView.View,
	scenery: TrackScroll.Scroll,
	predicted: { index: number, at: number }?, -- own locomotive: a crash our judgement already played (os.clock)
	connections: { RBXScriptConnection },
}
local tracked: { [Model]: Tracked } = {}
local mine: Model? = nil
local inputDown = false -- still held when a new locomotive arrives (respawn), so it starts flat
local ownCrashing = false
local crashGags = 0 -- counts own crash gags, so an older one's time-out leaves a newer one alone

local function refreshFaceSize()
	faceCam:setBig(inputDown or ownCrashing)
end

local function setSquashed(locomotive: Model, squashed: boolean)
	local entry = tracked[locomotive]
	if not entry or entry.squashed == squashed then
		return
	end
	entry.squashed = squashed
	entry.animator:setTarget(squashed)
	if entry.puff then
		entry.puff:burst()
	end
end

local function playCrash(locomotive: Model, entry: Tracked, index: number)
	entry.course:stampFace(index)
	entry.animator:jolt(Config.Run.CrashJolt)
	RunFeedback.stars(locomotive, Config.Run.CrashSeconds)
	if locomotive == mine then
		ownCrashing = true
		refreshFaceSize()
		faceCam:flash("쾅!", CRASH_WORD)
		-- The server's crash ends it (CrashIndex back to 0); if the server never crashed (it had judged that bridge
		-- already), the window still goes back after the crash time.
		crashGags += 1
		local this = crashGags
		task.delay(Config.Run.CrashSeconds + Config.Run.HoldSeconds, function()
			local serverCrash = locomotive:GetAttribute(Names.CrashIndex)
			local serverCrashing = typeof(serverCrash) == "number" and serverCrash > 0
			if crashGags == this and ownCrashing and locomotive == mine and not serverCrashing then
				ownCrashing = false
				refreshFaceSize()
			end
		end)
	end
end

local function showScore(locomotive: Model)
	local passed, crashes = locomotive:GetAttribute(Names.Passed), locomotive:GetAttribute(Names.Crashes)
	faceCam:setScore(if typeof(passed) == "number" then passed else 0, if typeof(crashes) == "number" then crashes else 0)
end

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	local locomotive = instance
	local base = locomotive:WaitForChild(Names.BasePart, 10)
	if tracked[locomotive] or not locomotive.Parent or not CollectionService:HasTag(locomotive, Names.LocomotiveTag) then
		return -- tracked meanwhile by a second signal, or gone / untagged while waiting
	end
	local animator = LocomotiveAnimator.new(locomotive)
	if not (animator and base and base:IsA("BasePart")) then
		return
	end
	local entry: Tracked = {
		animator = animator,
		puff = SteamPuff.new(locomotive),
		squashed = false,
		run = RunTracker.new(locomotive),
		course = CourseView.new(locomotive, base),
		scenery = TrackScroll.new(locomotive, base),
		predicted = nil,
		connections = {},
	}
	tracked[locomotive] = entry
	local isMine = locomotive:GetAttribute(Names.OwnerUserId) == player.UserId
	local function onCrashIndex()
		local index = locomotive:GetAttribute(Names.CrashIndex)
		if typeof(index) ~= "number" or index <= 0 then
			if locomotive == mine then
				ownCrashing = false
				refreshFaceSize()
			end
		elseif entry.predicted and entry.predicted.index == index and os.clock() - entry.predicted.at < Config.Run.PredictionSeconds then
			entry.predicted = nil -- our own judgement already played it
		else
			playCrash(locomotive, entry, index)
		end
	end
	table.insert(entry.connections, locomotive:GetAttributeChangedSignal(Names.CrashIndex):Connect(onCrashIndex))
	if isMine then
		mine = locomotive
		ownCrashing = false
		DriverCamera.follow(locomotive)
		faceCam:show(locomotive)
		refreshFaceSize()
		showScore(locomotive)
		for _, name in { Names.Passed, Names.Crashes } do
			table.insert(entry.connections, locomotive:GetAttributeChangedSignal(name):Connect(function()
				showScore(locomotive)
			end))
		end
		setSquashed(locomotive, inputDown)
		squashRemote:FireServer(inputDown) -- also replaces a state the server still holds back from the old locomotive
	else
		local function follow()
			setSquashed(locomotive, locomotive:GetAttribute(Names.Squashed) == true)
		end
		table.insert(entry.connections, locomotive:GetAttributeChangedSignal(Names.Squashed):Connect(follow))
		follow()
	end
	onCrashIndex() -- a locomotive that arrives in the middle of a crash (joining late) shows it too
end

CollectionService:GetInstanceAddedSignal(Names.LocomotiveTag):Connect(function(instance)
	task.spawn(track, instance)
end)
CollectionService:GetInstanceRemovedSignal(Names.LocomotiveTag):Connect(function(instance)
	if not instance:IsA("Model") then
		return
	end
	local entry = tracked[instance]
	tracked[instance] = nil
	if entry then
		for _, connection in entry.connections do
			connection:Disconnect()
		end
		if entry.puff then
			entry.puff:destroy()
		end
		entry.run:destroy()
		entry.course:destroy()
		entry.scenery:destroy()
	end
	if mine == instance then
		mine = nil
		ownCrashing = false
		faceCam:hide()
	end
end)
for _, instance in CollectionService:GetTagged(Names.LocomotiveTag) do
	task.spawn(track, instance)
end

SquashInput.bind(function(isDown: boolean)
	inputDown = isDown
	local own = mine
	if own then
		setSquashed(own, isDown)
	end
	refreshFaceSize()
	squashRemote:FireServer(isDown) -- even without a locomotive, so the server's latest state is never a stale one
end)

RunService.RenderStepped:Connect(function(dt: number)
	local now = Workspace:GetServerTimeNow()
	for _, entry in tracked do
		entry.animator:setRunSpeed(entry.run:speed(now))
		entry.animator:update(dt)
		local distance = entry.run:distance(now)
		entry.course:update(distance)
		entry.scenery:update(distance)
	end
	-- Our own bridges, judged from the shape just drawn; the server confirms.
	local own = mine
	local entry = own and tracked[own]
	if own and entry then
		local event = entry.run:judge(now, entry.animator:height())
		if event then
			bridgeRemote:FireServer(event.index, event.kind == "hit", event.distance)
			if event.kind == "hit" then
				entry.predicted = { index = event.index, at = os.clock() }
				playCrash(own, entry, event.index)
			else
				faceCam:flash("통과!", PASS_WORD)
			end
		end
	end
	faceCam:update() -- after the animators: it copies the parts they just moved
end)
