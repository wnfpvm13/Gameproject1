--!strict
-- Effects: the flying chair firing (an explosion — bigger the fewer lives were left, a white flash for the biggest —,
-- the seat flap snapping back on its hinge, "펑", smoke and confetti),
-- the splash where the player hits the water (no sound: owner 2026-10-24), the elimination buzzer and red flash, floating emoji reactions, the presenter's sound
-- buttons and a seat bell's ding with its light (bundle 6b). Since 2026-10-26 (owner, the recommended choice) the game's
-- own moments have sounds too (`cue`, the bomb's ticking `ticking`) and the winners get confetti and a fanfare
-- (`celebrate`).
-- The server only sends signals; every client animates the flap itself (a server-moved flap would stutter).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BannedWords"):WaitForChild("Config"))

local Fx = {}

local CONFETTI = {
	Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 200, 70), Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(140, 230, 120), Color3.fromRGB(220, 130, 255),
}

local flash: Frame
local whiteFlashFrame: Frame -- (its own frame: the elimination's red flash may run at the same time)
local buzzer: Sound
local bang: Sound
local bellSound: Sound
local presenterSounds: { Sound } = {} -- the presenter's sound buttons (Config.PRESENTER_SOUNDS order)
local cues: { [string]: Sound } = {} -- the game's moments (Fx.cue)
local tick: Sound -- the bomb's ticking (Fx.ticking)
local rolls = 0 -- the roulette's drum rolls started (Fx.stopRoll cancels the waiting one and stops the playing one)
local rolling: Sound? = nil
local restOf: { [BasePart]: CFrame } = {} -- each hinge's resting CFrame (taken the first time it fires)
local playing: { [BasePart]: number } = {} -- hinge -> current animation number

local effects: SoundGroup? = nil -- every game sound plays in the player's "효과음" group (bundle 11a; copies keep it)

local function sound(name: string, id: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume
	s.SoundGroup = effects
	s.Parent = SoundService
	return s
end

-- Plays a copy, so two launches (or sound buttons) close together do not cut each other. The copy goes when it ends;
-- in case it never does, twice its length after it loaded (at least SOUND_COPY_SECONDS; the drum roll runs 8.3 s),
-- or SOUND_LOAD_GIVE_UP seconds if it never loads.
local SOUND_COPY_SECONDS = 8
local SOUND_LOAD_GIVE_UP = 30
local function playCopy(template: Sound)
	local copy = template:Clone()
	copy.Parent = SoundService
	copy:Play()
	copy.Ended:Once(function()
		copy:Destroy()
	end)
	local function expire()
		Debris:AddItem(copy, math.max(SOUND_COPY_SECONDS, copy.TimeLength) * 2)
	end
	if copy.IsLoaded then
		expire()
	else
		copy.Loaded:Once(expire)
		Debris:AddItem(copy, SOUND_LOAD_GIVE_UP)
	end
end

-- `group`: the sound group every game sound plays in (client Sound, the player's "효과음" volume).
function Fx.init(group: SoundGroup)
	effects = group
	local gui = Instance.new("ScreenGui")
	gui.Name = "BannedWordsFx"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui
	whiteFlashFrame = flash:Clone()
	whiteFlashFrame.Name = "WhiteFlash"
	whiteFlashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	whiteFlashFrame.Parent = gui

	buzzer = sound("Buzzer", Config.SOUND_BUZZER, 0.6)
	bang = sound("Bang", Config.SOUND_BANG, 0.8)
	bellSound = sound("Bell", Config.SOUND_BELL, 0.7)
	for i, entry in Config.PRESENTER_SOUNDS do
		presenterSounds[i] = sound("PresenterSound" .. i, entry.id, 0.7)
	end
	cues.right = sound("Right", Config.SOUND_RIGHT, Config.SOUND_VOLUME)
	cues.win = sound("Win", Config.SOUND_WIN, Config.SOUND_VOLUME)
	cues.roll = sound("Roll", Config.SOUND_ROLL, Config.SOUND_VOLUME)
	cues.whistle = sound("Whistle", Config.SOUND_WHISTLE, Config.SOUND_VOLUME)
	cues.fire = sound("Fire", Config.SOUND_BANG, Config.SOUND_VOLUME)
	tick = sound("Tick", Config.SOUND_TICK, Config.SOUND_VOLUME * 0.8)
	tick.Looped = true
end

-- One of the game's moments: "right" (my answer was right), "win" (the round's winners), "whistle" (무궁화's red
-- light), "fire" (총잡이 결투's "발사!"), "roll" (the roulette spins: `seconds` until it stops, the crash meets it).
function Fx.cue(name: string, seconds: number?)
	local template = cues[name]
	if not template then
		return
	end
	if name == "roll" and seconds then
		-- (started so its crash lands on the pick: later for a long spin, part-way in for a short one)
		rolls += 1
		local mine = rolls
		local wait = math.max(0, seconds - Config.SOUND_ROLL_CRASH_AT)
		task.delay(wait, function()
			if mine ~= rolls then
				return -- (stopped meanwhile)
			end
			local copy = template:Clone()
			copy.TimePosition = math.max(0, Config.SOUND_ROLL_CRASH_AT - seconds)
			copy.Parent = SoundService
			copy:Play()
			rolling = copy
			Debris:AddItem(copy, 12)
		end)
		return
	end
	playCopy(template)
end

-- The roulette is over or stopped: no drum roll waiting, none playing on.
function Fx.stopRoll()
	rolls += 1
	if rolling then
		rolling:Stop()
		rolling = nil
	end
end

-- The bomb's ticking: on while the bomb goes round, off when it is over.
function Fx.ticking(on: boolean)
	if on and not tick.IsPlaying then
		tick:Play()
	elseif not on and tick.IsPlaying then
		tick:Stop()
	end
end

local BELL_LIGHT_SECONDS = 0.6
local bellRings: { [Model]: number } = {}
-- A seat bell rang: the ding, and that bell's light (map contract: Bell.Light holds a PointLight) for a moment.
function Fx.bellRang(bell: Model?)
	playCopy(bellSound)
	local light = bell and bell:FindFirstChild("Light")
	local glow = light and light:FindFirstChildOfClass("PointLight")
	if not (bell and light and light:IsA("BasePart") and glow) then
		return
	end
	bellRings[bell] = (bellRings[bell] or 0) + 1
	local ring = bellRings[bell]
	glow.Enabled = true
	light.Material = Enum.Material.Neon
	task.delay(BELL_LIGHT_SECONDS, function()
		if bellRings[bell] == ring then
			glow.Enabled = false
			light.Material = Enum.Material.SmoothPlastic
		end
	end)
end

-- The presenter pressed a sound button (everyone hears it).
function Fx.presenterSound(index: number)
	local template = presenterSounds[index]
	if template then
		playCopy(template)
	end
end

local function anchorAt(position: Vector3, lifetime: number): Part
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Parent = workspace
	task.delay(lifetime, function()
		anchor:Destroy()
	end)
	return anchor
end

local function emitter(parent: Instance, props: { [string]: any }, count: number)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	e:Emit(count)
end

-- The bang at the chair: a white smoke puff, sparks and a little confetti (`size` 1 = normal; a bigger blast throws
-- more of them and a wider puff).
local function burst(position: Vector3, size: number)
	local anchor = anchorAt(position, 3)
	emitter(anchor, {
		Color = ColorSequence.new(Color3.fromRGB(242, 242, 242)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 7 * size) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(6, 14),
		Drag = 4,
		SpreadAngle = Vector2.new(180, 180),
	}, math.round(16 * size))
	emitter(anchor, {
		Color = ColorSequence.new(Color3.fromRGB(255, 225, 130), Color3.fromRGB(255, 120, 40)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(25, 45),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(70, 70),
	}, math.round(24 * size))
	for _, color in CONFETTI do
		emitter(anchor, {
			Color = ColorSequence.new(color),
			Size = NumberSequence.new(0.35),
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(14, 28),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -30, 0),
			RotSpeed = NumberRange.new(-300, 300),
			Rotation = NumberRange.new(0, 360),
		}, math.round(6 * size))
	end
end

local function chairOf(seatIndex: number): (BasePart?, BasePart?)
	local hall = workspace:FindFirstChild("PoolHall")
	local chairs = hall and hall:FindFirstChild("Chairs")
	if not chairs then
		return nil, nil
	end
	for _, chair in chairs:GetChildren() do
		local seat = chair:FindFirstChild("Seat") :: BasePart?
		if seat and seat:GetAttribute("SeatIndex") == seatIndex then
			local flap = chair:FindFirstChild("Flap")
			return seat, flap and flap:FindFirstChild("Hinge") :: BasePart?
		end
	end
	return nil, nil
end

-- Flap angle (degrees) t seconds after the launch: snap open with a small overshoot, settle, hold, ease back down.
local function flapAngle(t: number): number
	local open, overshoot = Config.CHAIR_FLAP_DEGREES, Config.CHAIR_OVERSHOOT_DEGREES
	local snapEnd = Config.CHAIR_SNAP_SECONDS
	local settleEnd = snapEnd + Config.CHAIR_SETTLE_SECONDS
	local holdEnd = settleEnd + Config.CHAIR_HOLD_SECONDS
	local recoverEnd = holdEnd + Config.CHAIR_RECOVER_SECONDS
	if t < snapEnd then
		return (open + overshoot) * (1 - (1 - t / snapEnd) ^ 3)
	elseif t < settleEnd then
		return open + overshoot * (1 - (t - snapEnd) / Config.CHAIR_SETTLE_SECONDS)
	elseif t < holdEnd then
		return open
	elseif t < recoverEnd then
		local a = (t - holdEnd) / Config.CHAIR_RECOVER_SECONDS
		return open * (1 + math.cos(math.pi * a)) / 2
	end
	return 0
end

local function snapFlap(hinge: BasePart)
	local rest = restOf[hinge] or hinge.CFrame
	restOf[hinge] = rest
	local number = (playing[hinge] or 0) + 1
	playing[hinge] = number
	local started = os.clock()
	local total = Config.CHAIR_SNAP_SECONDS + Config.CHAIR_SETTLE_SECONDS + Config.CHAIR_HOLD_SECONDS + Config.CHAIR_RECOVER_SECONDS
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if playing[hinge] ~= number or not hinge.Parent then
			connection:Disconnect()
			return
		end
		local t = os.clock() - started
		if t >= total then
			hinge.CFrame = rest
			playing[hinge] = nil
			connection:Disconnect()
			return
		end
		hinge.CFrame = rest * CFrame.Angles(math.rad(flapAngle(t)), 0, 0)
	end)
end

-- A flying chair fired: the flap snaps back, "펑", smoke at the seat.
-- A launch (`info.size`: 1 normal, bigger the fewer lives were left, owner 2026-10-24).
function Fx.fling(info: { seatIndex: number?, blastAt: Vector3?, size: number? })
	local size = if typeof(info.size) == "number" then math.clamp(info.size, 1, 3) else 1
	playCopy(bang)
	if typeof(info.blastAt) == "Vector3" then
		-- Roblox's own explosion look; it pushes and breaks nothing (the server throws the body).
		local explosion = Instance.new("Explosion")
		explosion.Position = info.blastAt
		explosion.BlastRadius = Config.BLAST_RADIUS * size
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.ExplosionType = Enum.ExplosionType.NoCraters
		explosion.Parent = workspace
		Debris:AddItem(explosion, 3)
	end
	local seat: BasePart?, hinge: BasePart? = nil, nil
	if info.seatIndex then
		seat, hinge = chairOf(info.seatIndex)
	end
	if hinge then
		snapFlap(hinge)
	end
	if seat then
		burst(seat.Position + Vector3.new(0, 1, 0), size)
	end
end

-- A white flash over the screen (the biggest blasts; not with the device's reduced motion, checked by the caller).
function Fx.whiteFlash()
	whiteFlashFrame.BackgroundTransparency = Config.FLASH_WHITE_ALPHA
	TweenService:Create(whiteFlashFrame, TweenInfo.new(Config.FLASH_WHITE_SECONDS, Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

-- The presenter pulled the "날려!" lever on the podium (PoolHall.PodiumSet.Lever: Base, Handle, Knob): the handle
-- swings down LEVER_DEGREES over its base and comes back within LEVER_SECONDS + LEVER_RETURN_SECONDS (no sound of its
-- own: the launch right after it bangs).
local leverRest: { [BasePart]: CFrame } = {}
local leverPulls = 0
function Fx.lever()
	local hall = workspace:FindFirstChild("PoolHall")
	local set = hall and hall:FindFirstChild("PodiumSet")
	local lever = set and set:FindFirstChild("Lever")
	local base = lever and lever:FindFirstChild("Base") :: BasePart?
	if not (lever and base) then
		return
	end
	local moving: { BasePart } = {}
	for _, name in { "Handle", "Knob" } do
		local part = lever:FindFirstChild(name) :: BasePart?
		if part then
			leverRest[part] = leverRest[part] or part.CFrame
			table.insert(moving, part)
		end
	end
	local pivot = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
	leverPulls += 1
	local pull = leverPulls
	local started = os.clock()
	local total = Config.LEVER_SECONDS + Config.LEVER_RETURN_SECONDS
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if pull ~= leverPulls or t >= total then
			if pull == leverPulls then
				for _, part in moving do
					part.CFrame = leverRest[part]
				end
			end
			connection:Disconnect()
			return
		end
		-- Down fast (first 30%), held, then back up.
		local down = math.min(1, t / (Config.LEVER_SECONDS * 0.3))
		local back = math.clamp((t - Config.LEVER_SECONDS) / Config.LEVER_RETURN_SECONDS, 0, 1)
		local angle = math.rad(Config.LEVER_DEGREES) * (1 - (1 - down) ^ 2) * (1 - back)
		local swing = pivot * CFrame.Angles(angle, 0, 0) * pivot:Inverse()
		for _, part in moving do
			part.CFrame = swing * leverRest[part]
		end
	end)
end

-- The player hit the water: a white column, a spray of drops and a ring of mist, sized to read from the show camera
-- (a blast carries them about 40-85 studs out over the pool, 80-130 studs from the camera).
function Fx.splash(position: Vector3)
	local anchor = anchorAt(position + Vector3.new(0, 0.5, 0), 3)
	emitter(anchor, {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(45, 60),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(6, 6),
		Acceleration = Vector3.new(0, -60, 0),
	}, 20)
	emitter(anchor, {
		Color = ColorSequence.new(Color3.fromRGB(235, 250, 255), Color3.fromRGB(150, 215, 240)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 1) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.8) }),
		Lifetime = NumberRange.new(1, 1.5),
		Speed = NumberRange.new(34, 52),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(18, 18),
		Acceleration = Vector3.new(0, -70, 0),
	}, 60)
	emitter(anchor, {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 18) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(10, 16),
		Drag = 3,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(80, 80),
	}, 18)
end

-- Someone went out: the buzzer, and a red flash unless `calm` (the device's reduced motion setting).
-- The round's winners: a fanfare and confetti over each of them (owner 2026-10-26, the recommended choice: the result
-- was one card and a toast).
function Fx.celebrate(winners: { Player })
	playCopy(cues.win)
	for _, player in winners do
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if head then
			local anchor = anchorAt(head.Position + Vector3.new(0, 4, 0), 4)
			for _, color in CONFETTI do
				emitter(anchor, {
					Color = ColorSequence.new(color),
					Size = NumberSequence.new(0.4),
					Lifetime = NumberRange.new(1.6, 2.6),
					Speed = NumberRange.new(12, 22),
					EmissionDirection = Enum.NormalId.Top,
					SpreadAngle = Vector2.new(50, 50),
					Acceleration = Vector3.new(0, -18, 0),
					RotSpeed = NumberRange.new(-300, 300),
					Rotation = NumberRange.new(0, 360),
				}, 14)
			end
		end
	end
end

-- Someone said a word: buzzer + red flash (the launch itself comes with the "Fling" signal).
function Fx.elimination(calm: boolean?)
	buzzer:Play()
	if calm then
		return
	end
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

-- An emoji floats up from above the player's head and fades.
function Fx.reaction(player: Player?, emoji: string)
	local head = player and player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(2, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Text = emoji
	label.Parent = gui
	gui.Adornee = head
	gui.Parent = head
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	task.delay(1.7, function()
		gui:Destroy()
	end)
end

return Fx
