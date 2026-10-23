--!strict
-- Instance, tag and attribute names shared by server and client. Requires nothing.

return {
	RemotesFolder = "Remotes",
	SquashRemote = "Squash",
	BridgeRemote = "Bridge",
	-- Local folders each client makes in Workspace for what it draws, and the stage's haze in Lighting
	CourseFolder = "WesternTrainCourse",
	SceneryFolder = "WesternTrainScenery",
	Haze = "WesternTrainHaze",
	LocomotiveTag = "WesternTrainLocomotive",
	-- On the locomotive model
	OwnerUserId = "OwnerUserId",
	Squashed = "Squashed",
	BasePart = "Base",
	CameraFocus = "CameraFocus",
	ChimneyCap = "ChimneyCap",
	SpanFront = "SpanFront", -- the locomotive's front and back ends in its own Z (front < 0 < back)
	SpanBack = "SpanBack",
	-- The run (CourseService writes them, then bumps RunVersion so a client reads all three together)
	RunStart = "RunStart",
	RunFrom = "RunFrom",
	RunSpeed = "RunSpeed",
	RunVersion = "RunVersion",
	CrashIndex = "CrashIndex", -- the bridge being crashed into (0 = none)
	Passed = "Passed",
	Crashes = "Crashes",
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
	-- On the legs: they swing about the hip (rest position relative to the Base part), each side the other way
	KickPivot = "KickPivot",
	KickSide = "KickSide",
}
