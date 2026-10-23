--!strict
-- Instance, tag and attribute names shared by server and client. Requires nothing.

return {
	RemotesFolder = "Remotes",
	SquashRemote = "Squash",
	LocomotiveTag = "WesternTrainLocomotive",
	-- On the locomotive model
	OwnerUserId = "OwnerUserId",
	Squashed = "Squashed",
	BasePart = "Base",
	CameraFocus = "CameraFocus",
	ChimneyCap = "ChimneyCap",
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
