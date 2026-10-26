--!strict
-- Other ways players write a ChosungBank word (bundle 10, review 2026-10-25: "돈까스" for 돈가스 was a wrong answer).
-- 머리 위 스무고개 takes them as the right answer and as writing the word in chat; WordService keeps a chat line holding
-- one from the word's owner. Data only: word -> its other forms (spaces and marks never matter, Judge.normalizeChat).
-- No one-letter forms, and none inside everyday words: the chat rule looks for them inside any line (review
-- 2026-10-26: 버거 hid "너무 버거워", 거북 "자세가 거북해"); none that also means another word in play (바이크 is a
-- bicycle too) or a name (크루즈).
local WordAliases: { [string]: { string } } = {
	["돈가스"] = { "돈까스" },
	["짜장면"] = { "자장면" },
	["순두부"] = { "순두부찌개" },
	["튀르키예"] = { "터키" },
	["호주"] = { "오스트레일리아" },
	["경찰관"] = { "경찰" },
	["소방관"] = { "소방수" },
	["복싱"] = { "권투" },
	["헬리콥터"] = { "헬기" },
	["지하철"] = { "전철" },
	["구급차"] = { "앰뷸런스" },
	["요리사"] = { "셰프" },
	["조종사"] = { "파일럿" },
	["크레파스"] = { "크레용" },
	["스테이플러"] = { "호치키스" },
}

return WordAliases
