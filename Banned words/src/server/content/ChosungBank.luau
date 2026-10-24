--!strict
-- 초성 quiz words (bundle 8c, owner 2026-10-24). Data only: words by category; the quiz shows a word's initial
-- consonants (shared/Hangul) with its category, and three other words of the same category whose initials differ as
-- the wrong choices. Everyday words anyone around 17 knows; no names of people or brands, nothing sensitive. Words
-- that contain a banned word in play are skipped at run time.

local ChosungBank = {
	{ category = "과일", words = { "바나나", "사과", "포도", "딸기", "수박", "참외", "복숭아", "자두", "키위", "망고", "귤", "레몬", "체리", "파인애플", "블루베리", "멜론", "석류", "감", "배", "앵두" } },
	{ category = "동물", words = { "강아지", "고양이", "호랑이", "사자", "코끼리", "기린", "토끼", "거북이", "다람쥐", "고슴도치", "펭귄", "하마", "얼룩말", "캥거루", "판다", "여우", "늑대", "원숭이", "부엉이", "돌고래" } },
	{ category = "음식", words = { "떡볶이", "김밥", "비빔밥", "불고기", "라면", "짜장면", "짬뽕", "냉면", "삼겹살", "김치찌개", "된장찌개", "순두부", "잡채", "만두", "치킨", "피자", "햄버거", "돈가스", "칼국수", "갈비탕" } },
	{ category = "나라", words = { "일본", "중국", "미국", "영국", "프랑스", "독일", "이탈리아", "스페인", "캐나다", "호주", "브라질", "멕시코", "인도", "태국", "베트남", "러시아", "이집트", "스위스", "튀르키예", "아르헨티나" } },
	{ category = "직업", words = { "소방관", "경찰관", "의사", "간호사", "선생님", "요리사", "미용사", "택배 기사", "제빵사", "조종사", "변호사", "약사", "수의사", "기자", "화가", "가수", "배우", "농부", "어부", "건축가" } },
	{ category = "운동", words = { "축구", "야구", "농구", "배구", "탁구", "테니스", "배드민턴", "수영", "태권도", "유도", "양궁", "펜싱", "골프", "볼링", "스키", "스케이트", "마라톤", "씨름", "복싱", "럭비" } },
	{ category = "탈것", words = { "자전거", "자동차", "버스", "지하철", "기차", "비행기", "헬리콥터", "배", "오토바이", "트럭", "택시", "케이블카", "킥보드", "열기구", "잠수함", "구급차", "소방차", "유람선", "트랙터", "로켓" } },
	{ category = "학교 물건", words = { "연필", "지우개", "공책", "필통", "가위", "풀", "자", "색연필", "크레파스", "물감", "칠판", "분필", "책상", "의자", "사물함", "교과서", "형광펜", "볼펜", "스테이플러", "계산기" } },
}

return ChosungBank
