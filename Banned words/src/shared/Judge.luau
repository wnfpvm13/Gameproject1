--!strict
-- Forbidden-word judge shared by the live STT test and (later) WordJudgeService.
-- Confirmed = some eojeol starts with the word (or an alias) and the rest is empty or a chain of particles/endings.
-- Suspect = the word only appears once spaces are removed (STT spacing errors) -> "아슬아슬", never an elimination.

local Judge = {}

-- Particles and copula endings that may follow a noun. They can stack ("치킨으로도", "치킨이라고요"), so the rest of
-- an eojeol counts if it splits entirely into these pieces. Verbs/derivations ("사과하다", "치킨집") never match.
local SUFFIXES = {
	"이", "가", "을", "를", "은", "는", "도", "만", "에", "에서", "에게", "께", "한테", "한테서", "로", "으로",
	"의", "와", "과", "랑", "이랑", "하고", "처럼", "보다", "까지", "부터", "마다", "조차", "밖에", "라도", "이라도",
	"나", "이나", "든지", "이든지", "야", "아", "이야", "예요", "이에요", "이요", "요", "라고", "이라고", "란", "이란",
	"다", "이다", "입니다", "이고", "고", "이며", "며", "인데", "이지", "지", "이네", "네", "였어", "이었어", "같이", "같은",
	"들", "께서", "에게서", "로서", "으로서", "로써", "으로써",
}
table.sort(SUFFIXES, function(a, b)
	return #a > #b -- try longer pieces first ("으로" before "로")
end)

local function isSuffixChain(rest: string): boolean
	if rest == "" then
		return true
	end
	for _, suffix in SUFFIXES do
		if string.sub(rest, 1, #suffix) == suffix and isSuffixChain(string.sub(rest, #suffix + 1)) then
			return true
		end
	end
	return false
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
	return isSuffixChain(string.sub(eojeol, #word + 1))
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
