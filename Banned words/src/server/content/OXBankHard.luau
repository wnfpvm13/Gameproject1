--!strict
-- The hard mode's new O/X statements (똑똑이 모드, bundle 11b/11c, owner 2026-10-27): facts easy to get wrong, stable over
-- time. The mode also asks the normal bank's statements marked `hard` (missions/OXQuiz; the same tables). None gives
-- away an answer of the hard mode's quizzes or the number bank. Data only.
type Statement = { s: string, o: boolean, hard: boolean? } -- (as OXBank's: content modules do not require each other)

local OXBankHard: { Statement } = {
	{ s = "박쥐는 앞을 전혀 보지 못한다", o = false },
	{ s = "문어의 피는 파란빛을 띤다", o = true },
	{ s = "낙타의 혹에는 주로 물이 들어 있다", o = false },
	{ s = "지구는 완전한 공 모양이다", o = false },
	{ s = "다이아몬드도 아주 높은 온도에서는 불에 탄다", o = true },
	{ s = "유리창은 오랜 세월이 지나면 아래로 흘러내린다", o = false },
	{ s = "혀는 부위마다 느끼는 맛이 따로 정해져 있다", o = false },
	{ s = "삼킨 껌은 7년 동안 배 속에 남는다", o = false },
	{ s = "모기는 수컷도 사람의 피를 빤다", o = false },
	{ s = "고양이는 단맛을 느끼지 못한다", o = true },
	{ s = "북극성은 밤하늘에서 가장 밝은 별이다", o = false },
	{ s = "해마는 수컷이 새끼를 낳는다", o = true },
	{ s = "펭귄은 북극에도 산다", o = false },
	{ s = "금성에서는 해가 서쪽에서 뜬다", o = true },
	{ s = "달이 스스로 한 바퀴 도는 시간과 지구를 한 바퀴 도는 시간은 같다", o = true },
	{ s = "물은 섭씨 4도 근처에서 밀도가 가장 크다", o = true },
	{ s = "알루미늄은 자석에 붙지 않는다", o = true },
	{ s = "갓난아기는 어른보다 뼈의 개수가 많다", o = true },
	{ s = "일란성 쌍둥이도 지문은 서로 다르다", o = true },
	{ s = "에베레스트산은 지금도 해마다 조금씩 높아진다", o = true },
	{ s = "훈민정음은 처음 만들었을 때 28자였다", o = true },
	{ s = "자유의 여신상은 프랑스가 미국에 선물했다", o = true },
	{ s = "에펠탑은 여름에 조금 더 높아진다", o = true },
	{ s = "바나나는 아주 약한 방사선을 낸다", o = true },
	{ s = "상어의 뼈대는 연골로 되어 있다", o = true },
	{ s = "땅콩은 땅속에서 열매가 여문다", o = true },
	{ s = "감자는 뿌리가 아니라 줄기가 변한 것이다", o = true },
	{ s = "소의 위는 네 부분으로 나뉜다", o = true },
	{ s = "사람의 머리카락은 죽은 뒤에도 계속 자란다", o = false },
	{ s = "물고기는 잠을 자지 않는다", o = false },
}

return OXBankHard
