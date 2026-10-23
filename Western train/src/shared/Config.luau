--!strict
-- Numbers to tune for the Western train prototype (starting values; adjust after playtests).
-- Required by server and client. Requires nothing.

local Config = {}

-- The squash (S key): spring value 0 = normal shape, 1 = fully flat. Negative values (the overshoot after letting
-- go) make the locomotive taller and thinner for a moment, which is the "뽀용" bounce.
Config.Squash = {
	HeightAtFull = 0.4, -- height multiplier at value 1
	WidthAtFull = 1.3, -- width multiplier at value 1
	LengthAtFull = 1.08, -- length multiplier at value 1
	-- Spring toward flat (press) and back to normal (release): frequency in rad/s, damping ratio below 1 overshoots.
	PressFrequency = 24,
	PressDamping = 0.6,
	ReleaseFrequency = 18,
	ReleaseDamping = 0.32,
	-- Hard limits for the spring value, so a long frame hitch can never fling the shape.
	MinValue = -0.6,
	MaxValue = 1.4,
	RestEpsilon = 0.002, -- the spring counts as settled below this distance and speed
	ChimneyExponent = 1.8, -- the chimney folds harder than the body: its height factor is raised to this power
	MaxMessagesPerSecond = 20, -- beyond this rate the server holds a player's latest state until the second is over
	SteamPuffCount = 18, -- particles in the side puff when the body folds or springs back
	-- The legs sticking out of the cab swing about the hip as the body moves (they lag behind it): radians per unit of
	-- spring speed, opposite for the two legs. Up to LegKickUp upward; downward up to LegKickDown at full height, less
	-- as the body folds (none when fully flat), so the shoes never dig into the rails.
	LegKickGain = 0.07,
	LegKickUp = 0.7,
	LegKickDown = 0.35,
}

-- The locomotive wearing the player's avatar (studs unless noted; Z distances are measured back from the boiler
-- front): face on the smokebox, torso standing as the cab, arms as the coupling rods, legs sticking out of the back
-- (the soles are the rear buffers).
Config.Locomotive = {
	DeckHeight = 2.0, -- frame top and boiler bottom above the rails
	BoilerDiameter = 4.0,
	BoilerLength = 7.5,
	BandsAt = { 0.4, 0.8 }, -- brass boiler bands, as shares of the boiler length
	DoorDiameter = 4.4, -- iron smokebox door behind the face, a little wider than the boiler
	DoorThickness = 0.35,
	HeadToBoiler = 0.95, -- face height / boiler diameter
	HeadDepth = 0.6, -- the head is flattened front to back to this share, so it reads as the smokebox face
	CabWidth = 4.4,
	CabDepth = 3.0,
	CabHeight = 5.4, -- walls above the deck: the lower torso (waist) and the upper torso on it
	CabWaist = 1.0,
	RoofThickness = 0.3,
	RoofOverhang = 0.3,
	WheelTrack = 2.0, -- wheel centre distance from the middle line (the rails sit under the wheels)
	WheelWidth = 0.5,
	TyreThickness = 0.2, -- the iron rim around each red wheel
	DriverRadius = 1.5, -- the two big driving wheels on each side
	DriversAt = { 4.4, 8.0 },
	LeadRadius = 0.85, -- the small leading wheel under the face
	LeadAt = 1.2,
	CrankRadius = 0.8, -- the rods (arms) circle this far from the driving wheel centres
	CrankTurnsPerSecond = 1.5, -- the rods' idle speed until the server starts the run; then they follow the run speed
	ArmThickness = 0.8,
	HandSize = 1.3, -- the hand is a fist bigger than the rod (width and height), gripping the front crank pin
	HandLength = 0.8, -- the fist along the rod
	PinLength = 0.3, -- crank pins stick out this far from the wheels; the arms ride on them
	LegSpread = 1.3, -- each leg's distance from the middle line; they come out of the cab back at the waist (the pants)
	LegLength = 2.4, -- hip to ankle (thigh and shin)
	LegThickness = 0.85,
	FootLength = 1.2, -- the shoe's toe-to-heel length; with the toes up it is the buffer's height
	FrameThickness = 0.6,
	BeamAt = -1.6, -- red buffer beam front (in front of the boiler, under the face)
	BeamWidth = 4.8,
	BeamHeight = 0.7,
	ChimneyAt = 1.9,
	ChimneyHeight = 2.0, -- above the boiler top
	ChimneySink = 0.6, -- the chimney also reaches this far into the boiler, so no gap shows on the curve
	ChimneyDiameter = 1.1,
	CapHeight = 0.6,
	CapDiameter = 1.9,
	DomeAt = 4.6,
	DomeSize = 1.6,
	LampAt = 0.6,
	CowcatcherLength = 2.0,
	CowcatcherSlats = 5,
	Colors = {
		Boiler = Color3.fromRGB(52, 88, 64), -- deep green, so the player's face stands out (owner pick 2026-10-23)
		Wheel = Color3.fromRGB(140, 40, 30), -- dark red wheels like the old American 4-4-0s; the dark sleeves show on them
		Iron = Color3.fromRGB(46, 44, 48),
		Brass = Color3.fromRGB(196, 150, 64),
		Wood = Color3.fromRGB(122, 78, 46),
		Beam = Color3.fromRGB(128, 38, 30), -- dark brick red (not Thomas's bright red)
		Lamp = Color3.fromRGB(255, 214, 120),
	},
}

-- The boxcars behind the locomotive: the cowboy's roofs to run on. They squash with the locomotive (Z distances are
-- from each car's front end).
Config.Cars = {
	Count = 2,
	Length = 10,
	Gap = 0.8, -- between the cars, and between the locomotive's shoes and the first car
	Width = 4.6,
	RoofTop = 7.7, -- the same height as the cab roof; a gangplank crosses from the cab roof over the legs to the first car
	RoofThickness = 0.3,
	RoofOverhang = 0.3,
	WalkWidth = 1.6, -- the plank walkway along the middle of each roof, and the gangplank from the cab roof
	WalkThickness = 0.12,
	FloorHeight = 2.0, -- the car floor (the same deck height as the locomotive)
	WheelRadius = 0.9,
	WheelsAt = { 1.4, 3.2 }, -- each end's two wheels, from that end
	DoorWidth = 3.2,
	Colors = {
		Body = Color3.fromRGB(122, 50, 34), -- oxide-red boxcar
		Trim = Color3.fromRGB(64, 36, 26),
		Roof = Color3.fromRGB(70, 66, 64),
	},
}

-- The cowboy on the roof.
Config.Cowboy = {
	FlatHeight = 1.4, -- lying flat on a squashed roof, the cowboy is this tall above it (measured 1.38 in Studio)
	FlatDrop = 1.4, -- the lying body is drawn this far further down (turned face down it lies about 1.1 below the
	-- root, which stands 3 above the roof; 1.4 more puts it on the roof - measured in Studio)
	OnRoof = 0.6, -- the feet within this of a roof count as standing on it
	OthersReach = 3, -- other players' cowboys: extra reach down to their roof (their place arrives a little late)
	FloorThickness = 0.6, -- the invisible roof floors
	BridgeMargin = 0.5, -- a bridge counts as over the cowboy this much beyond its girder (along and across)
	SplatSeconds = 1.2, -- after a bridge hits the cowboy or the cowboy falls off: back on the last car after this
	KnockBack = 28, -- studs per second backward when a bridge hits the cowboy
	KnockUp = 14,
	FellBelow = 1.0, -- feet lower than this above the rail tops, on no roof: the cowboy is off the train
	SpawnLift = 3.5, -- the root above a roof when the cowboy is put on the last car
}

-- A stand-in driver for a cowboy without a partner (Studio testing: set the Workspace attribute Names.SoloCowboy): it
-- squashes a little before each bridge and lets go a little after.
Config.Bot = {
	LeadStuds = 8, -- squash when the front is this far from the bridge
	TrailStuds = 2, -- let go when the back is this far past it
}

-- Prototype ground and rails (the server's), and the scenery each client slides past the locomotives.
Config.Stage = {
	Slots = 4, -- one track per crew (a driver and a cowboy)
	SlotSpacing = 36,
	RailHeight = 0.4, -- rail top above the ground
	RailLength = 480, -- longer than the view ahead and behind (Config.Run)
	SleeperSpacing = 3,
	RoadsideProps = 16, -- cacti and rocks along each track, spread over the view, both sides
	RoadsideNear = 7, -- their distance from the track's middle line
	RoadsideFar = 13,
	Colors = {
		Sand = Color3.fromRGB(214, 176, 120),
		Rail = Color3.fromRGB(92, 88, 86),
		Sleeper = Color3.fromRGB(96, 66, 44),
		Cactus = Color3.fromRGB(86, 120, 64),
		Rock = Color3.fromRGB(150, 116, 86),
	},
	-- A light desert haze (Lighting Atmosphere) that hides the far ends of the rails.
	Haze = {
		Density = 0.32,
		Offset = 0.15,
		Color = Color3.fromRGB(232, 206, 168),
		Decay = Color3.fromRGB(196, 150, 104),
		Glare = 0,
		Haze = 1.4,
	},
}

-- The run toward the low bridges: the locomotive stands still and the world moves back past it.
Config.Run = {
	Speed = 24, -- studs per second
	StartDelay = 3, -- seconds after the locomotive appears before the world starts moving
	CrashSeconds = 2.2, -- the stamp gag; then the run jumps back to a little before that bridge
	ResumeDelay = 1.0, -- after the jump back, a moment before moving again
	RestartLead = 60, -- run distance before the crashed bridge where the run starts again: the train's front is then
	-- about 38 studs from it (the run distance is measured at the train's middle), and the bridge before it is behind
	-- the train's back (the smallest gap allows up to about 77)
	HoldSeconds = 1.0, -- after a hit seen on this client, how long it waits for the server's crash before following on
	PassTolerance = 0.35, -- seconds of network delay the server allows for a press when it checks a pass
	ReleaseGrace = 0.15, -- and for a release just before the bridge's end (the body takes about 0.05 s to rise above it)
	HistorySeconds = 10, -- how much of each driver's squash history the server keeps
	PredictionSeconds = 2, -- a crash this client predicted is matched with the server's crash for this long
	ReportTimeout = 1.5, -- the server judges a bridge alone this long after it passed if the driver said nothing
	ViewAhead = 220, -- bridges, sleepers and roadside props are drawn this far ahead
	ViewBehind = 60,
	CrashJolt = -9, -- spring speed added on a crash: the body stretches up and wobbles, the legs flail
	Stars = { -- circling above the face after a crash
		Count = 5,
		Size = 0.7,
		Radius = 2.6, -- around the head's middle line
		Lift = 0.6, -- above the head's top
		TurnsPerSecond = 0.8,
		Color = Color3.fromRGB(255, 214, 90),
	},
}

-- The low bridges over the track.
Config.Bridge = {
	FirstAt = 150, -- run distance of the first bridge (about 6 s after the start)
	Gaps = { 130, 110, 150, 100, 120 }, -- between bridges, repeating (uneven, so the rhythm does not lull)
	Clearance = 5.0, -- the girder's underside above the rails: the standing train (7.7 to the roofs, 8.6 to the
	-- chimney cap) hits it, a flat one (about 3.1) passes, and so does a cowboy lying flat on it (about 4.5)
	GirderHeight = 3.0,
	Depth = 6, -- along the track
	Span = 10, -- between the piers (the wheels and rods are about 6.7 wide)
	PierWidth = 2,
	StampFill = 0.9, -- the face stamp's height as a share of the girder
	StampThickness = 0.12,
	Colors = {
		Stone = Color3.fromRGB(176, 140, 104),
		Wood = Color3.fromRGB(110, 72, 44),
	},
}

-- The face window (right side of the screen): the play camera looks from behind, so this shows the player's own face.
-- The middle of the screen is kept clear for the track ahead (the bridges come from there), the top right for the
-- player list and the bottom right for the touch buttons. Sizes are shares of the screen height; the frame uses
-- Config.Locomotive.Colors Wood and Brass.
Config.FaceCam = {
	Height = 0.2,
	BigHeight = 0.3, -- while the locomotive is flat or crashed
	Top = 0.22, -- the window's top edge, as a share of the screen height below the Roblox top bar
	GrowSeconds = 0.15,
	ShrinkSeconds = 0.45, -- back to normal with a small bounce
	Margin = 12, -- pixels from the screen's right edge
	BorderThickness = 3,
	FlashSeconds = 0.9, -- how long a word (쾅!, 통과!) stays over the window before fading
	Distance = 11, -- camera distance in front of the face (studs)
	FieldOfView = 40,
	ViewDirection = Vector3.new(0.25, 0.12, -1), -- from the face toward the camera, locomotive space (forward is -Z)
	Sky = Color3.fromRGB(150, 196, 232),
	-- Dimmer than the ViewportFrame defaults (ambient 200, light 140 grey) and the first try (ambient 150, near-white
	-- light), which washed a light skin colour out to white.
	Ambient = Color3.fromRGB(105, 105, 110),
	Light = Color3.fromRGB(185, 178, 165),
	LightDirection = Vector3.new(-0.4, -1, 0.6), -- locomotive space: sunlight falling onto the face from above
}

Config.Camera = {
	StartZoom = 26, -- the camera starts this far from the locomotive, then the player can zoom freely
	StartHoldSeconds = 1.5, -- the start view is kept this long (Roblox's own camera reset can come a little later)
	MinZoomAfterStart = 8,
}

return Config
