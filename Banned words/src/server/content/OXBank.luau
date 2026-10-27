--!strict
-- O/X quiz statements (bundle 8c, owner 2026-10-24). Data only: `s` is read out on screen, `o` is true when it is
-- right (O) and false when it is wrong (X). Plain facts anyone around 17 can know or guess, stable over time, with the
-- condition that makes them true spelled out (1기압, 하계, 같은 부피); nothing sensitive; about half O and half X.
-- None repeats a fact of the quiz bank or the number bank (one game would give another's answer away). Statements
-- containing a banned word in play are skipped at run time.

-- `hard`: the hard mode asks it too (with OXBankHard's; bundle 11b).
export type Statement = { s: string, o: boolean, hard: boolean? }

local OXBank: { Statement } = {
	-- Animals and plants
	{ s = "코알라는 곰의 한 종류다", o = false },
	{ s = "고래는 포유류다", o = true },
	{ s = "펭귄은 날 수 없다", o = true },
	{ s = "상어는 어류다", o = true },
	{ s = "개구리는 파충류다", o = false },
	{ s = "물고기는 모두 알을 낳는다", o = false },
	{ s = "닭은 하늘을 오래 날 수 있다", o = false },
	{ s = "남극에는 북극곰이 산다", o = false },
	{ s = "고래상어는 고래가 아니라 상어다", o = true, hard = true },
	{ s = "달팽이는 이빨이 있다", o = true, hard = true },
	{ s = "코끼리는 육지에서 가장 무거운 동물이다", o = true },
	{ s = "카멜레온은 몸 색을 바꿀 수 있다", o = true },
	{ s = "꿀벌은 춤으로 꽃이 있는 곳을 알린다", o = true },
	{ s = "금붕어의 기억력은 3초뿐이다", o = false, hard = true },
	{ s = "타조는 위험하면 머리를 모래에 묻는다", o = false, hard = true },
	{ s = "황소는 빨간색을 보면 흥분한다", o = false, hard = true },
	{ s = "토마토는 식물학적으로 열매(과실)다", o = true, hard = true },
	{ s = "바나나는 나무가 아니라 풀에서 자란다", o = true, hard = true },
	{ s = "당근은 원래 모두 주황색이었다", o = false, hard = true },
	{ s = "식물도 호흡을 한다", o = true },
	-- Science and the sky
	{ s = "1기압에서 물은 섭씨 0도에 끓는다", o = false },
	{ s = "빛은 소리보다 빠르다", o = true },
	{ s = "북극은 남극보다 더 춥다", o = false, hard = true },
	{ s = "번개는 전기 현상이다", o = true },
	{ s = "번개는 같은 곳에 두 번 치지 않는다", o = false, hard = true },
	{ s = "화산은 바닷속에도 있다", o = true },
	{ s = "달은 스스로 빛을 낸다", o = false },
	{ s = "달에는 공기가 거의 없다", o = true },
	{ s = "해는 서쪽에서 뜬다", o = false },
	{ s = "만리장성은 달에서 맨눈으로 보인다", o = false, hard = true },
	{ s = "얼음은 같은 부피의 물보다 가벼워서 물에 뜬다", o = true },
	{ s = "사과는 물에 뜬다", o = true, hard = true },
	{ s = "1kg짜리 쇠가 1kg짜리 솜보다 무겁다", o = false },
	{ s = "자석의 같은 극끼리는 서로 밀어낸다", o = true },
	{ s = "다이아몬드는 탄소로 이루어져 있다", o = true },
	{ s = "금은 자석에 잘 붙는다", o = false },
	{ s = "사막에도 비가 내린다", o = true },
	{ s = "몸속 정맥을 흐르는 피는 파란색이다", o = false, hard = true },
	{ s = "사람은 뇌의 10%만 쓴다", o = false, hard = true },
	-- Places, culture and numbers
	{ s = "한글을 만든 왕은 세종대왕이다", o = true },
	{ s = "올림픽 금메달은 순금으로 만든다", o = false },
	{ s = "대한민국의 나라꽃은 무궁화다", o = true },
	{ s = "설날은 음력 1월 1일이다", o = true },
	{ s = "백두산은 한반도에서 가장 높은 산이다", o = true },
	{ s = "이집트에는 피라미드가 있다", o = true },
	{ s = "손톱은 발톱보다 빨리 자란다", o = true },
	{ s = "하계 올림픽은 4년마다 열린다", o = true },
	{ s = "해바라기는 다 자란 뒤에도 하루 종일 해를 따라 돈다", o = false, hard = true },
	{ s = "모든 소수는 홀수다", o = false },
	{ s = "0은 짝수다", o = true },
}

return OXBank
