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

-- Chat (docs/DESIGN_V3.md §7; bundle 5b): only letters are kept — Hangul syllables, Hangul letters, Latin letters and
-- digits (read as Sino-Korean first) — so spaces of any kind, punctuation (·, ㆍ, …), emoji and invisible characters
-- cannot split a word: "사 과", "사·과", "사🍎과" are hits. A word across two words ("의사 과학자") becomes one too;
-- the presenter's rescue covers that, and also digits read as words ("4과"). Letters spelled out in jamo ("ㅅㅏㄱㅘ") are
-- not joined into syllables, so they are not caught (owner 2026-10-23).
local FILLERS = { [0x115F] = true, [0x1160] = true, [0x3164] = true } -- Hangul fillers: they look like blanks

local function keep(code: number): boolean
	if FILLERS[code] then
		return false
	end
	return (code >= 0xAC00 and code <= 0xD7A3) -- Hangul syllables
		or (code >= 0x1100 and code <= 0x11FF) -- Hangul jamo
		or (code >= 0x3131 and code <= 0x318C) -- Hangul compatibility letters (not ㆍ U+318D, a middle dot)
		or (code >= 0x61 and code <= 0x7A) -- a-z (lower-cased already)
		or (code >= 0x30 and code <= 0x39)
end

-- Full-width digits (０-９) count like ASCII ones (read as Sino-Korean in normalize).
local function prepare(text: string): string
	local s = string.gsub(text, "\239\188[\144-\153]", function(digit: string): string
		return string.char(string.byte(digit, 3) - 0x90 + 0x30)
	end)
	return Judge.normalize(s)
end

function Judge.normalizeChat(text: string): string
	local s = prepare(text)
	local out = {}
	local ok = pcall(function()
		for _, code in utf8.codes(s) do
			if keep(code) then
				table.insert(out, utf8.char(code))
			end
		end
	end)
	if not ok then
		return (string.gsub(s, "[%s%p]", "")) -- not valid UTF-8: the ASCII rule at least
	end
	return table.concat(out)
end

-- A chat line's words (머리 위 스무고개, bundle 9c): the runs of the letters normalizeChat keeps; anything else (spaces,
-- marks, emoji, invisible characters) ends a word. "사과, 배!" -> { "사과", "배" }; not valid UTF-8 -> none.
function Judge.chatWords(text: string): { string }
	local s = prepare(text)
	local words: { string } = {}
	local current: { string } = {}
	local ok = pcall(function()
		for _, code in utf8.codes(s) do
			if keep(code) then
				table.insert(current, utf8.char(code))
			elseif #current > 0 then
				table.insert(words, table.concat(current))
				current = {}
			end
		end
	end)
	if not ok then
		return {}
	end
	if #current > 0 then
		table.insert(words, table.concat(current))
	end
	return words
end

-- Whether `text` (a chat message) holds `word` or one of its aliases.
function Judge.chatHit(word: string, text: string, aliases: { string }?): boolean
	local normalized = Judge.normalizeChat(text)
	if string.find(normalized, Judge.normalizeChat(word), 1, true) then
		return true
	end
	local others: { string } = aliases or {}
	for _, alias in others do
		if string.find(normalized, Judge.normalizeChat(alias), 1, true) then
			return true
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
