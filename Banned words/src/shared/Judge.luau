--!strict
-- Forbidden-word judge (V2 rule, owner-confirmed): after normalisation, the word appearing anywhere inside one
-- recognised utterance as a contiguous substring is a hit. No meaning or part-of-speech analysis:
--   사과 -> "사과", "사과나무 아래", "내가 사과했어", "청사과 주스" are hits;
--   "의사 과학자" (only joined across a space), "사-과", "애플" are not.

local Judge = {}

-- STT sometimes writes Sino-Korean numbers as digits ("칠판" -> "7판").
local SINO_DIGITS: { [string]: string } = {
	["0"] = "영", ["1"] = "일", ["2"] = "이", ["3"] = "삼", ["4"] = "사",
	["5"] = "오", ["6"] = "육", ["7"] = "칠", ["8"] = "팔", ["9"] = "구",
}

local nfc = (utf8 :: any).nfcnormalize -- Roblox only; the standalone Luau CLI used by unit tests lacks it

-- NFC, lower case, digits read as Sino-Korean, punctuation as spaces (so "사-과" never joins into "사과").
function Judge.normalize(text: string): string
	local s = if nfc then nfc(text) else text
	s = string.lower(s)
	s = string.gsub(s, "%d", SINO_DIGITS)
	s = string.gsub(s, "%p", " ")
	return s
end

function Judge.isConfirmed(word: string, text: string, aliases: { string }?): boolean
	local normalized = Judge.normalize(text)
	if string.find(normalized, Judge.normalize(word), 1, true) then
		return true
	end
	if aliases then
		for _, alias in aliases do
			if string.find(normalized, Judge.normalize(alias), 1, true) then
				return true
			end
		end
	end
	return false
end

-- True if either word contains the other (such pairs must never be in play together: 사과 / 사과나무).
function Judge.overlaps(a: string, b: string): boolean
	local na, nb = Judge.normalize(a), Judge.normalize(b)
	return string.find(na, nb, 1, true) ~= nil or string.find(nb, na, 1, true) ~= nil
end

-- Picks the particle by the last syllable's final consonant: josa("영화관", "을", "를") -> "을".
function Judge.josa(word: string, withFinal: string, withoutFinal: string): string
	local last = 0
	for _, code in utf8.codes(word) do
		last = code
	end
	local hasFinal = last >= 0xAC00 and last <= 0xD7A3 and (last - 0xAC00) % 28 ~= 0
	return if hasFinal then withFinal else withoutFinal
end

return Judge
