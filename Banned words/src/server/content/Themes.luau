--!strict
-- Round themes and their mission cards (data only, V2.1). A theme gives the table a reason to talk:
-- loose roles (acting is optional), three missions played in this order (a little story), quiet-time events and
-- topic cards. Every place and group in a card is imaginary, so it works with 2 or 10 players.
--
-- Mission card = situation, problem, goal, 2-3 options. Stages: a notice after a while, a short vote, then a
-- follow-up that depends on the vote (or "undecided" on a tie / no votes). Nobody dies for a mission result.
--
-- Writing rules (docs/DESIGN_V2.md, V2.1):
--   - never tell anyone to say a specific word; every card must be answerable in many ways;
--   - NO text here may contain any word-bank word (or alias): the game never adapts cards to the secret words,
--     so the text itself must be safe for every word. tools/check_content.luau checks this — run it after edits;
--   - nothing aggressive, nothing asking for real personal info.
-- "{name}" in an event is replaced by a random alive player's ROLE (role texts are checked like everything else;
-- display names are not, so they never go into a card); "{이가}" becomes 이/가 to fit that role.

export type Option = { id: string, text: string }

export type Mission = {
	id: string,
	situation: string,
	problem: string,
	goal: string,
	options: { Option },
	notice: string, -- shown MISSION_NOTICE_AT seconds in (raises the stakes)
	followups: { [string]: string }, -- option id (or "undecided") -> new condition after the vote
}

export type Theme = {
	name: string,
	roles: { string },
	missions: { Mission },
	events: { string },
	topics: { string },
}

local Themes = {}

Themes.list = {
	{
		name = "회식 자리",
		roles = { "사장", "부장", "과장", "대리", "신입", "인턴", "총무", "막내", "경리", "거래처 손님", "영업왕", "야근왕" },
		missions = {
			{
				id = "dinner_seats",
				situation = "예약한 방이 생각보다 좁아요.",
				problem = "다 같이 앉으려면 누군가는 불편해져요.",
				goal = "모두가 납득할 자리 배치를 정해 보세요.",
				options = {
					{ id = "squeeze", text = "좁아도 한 방에 다 같이" },
					{ id = "split", text = "두 테이블로 나눠 앉기" },
					{ id = "move", text = "다른 가게로 옮기기" },
				},
				notice = "옆방 손님이 곧 나간다고 해요.",
				followups = {
					squeeze = "끝자리는 불편한 대신 먼저 나갈 수 있어요. 어떤 기준으로 정할까요?",
					split = "두 테이블 분위기가 달라요. 누가 어느 쪽에 앉을까요?",
					move = "새 가게까지 걸어서 10분이래요. 가는 길에 뭘 할까요?",
					undecided = "직원이 조금 더 기다려 준대요. 다른 방법은 없을까요?",
				},
			},
			{
				id = "dinner_menu",
				situation = "정해진 금액 안에서 다 같이 먹을 것을 골라야 해요.",
				problem = "종류를 늘리면 양이 줄고, 나눠 고르면 오래 기다려야 해요.",
				goal = "양, 종류, 기다리는 시간 중 무엇을 먼저 챙길지 정해 보세요.",
				options = {
					{ id = "plenty", text = "한 종류를 넉넉하게" },
					{ id = "variety", text = "두 종류를 조금씩" },
					{ id = "later", text = "일부 먼저, 나머지는 나중에" },
				},
				notice = "한 번 고르면 바꿀 수 없대요.",
				followups = {
					plenty = "곁들일 것은 하나만 더 고를 수 있대요. 무엇을 챙길까요?",
					variety = "한쪽만 먼저 나왔어요. 바로 나눌지 함께 기다릴지 정해 볼까요?",
					later = "먼저 나온 몫이 적어요. 조금씩 나눌지, 배고픈 쪽부터 줄지 정해 볼까요?",
					undecided = "바로 받을 수 있는 양이 줄었어요. 적게 먼저 받을지, 더 기다릴지 골라 볼까요?",
				},
			},
			{
				id = "dinner_bill",
				situation = "식사가 끝나고 영수증이 나왔어요.",
				problem = "생각보다 금액이 훨씬 커요.",
				goal = "어떻게 낼지 정해 보세요.",
				options = {
					{ id = "equal", text = "똑같이 나눠 내기" },
					{ id = "eaten", text = "먹은 만큼 내기" },
					{ id = "boss", text = "제일 높은 사람이 내기" },
				},
				notice = "가게에서 할인 쿠폰을 준대요.",
				followups = {
					equal = "적게 먹은 사람이 억울하대요. 뭐라고 설득할까요?",
					eaten = "누가 뭘 먹었는지 기억이 안 나요. 어떻게 따질까요?",
					boss = "높은 사람이 카드를 두고 왔대요. 이제 어떡하죠?",
					undecided = "가게가 오늘만 여러 번 나눠 결제해 준대요. 어떤 기준으로 나눌까요?",
				},
			},
		},
		events = {
			"갑자기 정전이 됐다가 다시 불이 들어왔어요",
			"{name} 앞에 처음 보는 메뉴가 나왔어요",
			"옆 테이블에서 축하 노래가 들려요",
			"내일 아침 모임이 갑자기 잡혔어요",
			"2차를 갈지 말지 의견이 갈려요",
			"{name}{이가} 건배사를 맡게 됐어요",
			"{name} 휴대폰으로 급한 연락이 왔어요",
		},
		topics = {
			"회식 메뉴로 최악은?",
			"들어 본 최고의 칭찬",
			"2차로 가고 싶은 곳",
			"보너스가 나오면 하고 싶은 것",
			"일하다 생길 법한 황당한 일",
		},
	},
	{
		name = "방과 후 우리 반",
		roles = { "반장 후보", "부반장", "전학생", "운동부장", "청소 당번", "지각 대장", "수학 천재", "미술부", "방송부", "학생회장", "잠꾸러기", "축구부" },
		missions = {
			{
				id = "class_election",
				situation = "가상의 후보 셋이 서로 다른 공약을 냈어요.",
				problem = "이번에는 한 가지 일에만 힘을 쓸 수 있어요.",
				goal = "우리 반에 먼저 필요한 일을 골라 보세요.",
				options = {
					{ id = "play", text = "함께 노는 틈 늘리기" },
					{ id = "share", text = "같이 쓰는 물건 늘리기" },
					{ id = "rest", text = "조용히 쉴 곳 꾸미기" },
				},
				notice = "도와줄 사람이 줄어서 계획을 작게 줄여야 해요.",
				followups = {
					play = "여럿이 모이면 시끄러워질 수 있대요. 쉬는 쪽도 편할 규칙을 정해 볼까요?",
					share = "둘 곳이 부족해요. 적게 들일지, 놓는 곳을 바꿀지 정해 볼까요?",
					rest = "쓸 수 있는 자리가 적어요. 차례로 쓸지, 머무는 시간을 줄일지 정해 볼까요?",
					undecided = "작게 한 번 해 볼 기회가 생겼어요. 무엇을 먼저 해 보고 판단할까요?",
				},
			},
			{
				id = "class_outing",
				situation = "반 단체 나들이 장소를 정해야 해요.",
				problem = "돈은 적고 가고 싶은 곳은 제각각이에요.",
				goal = "모두 갈 만한 곳을 정해 보세요.",
				options = {
					{ id = "mountain", text = "가까운 산" },
					{ id = "museum", text = "박물관" },
					{ id = "camp", text = "캠핑장" },
				},
				notice = "버스를 한 대만 빌릴 수 있대요.",
				followups = {
					mountain = "정상까지 못 가겠다는 친구가 있어요. 어떻게 할까요?",
					museum = "지루할 거라는 반응이 많아요. 재밌게 만들 방법은?",
					camp = "밤에 할 놀이를 정해야 해요. 뭐가 좋을까요?",
					undecided = "담임이 다음 주까지 정하래요. 후보를 줄여 볼까요?",
				},
			},
			{
				id = "class_festival",
				situation = "학교 축제에서 반 부스를 맡았어요.",
				problem = "준비할 시간이 이틀뿐이에요.",
				goal = "무슨 부스를 열지 정해 보세요.",
				options = {
					{ id = "food", text = "간식 가게" },
					{ id = "haunted", text = "귀신의 집" },
					{ id = "photo", text = "포토존" },
				},
				notice = "옆 반도 같은 부스를 준비 중이래요.",
				followups = {
					food = "재료값이 모자라요. 어떻게 마련할까요?",
					haunted = "무서운 역할이 인기가 없어요. 어떻게 하면 하고 싶어질까요?",
					photo = "꾸밀 소품이 부족해요. 뭘 가져올까요?",
					undecided = "옆 반이 같이 하자고 제안했어요. 합칠까요, 따로 할까요?",
				},
			},
		},
		events = {
			"담임이 갑자기 문을 열었어요",
			"{name} 서랍에서 쪽지가 나왔어요",
			"내일 깜짝 퀴즈가 있다는 공지가 떴어요",
			"점심 메뉴가 바뀌었다는 소문이 돌아요",
			"{name}{이가} 반장 후보로 추천됐어요",
			"창밖에 갑자기 비가 쏟아져요",
			"에어컨이 고장 났어요",
		},
		topics = {
			"가장 좋아했던 점심 메뉴",
			"학교에서 제일 무서운 장소",
			"반장이 되면 바꾸고 싶은 것",
			"기억에 남는 수업 시간",
			"쉬는 시간에 제일 많이 하는 것",
		},
	},
	{
		name = "단체 나들이 계획",
		roles = { "총무", "운전 담당", "기록 담당", "맛집 탐정", "길치", "짐꾼", "일정 담당", "늦잠 대장", "분위기 메이커", "안전 요원", "기념품 수집가", "캠핑 고수" },
		missions = {
			{
				id = "outing_place",
				situation = "다 같이 1박 2일로 놀러 가기로 했어요.",
				problem = "산파, 계곡파, 도시파로 의견이 갈렸어요.",
				goal = "어디로 갈지 정해 보세요.",
				options = {
					{ id = "mountain", text = "산" },
					{ id = "valley", text = "계곡" },
					{ id = "city", text = "도시 구경" },
				},
				notice = "출발 날 비 소식이 있대요.",
				followups = {
					mountain = "등산화가 없는 사람이 있어요. 어떻게 할까요?",
					valley = "물에 들어가기 싫은 사람이 있어요. 뭘 하면 좋을까요?",
					city = "볼 곳이 너무 많아요. 딱 세 군데만 고른다면?",
					undecided = "비가 올 수도 있으니 실내에서 할 것도 하나 넣재요. 뭘 넣을까요?",
				},
			},
			{
				id = "outing_ride",
				situation = "이동 수단을 정해야 해요.",
				problem = "차는 한 대뿐이고 사람은 많아요.",
				goal = "어떻게 갈지 정해 보세요.",
				options = {
					{ id = "car", text = "차로 나눠서 두 번 가기" },
					{ id = "train", text = "기차" },
					{ id = "bus", text = "버스 대절" },
				},
				notice = "기차 좌석이 거의 다 팔렸대요.",
				followups = {
					car = "먼저 간 쪽이 한참 기다려야 해요. 기다리는 동안 뭘 할까요?",
					train = "가는 동안 먹을 간식을 정해야 해요. 뭐가 좋을까요?",
					bus = "가는 동안 할 놀이를 정해 볼까요?",
					undecided = "몇 명만 먼저 출발하자는 말이 나와요. 어떻게 나눌까요?",
				},
			},
			{
				id = "outing_stay",
				situation = "묵을 곳을 골라야 해요.",
				problem = "좋은 곳은 비싸고 싼 곳은 멀어요.",
				goal = "어디서 잘지 정해 보세요.",
				options = {
					{ id = "cheap", text = "싸고 먼 곳" },
					{ id = "nice", text = "비싸고 가까운 곳" },
					{ id = "tent", text = "텐트 치기" },
				},
				notice = "한 곳이 갑자기 반값이 됐대요.",
				followups = {
					cheap = "돌아오는 길이 너무 멀어요. 어떻게 버틸까요?",
					nice = "누가 돈을 더 낼지 정해야 해요. 어떻게 나눌까요?",
					tent = "텐트 치는 법을 아무도 몰라요. 어떤 순서로 해 볼까요?",
					undecided = "두 곳 중 한 곳만 남았대요. 어느 쪽을 포기할까요?",
				},
			},
		},
		events = {
			"쓸 수 있는 돈이 절반으로 줄었어요",
			"{name}{이가} 신분증을 잃어버렸대요",
			"예약 하나가 취소됐어요",
			"{name}{이가} 맛집 목록을 들고 왔어요",
			"기차표가 한 장 모자라요",
			"근처에서 축제가 열린다는 소식이에요",
			"{name} 짐이 너무 무거워요",
		},
		topics = {
			"놀러 가서 꼭 먹어야 하는 것",
			"함께 움직일 때 편한 규칙",
			"산이 좋아, 물가가 좋아?",
			"짐에 꼭 챙기는 것",
			"언젠가 가 보고 싶은 나라",
		},
	},
	{
		name = "동네 중고 장터",
		roles = { "판매왕", "흥정의 달인", "수집가", "구경꾼", "가게 주인", "단골손님", "초보 판매자", "감정사", "배달원", "경매사", "짠돌이", "부자 손님" },
		missions = {
			{
				id = "market_console",
				situation = "장터에 낡은 오락기가 나왔어요.",
				problem = "사고 싶은 사람은 많은데 하나뿐이에요.",
				goal = "누가 어떻게 가져갈지 정해 보세요.",
				options = {
					{ id = "auction", text = "경매로 팔기" },
					{ id = "first", text = "먼저 온 사람에게" },
					{ id = "share", text = "같이 사서 돌려 쓰기" },
				},
				notice = "주인이 가격을 깎아 줄 수도 있대요.",
				followups = {
					auction = "가격이 너무 올라갔어요. 여기서 멈출까요?",
					first = "줄을 섰는데 새치기가 생겼어요. 어떻게 할까요?",
					share = "돌려 쓰는 규칙이 필요해요. 하루씩? 한 시간씩? 정해 볼까요?",
					undecided = "다른 손님이 더 높은 값을 불렀어요. 맞출까요, 포기할까요?",
				},
			},
			{
				id = "market_booth",
				situation = "우리도 장터에 작은 자리를 하나 받았어요.",
				problem = "싸게 내놓으면 남는 돈이 적고, 자세히 알리면 오래 걸려요.",
				goal = "어떤 방식으로 팔지 정해 보세요.",
				options = {
					{ id = "cheap", text = "값을 낮춰 빨리 팔기" },
					{ id = "show", text = "하나씩 보여 주며 제값에" },
					{ id = "bundle", text = "묶음으로만 팔기" },
				},
				notice = "마감 뒤 남은 건 직접 정리해야 한대요.",
				followups = {
					cheap = "손님이 더 깎아 달래요. 어디까지 낮출지 기준을 정해 볼까요?",
					show = "한 손님이 오래 머물러요. 뒤에서 기다리는 손님은 어떻게 챙길까요?",
					bundle = "한 개만 사고 싶은 손님이 왔어요. 묶음을 풀지, 그대로 둘지 정해 볼까요?",
					undecided = "작은 물건부터 먼저 내놓을 수 있대요. 무엇을 기준으로 첫 물건을 고를까요?",
				},
			},
			{
				id = "market_missing",
				situation = "진열해 둔 물건 하나가 사라졌어요.",
				problem = "누가 가져갔는지 아무도 못 봤대요.",
				goal = "어떻게 해결할지 정해 보세요.",
				options = {
					{ id = "search", text = "다 같이 찾아보기" },
					{ id = "ask", text = "주변 가게에 물어보기" },
					{ id = "forget", text = "잊고 장사하기" },
				},
				notice = "물건이 놓였던 자리를 본 사람이 있대요. 어디부터 확인할까요?",
				followups = {
					search = "찾다가 다른 물건이 나왔어요. 이건 누구 걸까요?",
					ask = "옆 가게도 물건을 잃어버렸대요. 같이 대책을 세울까요?",
					forget = "손님이 그 물건을 찾아요. 뭐라고 할까요?",
					undecided = "장터 관리인이 같이 찾아 준대요. 어디부터 볼까요?",
				},
			},
		},
		events = {
			"{name} 물건에 말도 안 되는 가격이 붙었어요",
			"깜짝 할인 시간이 시작됐어요",
			"가짜 명품이 돌고 있다는 소문이 나요",
			"{name}{이가} 전 재산을 걸고 경매에 참여했어요",
			"날씨가 나빠져서 장터가 곧 문을 닫아요",
			"{name} 가게에 손님이 몰려왔어요",
			"경품 추첨이 곧 시작돼요",
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

-- Topics that fit any theme (shown only when the table goes quiet).
Themes.general = {
	"요즘 제일 맛있게 먹은 음식",
	"무인도에 가져갈 물건 세 가지",
	"키우고 싶은 동물과 이름",
	"쉬는 날에 하고 싶은 것",
	"최근에 본 재밌는 영상",
	"하루 동안 투명인간이 된다면",
	"제일 좋아하는 계절과 이유",
	"로블록스에서 제일 좋아하는 곳",
	"초능력 하나를 고른다면",
	"어렸을 때 꿈",
	"요즘 제일 웃겼던 일",
	"받으면 기분 좋은 깜짝 이벤트",
	"비 오는 날 하면 좋은 것",
	"가장 좋아하는 캐릭터와 이유",
	"아침에 일어나서 제일 먼저 하는 일",
}

return Themes
