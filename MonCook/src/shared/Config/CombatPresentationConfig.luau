--!strict
return {
	BodyColor = { 1, 0.77, 0.35 }, HornColor = { 0.52, 0.89, 1 }, HeavyColor = { 1, 0.9, 0.65 },
	LightReactionSeconds = 0.19, HeavyReactionSeconds = 0.32, HornBreakReactionSeconds = 0.55,
	FeedbackDistance = 85, SparkSeconds = 0.16, DeathFadeStart = 0.8, DeathFadeSeconds = 1.1,
	-- Built-in short landing sample is available without an uploaded ID. Authored WAVs are in art/audio.
	BodySound = "rbxasset://sounds/action_jump_land.mp3", HornSound = "rbxasset://sounds/action_jump_land.mp3",
	BodyPitch = 0.85, HornPitch = 1.65, LightVolume = 0.22, HeavyVolume = 0.38,
	DebugBasicColor = { 1, 0.71, 0.22 }, DebugHeavyColor = { 1, 0.35, 0.2 }, DebugSegments = 20,
}
