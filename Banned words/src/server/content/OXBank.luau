--!strict
-- O/X quiz statements (bundle 8c, owner 2026-10-24). Data only: `s` is read out on screen, `o` is true when it is
-- right (O) and false when it is wrong (X). Plain facts anyone around 17 can know or guess, stable over time, with the
-- condition that makes them true spelled out (1기압, 하계, 같은 부피); nothing sensitive; about half O and half X.
-- None repeats a fact of the quiz bank or the number bank (one game would give another's answer away). Statements
-- containing a banned word in play are skipped at run time.

export type Statement = { s: string, o: boolean }

local OXBank: { Statement } = {
	-- Animals and plants
	{ s = "거미는 곤충이다", o = false },
	{ s = "고래는 포유류다", o = true },
	{ s = "펭귄은 날 수 없다", o = true },
	{ s = "상어는 어류다", o = true },
	{ s = "개구리는 파충류다", o = false },
	{ s = "물고기는 모두 알을 낳는다", o = false },
	{ s = "닭은 하늘을 오래 날 수 있다", o = false },
	{ s = "남극에는 북극곰이 산다", o = false },
	{ s = "북극에는 펭귄이 산다", o = false },
	{ s = "오스트레일리아에는 캥거루가 산다", o = true },
	{ s = "코끼리는 육지에서 가장 무거운 동물이다", o = true },
	{ s = "카멜레온은 몸 색을 바꿀 수 있다", o = true },
	{ s = "꿀벌은 춤으로 꽃이 있는 곳을 알린다", o = true },
	{ s = "금붕어의 기억력은 3초뿐이다", o = false },
	{ s = "타조는 위험하면 머리를 모래에 묻는다", o = false },
	{ s = "황소는 빨간색을 보면 흥분한다", o = false },
	{ s = "토마토는 식물학적으로 열매(과실)다", o = true },
	{ s = "바나나는 나무가 아니라 풀에서 자란다", o = true },
	{ s = "당근은 원래 모두 주황색이었다", o = false },
	{ s = "식물도 호흡을 한다", o = true },
	-- Science and the sky
	{ s = "1기압에서 물은 섭씨 0도에 끓는다", o = false },
	{ s = "빛은 소리보다 빠르다", o = true },
	{ s = "북극은 남극보다 더 춥다", o = false },
	{ s = "번개는 전기 현상이다", o = true },
	{ s = "번개는 같은 곳에 두 번 치지 않는다", o = false },
	{ s = "화산은 바닷속에도 있다", o = true },
	{ s = "달은 스스로 빛을 낸다", o = false },
	{ s = "달에는 공기가 거의 없다", o = true },
	{ s = "해는 서쪽에서 뜬다", o = false },
	{ s = "만리장성은 달에서 맨눈으로 보인다", o = false },
	{ s = "얼음은 같은 부피의 물보다 가벼워서 물에 뜬다", o = true },
	{ s = "사과는 물에 뜬다", o = true },
	{ s = "1kg짜리 쇠가 1kg짜리 솜보다 무겁다", o = false },
	{ s = "자석의 같은 극끼리는 서로 밀어낸다", o = true },
	{ s = "다이아몬드는 탄소로 이루어져 있다", o = true },
	{ s = "금은 자석에 잘 붙는다", o = false },
	{ s = "사막에도 비가 내린다", o = true },
	{ s = "피는 몸 밖으로 나오면 파랗게 변한다", o = false },
	{ s = "사람은 뇌의 10%만 쓴다", o = false },
	-- Places, culture and numbers
	{ s = "한글을 만든 왕은 세종대왕이다", o = true },
	{ s = "대한민국의 수도는 부산이다", o = false },
	{ s = "대한민국의 나라꽃은 무궁화다", o = true },
	{ s = "설날은 음력 1월 1일이다", o = true },
	{ s = "백두산은 한반도에서 가장 높은 산이다", o = true },
	{ s = "이집트에는 피라미드가 있다", o = true },
	{ s = "에펠탑은 영국 런던에 있다", o = false },
	{ s = "하계 올림픽은 4년마다 열린다", o = true },
	{ s = "정사각형은 네 변의 길이가 모두 같다", o = true },
	{ s = "모든 소수는 홀수다", o = false },
	{ s = "0은 짝수다", o = true },
}

return OXBank
