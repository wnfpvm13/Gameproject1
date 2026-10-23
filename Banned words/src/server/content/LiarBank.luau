--!strict
-- Categories and words for the liar game (docs/DESIGN_V3.md §5.2; bundle 6d). Data only. Everyday words anyone around
-- age 17 can describe in one clue; no real people, brands or sensitive matters. Each category has at least four words
-- (the named liar guesses the word among four of its category).

export type Category = { category: string, words: { string } }

local LiarBank: { Category } = {
	{ category = "음식", words = { "김밥", "떡볶이", "라면", "비빔밥", "치킨", "피자", "햄버거", "초밥" } },
	{ category = "과일", words = { "사과", "바나나", "수박", "딸기", "포도", "복숭아", "귤", "망고" } },
	{ category = "동물", words = { "강아지", "고양이", "토끼", "사자", "코끼리", "기린", "펭귄", "판다" } },
	{ category = "운동", words = { "축구", "농구", "야구", "수영", "배드민턴", "탁구", "볼링", "스키" } },
	{ category = "장소", words = { "도서관", "놀이공원", "영화관", "편의점", "공항", "병원", "바닷가", "캠핑장" } },
	{ category = "탈것", words = { "자전거", "버스", "지하철", "비행기", "배", "고속열차", "택시", "헬리콥터" } },
	{ category = "악기", words = { "피아노", "기타", "드럼", "바이올린", "플루트", "하모니카", "트럼펫", "우쿨렐레" } },
	{ category = "날씨", words = { "비", "눈", "태풍", "무지개", "안개", "천둥", "우박", "황사" } },
	{ category = "물건", words = { "우산", "안경", "시계", "가방", "베개", "칫솔", "거울", "열쇠" } },
	{ category = "직업", words = { "요리사", "소방관", "의사", "선생님", "가수", "경찰관", "우주비행사", "제빵사" } },
}

return LiarBank
