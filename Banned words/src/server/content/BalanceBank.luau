--!strict
-- "A vs B" questions for the balance game (docs/DESIGN_V3.md §5.2; bundle 6d). Data only. Light everyday choices that
-- anyone can argue about around age 17; nothing about real people, groups, politics, religion or other sensitive
-- matters, and no side that makes fun of anyone.

export type Question = { a: string, b: string }

local BalanceBank: { Question } = {
	{ a = "짜장면", b = "짬뽕" },
	{ a = "부먹", b = "찍먹" },
	{ a = "여름", b = "겨울" },
	{ a = "바다", b = "산" },
	{ a = "치킨", b = "피자" },
	{ a = "아침형 인간", b = "저녁형 인간" },
	{ a = "강아지", b = "고양이" },
	{ a = "콜라", b = "사이다" },
	{ a = "민트초코 좋아", b = "민트초코 싫어" },
	{ a = "물냉면", b = "비빔냉면" },
	{ a = "떡볶이", b = "라면" },
	{ a = "영화관", b = "집에서 영화" },
	{ a = "비 오는 날", b = "눈 오는 날" },
	{ a = "놀이공원", b = "워터파크" },
	{ a = "단짠", b = "맵단" },
	{ a = "순간이동 초능력", b = "투명 인간 초능력" },
	{ a = "평생 비 오는 날", b = "평생 바람 부는 날" },
	{ a = "편의점 도시락", b = "분식집 김밥" },
	{ a = "카레에 밥 비벼 먹기", b = "카레 따로 먹기" },
	{ a = "떡볶이 밀떡", b = "떡볶이 쌀떡" },
	{ a = "아침 산책", b = "저녁 산책" },
	{ a = "롤러코스터", b = "회전목마" },
	{ a = "공포 영화", b = "코미디 영화" },
	{ a = "양념치킨", b = "후라이드" },
	{ a = "아이스크림 콘", b = "아이스크림 컵" },
	{ a = "캠핑", b = "호텔" },
	{ a = "게임 혼자", b = "게임 같이" },
	{ a = "과거로 시간 여행", b = "미래로 시간 여행" },
	{ a = "붕어빵 머리부터", b = "붕어빵 꼬리부터" },
	{ a = "마라탕", b = "쌀국수" },
	{ a = "자전거", b = "킥보드" },
	{ a = "아침밥 꼭 먹기", b = "아침밥 건너뛰기" },
	{ a = "문자로 연락", b = "전화로 연락" },
	{ a = "케이크", b = "마카롱" },
	{ a = "꼬들꼬들 라면", b = "푹 익힌 라면" },
	{ a = "생일 파티 크게", b = "생일은 조용히" },
	{ a = "용 키우기", b = "유니콘 키우기" },
	{ a = "찐만두", b = "군만두" },
	{ a = "우주 여행", b = "심해 탐험" },
	{ a = "핫초코", b = "아이스티" },
}

return BalanceBank
