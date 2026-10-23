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
}

-- How the player's avatar becomes the locomotive (studs unless noted).
Config.Locomotive = {
	AvatarScale = 2.2, -- the whole avatar is scaled by this first
	TorsoLengthStretch = 2.4, -- then the torso is stretched along the track into the boiler
	TorsoThickness = 1.7, -- and made thicker (lying on its back, chest up, this is the boiler height)
	HeadToBoiler = 1.15, -- head height / boiler height (the face covers the front like a smokebox)
	DeckHeight = 1.6, -- boiler bottom above the rails
	WheelRadius = 1.3,
	WheelWidth = 0.6,
	WheelTrack = 2.3, -- wheel centre distance from the middle line (the rails sit under the wheels)
	WheelsPerSide = 3,
	FrameThickness = 0.5,
	ChimneyFromNeck = 1.8, -- chimney distance behind the neck end of the boiler
	ChimneyHeight = 2.6, -- above the boiler top
	ChimneySink = 0.8, -- the chimney also reaches this far into the boiler: the torso mesh is rounder than its box
	ChimneyDiameter = 1.3,
	CapHeight = 0.7,
	CapDiameter = 2.3,
	CowcatcherLength = 2.4,
	Colors = {
		Iron = Color3.fromRGB(46, 44, 48),
		Brass = Color3.fromRGB(196, 150, 64),
		Wood = Color3.fromRGB(122, 78, 46),
	},
}

-- Prototype ground and rails.
Config.Stage = {
	Slots = 4, -- one locomotive track per player
	SlotSpacing = 36,
	RailHeight = 0.4, -- rail top above the ground
	RailLength = 120,
	SleeperSpacing = 3,
}

Config.Camera = {
	StartZoom = 26, -- the camera starts this far from the locomotive, then the player can zoom freely
	StartHoldSeconds = 1.5, -- the start view is kept this long (Roblox's own camera reset can come a little later)
	MinZoomAfterStart = 8,
}

return Config
