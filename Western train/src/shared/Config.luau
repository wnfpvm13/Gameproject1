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

-- The locomotive wearing the player's avatar (studs unless noted; Z distances are measured back from the boiler
-- front): face on the smokebox, torso standing as the cab, arms as the coupling rods, shoes as the rear buffers.
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
	DriverRadius = 1.5, -- the two big driving wheels on each side
	DriversAt = { 4.4, 8.0 },
	LeadRadius = 0.85, -- the small leading wheel under the face
	LeadAt = 1.2,
	CrankRadius = 0.8, -- the rods (arms) circle this far from the driving wheel centres
	CrankTurnsPerSecond = 1.5, -- the train always looks like it is running (the world will move, not the train)
	ArmThickness = 0.8,
	PinLength = 0.3, -- crank pins stick out this far from the wheels; the arms ride on them
	BufferHeight = 1.9,
	BufferSpread = 1.3, -- shoe buffers' distance from the middle line
	ShinLength = 0.8, -- the lower legs stick out of the cab back this far, the shoes on their ends
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
		Iron = Color3.fromRGB(46, 44, 48),
		Brass = Color3.fromRGB(196, 150, 64),
		Wood = Color3.fromRGB(122, 78, 46),
		Beam = Color3.fromRGB(128, 38, 30), -- dark brick red (not Thomas's bright red)
		Lamp = Color3.fromRGB(255, 214, 120),
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
