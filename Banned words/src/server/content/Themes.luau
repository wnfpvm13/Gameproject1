--!strict
-- Round themes and their mission cards (data only, V2.1). A theme gives the table a reason to talk:
-- three missions played in this order (a little story), quiet-time events and topic cards. No personal roles
-- (owner 2026-10-20): everyone shares the same scene. Every place and group in a card is imaginary, so it works
-- with 2 or 10 players.
--
-- Mission card = title, situation, problem, goal, 2-3 options. Stages: a notice after a while, a short vote, then
-- a follow-up that depends on the vote (or "undecided" on a tie / no votes). Nobody dies for a mission result.
--
-- Writing rules (docs/DESIGN_V2.md, V2.1):
--   - never tell anyone to say a specific word; every card must be answerable in many ways;
--   - NO text here may contain any word-bank word (or alias): the game never adapts cards to the secret words,
--     so the text itself must be safe for every word. tools/check_content.luau checks this — run it after edits;
--   - nothing aggressive, nothing asking for real personal info, nobody singled out.

export type Option = { id: string, text: string }

export type Mission = {
	id: string,
	title: string, -- short event name shown on the collapsed card
	situation: string,
	problem: string,
	goal: string,
	options: { Option },
	notice: string, -- shown MISSION_NOTICE_AT seconds in (raises the stakes)
	followups: { [string]: string }, -- option id (or "undecided") -> new condition after the vote
}

export type Theme = {
	name: string,
	missions: { Mission },
	events: { string },
	topics: { string },
}

local Themes = {}

Themes.list = {
	{
		name = "회식 자리",
		missions = {
			{
				id = "dinner_seats",
				title = "좁은 방 대작전",
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
				title = "주문 눈치싸움",
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
				title = "영수증 대소동",
				situation = "예산은 20만 원인데 영수증에는 42만 원이 적혀 있어요.",
				problem = "누가 얼마나 더 내야 할지 아무도 몰라요.",
				goal = "어떻게 해결할지 정해 보세요.",
				options = {
					{ id = "check", text = "주문 내역 확인" },
					{ id = "pool", text = "돈 더 모으기" },
					{ id = "ask", text = "직원에게 문의" },
				},
				notice = "같은 메뉴가 영수증에 두 번 적혀 있대요.",
				followups = {
					check = "중복을 빼니 총액이 20만 원으로 줄었어요. 남은 할인은 어디에 쓸까요?",
					pool = "모자란 돈을 모으기로 했어요. 어떤 기준으로 나눌까요?",
					ask = "직원이 실수를 인정하고 디저트를 준대요. 무엇으로 받을까요?",
					undecided = "가게가 오늘만 여러 번 나눠 결제해 준대요. 어떤 기준으로 나눌까요?",
				},
			},
		},
		events = {
			"갑자기 정전이 됐다가 다시 불이 들어왔어요",
			"처음 보는 메뉴가 테이블에 올라왔어요",
			"옆 테이블에서 축하 노래가 들려요",
			"내일 아침 모임이 갑자기 잡혔어요",
			"2차를 갈지 말지 의견이 갈려요",
			"건배사를 할 사람이 필요해요",
			"누군가의 휴대폰이 계속 울려요",
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
		missions = {
			{
				id = "class_election",
				title = "공약 고르기",
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
				title = "나들이 장소 정하기",
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
				title = "축제 부스 준비",
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
			"서랍에서 주인 없는 쪽지가 나왔어요",
			"내일 깜짝 퀴즈가 있다는 공지가 떴어요",
			"점심 메뉴가 바뀌었다는 소문이 돌아요",
			"후보가 한 명 더 나왔대요",
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
		missions = {
			{
				id = "outing_place",
				title = "어디로 갈까",
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
				title = "이동 작전",
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
				title = "숙소 예약 사고",
				situation = "단체로 묵을 호텔을 예약했는데 날짜가 하루 어긋났어요.",
				problem = "바꾸면 돈이 들고, 그대로 두면 일정이 꼬여요.",
				goal = "비용과 일정을 어떻게 맞출지 정해 보세요.",
				options = {
					{ id = "change", text = "날짜 바꾸기" },
					{ id = "other", text = "다른 숙소 찾기" },
					{ id = "plan", text = "일정 바꾸기" },
				},
				notice = "날짜를 바꾸면 추가 요금을 내야 한대요.",
				followups = {
					change = "예약을 바꿨어요. 추가 요금 3만 원은 어떻게 나눌까요?",
					other = "근처에 방이 하나 남았대요. 좁아도 갈까요, 더 찾아볼까요?",
					plan = "하루 늦게 출발하기로 했어요. 남는 하루엔 뭘 할까요?",
					undecided = "호텔이 한 시간만 기다려 준대요. 무엇부터 확인할까요?",
				},
			},
		},
		events = {
			"쓸 수 있는 돈이 절반으로 줄었어요",
			"누군가 신분증을 두고 왔대요",
			"예약 하나가 취소됐어요",
			"맛집 목록이 새로 도착했어요",
			"기차표가 한 장 모자라요",
			"근처에서 축제가 열린다는 소식이에요",
			"짐 하나가 너무 무거워요",
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
		missions = {
			{
				id = "market_console",
				title = "중고 로봇 흥정",
				situation = "장터에 중고 로봇이 50만 원에 나왔어요.",
				problem = "비싸지만 갖고 싶다는 사람이 많아요.",
				goal = "살 가치가 있는지 정해 보세요.",
				options = {
					{ id = "haggle", text = "가격 깎기" },
					{ id = "test", text = "성능 확인" },
					{ id = "pass", text = "거래 포기" },
				},
				notice = "춤은 잘 추는데 청소는 서툴대요.",
				followups = {
					haggle = "판매자가 5만 원만 깎아 준대요. 더 깎을까요, 살까요?",
					test = "로봇이 혼자 춤을 추기 시작했어요. 이 성능이면 얼마가 적당할까요?",
					pass = "판매자가 10만 원을 낮춰 다시 제안했어요. 다시 생각해 볼까요?",
					undecided = "다른 손님이 관심을 보여요. 같이 사서 나눠 쓸까요?",
				},
			},
			{
				id = "market_booth",
				title = "장사 방식 고르기",
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
				title = "사라진 물건",
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
			"어떤 물건에 말도 안 되는 가격이 붙었어요",
			"깜짝 할인 시간이 시작됐어요",
			"가짜 명품이 돌고 있다는 소문이 나요",
			"누군가 전 재산을 걸고 경매에 참여했어요",
			"날씨가 나빠져서 장터가 곧 문을 닫아요",
			"우리 가게에 손님이 몰려왔어요",
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
