--!strict
-- Hangul helpers (bundle 8c, the 초성 quiz): the initial consonants of a word, e.g. "바나나" -> "ㅂㄴㄴ". Characters
-- that are not complete Hangul syllables (spaces, letters, numbers) are kept as they are. And the same initials made
-- readable on screen: Roblox drew lone consonants (ㄱ-ㅎ) at about half the height of a syllable in every font tried
-- (BuilderSans, NotoSansCJK, SourceSans, Arimo, Montserrat; 2026-10-25), so they are drawn bigger and spaced out
-- (RichText; used by the client's MissionPanel).
local Hangul = {}

local FIRST = 0xAC00 -- 가
local LAST = 0xD7A3 -- 힣
local PER_INITIAL = 588 -- 21 vowels x 28 finals
local INITIALS = { "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ" }

local JAMO_FIRST = 0x3131 -- ㄱ (the consonants of the compatibility jamo)
local JAMO_LAST = 0x314E -- ㅎ

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

local ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&apos;" }

-- `text` as RichText with every run of lone consonants at `size` and spaced out ("과일 · ㅂㄴㄴ" -> "과일 · " plus
-- "ㅂ ㄴ ㄴ" in a bigger font); a space between two words of consonants stays in the run, wider ("ㅌㅂ ㄱㅅ" -> "ㅌ ㅂ   ㄱ ㅅ"),
-- so the words still show apart. nil when it has none (show it as plain text). Everything else is escaped.
local WORD_GAP = "   "

local function isJamo(code: number): boolean
	return code >= JAMO_FIRST and code <= JAMO_LAST
end

function Hangul.richInitials(text: string, size: number): string?
	local codes = {}
	for _, code in utf8.codes(text) do
		table.insert(codes, code)
	end
	local out, run, found = {}, {}, false
	local function flush()
		if #run > 0 then
			table.insert(out, string.format('<font size="%d">%s</font>', size, table.concat(run)))
			table.clear(run)
		end
	end
	local i = 1
	while i <= #codes do
		local code = codes[i]
		if isJamo(code) then
			found = true
			if #run > 0 then
				table.insert(run, " ")
			end
			table.insert(run, utf8.char(code))
			i += 1
		elseif code == 32 and #run > 0 then
			local j = i
			while j <= #codes and codes[j] == 32 do
				j += 1
			end
			if j <= #codes and isJamo(codes[j]) then -- (spaces between two words of consonants: one wider gap)
				table.insert(run, WORD_GAP)
				table.insert(run, utf8.char(codes[j]))
				i = j + 1
			else
				flush()
				table.insert(out, " ")
				i += 1
			end
		else
			flush()
			local char = utf8.char(code)
			table.insert(out, ESCAPES[char] or char)
			i += 1
		end
	end
	flush()
	return if found then table.concat(out) else nil
end

return Hangul
