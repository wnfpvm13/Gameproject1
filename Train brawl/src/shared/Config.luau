--!strict
-- Every number to tune for Train brawl, in one place (studs and seconds; Y is height above the rail tops, and in a
-- train's own space -Z is ahead). Requires nothing.

local Config = {}

-- The arena: big trains side by side on parallel tracks. They stand still in the world; the scenery scrolls past
-- (Config.Run), so everything players stand on keeps still for physics.
Config.Arena = {
	Trains = 2,
	-- Between the roof edges of two trains: wider than a jump on the flat (about 8.7 studs with Roblox's default
	-- jump), so crossing takes a plank or a big hit.
	Gap = 12,
	RoofWidth = 10,
	-- Each train front to back: its cars. roof = the walkable top above the rails.
	Cars = {
		{ kind = "Locomotive", length = 18, roof = 11.5 },
		{ kind = "Boxcar", length = 20, roof = 10 },
		{ kind = "Boxcar", length = 20, roof = 10 },
	},
	CarGap = 0.5, -- between two cars of a train (well under a character's thickness, so nobody slips through)
	-- Planks across the gap between neighbouring trains, in the middle of these cars (both trains' cars there have
	-- the same roof height).
	PlankCars = { 2, 3 },
	PlankWidth = 4,
	PlankThickness = 0.4,
	PlankOverlap = 1, -- how far a plank lies on each roof
	-- The sand's top, under the rail tops (y 0). It is solid: a fighter who falls off lands on it and is left behind
	-- (the fall line is above it, so landing there is always out).
	GroundY = -1,
	WaitingRoomHeight = 70, -- the waiting room (and the stands for the knocked out) floats this high over the middle
	WaitingRoomSize = 36,
	WaitingRoomWall = 14, -- glass walls higher than a jump off someone's head
	Colors = {
		Boxcar = Color3.fromRGB(150, 58, 40),
		Roof = Color3.fromRGB(62, 58, 60),
		Boiler = Color3.fromRGB(52, 88, 64),
		Cab = Color3.fromRGB(40, 38, 42),
		Wheel = Color3.fromRGB(140, 40, 30),
		Plank = Color3.fromRGB(150, 110, 66),
		Room = Color3.fromRGB(210, 196, 170),
	},
}

-- The scenery that slides past to show the trains running.
Config.Run = {
	Speed = 30, -- studs per second backward (+Z)
	ViewAhead = 260, -- the scenery is laid out this far ahead of the middle and this far behind
	ViewBehind = 160,
	SleeperSpacing = 3,
	RoadsideProps = 20,
	RoadsideNear = 22, -- props stand this far from the arena's middle line, on both sides
	RoadsideFar = 60,
	Colors = {
		Sand = Color3.fromRGB(214, 176, 120),
		Rail = Color3.fromRGB(92, 88, 86),
		Sleeper = Color3.fromRGB(96, 66, 44),
		Cactus = Color3.fromRGB(86, 120, 64),
		Rock = Color3.fromRGB(150, 116, 86),
	},
}

-- The bat: a swing hits whoever stands in a cone in front of the swinger, once per swing.
Config.Bat = {
	-- From the swinger's middle to the target's, along the ground. As the hit lands, the drawn bat's tip passes about
	-- 4.2 in front of the middle at shoulder height (measured in Studio, 2026-10-24) and a body is about 1 thick, so
	-- the hits match the picture with a little to spare.
	Reach = 5.5,
	-- Extra reach the server allows for the network delay (a target running at 16 moves about 1.6 in 0.1 s). The
	-- server takes up to Reach + ReachSlack = 7 for a target standing still, so keep it small.
	ReachSlack = 1.5,
	HeightReach = 5, -- the target's middle within this much higher or lower
	HalfAngle = 70, -- degrees each side of where the swinger faces
	Cooldown = 0.55,
	CooldownSlack = 0.1, -- the server takes a swing this much early (clock and network jitter)
	SwingSeconds = 0.32, -- the drawn swing
	HitAt = 0.12, -- seconds into the swing when it lands
	-- The knock: speed away from the swinger along the ground, and upward. By the plain formula the flight carries
	-- about 5.1 (BatMath.flightDistance); measured in Studio a body travels about 6.2 in all, as it lands lying lower
	-- and slides a little before it gets up (2026-10-24; Push 28 went about 10.6, a whole roof). So: hit across the
	-- roof from the middle, you go off; hit from the near half toward the far side, or along the train, you stay on.
	Push = 18,
	Lift = 28,
	Length = 4.5, -- a big cartoon bat, so the reach shows
	Thickness = 0.55,
	Color = Color3.fromRGB(196, 150, 90),
}

-- Being knocked: stiff while flying, back on the feet after landing.
Config.Knock = {
	MinSeconds = 0.5, -- stiff at least this long
	MaxSeconds = 2.5, -- and at most this long, landed or not
	GroundReach = 0.6, -- the feet within this of something solid count as landed
	PredictForget = 0.6, -- a hit the swinger's screen already showed is not shown again when the server's comes
	-- A swing reaching the server this soon after its swinger was hit was pressed before the hit reached that player's
	-- screen (about a round trip), so it is still taken; later, until MinSeconds, the server refuses swings.
	SwingGrace = 0.25,
}

-- How a hit feels: a sound, a white flash on whoever is hit, and a little shake for the one hit.
Config.Feedback = {
	HitSound = "rbxasset://sounds/swordlunge.wav", -- built into every Roblox client
	SwingSound = "rbxasset://sounds/swordslash.wav",
	HitVolume = 0.8,
	SwingVolume = 0.4,
	HitStopSeconds = 0.06, -- whoever is hit holds still this long before flying (the beat that makes a hit land)
	FlashSeconds = 0.15,
	ShakeSeconds = 0.15,
	ShakeStuds = 0.5,
}

-- Falling off: feet below this much under the lowest roof have missed the train. From there the body lies down and
-- slides backward with the ground (left behind by the train) until it is taken to the stands.
Config.Fall = {
	Margin = 4,
	ShowSeconds = 1.6, -- the fall plays this long before the fighter goes to the stands (a sandbag is removed)
}

-- Rounds: wait for players, count down on the roofs, fight until one is left.
Config.Round = {
	MinPlayers = 2, -- counting sandbags in solo mode
	CountdownSeconds = 3,
	MaxSeconds = 180, -- then it ends with everyone still standing
	EndSeconds = 5, -- the result shows this long
	IntermissionSeconds = 4, -- in the waiting room before the next count
	KillCreditSeconds = 6, -- a fall counts as a KO for whoever hit the player within this long before
}

-- Studio-only practice (Workspace attribute Names.Solo): sandbags that wander the roofs and count as players.
Config.Sandbag = {
	Count = 3,
	WanderSeconds = 2.5, -- a new spot to walk to this often
	WalkSpeed = 8,
}

return Config
