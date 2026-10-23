--!strict
-- Western train client entry point: only wiring. Every train gets an animator, a steam puff, its run (RunTracker),
-- the moving world drawn around it (CourseView bridges, TrackScroll scenery) and a RoofRider for its cowboy, who is
-- laid flat on a squashed roof (CowboyPose). The player is a train's driver (Names.OwnerUserId) or its cowboy
-- (Names.CowboyUserId):
-- - driving: the squash key folds the train at once and the jump key makes it jump (both told to the server; no jump
--   while flat, and a squash held in the air waits for the landing), the bridges are judged here and reported, and the
--   face window shows the train;
-- - riding: the character is carried with the roof and follows the cowboy's rules (CowboyRules), the face window shows
--   the driver's face, and the train's jumps show the timing ring for a jump together (ApexRing); a bridge splat is
--   told to the server, so everyone sees the cowboy go paper-thin (PaperPose) and the driver hears of it.
-- Other trains follow their Squashed and JumpAt attributes. A crash on any train (its CrashIndex attribute, or our own
-- judgement first) plays the stamp, stars and a jolt.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("WesternTrain")
local Config = require(shared:WaitForChild("Config"))
local Names = require(shared:WaitForChild("Names"))
local TrainState = require(shared:WaitForChild("TrainState"))
local LocomotiveAnimator = require(script:WaitForChild("LocomotiveAnimator"))
local SquashInput = require(script:WaitForChild("SquashInput"))
local SteamPuff = require(script:WaitForChild("SteamPuff"))
local DriverCamera = require(script:WaitForChild("DriverCamera"))
local FaceCam = require(script:WaitForChild("FaceCam"))
local RunTracker = require(script:WaitForChild("RunTracker"))
local CourseView = require(script:WaitForChild("CourseView"))
local TrackScroll = require(script:WaitForChild("TrackScroll"))
local RunFeedback = require(script:WaitForChild("RunFeedback"))
local RoofRider = require(script:WaitForChild("RoofRider"))
local CowboyRules = require(script:WaitForChild("CowboyRules"))
local CowboyPose = require(script:WaitForChild("CowboyPose"))
local BarrelView = require(script:WaitForChild("BarrelView"))
local GoldView = require(script:WaitForChild("GoldView"))
local JumpInput = require(script:WaitForChild("JumpInput"))
local ApexRing = require(script:WaitForChild("ApexRing"))
local PaperPose = require(script:WaitForChild("PaperPose"))
local PaperPath = require(shared:WaitForChild("PaperPath"))

local player = Players.LocalPlayer
local remotes = shared:WaitForChild(Names.RemotesFolder)
local squashRemote = remotes:WaitForChild(Names.SquashRemote) :: RemoteEvent
local bridgeRemote = remotes:WaitForChild(Names.BridgeRemote) :: RemoteEvent
local mailRemote = remotes:WaitForChild(Names.MailRemote) :: RemoteEvent
local jumpRemote = remotes:WaitForChild(Names.JumpRemote) :: RemoteEvent
local goldRemote = remotes:WaitForChild(Names.GoldRemote) :: RemoteEvent
local splatRemote = remotes:WaitForChild(Names.SplatRemote) :: RemoteEvent
local faceCam = FaceCam.new(player:WaitForChild("PlayerGui"))
local apexRing = ApexRing.new(player:WaitForChild("PlayerGui"))

local CRASH_WORD = Color3.fromRGB(255, 120, 70)
local PASS_WORD = Color3.fromRGB(255, 230, 120)
local SPLAT_WORD = Color3.fromRGB(255, 160, 200)
local MAIL_WORD = Color3.fromRGB(150, 230, 140)
local GOLD_WORD = Color3.fromRGB(255, 214, 80)

type Tracked = {
	base: BasePart,
	animator: LocomotiveAnimator.Animator,
	puff: SteamPuff.Puff?,
	squashed: boolean,
	run: RunTracker.Tracker,
	course: CourseView.View,
	scenery: TrackScroll.Scroll,
	rider: RoofRider.Rider,
	barrels: BarrelView.View,
	gold: GoldView.View,
	rules: CowboyRules.Rules?, -- while the player rides this train
	predicted: { index: number, at: number }?, -- own train: a crash our judgement already played (os.clock)
	splat: number?, -- the server time a bridge last made paper of this train's cowboy
	cowboy: Model?, -- this train's cowboy's character, and since when (server time, as first seen here): a splat from
	cowboySince: number, -- before then was someone else's, or the character before a respawn, and is not drawn
	connections: { RBXScriptConnection },
}
local tracked: { [Model]: Tracked } = {}
local mine: Model? = nil -- the train the player drives
local riding: Model? = nil -- the train the player rides as the cowboy
local shownInWindow: Model? = nil
local inputDown = false -- the squash key is still held when a new train arrives (respawn), so it starts flat
local sentSquash: boolean? = nil -- the squash state last sent to the server
local ownCrashing = false
local crashGags = 0 -- counts own crash gags, so an older one's time-out leaves a newer one alone
local unbindSquash: (() -> ())? = nil
local jumpControl: JumpInput.Control? = nil

local function refreshFaceSize()
	faceCam:setBig(inputDown or ownCrashing)
end

local function showScore(locomotive: Model)
	local function count(name: string): number
		local value = locomotive:GetAttribute(name)
		return if typeof(value) == "number" then value else 0
	end
	local cowboy = TrainState.hasCowboy(locomotive)
	local mail = if cowboy then count(Names.MailTaken) else nil
	local gold = if cowboy then count(Names.GoldTaken) else nil
	faceCam:setScore(count(Names.Passed), count(Names.Crashes), mail, gold)
end

-- The face window shows the train the player drives or rides.
local function refreshWindow()
	local show = mine or riding
	if show == shownInWindow then
		return
	end
	shownInWindow = show
	if show then
		faceCam:show(show)
		showScore(show)
	else
		faceCam:hide()
	end
	refreshFaceSize()
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

-- Our own train is flat while the squash key is held, except in the air (it folds when it lands). The server hears
-- every change, even without a train, so its latest state is never a stale one.
local function refreshOwnSquash(now: number)
	local own = mine
	local entry = own and tracked[own]
	local flat = inputDown and not (entry and entry.animator:airborne(now))
	if own then
		setSquashed(own, flat)
	end
	if flat ~= sentSquash then
		sentSquash = flat
		squashRemote:FireServer(flat)
	end
end

local function onSquashKey(isDown: boolean)
	inputDown = isDown
	refreshOwnSquash(Workspace:GetServerTimeNow())
	refreshFaceSize()
end

-- Whether our own train may jump now: not flat (or still rising from it) and not in the air already.
local function canJump(entry: Tracked, now: number): boolean
	return not entry.squashed and entry.animator:flatness() <= Config.Jump.FlatLimit and not entry.animator:airborne(now)
end

local function onJumpKey()
	local own = mine
	local entry = own and tracked[own]
	local now = Workspace:GetServerTimeNow()
	if entry and canJump(entry, now) then
		entry.animator:jump(now)
		if entry.puff then
			entry.puff:burst()
		end
		jumpRemote:FireServer(now) -- when we pressed, so everyone draws the jump from the same moment
	end
end

-- The squash and jump keys belong to drivers only (a cowboy walks backward with S and jumps with Space). They stay
-- bound while a driver has no train for a moment (respawn), so a key held across it still counts.
local function refreshInput()
	if mine and not unbindSquash then
		unbindSquash = SquashInput.bind(onSquashKey)
		jumpControl = JumpInput.bind(onJumpKey)
	elseif riding and unbindSquash then
		local unbind = unbindSquash
		unbindSquash = nil
		unbind()
		local control = jumpControl
		jumpControl = nil
		if control then
			control.unbind()
		end
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
	elseif locomotive == riding then
		faceCam:flash("쾅!", CRASH_WORD)
	end
end

local function cowboyCharacter(locomotive: Model): Model?
	local id = locomotive:GetAttribute(Names.CowboyUserId)
	local cowboy = if typeof(id) == "number" and id ~= 0 then Players:GetPlayerByUserId(id) else nil
	return cowboy and cowboy.Character
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
		base = base,
		animator = animator,
		puff = SteamPuff.new(locomotive),
		squashed = false,
		run = RunTracker.new(locomotive),
		course = CourseView.new(locomotive, base),
		scenery = TrackScroll.new(locomotive, base),
		rider = RoofRider.new(locomotive),
		barrels = BarrelView.new(locomotive, base),
		gold = GoldView.new(locomotive, base),
		rules = nil,
		predicted = nil,
		splat = nil,
		cowboy = nil,
		cowboySince = 0,
		connections = {},
	}
	tracked[locomotive] = entry
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
	-- The cowboy's bridge splats (our own cowboy's we draw at once, from CowboyRules); the driver hears of them.
	local function onSplat(fresh: boolean)
		local at = locomotive:GetAttribute(Names.SplatAt)
		if typeof(at) == "number" and locomotive ~= riding then
			entry.splat = at
			if fresh and locomotive == mine then
				faceCam:flash("철퍽!", SPLAT_WORD)
			end
		end
	end
	table.insert(entry.connections, locomotive:GetAttributeChangedSignal(Names.SplatAt):Connect(function()
		onSplat(true)
	end))
	onSplat(false)
	table.insert(entry.connections, locomotive:GetAttributeChangedSignal(Names.MissedMail):Connect(function()
		local missed = locomotive:GetAttribute(Names.MissedMail)
		if typeof(missed) == "number" and missed > 0 and (locomotive == mine or locomotive == riding) then
			faceCam:flash("우편 놓침!", CRASH_WORD)
		end
	end))
	for _, name in { Names.Passed, Names.Crashes, Names.MailTaken, Names.GoldTaken, Names.CowboyUserId } do
		table.insert(entry.connections, locomotive:GetAttributeChangedSignal(name):Connect(function()
			if locomotive == shownInWindow then
				showScore(locomotive)
			end
		end))
	end
	-- Riding: this train's cowboy is the player (the server can name the cowboy after the train is built).
	local function onCowboy()
		local isCowboy = locomotive:GetAttribute(Names.CowboyUserId) == player.UserId
		if isCowboy and riding ~= locomotive then
			-- A new train can be named before the old one goes (the order is not guaranteed): let go of the old first.
			local old = riding and tracked[riding]
			if old and old.rules then
				old.rules:stop(player.Character)
				old.rules = nil
			end
			riding = locomotive
			entry.rules = CowboyRules.new(locomotive, base)
			apexRing:hide() -- the old train's ring, if any
			local at = locomotive:GetAttribute(Names.JumpAt)
			if typeof(at) == "number" then
				apexRing:start(at) -- a jump already under way (an old one just hides)
			end
		elseif not isCowboy and riding == locomotive then
			riding = nil
			apexRing:hide()
			local rules = entry.rules
			entry.rules = nil
			if rules then
				rules:stop(player.Character)
			end
		end
		refreshInput()
		refreshWindow()
	end
	table.insert(entry.connections, locomotive:GetAttributeChangedSignal(Names.CowboyUserId):Connect(onCowboy))
	if locomotive:GetAttribute(Names.OwnerUserId) == player.UserId then
		mine = locomotive
		ownCrashing = false
		DriverCamera.follow(locomotive)
		refreshInput()
		refreshWindow()
		sentSquash = nil -- send it again: also replaces a state the server still holds back from the old train
		refreshOwnSquash(Workspace:GetServerTimeNow())
	else
		local function follow()
			setSquashed(locomotive, locomotive:GetAttribute(Names.Squashed) == true)
		end
		table.insert(entry.connections, locomotive:GetAttributeChangedSignal(Names.Squashed):Connect(follow))
		follow()
		-- Its jumps, drawn from when they started on the server; the cowboy riding it gets the timing ring.
		local function jumped()
			local at = locomotive:GetAttribute(Names.JumpAt)
			if typeof(at) == "number" then
				entry.animator:jump(at)
				if locomotive == riding then
					apexRing:start(at)
				end
			end
		end
		table.insert(entry.connections, locomotive:GetAttributeChangedSignal(Names.JumpAt):Connect(jumped))
		jumped()
	end
	onCowboy()
	onCrashIndex() -- a train that arrives in the middle of a crash (joining late) shows it too
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
		entry.barrels:destroy()
		entry.gold:destroy()
	end
	if mine == instance then
		mine = nil
		ownCrashing = false
	end
	if riding == instance then
		riding = nil
		apexRing:hide()
		if entry and entry.rules then
			entry.rules:stop(player.Character)
		end
	end
	refreshInput()
	refreshWindow()
end)
for _, instance in CollectionService:GetTagged(Names.LocomotiveTag) do
	task.spawn(track, instance)
end

RunService.RenderStepped:Connect(function(dt: number)
	local now = Workspace:GetServerTimeNow()
	for locomotive, entry in tracked do
		entry.animator:setRunSpeed(entry.run:speed(now))
		entry.animator:update(dt, now)
		local distance = entry.run:distance(now)
		entry.course:update(distance)
		entry.scenery:update(distance)
		entry.barrels:update(distance)
		entry.gold:update(distance)
		-- The cowboy rides the roof just drawn, lying flat while it is flat.
		local character = cowboyCharacter(locomotive)
		if character ~= entry.cowboy then
			entry.cowboy = character
			entry.cowboySince = now
		end
		if character then
			local isMe = locomotive == riding
			local floor = entry.rider:update(character, isMe)
			local splat = entry.splat
			local paper = splat ~= nil and splat >= entry.cowboySince -- this very character was made paper
			local thickness = if paper then PaperPath.thickness(now - (splat :: number), Config.Cowboy.SplatSeconds, Config.Paper) else 1
			PaperPose.set(character, thickness)
			local flying = paper and now - (splat :: number) < Config.Cowboy.SplatSeconds
			local lie = if floor and not flying then entry.animator:flatness() else 0 -- paper flies flat out
			CowboyPose.set(character, lie)
			local rules = entry.rules
			if isMe and rules then
				local event, bag = rules:update(character, floor, lie, distance)
				if event == "splat" then
					entry.splat = now
					splatRemote:FireServer(now)
					faceCam:flash("철퍽!", SPLAT_WORD)
				elseif event == "fell" then
					faceCam:flash("앗!", SPLAT_WORD)
				elseif event == "barrel" then
					faceCam:flash("쿵!", SPLAT_WORD)
				elseif event == "mail" then
					mailRemote:FireServer(bag)
					faceCam:flash("우편!", MAIL_WORD)
				elseif event == "gold" then
					goldRemote:FireServer(bag)
					faceCam:flash("금화!", GOLD_WORD)
				end
			end
		end
	end
	PaperPose.flush() -- a cowboy drawn thin last frame but not this one goes back to their own shape
	apexRing:update(now)
	-- Our own train: a squash held through a jump folds it on landing; the jump button greys out while it cannot jump.
	refreshOwnSquash(now)
	local own = mine
	local entry = own and tracked[own]
	if entry and jumpControl then
		jumpControl.setEnabled(canJump(entry, now))
	end
	-- Our own bridges, judged from the shape just drawn; the server confirms.
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
