--!strict
-- Forbidden-word judge shared by the live STT test and (later) WordJudgeService.
-- Confirmed = some eojeol starts with the word (or an alias) and the rest is empty or a particle.
-- Suspect = the word only appears once spaces are removed (STT spacing errors) -> "아슬아슬", never an elimination.

local Judge = {}

local PARTICLES: { [string]: boolean } = {}
for _, p in
	{ "", "이", "가", "을", "를", "은", "는", "도", "만", "에", "에서", "로", "으로", "야", "아", "이야", "예요", "이에요", "랑", "이랑", "하고", "의", "께", "한테", "처럼", "보다" }
do
	PARTICLES[p] = true
end

-- STT sometimes writes Sino-Korean numbers as digits ("칠판" -> "7판").
local SINO_DIGITS: { [string]: string } = {
	["0"] = "영", ["1"] = "일", ["2"] = "이", ["3"] = "삼", ["4"] = "사",
	["5"] = "오", ["6"] = "육", ["7"] = "칠", ["8"] = "팔", ["9"] = "구",
}

function Judge.normalize(text: string): string
	local lowered = string.lower(text)
	local digitsRead = string.gsub(lowered, "%d", SINO_DIGITS)
	local spaced = string.gsub(digitsRead, "%p", " ")
	return spaced
end

function Judge.eojeols(text: string): { string }
	local list = {}
	for part in string.gmatch(Judge.normalize(text), "%S+") do
		table.insert(list, part)
	end
	return list
end

local function startsWithParticle(eojeol: string, word: string): boolean
	if string.sub(eojeol, 1, #word) ~= word then
		return false
	end
	return PARTICLES[string.sub(eojeol, #word + 1)] == true
end

function Judge.isConfirmed(word: string, text: string, aliases: { string }?): boolean
	local forms = { word }
	if aliases then
		for _, alias in aliases do
			table.insert(forms, string.lower(alias))
		end
	end
	for _, eojeol in Judge.eojeols(text) do
		for _, form in forms do
			if startsWithParticle(eojeol, form) then
				return true
			end
		end
	end
	return false
end

function Judge.isSuspect(word: string, text: string): boolean
	if Judge.isConfirmed(word, text) then
		return false
	end
	local noSpace = string.gsub(Judge.normalize(text), "%s", "")
	return string.find(noSpace, word, 1, true) ~= nil
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

-- "CONFIRMED" | "SUSPECT" | "NONE"
function Judge.classify(word: string, text: string, aliases: { string }?): string
	if Judge.isConfirmed(word, text, aliases) then
		return "CONFIRMED"
	elseif Judge.isSuspect(word, text) then
		return "SUSPECT"
	end
	return "NONE"
end

return Judge
