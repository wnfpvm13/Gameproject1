--!strict
-- Situation themes for the assistant host (data only). A theme gives the table a reason to talk:
-- one situation line, a loose role per player (acting it out is optional), small events, topic cards.
-- Writing rules (docs/DESIGN_V2.md): never tell anyone to say a specific word, every card must be answerable
-- without any particular word, nothing aggressive or asking for real personal info.
-- "{name}" in an event is replaced by a random alive player (a visual spotlight only; nobody is forced to speak).

export type Theme = {
	name: string,
	situation: string,
	roles: { string },
	events: { string },
	topics: { string },
}

local Themes = {}

Themes.list = {
	{
		name = "회식 자리",
		situation = "회사 회식 자리! 오늘 누가 계산할지 정해야 해요",
		roles = { "사장", "부장", "과장", "대리", "신입", "인턴", "총무", "막내", "경리", "거래처 손님", "영업왕", "야근왕" },
		events = {
			"갑자기 정전이 됐다가 다시 불이 들어왔어요",
			"{name}님 앞에 처음 보는 메뉴가 나왔어요",
			"계산서가 도착했어요. 금액이 생각보다 커요",
			"옆 테이블에서 생일 노래가 들려요",
			"내일 아침 회의가 갑자기 잡혔어요",
			"2차를 갈지 말지 투표해야 해요",
			"{name}님이 건배사를 맡게 됐어요",
			"{name}님 휴대폰으로 급한 연락이 왔어요",
		},
		topics = {
			"회식 메뉴로 최악은?",
			"상사에게 들어 본 최고의 칭찬",
			"2차로 가고 싶은 곳",
			"월급날 제일 먼저 하고 싶은 것",
			"회사에서 생길 법한 황당한 일",
		},
	},
	{
		name = "방과 후 교실",
		situation = "방과 후 교실! 반장 선거가 내일이에요",
		roles = { "반장 후보", "부반장", "전학생", "체육부장", "급식 당번", "지각 대장", "수학 천재", "미술부", "방송부", "학생회장", "잠꾸러기", "축구부" },
		events = {
			"담임이 갑자기 교실 문을 열었어요",
			"{name}님 책상 서랍에서 쪽지가 나왔어요",
			"내일 쪽지 시험이 있다는 공지가 떴어요",
			"급식 메뉴가 바뀌었다는 소문이 돌아요",
			"{name}님이 반장 후보로 추천됐어요",
			"창밖에 갑자기 비가 쏟아져요",
			"수학여행 장소를 정해야 해요",
			"교실 에어컨이 고장 났어요",
		},
		topics = {
			"가장 좋아했던 급식 메뉴",
			"학교에서 제일 무서운 장소",
			"반장이 되면 바꾸고 싶은 것",
			"수학여행으로 가고 싶은 곳",
			"기억에 남는 수업 시간",
		},
	},
	{
		name = "단체 여행 계획",
		situation = "다 같이 떠나기로 했어요! 어디로 갈지 정해야 해요",
		roles = { "총무", "운전 담당", "사진 담당", "맛집 탐정", "길치", "짐꾼", "일정 담당", "늦잠 대장", "분위기 메이커", "안전 요원", "기념품 수집가", "캠핑 고수" },
		events = {
			"예산이 절반으로 줄었어요",
			"{name}님이 여권을 잃어버렸대요",
			"출발 날 비 예보가 나왔어요",
			"숙소 예약 하나가 취소됐어요",
			"{name}님이 맛집 목록을 들고 왔어요",
			"기차표가 한 장 모자라요",
			"현지에서 축제가 열린다는 소식이에요",
			"{name}님 캐리어가 너무 무거워요",
		},
		topics = {
			"여행 가서 꼭 먹어야 하는 것",
			"최악의 여행 메이트 유형",
			"산이 좋아, 물가가 좋아?",
			"짐에 꼭 챙기는 것",
			"언젠가 가 보고 싶은 나라",
		},
	},
	{
		name = "동네 중고 장터",
		situation = "동네 중고 장터! 각자 물건을 팔고 사야 해요",
		roles = { "판매왕", "흥정의 달인", "수집가", "구경꾼", "가게 주인", "단골손님", "초보 판매자", "감정사", "배달원", "경매사", "짠돌이", "부자 손님" },
		events = {
			"{name}님 물건에 말도 안 되는 가격이 붙었어요",
			"깜짝 할인 시간이 시작됐어요",
			"가짜 명품이 돌고 있다는 소문이 나요",
			"{name}님이 전 재산을 걸고 경매에 참여했어요",
			"날씨가 나빠져서 장터가 곧 문을 닫아요",
			"{name}님 가게에 손님이 몰려왔어요",
			"경품 추첨이 곧 시작돼요",
			"진열해 둔 물건 하나가 사라졌어요",
		},
		topics = {
			"버리기 아까운 물건",
			"제일 잘 샀다고 생각하는 물건",
			"제일 후회한 구매",
			"흥정 꿀팁",
			"만 원으로 살 수 있는 최고의 물건",
		},
	},
} :: { Theme }

-- Topics that fit any theme.
Themes.general = {
	"요즘 제일 맛있게 먹은 음식",
	"무인도에 가져갈 물건 세 가지",
	"키우고 싶은 동물과 이름",
	"주말에 하고 싶은 것",
	"최근에 본 재밌는 영상",
	"하루 동안 투명인간이 된다면",
	"제일 좋아하는 계절과 이유",
	"로블록스에서 제일 좋아하는 게임",
	"초능력 하나를 고른다면",
	"어렸을 때 꿈",
	"요즘 제일 웃겼던 일",
	"받고 싶은 선물",
	"비 오는 날 하면 좋은 것",
	"가장 좋아하는 캐릭터와 이유",
	"아침에 일어나서 제일 먼저 하는 일",
}

return Themes
