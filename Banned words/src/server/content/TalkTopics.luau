--!strict
-- Topics of the banned-word talk (docs/DESIGN_V3.md §5-6; bundle 6a, owner 2026-10-23). Data only. Everyone talks
-- about the topic for TALK_SECONDS and tries to make the others say their banned word, so a topic should be easy for
-- anyone to talk about together and pull in lots of everyday words. Like the one-word topics, no topic names or points
-- at a real person, asks for personal details (school, where you live, real name, contacts, age, looks) or touches
-- sensitive matters. The words are drawn after the topic and never inside it (WordService).

local TalkTopics: { string } = {
	"편의점에서 제일 맛있는 것",
	"여름 방학에 하고 싶은 일",
	"무인도에 딱 세 개만 가져간다면",
	"제일 맛있었던 길거리 음식",
	"비 오는 날 하기 좋은 일",
	"요즘 자주 듣는 노래 이야기",
	"놀이공원에서 제일 먼저 탈 것",
	"겨울이 오면 생각나는 것",
	"하루 동안 투명 인간이 된다면",
	"최고의 야식 메뉴",
	"캠핑 가면 꼭 챙길 것",
	"돈 걱정 없이 하루를 보낸다면",
	"어릴 때 좋아했던 장난감",
	"제일 무서웠던 놀이기구",
	"집에서 뒹굴 때 하는 일",
	"좋아하는 과자 순위",
	"바다와 산 중에 고른다면",
	"동물과 대화할 수 있다면",
	"생일에 받고 싶은 선물",
	"최고의 아침 메뉴",
	"게임 속 세계에 들어간다면",
	"좀비가 나타나면 숨을 곳",
	"우주여행을 간다면 할 일",
	"제일 기억에 남는 여행",
	"요즘 빠진 간식",
	"로봇 친구가 생긴다면",
	"휴대폰 없이 하루 보내기",
	"제일 좋아하는 날씨",
	"소풍 도시락에 넣을 것",
	"마법 학교에 입학한다면",
	"카페에 가면 시키는 것",
	"영화관에서 꼭 사는 것",
	"하늘을 날 수 있다면 갈 곳",
	"냉장고에 항상 있는 것",
	"축제에서 하고 싶은 것",
	"반려동물을 키운다면",
	"시간을 멈출 수 있다면",
	"최애 피자 토핑",
	"꿈에서 본 이상한 장면",
	"눈이 펑펑 오는 날 할 일",
}

return TalkTopics
