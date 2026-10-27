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
	stack: { along: number, width: number, height: number }?,
	crates: { { along: number, width: number, length: number, height: number } }?,
	cupola: { from: number, to: number, width: number, height: number }?,
}

-- A weapon: the shape WeaponRules.Weapon reads (written out again here, as Config requires nothing; keep them the same).
type Weapon = {
	style: string,
	damage: number,
	push: number,
	launch: boolean?,
	reach: number?,
	halfAngle: number?,
	radius: number?,
	ahead: number?,
	throwSpeed: number?,
	throwLift: number?,
	fuse: number?,
	cooldown: number,
	hitAt: number,
	seconds: number,
	uses: number?,
	heldSeconds: number?,
	resist: number?,
	slow: number?,
	weight: number?,
}

-- The arena: big trains side by side on parallel tracks. They stand still in the world; the scenery scrolls past
-- (Config.Run), so everything players stand on keeps still for physics.
Config.Arena = {
	-- Between the roof edges of two trains: wider than a running jump, even one dropping from the highest top to the
	-- lowest across from it, so crossing takes a plank or a big hit. Measured in Studio (2026-10-25, default R15, jump
	-- pressed as late as 1.9 past the edge, where it still stands): a jump crossed 12.75 on the flat, 13.75 dropping 5,
	-- 14.25 dropping 8, never 13 / 14 / 14.5 or 15 — the first 12 was crossed from a roof down onto a flatcar (tests:
	-- JUMP_EXTRA). Still enough with the trains 1.5 times bigger: facing wide tops still drop at most 5 across a gap (a
	-- boxcar or caboose roof 15 to a flatcar deck 10, as before), the biggest drop (9, from a lookout) starts well in
	-- from the edge (tests).
	Gap = 15,
	-- Every car is this wide. The trains were made 1.5 times bigger (owner 2026-10-25, "the map feels small"): widths,
	-- lengths and the drawn details grew 1.5 times (Config.Decor.DetailScale), the heights only by about 5 (a jump does
	-- not grow, so neighbouring tops and the tops standing on them stay within one; tests).
	RoofWidth = 15,
	CarGap = 0.5, -- between two cars of a train (well under a character's thickness, so nobody slips through)
	BodyInset = 0.45, -- a car body is this much narrower than its roof on each side (the roof overhangs it)
	BodyBottom = 2.9, -- a car body's underside: the wheels and trucks show below it (drawn on the clients)
	Gauge = 4.5, -- each rail this far either side of a train's middle line
	-- A locomotive's solid frame under the boiler is this wide: all of it under the boiler (no ledge sticks out beside
	-- it) and inside the drawn driving wheels (tests).
	LocomotiveFrame = 7.5,
	StackPipe = 0.62, -- a chimney's pipe, as a share of its flared top's width
	-- The kinds of car (ArenaLayout.Kind): length, walkable roof height, spawn spots (shares along the car), whether
	-- planks may rest on the roof, and their extra tops. Flatcars are low decks to drop into and climb out of (the
	-- crates are steps; attacks do not care about them); a caboose's lookout and a locomotive's chimney top are the
	-- high perches (the chimney's the highest).
	CarKinds = {
		-- A round boiler in front (its top a narrow ridge) and the cab's flat roof over the back 35%. The chimney on the
		-- boiler is solid, its flared top a small round perch (a drawn-only chimney would be walked through).
		Locomotive = {
			length = 27,
			roof = 16,
			roofFrom = 0.65,
			spawns = { 0.82 },
			plank = false,
			boiler = { to = 0.65, top = 15.5, width = 12 },
			stack = { along = 0.12, width = 4.8, height = 4.5 },
		},
		Tender = { length = 15, roof = 12.5, spawns = { 0.5 }, plank = true }, -- the coal car behind a locomotive: low and flat
		Boxcar = { length = 30, roof = 15, spawns = { 0.3, 0.7 }, plank = true },
		Flatcar = {
			length = 27,
			roof = 10,
			spawns = { 0.25 },
			plank = true,
			-- Steps up to a neighbour's roof (their heights stay jump-sized; only their footprint grew).
			crates = { { along = 0.62, width = 6, length = 6, height = 2.5 }, { along = 0.86, width = 7.5, length = 4.5, height = 4.5 } },
		},
		Caboose = { length = 21, roof = 15, spawns = { 0.3 }, plank = true, cupola = { from = 0.55, to = 0.9, width = 9, height = 4 } },
	} :: { [string]: CarKind },
	-- The trains, left to right: their cars front to back, and how far each stands back (+Z) or ahead (-Z), so that
	-- different cars face each other. The middle one is the main stage (spawns fill it first).
	Trains = {
		{ shift = 4.5, cars = { "Locomotive", "Tender", "Boxcar", "Flatcar" } },
		{ shift = 0, cars = { "Locomotive", "Tender", "Boxcar", "Caboose" } },
		{ shift = -4.5, cars = { "Locomotive", "Tender", "Flatcar", "Boxcar" } },
	},
	-- Planks across a gap only where two flat tops of the same height face each other along at least PlankWidth
	-- (PlankEdge in from their ends), the widest first, at most PlanksPerGap per gap, PlankSpacing apart.
	PlankWidth = 4,
	PlankThickness = 0.4,
	PlankOverlap = 1.5, -- how far a plank lies on each roof
	PlankEdge = 0.5,
	PlanksPerGap = 2,
	PlankSpacing = 12,
	-- The sand's top, under the rail tops (y 0). It is solid: a fighter who falls off lands on it and is left behind
	-- (the fall line is above it, so landing there is always out).
	GroundY = -1,
	WaitingRoomHeight = 80, -- the waiting room (and the stands for the knocked out) floats this high over the middle
	WaitingRoomSize = 36,
	WaitingRoomWall = 14, -- glass walls higher than a jump off someone's head
	WaitingRoomWindow = 12, -- a glass square in the middle of its floor, to look down on the trains through
	-- A body higher than this under the waiting room has reached the stands (the home-run show and flight stop there);
	-- a home run's top stays under it (tests).
	StandsMargin = 8,
	Colors = {
		Boxcar = Color3.fromRGB(150, 58, 40),
		Tender = Color3.fromRGB(58, 52, 50),
		Coal = Color3.fromRGB(30, 28, 28),
		Flatcar = Color3.fromRGB(120, 84, 52),
		Crate = Color3.fromRGB(176, 132, 80),
		Caboose = Color3.fromRGB(176, 46, 38),
		Roof = Color3.fromRGB(96, 70, 56), -- weathered rust: bodies (often dark) stand out on it (it was a dark grey)
		Boiler = Color3.fromRGB(52, 88, 64),
		Cab = Color3.fromRGB(40, 38, 42),
		Wheel = Color3.fromRGB(140, 40, 30),
		Plank = Color3.fromRGB(150, 110, 66),
		Room = Color3.fromRGB(210, 196, 170),
		Glass = Color3.fromRGB(196, 222, 232),
	},
}

-- The scenery that slides past to show the trains running.
Config.Run = {
	Speed = 30, -- studs per second backward (+Z)
	ViewAhead = 260, -- the scenery is laid out this far ahead of the middle and this far behind
	ViewBehind = 160,
	SleeperSpacing = 3,
	GroundTile = 100, -- the running ground's tiles are about this long (drawn on the clients over the server's sand)
	RoadsideProps = 20,
	RoadsideClearance = 7, -- props stand at least this far beyond the outermost train's edge
	RoadsideFar = 75,
	-- Telegraph poles along one side (Side -1 = left), Distance beyond the outermost train's edge, every Spacing.
	PoleSide = -1,
	PoleDistance = 14,
	PoleSpacing = 42,
	PoleHeight = 14,
	Colors = {
		Sand = Color3.fromRGB(214, 176, 120),
		Rail = Color3.fromRGB(92, 88, 86),
		Sleeper = Color3.fromRGB(96, 66, 44),
		Cactus = Color3.fromRGB(86, 120, 64),
		Rock = Color3.fromRGB(150, 116, 86),
		Ballast = Color3.fromRGB(128, 112, 96),
		Pole = Color3.fromRGB(104, 78, 56),
		Wire = Color3.fromRGB(40, 38, 38),
	},
}

-- The canyon the trains run through (drawn on the clients, Canyon): sandstone walls either side in stepped layers,
-- sliding past like the rest of the scenery. Laid out far ahead and behind, so their wrap-around happens deep in the
-- haze (Lighting's Atmosphere); the sand reaches under all of it (ArenaBuilder).
Config.Canyon = {
	-- The walls' nearest face from the middle line, and up to InnerVary farther. A home run flies about 66 sideways
	-- before it twinkles out, so even from the outermost roof it stays clear of the walls, their foot slopes
	-- (TalusWidth), the ribs of rock standing out of them (RibOut) and the rock spires in front (SpireOut) (tests).
	Inner = 135,
	InnerVary = 20,
	Depth = 80, -- how far out the walls go
	TalusWidth = 12, -- the rubble slope at a wall's foot
	RibOut = 6, -- a rib of rock stands at most this far out of its wall
	SpireOut = 16, -- a rock spire stands at most this far in front of its wall
	Ahead = 700,
	Behind = 500,
	SegmentMin = 40, -- each stretch of wall is this long
	SegmentMax = 90,
	HeightMin = 50,
	HeightMax = 100,
	Colors = {
		Color3.fromRGB(176, 92, 60), -- the layers, from the foot up
		Color3.fromRGB(204, 130, 86),
		Color3.fromRGB(160, 82, 56),
		Color3.fromRGB(222, 164, 112),
	},
}

-- The drawn-only dressing on the clients (CarDecor, LocomotiveDecor, Stands): nothing of it collides, casts a shadow
-- or is seen by raycasts, so it never changes where anyone can stand.
Config.Decor = {
	Lettering = "CANYON LINE", -- painted on the boxcars' and the caboose's sides
	-- The fixed sizes of the drawn details were first chosen for 10-wide cars; they are multiplied by this (thin parts'
	-- thickness, ladders and other people-sized things are not).
	DetailScale = 1.5,
	DriverRadius = 2.6, -- a locomotive's big driving wheels (two pairs, under the boiler); the coupling rods circle with them
	TruckWheelRadius = 1.4, -- the other cars' wheels, two pairs under each end, under the body's underside
	CrankRadius = 1,
	-- Chimney smoke: it leaves fast upward and fades while the run's wind bends it back, so it is gone above the
	-- roofs behind the locomotive instead of hiding them.
	SmokeRate = 30, -- puffs per second from each chimney
	SmokeSpeed = 15,
	SmokeSeconds = 1.6,
	SmokeWind = 18, -- backward pull (studs/s²)
	Colors = {
		Iron = Color3.fromRGB(48, 46, 48), -- trucks, straps, couplers, rods
		Trim = Color3.fromRGB(226, 208, 170), -- window frames, lettering
		Window = Color3.fromRGB(36, 42, 50),
		Brass = Color3.fromRGB(198, 158, 76),
		Lamp = Color3.fromRGB(255, 228, 156),
		Marker = Color3.fromRGB(232, 64, 44),
		Wood = Color3.fromRGB(112, 78, 50), -- walkways, stakes, posts, the stands' frame
		Smoke = Color3.fromRGB(110, 104, 100),
		SmokeFade = Color3.fromRGB(196, 190, 184),
		Rope = Color3.fromRGB(150, 124, 84),
	},
	-- The four hot-air balloons that hold the stands up: each envelope's colour and its stripes'.
	Balloons = {
		{ Color3.fromRGB(214, 64, 52), Color3.fromRGB(246, 226, 188) },
		{ Color3.fromRGB(58, 110, 178), Color3.fromRGB(246, 226, 188) },
		{ Color3.fromRGB(236, 184, 56), Color3.fromRGB(200, 70, 48) },
		{ Color3.fromRGB(72, 140, 92), Color3.fromRGB(246, 226, 188) },
	},
	BalloonRadius = 7,
	Flags = { Color3.fromRGB(214, 64, 52), Color3.fromRGB(246, 226, 188), Color3.fromRGB(58, 110, 178), Color3.fromRGB(236, 184, 56) },
}

-- Attacks with any weapon: what the server allows for the network.
Config.Attack = {
	-- Extra reach the server allows for the network delay (a target running at 16 moves about 1.6 in 0.1 s). With the
	-- bat the server takes up to 5.5 + 1.5 = 7 for a target standing still, so keep it small.
	ReachSlack = 1.5,
	HeightReach = 5, -- the target's middle within this much higher or lower (cones and areas alike)
	CooldownSlack = 0.1, -- the server takes an attack this much early (clock and network jitter)
	-- The attacker's 1-2-3 string (AttackString, punches and swings): when the last attack landed, an attack starting
	-- within StringGap after its weapon was ready again is the next step; the StringCount-th (the 3rd) launches what it
	-- hits, landing FinisherWindup later than the weapon's hitAt (a wind-up everyone sees) and drawn FinisherStretch
	-- times the weapon's seconds. The server takes the client's step up to StringSlack later than its own clock would
	-- (network jitter).
	StringCount = 3,
	StringGap = 0.35, -- with bare fists: a new attack within 0.8 s of the last one keeps the string
	StringSlack = 0.15,
	FinisherWindup = 0.08,
	FinisherStretch = 1.5,
}

-- The bat's look (WeaponGear): a big cartoon bat, so its reach shows.
Config.Bat = {
	Length = 4.5,
	Thickness = 0.55,
	Color = Color3.fromRGB(196, 150, 90),
}

-- The weapons (owner 2026-10-25: "기본은 맨주먹으로 하자. 그리고 다른 무기들을 추가한다"). Everyone fights with bare fists;
-- weapons come in crates dropped onto the trains (Config.Drops) and last for their uses or their seconds held, then it
-- is fists again (WeaponService). Every hit goes through the health rules (HitRules): damage replaces a fist's, push
-- multiplies the push health gives (so a weapon throws a full-health fighter no farther off than health allows: no
-- single hit carries one off a roof from its middle, tests), launch makes even a first hit a launch. style: how it
-- attacks and is drawn (punch, swing: a cone of reach and halfAngle; slam: an area of radius just ahead; throw: a lit
-- stick that bursts after its fuse). hitAt: seconds after pressing when it lands; seconds: the drawn attack. weight:
-- how often a crate holds it. (Its name on screen is in Words.Weapons.)
Config.Weapons = {
	-- A quick jab: short reach, light damage, a little push (13 punches empty health).
	-- (Its cooldown leaves a punched fighter, stunned Config.Hit.LightStun, a moment to answer before the next punch.)
	Fist = { style = "punch", damage = 8, push = 0.8, reach = 4, halfAngle = 60, cooldown = 0.45, hitAt = 0.1, seconds = 0.26 },
	-- The old bat: as the whole game used before the weapons (reach measured: the drawn tip passes 4.2 ahead as it hits).
	Bat = {
		style = "swing",
		damage = 12,
		push = 1,
		reach = 5.5,
		halfAngle = 70,
		cooldown = 0.55,
		hitAt = 0.12,
		seconds = 0.32,
		uses = 15,
		weight = 3,
	},
	-- Raised high (a long wind-up everyone sees), slammed down: everyone around the spot just ahead flies, away from the
	-- one who slammed.
	Hammer = {
		style = "slam",
		damage = 16,
		push = 1.25,
		launch = true,
		radius = 6.5,
		ahead = 3,
		cooldown = 1.1,
		hitAt = 0.45,
		seconds = 0.75,
		uses = 3,
		weight = 2,
	},
	-- Thrown in an arc; a red ring shows where it comes down; it bursts after its fuse, throwing everyone around out.
	Dynamite = {
		style = "throw",
		damage = 18,
		push = 1.35,
		launch = true,
		radius = 8,
		throwSpeed = 36,
		throwLift = 36,
		fuse = 1.6,
		cooldown = 0.9,
		hitAt = 0.18,
		seconds = 0.45,
		uses = 1,
		weight = 2,
	},
	-- Heavy: while it is held its holder is pushed half as far but walks slower; a slow, hard swing.
	GoldBar = {
		style = "swing",
		damage = 15,
		push = 1.15,
		reach = 5,
		halfAngle = 65,
		cooldown = 0.7,
		hitAt = 0.2,
		seconds = 0.45,
		heldSeconds = 15,
		resist = 0.5,
		slow = 0.75,
		weight = 1.5,
	},
} :: { [string]: Weapon }

-- The weapon crates (WeaponDrops): the first some seconds into a fight, then one every few seconds while fewer are on
-- the map than one for every three fighters left (at most MaxOnMap). Each floats down FallSeconds from FallHeight with
-- its shadow growing where it lands; a crate nobody takes goes away after LifeSeconds.
Config.Drops = {
	FirstAfter = 15,
	Every = 15,
	MaxOnMap = 2,
	FallSeconds = 3,
	FallHeight = 40,
	LifeSeconds = 25,
	PickupReach = 3.5, -- a fighter this close (along the ground) takes it
}

-- Health and what a hit does (the rules are in HitRules; Smash Legends-style): health drops with every hit, and the
-- lower it is the farther a hit pushes. The first hits of an attacker's string are light (a flinch and a short push,
-- no lying down, over before the swinger's next swing, so the one hit can answer); the string's last hit launches
-- (flying, lying down) and leaves its fighter unhittable for a moment; the hit that empties health is a smash (a certain
-- ring-out). Falling off is out at any health. A body travels about 0.28 to 0.42 x the launch push (measured: push 18
-- went 6.2, 24.4 went 10.3, 28 went 10.6, 15.4 went 4.3 to 5.4, 29.2 went 11.0, landing lying and sliding a little) and
-- 1.2 to 2 studs from a light hit (the light pushes stayed as they were when the roofs grew: planks are still 4 wide).
-- Every fighter's body: Roblox's standard R15 body parts at these scales (players: AvatarRules, practice bots:
-- Sandbags; owner 2026-10-27: "since we hit each other, the bodies taking the hits should be the same"). These are
-- the blocky standard body's own proportions (HipHeight 2; a new HumanoidDescription's 0.3 body type and 1 proportion
-- stand about 0.2 taller).
Config.Body = {
	Scales = {
		HeightScale = 1,
		WidthScale = 1,
		DepthScale = 1,
		HeadScale = 1,
		BodyTypeScale = 0,
		ProportionScale = 0,
	} :: { [string]: number },
}

Config.Health = {
	Max = 100, -- each weapon's damage is its own (Config.Weapons)
	LowFraction = 0.3, -- at or under this share the bar goes red and blinks
}

Config.Hit = {
	-- What launches: the attacker's string (Config.Attack.StringCount), a weapon that always launches, or the guard
	-- against being ganged up on: GangHits hits within GangWindow from two or more attackers together launch (with
	-- the moment of being unhittable after it), so a crowd cannot keep someone flinching.
	GangWindow = 1.5,
	GangHits = 3,
	-- Light: held still Config.Feedback.HitStop.light, then pushed along the ground for SlideSeconds at a speed from
	-- LightFull (full health) to LightEmpty (none); no swinging for LightStun. Measured 2026-10-25: 1.2 studs at 88
	-- health, 2 at 40 (the Humanoid carries on a little after the push).
	LightStun = 0.3,
	SlideSeconds = 0.18,
	LightFull = 5.5,
	LightEmpty = 14,
	-- Launch: push from LaunchFull (at full health) to LaunchEmpty (at none), lift LaunchLift. A string's third hit
	-- launches, so with a bat the first one comes at 64 health: measured 4.3 to 5.4 studs; the second at 28: 11.0 (2026-10-25, with the
	-- 15-wide roofs: 7.5 from the middle to an edge; on 10-wide roofs two thirds of these pushes went 3.6 and 6.9). The two light
	-- hits before it push too: taken all the same way from the middle of a roof, a first string can carry a fighter off.
	LaunchFull = 1.5,
	LaunchEmpty = 40,
	LaunchLift = 28,
	LaunchImmune = 0.9, -- a launched fighter cannot be hit for this long (flight, getting up and a moment more)
	-- Smash, the home run: high into the sky and away. With this lift a body is still in the air (higher than the
	-- highest top) when Config.Fall.HomeRunSeconds ends and it twinkles out - hit on the lowest deck it would reach the
	-- sand about 0.37 s later (its flight starts after the 0.16 s hold) - and its top (about 55, 60 from a chimney top) stays under the stands (80) (tests).
	SmashPush = 60,
	SmashLift = 120,
}

-- Being launched: stiff while flying, back on the feet after landing.
Config.Knock = {
	MinSeconds = 0.5, -- stiff at least this long
	MaxSeconds = 2.5, -- and at most this long, landed or not
	GroundReach = 0.6, -- the feet within this of something solid count as landed
	-- A swing reaching the server this soon after its swinger was hit was pressed before the hit reached that player's
	-- screen (about a round trip), so it is still taken; later, while the hit's stun lasts (Config.Hit.LightStun or
	-- MinSeconds), the server refuses swings.
	SwingGrace = 0.25,
	-- A home run's body tumbles head over heels the way it was pushed, this many turns over its flight. A plain launch
	-- does not: measured 2026-10-26 (Studio, same rig with and without), a quarter turn sent a health-64 launch 6.9 studs
	-- instead of 3.1 (the body lands on its back and slides) - near the 7.5 from a roof's middle to its edge, so it
	-- would change who stays on. A launch shows by its flailing pose instead (AttackPoses).
	SpinTurns = { launch = 0, smash = 1.25 } :: { [string]: number },
}

-- How a hit feels: its sound (Config.Sounds), a white flash and a comic burst where it lands, a hold (whoever is hit
-- holds still, and the attacker's pose pauses with it), and a camera kick the way the hit went.
Config.Feedback = {
	-- The hold: a heavier hit holds longer (the beat that makes a hit land). A launch's flight starts after it.
	HitStop = { light = 0.06, launch = 0.1, smash = 0.16 } :: { [string]: number },
	FlashSeconds = 0.15,
	BurstSeconds = 0.18, -- the comic burst where a hit lands
	KickSeconds = 0.2, -- the camera kick
	KickStuds = { light = 0.35, launch = 0.8, smash = 1.1, dealt = 0.15 } :: { [string]: number }, -- dealt: the attacker's own
	FovPunch = 7, -- a launch or smash taken narrows the view this many degrees for a moment
	DustSeconds = 0.6, -- the puff where a launched body lands
	HomeRunTextSeconds = 1.6, -- the big "홈런!" over where the home run was hit
	Gold = Color3.fromRGB(255, 214, 90), -- the home run's colour (text, trail, feed line)
	TrailSeconds = 0.25, -- the light trail behind a home-run flight
	FeedSeconds = 4, -- a line in the knock-off feed stays this long
	FeedLines = 3,
}

-- Sounds: only Roblox's own licensed library (Pro Sound Effects and APM Music uploads), free to use in Roblox games; no
-- built-in default sounds (players know them, and they read as unfinished). volume is the Sound's; seconds cuts a long
-- one short (it fades out over the last 0.5); vary plays it up to that share higher or lower each time.
-- Music plays in the Music group (the on-screen button mutes it), the rest in Effects.
Config.Sounds = {
	Swing = { id = "rbxassetid://9120972321", volume = 0.5, vary = 0.08 }, -- Wood Whoosh Slicing Air Quick Swings 4 (the bat)
	Punch = { id = "rbxassetid://9120728815", volume = 0.45, seconds = 0.6, vary = 0.08 }, -- Whoosh Heavy Punches 1
	HeavySwing = { id = "rbxassetid://9125959352", volume = 0.6, seconds = 1.1, vary = 0.05 }, -- Slowed Whip Swishes Whomping Airy Whoosh Bys (the hammer)
	GoldSwing = { id = "rbxassetid://9120742729", volume = 0.55, vary = 0.06 }, -- Whoosh Thick Quick Multiple Variations 1 (the gold bar)
	Throw = { id = "rbxassetid://9126283052", volume = 0.5, vary = 0.08 }, -- Wood Swish Ruler Whoosh Fast Movement In Air (a dynamite throw)
	PunchHit = { id = "rbxassetid://9113564874", volume = 0.8, seconds = 0.8, vary = 0.1 }, -- Boxing Hits 6
	BatHit = { id = "rbxassetid://9113502635", volume = 0.8, seconds = 0.7, vary = 0.08 }, -- Body Hits 10 (a 2x4 on the body)
	HammerHit = { id = "rbxassetid://9114757272", volume = 0.9, seconds = 1.2, vary = 0.05 }, -- Hammer Tire Exterior Sledgehammer Impacts 1
	GoldHit = { id = "rbxassetid://9116554603", volume = 0.8, seconds = 1.2, vary = 0.06 }, -- Metal Crown Kings Headgear Hit Clang 1
	BodyLaunch = { id = "rbxassetid://9113570289", volume = 0.95, vary = 0.06 }, -- Boxing Hits 14 (a heavy blow into a bag)
	HitLaunch = { id = "rbxassetid://9125380595", volume = 0.9, seconds = 1.2, vary = 0.05 }, -- Baseball Wood Bat Power Whack 1
	HomeRun = { id = "rbxassetid://9125380872", volume = 1, seconds = 2 }, -- Baseball Wood Bat Power Whack 5
	FlyOff = { id = "rbxassetid://9119198150", volume = 0.5 }, -- Slide Whistle 6 (a home-run body flying off)
	StarPop = { id = "rbxassetid://9113263649", volume = 0.6 }, -- Balloon Pop 3 (a home-run flight popping out of the sky)
	Blast = { id = "rbxassetid://9120769331", volume = 1, seconds = 2.5 }, -- Wind Whoosh Sonic Boom Low End Impact 1
	Fuse = { id = "rbxassetid://9119380593", volume = 0.5, seconds = 1.6 }, -- Soldering From Sparklers 1 (a fizzing fuse)
	Parachute = { id = "rbxassetid://9117235033", volume = 0.5, seconds = 2 }, -- Parachute Blossom 9
	CrateLand = { id = "rbxassetid://9113466920", volume = 0.7, seconds = 1.5, vary = 0.08 }, -- Board Drops Wood Impacts Wobble 3
	Pickup = { id = "rbxassetid://9120873789", volume = 0.7, seconds = 0.8 }, -- Wooden Chest Open Close Cedar Box 9 (a weapon taken from a crate)
	CountBell = { id = "rbxassetid://9116223567", volume = 0.5, seconds = 0.9 }, -- Large Metal Triangle Single Ringing Hits 3 (each count-down second)
	Whistle = { id = "rbxassetid://9119628070", volume = 0.55, seconds = 2.5 }, -- Steam Train Whistle Airy 2
	WinBell = { id = "rbxassetid://9113583408", volume = 0.6, seconds = 3 }, -- Brass Bell Various Rings Long Decays 1 (a winner)
	Cheer = { id = "rbxassetid://9120973900", volume = 0.3, seconds = 2.5 }, -- Wrestling Crowd 2 (the stands cheering a winner)
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

-- Studio-only practice (Workspace attribute Names.Solo): bots that count as players and fight (BotBrain): each goes for
-- the nearest other fighter on the top it stands on and punches its string, and wanders the top when nobody is there.
-- (Owner 2026-10-27: "AI들이 공격하지 않아" - the practice sandbags only wandered.)
Config.Sandbag = {
	Count = 5,
	WanderSeconds = 2.5, -- a new spot to walk to this often
	WalkSpeed = 8, -- wandering
	ChaseSpeed = 14, -- going for someone (a little slower than a player's 16, so one can get away)
	ThinkSeconds = 0.1, -- how often a bot looks again
	PerTarget = 2, -- at most this many bots go for one fighter
	-- It runs to StandOff away and, within StepIn of PunchFrom, steps straight in at StepSpeed; it punches once at
	-- StandOff (inside a fist's reach, 4) and goes after it again past PunchFrom. Two bots stepping at each other
	-- close 2 x StepSpeed x ThinkSeconds (1.2) between looks, so they stop no nearer than about 2 (bodies touch at 1.5).
	StandOff = 3.2,
	PunchFrom = 3.9,
	StepIn = 3,
	StepSpeed = 6,
	Margin = 1.5, -- spots stay this far inside a top's edges
	React = { 0.3, 0.5 }, -- seconds before the first punch at someone newly in reach (a random share between)
	Rest = { 0.6, 0.9 }, -- the breather after a string
	Jitter = 0.08, -- up to this much later than its fist is ready, between punches of a string
	FullString = 0.75, -- the chance a string is meant to go all three; otherwise it stops after one or two
}

return Config
