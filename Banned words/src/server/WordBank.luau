--!strict
-- Version 2 word bank (server only, never replicated). Words come from the 2026-10-17 STT probe;
-- 기린 / 시계 / 칠판 were dropped because synthetic speech came back misheard or empty.

export type Entry = { word: string, aliases: { string }, category: string }

local WordBank = {}

local WORDS: { Entry } = {}
local function add(category: string, list: { string })
	for _, word in list do
		table.insert(WORDS, { word = word, aliases = {}, category = category })
	end
end

add("음식", { "치킨", "피자", "떡볶이", "라면", "김밥", "사과", "바나나", "아이스크림", "햄버거", "초콜릿" })
add("동물", { "강아지", "고양이", "토끼", "호랑이", "코끼리", "원숭이", "펭귄", "거북이", "햄스터" })
add("학교", { "숙제", "선생님", "교실", "시험", "연필", "지우개", "급식", "방학", "운동장" })
add("물건", { "컴퓨터", "핸드폰", "의자", "책상", "우산", "냉장고", "텔레비전", "안경", "가방" })
add("장소", { "수영장", "놀이터", "병원", "편의점", "도서관", "바다", "공원", "영화관", "학원", "지하철" })
add("날씨", { "무지개", "눈사람", "장마", "태풍", "여름", "겨울", "봄비", "구름", "번개", "단풍" })

-- Draws `count` distinct words, spreading categories so hints do not overlap.
function WordBank.draw(count: number, rng: Random): { Entry }
	local pool = table.clone(WORDS)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local picked: { Entry } = {}
	local usedCategory: { [string]: number } = {}
	local maxPerCategory = math.ceil(count / 6)
	for _, entry in pool do
		if #picked >= count then
			break
		end
		local used = usedCategory[entry.category] or 0
		if used < maxPerCategory then
			usedCategory[entry.category] = used + 1
			table.insert(picked, entry)
		end
	end
	return picked
end

return WordBank
