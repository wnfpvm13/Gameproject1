--!strict
-- Names shared by the server and the clients (one place, so they cannot drift). Requires nothing.
return {
	-- Folders and remotes
	RemotesFolder = "Remotes",
	SwingRemote = "Swing", -- client -> server: I swing
	HitRemote = "Hit", -- server -> every client: who was hit, and the knock for the one it hit
	ArenaFolder = "TrainBrawlArena",
	SceneryFolder = "TrainBrawlScenery",
	WaitingRoom = "WaitingRoom",
	BatPart = "Bat",
	SandbagTag = "TrainBrawlSandbag",
	-- Workspace attributes (the round, written by the server)
	Phase = "Phase", -- "Waiting" | "Countdown" | "Fight" | "Ended"
	PhaseEndsAt = "PhaseEndsAt", -- server time the phase ends (0 = waiting for players)
	AliveCount = "AliveCount",
	Winner = "Winner", -- the last one standing's name ("" = none yet or nobody)
	Solo = "TrainBrawlSolo", -- set in Studio: sandbags join so one tester can play
	-- Character attributes
	SwingAt = "SwingAt", -- server time the character's last swing started (every client draws it)
	Alive = "Alive", -- in the current round and still on the trains
	KOs = "KOs", -- knock-offs this round (on the fighter's character or sandbag model)
}
