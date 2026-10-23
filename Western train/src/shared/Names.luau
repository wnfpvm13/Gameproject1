--!strict
-- Instance, tag and attribute names shared by server and client. Requires nothing.

return {
	RemotesFolder = "Remotes",
	SquashRemote = "Squash",
	BridgeRemote = "Bridge",
	MailRemote = "Mail",
	-- Local folders each client makes in Workspace for what it draws, and the stage's haze in Lighting
	CourseFolder = "WesternTrainCourse",
	SceneryFolder = "WesternTrainScenery",
	Haze = "WesternTrainHaze",
	-- On Workspace, for testing alone in Studio: the player becomes a cowboy on a train with a stand-in driver
	SoloCowboy = "WesternTrainSoloCowboy",
	LocomotiveTag = "WesternTrainLocomotive",
	-- On the locomotive model
	OwnerUserId = "OwnerUserId", -- the driver (0 = the stand-in driver)
	CowboyUserId = "CowboyUserId", -- the cowboy on its roof (0 = none)
	Squashed = "Squashed",
	BasePart = "Base",
	CameraFocus = "CameraFocus",
	ChimneyCap = "ChimneyCap",
	SpanFront = "SpanFront", -- the train's front and back ends (cowcatcher, last car) in its own Z (front < 0 < back)
	SpanBack = "SpanBack",
	CarRoofFront = "CarRoofFront", -- where the first car's roof begins (Z): barrels land there
	-- The run (CourseService writes them, then bumps RunVersion so a client reads all three together)
	RunStart = "RunStart",
	RunFrom = "RunFrom",
	RunSpeed = "RunSpeed",
	RunVersion = "RunVersion",
	CrashIndex = "CrashIndex", -- the bridge being crashed into (0 = none)
	Passed = "Passed",
	Crashes = "Crashes",
	-- Mail: the next bag to pick up and the bags picked up (MailService), and the bag just missed (CourseService; 0 =
	-- none, the run goes back while it is set)
	MailNext = "MailNext",
	MailTaken = "MailTaken",
	MissedMail = "MissedMail",
	-- On every part that squashes: its rest pose relative to the Base part
	RestCFrame = "RestCFrame",
	RestSize = "RestSize",
	RestAnchor = "RestAnchor",
	RestMeshScale = "RestMeshScale",
	SquashExponent = "SquashExponent",
	-- On the coupling rods (arms) and crank pins: they circle with the driving wheels
	CrankRadius = "CrankRadius",
	CrankPhase = "CrankPhase",
	-- The avatar's head part (R15 name): the face on the smokebox, also found by the client's face window
	AvatarHead = "Head",
	-- On the roof parts the cowboy stands on (they keep their collisions)
	Walkable = "Walkable",
	CarPart = "CarPart", -- on every boxcar part (the face window leaves them out)
	-- On the legs: they swing about the hip (rest position relative to the Base part), each side the other way
	KickPivot = "KickPivot",
	KickSide = "KickSide",
}
