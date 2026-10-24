--!strict
-- Hangul helpers (bundle 8c, the 초성 quiz): the initial consonants of a word, e.g. "바나나" -> "ㅂㄴㄴ". Characters
-- that are not complete Hangul syllables (spaces, letters, numbers) are kept as they are.
local Hangul = {}

local FIRST = 0xAC00 -- 가
local LAST = 0xD7A3 -- 힣
local PER_INITIAL = 588 -- 21 vowels x 28 finals
local INITIALS = { "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ" }

function Hangul.initials(word: string): string
	local out = {}
	for _, code in utf8.codes(word) do
		if code >= FIRST and code <= LAST then
			table.insert(out, INITIALS[(code - FIRST) // PER_INITIAL + 1])
		else
			table.insert(out, utf8.char(code))
		end
	end
	return table.concat(out)
end

return Hangul
