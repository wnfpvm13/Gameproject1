--!strict
-- Names shared by the server and the clients (one place, so they cannot drift). Requires nothing.
return {
	-- Folders and remotes
	RemotesFolder = "Remotes",
	SwingRemote = "Swing", -- client -> server: I swing
	HitRemote = "Hit", -- server -> every client: who was hit, and the knock for the one it hit
	FeedRemote = "Feed", -- server -> every client: who knocked whom out and how ("homerun" or "fall")
	BlastRemote = "Blast", -- server -> every client: a dynamite burst (where, how wide)
	BlockRemote = "Block", -- client -> server: the block control went down (true) or up (false)
	DodgeRemote = "Dodge", -- client -> server: I roll, along this flat direction
	SweptRemote = "Swept", -- server -> every client: a low bridge swept this fighter off (and the throw for it)
	ArenaFolder = "TrainBrawlArena",
	SceneryFolder = "TrainBrawlScenery",
	CanyonFolder = "TrainBrawlCanyon",
	CarDecorFolder = "TrainBrawlCarDecor",
	LocomotiveDecorFolder = "TrainBrawlLocomotiveDecor",
	StandsFolder = "TrainBrawlStands",
	WaitingRoom = "WaitingRoom",
	WeaponPart = "HeldWeapon", -- the weapon in a character's hand (WeaponGear)
	-- On a held weapon: the two points a blow's streak runs between (WeaponGear makes them, SwingTrail draws it)
	TrailTip = "TrailTip",
	TrailBase = "TrailBase",
	-- What weapons leave in the arena folder (the server's Missiles, Wheels, Slicks; DropShow sounds them)
	LumpPart = "CoalLump",
	WheelModel = "RollingWheel",
	SlickPart = "OilSlick",
	CratesFolder = "TrainBrawlCrates",
	SandbagTag = "TrainBrawlSandbag",
	-- Workspace attributes (the round, written by the server)
	Phase = "Phase", -- "Waiting" | "Countdown" | "Fight" | "Ended"
	PhaseEndsAt = "PhaseEndsAt", -- server time the phase ends (0 = waiting for players)
	AliveCount = "AliveCount",
	Winner = "Winner", -- the last one standing's name ("" = none yet or nobody; several winners' names joined)
	WinnerCount = "WinnerCount", -- how many won (more than one: tied when the time ran out)
	WinnerStreak = "WinnerStreak", -- the single winner's wins in a row this visit (0: none)
	Solo = "TrainBrawlSolo", -- set in Studio: sandbags join so one tester can play
	BridgeAt = "BridgeAt", -- server time a low bridge's beam reaches the front of the trains (Bridges; none: no bridge)
	GoldenAt = "GoldenAt", -- server time the golden crate starts falling (WeaponDrops; none: none coming or lying)
	GoldenSpot = "GoldenSpot", -- where it lands (a Vector3, with GoldenAt)
	GoldenTaken = "GoldenTaken", -- who took it this fight and what: "name|weapon" (none: nobody yet)
	-- Character attributes
	SwingAt = "SwingAt", -- server time the character's last attack started (every client draws it)
	SwingWeapon = "SwingWeapon", -- the weapon that attack was made with (set just before SwingAt)
	SwingStep = "SwingStep", -- that attack's step in its attacker's string (AttackString; set just before SwingAt)
	-- that attack's number as its player's client counted them (set just before SwingAt; the client tells its own
	-- attacks apart by it, OwnSwing)
	SwingTag = "SwingTag",
	Weapon = "Weapon", -- the weapon a character holds (Config.Weapons; "Fist" or none = bare fists)
	BodyReady = "BodyReady", -- a player's character was given the standard body (AvatarRules): it may join a round
	WeaponUses = "WeaponUses", -- attacks left with it (when it has uses)
	WeaponEndsAt = "WeaponEndsAt", -- server time it runs out (when it lasts a time)
	-- Ground marks (drawn on each client by GroundMarks over the server's invisible flat parts)
	BlastMark = "BlastRing", -- where a thrown stick will burst (Dynamite), its radius as wide
	LandingMark = "LandingMark", -- where a crate will land (WeaponDrops)
	MarkEndsAt = "EndsAt", -- server time the burst or the landing happens
	MarkSeconds = "Seconds", -- how long the mark shows in all
	-- Crate attributes (WeaponDrops)
	CrateWeapon = "Weapon", -- what is inside
	CrateLanded = "Landed",
	CrateTakenBy = "TakenBy", -- the name of the character who took it
	CrateGolden = "Golden", -- the golden crate (true)
	Alive = "Alive", -- in the current round and still on the trains
	KOs = "KOs", -- knock-offs this round (on the fighter's character or sandbag model)
	Health = "Health", -- combat health this round (not the Humanoid's), written by the server (FighterHealth)
	Tickets = "Tickets", -- tickets left this round (Config.Round.Tickets; RoundService)
	-- On the way back after a fall with a ticket left (Comebacks): "Up" (the fall, then the stands) or "Down" (under a
	-- parachute); none when not coming back
	ReturnPhase = "ReturnPhase",
	ReturnAt = "ReturnAt", -- server time the parachute drop starts (while "Up")
	GuardUntil = "GuardUntil", -- server time a fighter just back stops being unhittable (FighterHealth; 0 = attacked)
	Blocking = "Blocking", -- the fighter is blocking now (Guarding; true or none)
	DodgeAt = "DodgeAt", -- server time the fighter's last dodge roll started (Dodging; every client draws it)
	DodgeDir = "DodgeDir", -- that roll's flat direction (set just before DodgeAt)
	-- The arena's cars: each a Model named CarModel..k in its train's Model (TrainModel..i), its planks named PlankPart
	-- with PlankNumber (ArenaBuilder). A back car coming off (Uncoupling) carries CarLeavingAt (server time it lets go)
	-- and, once gone, CarGone.
	TrainModel = "Train",
	CarModel = "Car",
	PlankPart = "Plank",
	PlankNumber = "Number",
	CarLeavingAt = "LeavingAt",
	CarGone = "Gone",
}
