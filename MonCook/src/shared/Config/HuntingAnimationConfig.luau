--!strict
-- Fill owned, published animation IDs after Studio acceptance. Empty IDs use
-- authored KeyframeSequence previews in Studio and procedural fallback elsewhere.
return {
	Player = { Basic1 = "", Basic2 = "", Basic3 = "", Heavy = "", Dodge = "" },
	StudioClipPreview = true, PredictionTimeout = 1.5, TrackFadeSeconds = 0.04,
	MonsterLOD = { Near = 45, Medium = 90, Far = 150, MediumHz = 20, FarHz = 8, SleepHz = 2 },
}
