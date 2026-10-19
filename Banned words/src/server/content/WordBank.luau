--!strict
-- Word bank (version 2, server only, never replicated). Data + drawing only.
-- Nouns: everyday 2-5 syllable words. Habits: speech habits for the third word (무한도전 세븐's '에이' idea).
-- Rules: no 1-syllable words; words that misheard in the 2026-10-17 STT probe (기린, 시계, 칠판) stay out.
-- Overlapping pairs (공원 / 놀이공원) may both be listed: draw() never puts overlapping words in play together.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Judge = require(ReplicatedStorage:WaitForChild("BannedWords"):WaitForChild("Judge"))

export type Entry = { word: string, aliases: { string }, category: string }

local WordBank = {}

local NOUNS: { Entry } = {}
local HABITS: { Entry } = {}

local function add(into: { Entry }, category: string, list: { string })
	for _, word in list do
		table.insert(into, { word = word, aliases = {}, category = category })
	end
end

add(NOUNS, "음식", { "치킨", "피자", "떡볶이", "라면", "김밥", "사과", "바나나", "아이스크림", "햄버거", "초콜릿", "삼겹살", "짜장면", "수박", "딸기", "만두", "케이크" })
add(NOUNS, "동물", { "강아지", "고양이", "토끼", "호랑이", "코끼리", "원숭이", "펭귄", "거북이", "햄스터", "돌고래", "다람쥐", "앵무새" })
add(NOUNS, "학교", { "숙제", "선생님", "교실", "시험", "연필", "지우개", "급식", "방학", "운동장", "공책", "체육", "졸업" })
add(NOUNS, "물건", { "컴퓨터", "핸드폰", "의자", "책상", "우산", "냉장고", "텔레비전", "안경", "가방", "이어폰", "자전거", "지갑", "베개" })
add(NOUNS, "장소", { "수영장", "놀이터", "병원", "편의점", "도서관", "바다", "공원", "영화관", "학원", "지하철", "놀이공원", "빵집", "미용실", "경찰서" })
add(NOUNS, "날씨", { "무지개", "눈사람", "장마", "태풍", "여름", "겨울", "봄비", "구름", "번개", "단풍", "소나기", "미세먼지" })
add(NOUNS, "생활", { "월급", "용돈", "생일", "택배", "유튜브", "노래방", "주말", "여행", "사진", "선물", "계산서", "회의" })
add(HABITS, "말버릇", { "진짜", "대박", "완전", "솔직히", "아무튼", "약간", "그러니까", "근데", "혹시", "제발", "미안", "엄청", "게임", "웃겨" })

local function overlapsAny(word: string, taken: { string }): boolean
	for _, other in taken do
		if Judge.overlaps(word, other) then
			return true
		end
	end
	return false
end

local function drawFrom(list: { Entry }, taken: { string }, rng: Random): Entry?
	local start = rng:NextInteger(1, #list)
	for offset = 0, #list - 1 do
		local entry = list[(start + offset - 1) % #list + 1]
		if not overlapsAny(entry.word, taken) then
			return entry
		end
	end
	return nil
end

-- One word that neither contains nor is contained in any word in `taken`. Habits fall back to nouns.
function WordBank.draw(kind: "noun" | "habit", taken: { string }, rng: Random): Entry?
	if kind == "habit" then
		local habit = drawFrom(HABITS, taken, rng)
		if habit then
			return habit
		end
	end
	return drawFrom(NOUNS, taken, rng)
end

function WordBank.counts(): (number, number)
	return #NOUNS, #HABITS
end

return WordBank
