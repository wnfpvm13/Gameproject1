--!strict
-- Every number to tune for Train brawl, in one place (studs and seconds; Y is height above the rail tops, and in a
-- train's own space -Z is ahead). Requires nothing.

local Config = {}

-- A kind of car: the shape ArenaLayout.Kind reads (written out again here, as Config requires nothing). The arena's
-- builders pass Config.Arena to ArenaLayout, so the type check catches most drift between the two (a field added
-- on one side fails it); keep them the same by hand.
type CarKind = {
	length: number,
	roof: number,
	roofFrom: number?,
	spawns: { number },
	plank: boolean,
	boiler: { to: number, top: number, width: number }?,
	crates: { { along: number, width: number, length: number, height: number } }?,
	cupola: { from: number, to: number, width: number, height: number }?,
}

-- The arena: big trains side by side on parallel tracks. They stand still in the world; the scenery scrolls past
-- (Config.Run), so everything players stand on keeps still for physics.
Config.Arena = {
	-- Between the roof edges of two trains: wider than a running jump, even one dropping from the highest top to the
	-- lowest across from it, so crossing takes a plank or a big hit. Measured in Studio (2026-10-25, default R15, jump
	-- pressed as late as 1.9 past the edge, where it still stands): a jump crossed 12.75 on the flat, 13.75 dropping 5,
	-- 14.25 dropping 8, never 13 / 14 / 14.5 or 15 — the first 12 was crossed from a roof down onto a flatcar (tests:
	-- JUMP_EXTRA).
	Gap = 15,
	RoofWidth = 10, -- every car is this wide
	CarGap = 0.5, -- between two cars of a train (well under a character's thickness, so nobody slips through)
	-- The kinds of car (ArenaLayout.Kind): length, walkable roof height, spawn spots (shares along the car), whether
	-- planks may rest on the roof, and their extra tops. Flatcars are low decks to drop into and climb out of (the
	-- crates are steps; the bat does not care about them), a caboose's lookout is the highest perch.
	CarKinds = {
		-- A round boiler in front (its top a narrow ridge) and the cab's flat roof over the back 35%.
		Locomotive = { length = 18, roof = 11.5, roofFrom = 0.65, spawns = { 0.82 }, plank = false, boiler = { to = 0.65, top = 11, width = 8 } },
		Tender = { length = 10, roof = 8, spawns = { 0.5 }, plank = true }, -- the coal car behind a locomotive: low and flat
		Boxcar = { length = 20, roof = 10, spawns = { 0.3, 0.7 }, plank = true },
		Flatcar = {
			length = 18,
			roof = 5,
			spawns = { 0.25 },
			plank = true,
			crates = { { along = 0.62, width = 4, length = 4, height = 2.5 }, { along = 0.86, width = 5, length = 3, height = 4.5 } },
		},
		Caboose = { length = 14, roof = 10, spawns = { 0.3 }, plank = true, cupola = { from = 0.55, to = 0.9, width = 6, height = 3 } },
	} :: { [string]: CarKind },
	-- The trains, left to right: their cars front to back, and how far each stands back (+Z) or ahead (-Z), so that
	-- different cars face each other. The middle one is the main stage (spawns fill it first).
	Trains = {
		{ shift = 3, cars = { "Locomotive", "Tender", "Boxcar", "Flatcar" } },
		{ shift = 0, cars = { "Locomotive", "Tender", "Boxcar", "Caboose" } },
		{ shift = -3, cars = { "Locomotive", "Tender", "Flatcar", "Boxcar" } },
	},
	-- Planks across a gap only where two flat tops of the same height face each other along at least PlankWidth
	-- (PlankEdge in from their ends), the widest first, at most PlanksPerGap per gap, PlankSpacing apart.
	PlankWidth = 4,
	PlankThickness = 0.4,
	PlankOverlap = 1, -- how far a plank lies on each roof
	PlankEdge = 0.5,
	PlanksPerGap = 2,
	PlankSpacing = 8,
	-- The sand's top, under the rail tops (y 0). It is solid: a fighter who falls off lands on it and is left behind
	-- (the fall line is above it, so landing there is always out).
	GroundY = -1,
	WaitingRoomHeight = 70, -- the waiting room (and the stands for the knocked out) floats this high over the middle
	WaitingRoomSize = 36,
	WaitingRoomWall = 14, -- glass walls higher than a jump off someone's head
	Colors = {
		Boxcar = Color3.fromRGB(150, 58, 40),
		Tender = Color3.fromRGB(58, 52, 50),
		Coal = Color3.fromRGB(30, 28, 28),
		Flatcar = Color3.fromRGB(120, 84, 52),
		Crate = Color3.fromRGB(176, 132, 80),
		Caboose = Color3.fromRGB(176, 46, 38),
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
	RoadsideClearance = 7, -- props stand at least this far beyond the outermost train's edge
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
	Length = 4.5, -- a big cartoon bat, so the reach shows
	Thickness = 0.55,
	Color = Color3.fromRGB(196, 150, 90),
}

-- Health and what a hit does (the rules are in HitRules; Smash Legends-style): health drops with every hit, and the
-- lower it is the farther a hit pushes. The first hits of a combo are light (a flinch and a short push, no lying
-- down, over before the swinger's next swing, so the one hit can answer); the hit that ends a combo launches (flying,
-- lying down) and leaves its fighter unhittable for a moment; the hit that empties health is a smash (a certain
-- ring-out). Falling off is out at any health. A body travels about 0.35 to 0.42 x the launch push (measured: push 18
-- went 6.2, 24.4 went 10.3, 28 went 10.6, landing lying and sliding a little) and 1.2 to 2 studs from a light hit.
Config.Health = {
	Max = 100,
	HitDamage = 12, -- the 9th hit from full empties it
	LowFraction = 0.3, -- at or under this share the bar goes red and blinks
}

Config.Hit = {
	ComboWindow = 1.5, -- hits on the same fighter within this long of the combo's first one count together
	LaunchOn = 3, -- the hit that ends a combo (the 3rd) launches
	-- Light: held still Config.Feedback.HitStopSeconds, then pushed along the ground for SlideSeconds at a speed from
	-- LightFull (full health) to LightEmpty (none); no swinging for LightStun. Measured 2026-10-25: 1.2 studs at 88
	-- health, 2 at 40 (the Humanoid carries on a little after the push).
	LightStun = 0.3,
	SlideSeconds = 0.18,
	LightFull = 5.5,
	LightEmpty = 14,
	-- Launch: push from LaunchFull (at full health) to LaunchEmpty (at none), lift LaunchLift. A launch ends a combo,
	-- so the first one comes at 64 health: measured 3.6 studs; the second at 28: 6.9 (2026-10-25). The two light hits
	-- before it push too: taken all the same way from the middle of a roof, a first combo can carry a fighter off.
	LaunchFull = 1,
	LaunchEmpty = 27,
	LaunchLift = 28,
	LaunchImmune = 0.9, -- a launched fighter cannot be hit for this long (flight, getting up and a moment more)
	-- Smash, the home run: high into the sky and away. With this lift a body is still in the air (higher than the
	-- highest top) when Config.Fall.HomeRunSeconds ends and it twinkles out - hit on the lowest deck it would reach the
	-- sand about 0.23 s later - and its top (about 50, 53 from the lookout) stays under the stands (70) (tests).
	SmashPush = 60,
	SmashLift = 120,
}

-- Being launched: stiff while flying, back on the feet after landing.
Config.Knock = {
	MinSeconds = 0.5, -- stiff at least this long
	MaxSeconds = 2.5, -- and at most this long, landed or not
	GroundReach = 0.6, -- the feet within this of something solid count as landed
	PredictForget = 0.6, -- a hit the swinger's screen already showed is not shown again when the server's comes
	-- A swing reaching the server this soon after its swinger was hit was pressed before the hit reached that player's
	-- screen (about a round trip), so it is still taken; later, while the hit's stun lasts (Config.Hit.LightStun or
	-- MinSeconds), the server refuses swings.
	SwingGrace = 0.25,
}

-- How a hit feels: its sound (Config.Sounds), a white flash on whoever is hit, and a little shake for the one hit.
Config.Feedback = {
	HitStopSeconds = 0.06, -- whoever is hit holds still this long before flying (the beat that makes a hit land)
	FlashSeconds = 0.15,
	ShakeSeconds = 0.15,
	ShakeStuds = 0.5,
	HomeRunTextSeconds = 1.6, -- the big "홈런!" over where the home run was hit
	Gold = Color3.fromRGB(255, 214, 90), -- the home run's colour (text, trail, feed line)
	TrailSeconds = 0.25, -- the light trail behind a home-run flight
	TwinkleSeconds = 0.7, -- the star a home-run flight ends in
	FeedSeconds = 4, -- a line in the knock-off feed stays this long
	FeedLines = 3,
}

-- Sounds: Roblox's own licensed library (Pro Sound Effects and APM Music uploads), free to use in Roblox games; and
-- the built-in rbxasset ones. volume is the Sound's; seconds cuts a long one short (it fades out over the last 0.5).
-- Music plays in the Music group (the on-screen button mutes it), the rest in Effects.
Config.Sounds = {
	Swing = { id = "rbxassetid://9120972321", volume = 0.5 }, -- Wood Whoosh Slicing Air Quick Swings 4
	HitLight = { id = "rbxassetid://9119330371", volume = 0.9 }, -- Soccer Ball Tackle 4 (a deep thump)
	HitLaunch = { id = "rbxassetid://9125380595", volume = 0.9, seconds = 1.2 }, -- Baseball Wood Bat Power Whack 1
	HomeRun = { id = "rbxassetid://9125380872", volume = 1, seconds = 2 }, -- Baseball Wood Bat Power Whack 5
	Cheer = { id = "rbxassetid://9120973900", volume = 0.45, seconds = 3.5 }, -- Wrestling Crowd 2 (cheers)
	Twinkle = { id = "rbxassetid://9126073001", volume = 0.7 }, -- Synth Sparkle Tone Ding 4
	Whistle = { id = "rbxassetid://9119628070", volume = 0.55, seconds = 2.5 }, -- Steam Train Whistle Airy 2
	Tick = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45 },
	Win = { id = "rbxassetid://9126073318", volume = 0.7 }, -- Synth Sparkle Tone Ding 1 (with the cheer)
	Train = { id = "rbxassetid://9112889081", volume = 0.22, looped = true }, -- Train Steam 2 (a steady chuff)
	MusicWaiting = { id = "rbxassetid://1840254626", volume = 0.25, looped = true, music = true }, -- Country Fiddle
	MusicFight = { id = "rbxassetid://1838431777", volume = 0.2, looped = true, music = true }, -- Resophonic Reel
}

-- Falling off: feet below this much under the lowest top (a flatcar's deck) have missed the train. From there the body lies down and
-- slides backward with the ground (left behind by the train) until it is taken to the stands.
Config.Fall = {
	Margin = 4,
	ShowSeconds = 1.6, -- the fall plays this long before the fighter goes to the stands (a sandbag is removed)
	HomeRunSeconds = 1.1, -- a home-run flight lasts this long, then twinkles out and goes to the stands
}

-- Rounds: wait for players, count down on the trains, fight until one is left.
Config.Round = {
	MinPlayers = 2, -- counting sandbags in solo mode
	CountdownSeconds = 3,
	MaxSeconds = 180, -- then it ends with everyone still standing
	EndSeconds = 5, -- the result shows this long
	IntermissionSeconds = 4, -- in the waiting room before the next count
	KillCreditSeconds = 6, -- a fall counts as a KO for whoever hit the player within this long before
}

-- Studio-only practice (Workspace attribute Names.Solo): sandbags that wander the top they stand on and count as
-- players.
Config.Sandbag = {
	Count = 5,
	WanderSeconds = 2.5, -- a new spot to walk to this often
	WalkSpeed = 8,
}

return Config
