--!strict
-- Round topics and question cards: give strangers something to talk about, and break silence
-- (staying quiet is the safest strategy in a forbidden-word game, so the cards force everyone to speak).

local Prompts = {}

local TOPICS = {
	"여름방학에 꼭 하고 싶은 것",
	"요즘 제일 맛있게 먹은 음식",
	"학교나 학원에서 있었던 웃긴 일",
	"무인도에 가져갈 물건 세 가지",
	"키우고 싶은 동물과 이름",
	"주말에 친구랑 가고 싶은 곳",
	"최근에 본 재밌는 영상",
	"내가 만약 하루 동안 투명인간이라면",
	"제일 좋아하는 계절과 이유",
	"로블록스에서 제일 좋아하는 게임",
}

local QUESTIONS = {
	"어제 저녁에 뭐 먹었어요?",
	"요즘 제일 좋아하는 노래는?",
	"아침에 일어나서 제일 먼저 하는 일은?",
	"가장 가 보고 싶은 나라와 이유는?",
	"용돈이 생기면 뭐부터 살 거예요?",
	"제일 무서웠던 경험을 말해 주세요",
	"좋아하는 과목과 싫어하는 과목은?",
	"지금 방에 있는 물건 세 가지를 말해 주세요",
	"초능력 하나를 고른다면?",
	"오늘 하루를 한 문장으로 말해 주세요",
	"좋아하는 간식을 설명해 주세요",
	"친구에게 받고 싶은 선물은?",
	"비 오는 날 하면 좋은 것은?",
	"어렸을 때 꿈은 뭐였어요?",
	"최근에 웃었던 일은?",
	"가장 좋아하는 캐릭터와 이유는?",
}

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

function Prompts.topic(rng: Random): string
	return pick(TOPICS, rng)
end

function Prompts.question(rng: Random): string
	return pick(QUESTIONS, rng)
end

return Prompts
