--!strict
-- Names shared by the server and the clients (one place, so they cannot drift). Requires nothing.
return {
	-- Folders and remotes
	RemotesFolder = "Remotes",
	SwingRemote = "Swing", -- client -> server: I swing
	HitRemote = "Hit", -- server -> every client: who was hit, and the knock for the one it hit
	FeedRemote = "Feed", -- server -> every client: who knocked whom out and how ("homerun" or "fall")
	BlastRemote = "Blast", -- server -> every client: a dynamite burst (where, how wide)
	ArenaFolder = "TrainBrawlArena",
	SceneryFolder = "TrainBrawlScenery",
	CanyonFolder = "TrainBrawlCanyon",
	CarDecorFolder = "TrainBrawlCarDecor",
	LocomotiveDecorFolder = "TrainBrawlLocomotiveDecor",
	StandsFolder = "TrainBrawlStands",
	WaitingRoom = "WaitingRoom",
	WeaponPart = "HeldWeapon", -- the weapon in a character's hand (WeaponGear)
	CratesFolder = "TrainBrawlCrates",
	SandbagTag = "TrainBrawlSandbag",
	-- Workspace attributes (the round, written by the server)
	Phase = "Phase", -- "Waiting" | "Countdown" | "Fight" | "Ended"
	PhaseEndsAt = "PhaseEndsAt", -- server time the phase ends (0 = waiting for players)
	AliveCount = "AliveCount",
	Winner = "Winner", -- the last one standing's name ("" = none yet or nobody)
	Solo = "TrainBrawlSolo", -- set in Studio: sandbags join so one tester can play
	-- Character attributes
	SwingAt = "SwingAt", -- server time the character's last attack started (every client draws it)
	SwingWeapon = "SwingWeapon", -- the weapon that attack was made with (set just before SwingAt)
	SwingStep = "SwingStep", -- that attack's step in its attacker's string (AttackString; set just before SwingAt)
	Weapon = "Weapon", -- the weapon a character holds (Config.Weapons; "Fist" or none = bare fists)
	WeaponUses = "WeaponUses", -- attacks left with it (when it has uses)
	WeaponEndsAt = "WeaponEndsAt", -- server time it runs out (when it lasts a time)
	-- Crate attributes (WeaponDrops)
	CrateWeapon = "Weapon", -- what is inside
	CrateLanded = "Landed",
	CrateTakenBy = "TakenBy", -- the name of the character who took it
	Alive = "Alive", -- in the current round and still on the trains
	KOs = "KOs", -- knock-offs this round (on the fighter's character or sandbag model)
	Health = "Health", -- combat health this round (not the Humanoid's), written by the server (FighterHealth)
}
