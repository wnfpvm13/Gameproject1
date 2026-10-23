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
}
