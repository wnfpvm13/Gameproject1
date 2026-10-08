--!strict
-- Presentation values only. RGB arrays keep this module usable in pure tests.
return table.freeze({
	Background = { 0.25, 0.20, 0.15 }, BackgroundTransparency = 0.16,
	Text = { 1.0, 0.94, 0.78 }, Muted = { 0.82, 0.77, 0.62 },
	Gold = { 0.86, 0.61, 0.28 }, Rare = { 0.72, 0.48, 0.95 }, Health = { 0.43, 0.77, 0.41 },
	TouchButton = 58, NarrowButton = 50, PanelWidth = 330, PanelHeight = 320,
	MinimumTouch = 44, NoticeSeconds = 1.8, RareNoticeSeconds = 1.15, LootVisualSeconds = 0.8,
	MaxNotices = 3, MaxLootVisuals = 4,
})
